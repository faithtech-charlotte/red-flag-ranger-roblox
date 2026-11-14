--[[
	TrailWalk: a walk around the Meadow Trail with your dog on a leash.

	Start at the trailhead (tagged "TrailHead"). The leash clips on and the
	dog walks beside you. Follow the paw markers (MarkerIndex 1..N) in
	order; sniff spots (SniffIndex) are small bonuses. Two or three times
	per walk a squirrel darts out and the dog lunges: hold the button to keep
	the leash steady. A steady hold settles the dog; a miss means it tugs a
	few studs off the path and comes back. The walk never fails.

	Server-authoritative (rules in Logic/TrailRules):
	  * one run id per walk; every client message names it
	  * markers are credited from the player's position, checked here, in
	    order, once each, no faster than a minimum time apart
	  * the server opens each squirrel challenge (own id, own window) and
	    measures the hold between the client's holdStart and holdEnd
	  * trail stars (1-3) are computed here and passed to
	    Activity.complete as the rating
	Cancelling (Stop, whistle, leaving the trail, respawn, another activity)
	voids the run and cleans up the leash, squirrel and target.

	The dog is only ever moved through PetService states: Following while
	walking, MovingToTarget (byActivity, a target on the ground) for the
	lunge and tug, then Following again.
]]

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Places = require(ReplicatedStorage.Shared.Places)
local ObstacleHop = require(ReplicatedStorage.Shared.ObstacleHop)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TrailRules = require(script.Parent.Parent.Logic.TrailRules)

local MAX_RUN_SECONDS = 300
local LEAVE_MARGIN = 30 -- studs outside the trail area before the walk ends
local START_DISTANCE = 14
local LUNGE_STUDS = 3.5
local TUG_STUDS = 3.5 -- further, on a miss
local TUG_SECONDS = 1.4
local LEASH_COLOR = Color3.fromRGB(239, 71, 111)

local TrailWalk = {}
local S, Activity

type Entry = {
	run: TrailRules.Run,
	session: any,
	challengeAt: { [number]: boolean },
	challengeN: number,
	pending: number, -- squirrel moments reached but not yet opened
	leash: Beam?,
	squirrel: Model?,
	target: Attachment?,
	inward: Vector3?,
}
local walks: { [Player]: Entry } = {}
local markers: { Vector3 } = {}
local sniffs: { Vector3 } = {}

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function groundY(x: number, z: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = {}
	local pets = workspace:FindFirstChild("Pets")
	if pets then
		table.insert(ignore, pets)
	end
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	for _, entry in walks do
		if entry.squirrel then
			table.insert(ignore, entry.squirrel)
		end
	end
	-- The ground under a fence or bench, not its top (and never a blocker).
	params.FilterDescendantsInstances = ObstacleHop.groundIgnore(ignore)
	params.RespectCanCollide = true
	local hit = workspace:Raycast(Vector3.new(x, 30, z), Vector3.new(0, -60, 0), params)
	return hit and hit.Position.Y or 0
end

-- Points the dog at a spot ON THE GROUND (it runs there, never flies).
-- Returns the PetService token, or nil if the dog couldn't be moved.
local function dogTo(player: Player, entry: Entry, at: Vector3): number?
	local model = S.Pet.getModel(player)
	if not model then
		return nil
	end
	if not entry.target then
		local a = Instance.new("Attachment")
		a.Name = `TrailTarget_{player.UserId}`
		a.Parent = workspace.Terrain
		entry.target = a
	end
	local target = entry.target :: Attachment
	local feet = model:GetAttribute("GroundOffset") or 1.5
	target.WorldPosition = Vector3.new(at.X, groundY(at.X, at.Z) + feet, at.Z)
	local ok, _, token = S.Pet.setState(player, "MovingToTarget", { byActivity = true, target = target })
	return ok and token or nil
end

-- Back to walking beside the owner (only if we were the ones moving it).
local function dogBack(player: Player)
	if S.Pet.getState(player) == "MovingToTarget" then
		S.Pet.setState(player, "Following")
	end
end

local function makeSquirrel(at: Vector3, facing: Vector3): Model
	local m = Instance.new("Model")
	m.Name = "TrailSquirrel"
	local y = groundY(at.X, at.Z)
	local cf = CFrame.lookAt(Vector3.new(at.X, y + 0.6, at.Z), Vector3.new(at.X + facing.X, y + 0.6, at.Z + facing.Z))
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(1.2, 1.2, 1.2)
	body.Color = Color3.fromRGB(150, 95, 60)
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body.CFrame = cf
	body.Parent = m
	local tail = Instance.new("Part")
	tail.Name = "Tail"
	tail.Size = Vector3.new(0.6, 1.6, 0.6)
	tail.Color = Color3.fromRGB(190, 130, 80)
	tail.Material = Enum.Material.SmoothPlastic
	tail.Anchored = false
	tail.Massless = true
	tail.CanCollide = false
	tail.CanQuery = false
	tail.CanTouch = false
	tail.CFrame = cf * CFrame.new(0, 0.7, 0.7) * CFrame.Angles(math.rad(-25), 0, 0)
	tail.Parent = m
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = tail
	weld.Parent = body
	-- A shape and words, not only a color or sound.
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 54)
	gui.StudsOffset = Vector3.new(0, 2.2, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.Text = "🐿️ Squirrel!"
	label.Parent = gui
	gui.Parent = body
	m.PrimaryPart = body
	return m
end

local function removeSquirrel(entry: Entry)
	local squirrel = entry.squirrel
	entry.squirrel = nil
	if not squirrel then
		return
	end
	local body = squirrel.PrimaryPart
	if body and entry.inward then
		-- Darts back the way it came, then disappears.
		local away = body.CFrame + entry.inward * 8
		TweenService:Create(body, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = away }):Play()
	end
	task.delay(0.55, function()
		squirrel:Destroy()
	end)
end

local function cleanup(player: Player, entry: Entry)
	if entry.leash then
		entry.leash:Destroy()
		entry.leash = nil
	end
	removeSquirrel(entry)
	if entry.target then
		entry.target:Destroy()
		entry.target = nil
	end
	if walks[player] == entry then
		walks[player] = nil
	end
end

local function push(player: Player, payload: { [string]: any })
	S.Net.push(player, Remotes.PushKinds.TrailWalk, payload)
end

local function resolve(player: Player, entry: Entry, challengeId: string, result: string)
	if walks[player] ~= entry then
		return
	end
	push(player, { state = "challenge", runId = entry.run.id, challengeId = challengeId, result = result })
	removeSquirrel(entry)
	if result == "steady" then
		dogBack(player)
		S.Pet.react(player, "happy")
		return
	end
	-- A miss: the dog tugs a few studs further off the path, then comes back.
	local pet = S.Pet.getActive(player)
	local inward = entry.inward
	if not pet or not inward then
		dogBack(player)
		return
	end
	local token = dogTo(player, entry, pet.root.Position + inward * TUG_STUDS)
	S.Pet.react(player, "excited")
	task.delay(TUG_SECONDS, function()
		if walks[player] == entry and token and S.Pet.isCurrent(player, token) then
			dogBack(player)
			S.Pet.react(player, "comfort")
		end
	end)
end

local openSquirrel
function openSquirrel(player: Player, entry: Entry)
	local run = entry.run
	if walks[player] ~= entry or not TrailRules.isLive(run, run.id) then
		return
	end
	if run.open then
		-- One challenge at a time: wait for the open one to settle, then
		-- run this one, so every planned squirrel moment happens.
		task.delay(0.5, openSquirrel, player, entry)
		return
	end
	entry.pending = math.max(0, entry.pending - 1)
	local pet = S.Pet.getActive(player)
	local place = Places.get("trail")
	if not pet or not place then
		return
	end
	entry.challengeN += 1
	local challengeId = `{run.id}:{entry.challengeN}`
	if not TrailRules.openChallenge(run, run.id, challengeId, os.clock()) then
		return
	end
	-- The squirrel comes from inside the loop (open grass, bushes, trees),
	-- never from beyond the fence.
	local dogPos = pet.root.Position
	local toCenter = Vector3.new(place.center.X - dogPos.X, 0, place.center.Z - dogPos.Z)
	local inward = toCenter.Magnitude > 0.1 and toCenter.Unit or Vector3.new(1, 0, 0)
	entry.inward = inward
	local squirrel = makeSquirrel(dogPos + inward * 11, -inward)
	squirrel.Parent = workspace
	entry.squirrel = squirrel
	local body = squirrel.PrimaryPart :: BasePart
	TweenService:Create(body, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = body.CFrame - inward * 4,
	}):Play()
	dogTo(player, entry, dogPos + inward * LUNGE_STUDS)
	S.Pet.react(player, "alert")
	push(player, {
		state = "squirrel",
		runId = run.id,
		challengeId = challengeId,
		window = TrailRules.WINDOW_SECONDS,
		hold = TrailRules.HOLD_SECONDS,
	})
	task.delay(TrailRules.WINDOW_SECONDS + 0.25, function()
		local result = TrailRules.expireChallenge(run, challengeId, os.clock())
		if result then
			resolve(player, entry, challengeId, result)
		end
	end)
end

local function finishWalk(player: Player, entry: Entry)
	local run = entry.run
	local def = Activity.def("trail_walk")
	local ok, _, summary = TrailRules.complete(run, run.id, os.clock(), def and def.parSeconds)
	if not ok or not summary then
		return
	end
	local session = entry.session
	cleanup(player, entry)
	dogBack(player)
	Activity.finish(player, session)
	push(player, {
		state = "done",
		runId = run.id,
		stars = summary.stars,
		seconds = summary.seconds,
		steady = summary.steady,
		challenges = summary.challenges,
		sniffs = summary.sniffs,
		sniffTotal = #sniffs,
	})
	Activity.complete(player, "trail_walk", { timeSeconds = summary.seconds, rating = summary.stars })
end

local function begin(player: Player, head: BasePart)
	local ok, reason = Activity.canStart(player, "trail_walk")
	if not ok then
		S.Net.toast(player, reason or "Not right now.", "info")
		return
	end
	local hrp = Activity.hrp(player)
	if not hrp or (hrp.Position - head.Position).Magnitude > START_DISTANCE then
		return
	end
	local existing = walks[player]
	if existing and Activity.current(player) == existing.session then
		S.Net.toast(player, "You're already on a walk! Follow the paw prints.", "info")
		return
	end
	local pet = S.Pet.getActive(player)
	if not pet or #markers == 0 then
		S.Net.toast(player, pet and "The trail isn't ready yet." or "Adopt a dog first!", "info")
		return
	end

	local now = os.clock()
	local run = TrailRules.newRun(HttpService:GenerateGUID(false), now, #markers, #sniffs)
	local entry: Entry = {
		run = run,
		session = nil,
		challengeAt = {},
		challengeN = 0,
		pending = 0,
	}
	for _, m in TrailRules.pickChallengeMarkers(#markers, math.random(2, 3), math.random) do
		entry.challengeAt[m] = true
	end
	entry.session = Activity.begin(player, "trail_walk", function(why)
		TrailRules.cancel(run)
		cleanup(player, entry)
		dogBack(player)
		push(player, { state = "cancel", runId = run.id, reason = why })
		if why == "walked away" then
			S.Net.toast(player, "You left the trail, so the walk ended. Come back any time!", "info")
		end
	end)
	walks[player] = entry

	-- The dog joins you at the trailhead and the leash clips on.
	if (pet.root.Position - hrp.Position).Magnitude > 30 then
		pet.model:PivotTo(CFrame.new(hrp.Position + hrp.CFrame.RightVector * 3))
	end
	S.Pet.setState(player, "Following")
	local model = S.Pet.getModel(player)
	if model and player.Character and not model:FindFirstChild("Leash") then
		entry.leash = S.Appearance.leash(model, player.Character, LEASH_COLOR, "TrailLeash")
	end
	S.Pet.react(player, "excited")
	push(player, {
		state = "start",
		runId = run.id,
		markers = markers,
		sniffs = sniffs,
		total = #markers,
		hold = TrailRules.HOLD_SECONDS,
		window = TrailRules.WINDOW_SECONDS,
	})
	local session = entry.session
	task.delay(MAX_RUN_SECONDS, function()
		if walks[player] == entry then
			S.Net.toast(player, "That was a long walk! Let's call it here.", "info")
			Activity.interrupt(player, "timeout", session)
		end
	end)
end

local function hold(player: Player, payload: any): (boolean, string?, any?)
	local entry = walks[player]
	if not entry or typeof(payload) ~= "table" then
		return false, nil
	end
	local run = entry.run
	local now = os.clock()
	if payload.phase == "start" then
		local ok = TrailRules.holdStart(run, payload.runId, payload.challengeId, now)
		return ok, nil
	elseif payload.phase == "end" then
		local ok, why, result = TrailRules.holdEnd(run, payload.runId, payload.challengeId, now)
		if ok and result then
			resolve(player, entry, payload.challengeId, result)
		end
		return ok, nil, ok and { result = result or why } or nil
	end
	return false, nil
end

local function tick()
	local now = os.clock()
	for player, entry in walks do
		if Activity.current(player) ~= entry.session then
			cleanup(player, entry) -- ended some other way
			continue
		end
		local hrp = Activity.hrp(player)
		if not hrp or not S.Pet.getActive(player) then
			Activity.interrupt(player, "lost", entry.session)
			continue
		end
		if not Places.isInside("trail", hrp.Position, LEAVE_MARGIN) then
			Activity.interrupt(player, "walked away", entry.session)
			continue
		end
		local run = entry.run
		if TrailRules.allMarkers(run) then
			-- Every marker reached: finish once queued squirrels are settled.
			if entry.pending == 0 and not run.open then
				finishWalk(player, entry)
			end
			continue
		end
		local index = run.nextMarker
		local at = markers[index]
		if at then
			local d = flatDistance(hrp.Position, at)
			if d <= TrailRules.MARKER_RADIUS and TrailRules.reachMarker(run, run.id, index, d, now) then
				push(player, { state = "marker", runId = run.id, index = index, total = #markers })
				if entry.challengeAt[index] then
					entry.pending += 1
					task.delay(0.6 + math.random() * 0.8, openSquirrel, player, entry)
				end
				if TrailRules.allMarkers(run) and entry.pending == 0 and not run.open then
					finishWalk(player, entry)
					continue
				end
			end
		end
		for i, spot in sniffs do
			if not run.sniffed[i] and flatDistance(hrp.Position, spot) <= TrailRules.SNIFF_RADIUS then
				if TrailRules.sniff(run, run.id, i) then
					S.Pet.react(player, "sniff")
					push(player, { state = "sniff", runId = run.id, index = i, total = #sniffs })
				end
			end
		end
	end
end

local function loadTrail()
	local trail = S.World.getTrail()
	if not trail then
		warn("[TrailWalk] no Trail in the world")
		return
	end
	local m, s = {}, {}
	for _, d in trail:GetDescendants() do
		if d:IsA("BasePart") then
			local mi = d:GetAttribute("MarkerIndex")
			local si = d:GetAttribute("SniffIndex")
			if typeof(mi) == "number" then
				m[mi] = d.Position
			elseif typeof(si) == "number" then
				s[si] = d.Position
			end
		end
	end
	for i = 1, #m do
		markers[i] = m[i]
	end
	for i = 1, #s do
		sniffs[i] = s[i]
	end
	if #markers == 0 then
		warn("[TrailWalk] trail has no markers")
	end
end

function TrailWalk.init(services, activity)
	S = services
	Activity = activity
end

function TrailWalk.start()
	loadTrail()
	local function setup(head: Instance)
		if not head:IsA("BasePart") or head:FindFirstChild("TrailPrompt") then
			return
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "TrailPrompt"
		prompt.ActionText = "Start a walk"
		prompt.ObjectText = "Meadow Trail"
		prompt.HoldDuration = 0.25
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = head
		prompt.Triggered:Connect(function(player)
			begin(player, head)
		end)
	end
	CollectionService:GetInstanceAddedSignal("TrailHead"):Connect(setup)
	for _, h in CollectionService:GetTagged("TrailHead") do
		setup(h)
	end
	-- Short interval: a quick tap sends start and end close together.
	S.Net.on(Remotes.RequestKinds.TrailHold, hold, 0.05)
	Players.PlayerRemoving:Connect(function(player)
		local entry = walks[player]
		if entry then
			cleanup(player, entry)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.2)
			tick()
		end
	end)
end

return TrailWalk
