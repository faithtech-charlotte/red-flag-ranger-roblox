--[[
	Frisbee: a catch-training game on the Frisbee Field next to the Training
	Grounds.

	  Grab a frisbee   (the stack of discs at the field's throwing line)
	    -> you get a "Frisbee" Tool; your dog runs out into the field and
	       waits, watching you
	  Hold to wind up, release to throw
	    -> FrisbeeThrow { target, pitch, power }: direction from the aim
	       point, launch angle from how high you aim, speed from the wind-up
	  The disc flies with real disc aerodynamics (Shared/FrisbeeMath): lift,
	  drag, and the gyroscopic turn-and-fade of a spinning disc.
	  Your dog reads the flight, sprints to where it will come down, and
	  leaps for it. Caught in the air: it counts. Landed first: the dog
	  still brings it back, but it doesn't count.
	  The dog trots back, drops it at your feet (it pops back into your
	  hand), then runs out again and waits for the next throw.
	  Three catches complete the game (rewards in Content/Activities).

	Server authority: the server simulates the flight with the same fixed
	step as the clients, decides catches and landings (including hitting
	trees and buildings), and pays rewards. Clients only draw the disc.

	The game ends early if you walk away from the field, whistle the dog
	back (any base command), press Stop, respawn, or leave the match.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local FetchMath = require(script.Parent.Parent.Logic.FetchMath)
local FrisbeeMath = require(ReplicatedStorage.Shared.FrisbeeMath)
local Places = require(ReplicatedStorage.Shared.Places)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ACTIVITY_ID = "frisbee"
local SESSION_ID = "frisbee_game"
local PLACE_ID = "frisbee_field"
local TOOL_NAME = "Frisbee"
local DISC_NAME = "Frisbee"
local DISC_SIZE = Vector3.new(0.3, 2.2, 2.2) -- ~2.5x a real disc so it reads on screen
local DISC_COLOR = Color3.fromRGB(255, 90, 140)

local DOG_SPEED = 30 -- studs/s, PetService's sprint (fast) speed
local REACTION = 0.35 -- the dog watches the disc leave before sprinting
local CATCH_HEIGHT = 4.2 -- studs above the ground a leaping dog can snatch
local AIM_HEIGHT = 3.4 -- the dog plans for a catch a little below its limit
local CATCH_RADIUS = 3.2
local LEAP_ABOVE = 1.6 -- catches higher than this get a leap
local MIN_FROM_THROWER = 6
local MAX_FLIGHT = 7
local PICKUP_TIMEOUT = 10
local RETURN_TIMEOUT = 12
local WAIT_DISTANCE = 22 -- how far out the dog waits for the next throw
local LEAVE_MARGIN = 30 -- walk this far outside the field and the game ends
local IDLE_TIMEOUT = 120
local WORLD_HALF = 250

type Game = {
	session: any,
	catches: number,
	throws: number,
	phase: string, -- "out" (heading out / waiting), "flight", "fetching", "returning", "done"
	disc: BasePart?,
	chase: Attachment, -- where the dog runs during a throw
	spot: Attachment, -- where the dog waits between throws
	lastDir: Vector3,
	lastActive: number,
	lastThrowAt: number,
}

local Frisbee = {}
local S, Activity
local games: { [Player]: Game } = {}

local function setPetAttr(player: Player, name: string, value: any)
	local model = S.Pet.getModel(player)
	if model then
		model:SetAttribute(name, value)
	end
end

local function toolOf(player: Player): Tool?
	local c = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack") -- gone while a player leaves
	local t = (c and c:FindFirstChild(TOOL_NAME)) or (backpack and backpack:FindFirstChild(TOOL_NAME))
	return t and t:IsA("Tool") and t or nil
end

local function setDiscInHand(player: Player, visible: boolean)
	local tool = toolOf(player)
	local handle = tool and tool:FindFirstChild("Handle") :: BasePart?
	if handle then
		handle.Transparency = visible and 0 or 1
		tool:SetAttribute("InHand", visible)
	end
end

local function discInHand(player: Player): boolean
	local tool = toolOf(player)
	return tool ~= nil and tool:GetAttribute("InHand") ~= false
end

local function makeTool(player: Player)
	if toolOf(player) then
		return
	end
	local tool = Instance.new("Tool")
	tool.Name = TOOL_NAME
	tool.ToolTip = "Hold to wind up, release to throw! Aim higher for a floatier throw."
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.Grip = CFrame.new(0, -0.2, -0.6) * CFrame.Angles(0, 0, math.rad(90))
	tool:SetAttribute("InHand", true)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Shape = Enum.PartType.Cylinder
	handle.Size = Vector3.new(0.25, 1.8, 1.8)
	handle.Color = DISC_COLOR
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	tool.Equipped:Connect(function()
		setPetAttr(player, "ToyOut", true)
	end)
	tool.Unequipped:Connect(function()
		setPetAttr(player, "ToyOut", false)
		setPetAttr(player, "Ready", false)
	end)
	tool.Parent = player.Backpack
end

local function removeTool(player: Player)
	local tool = toolOf(player)
	if tool then
		tool:Destroy()
	end
	setPetAttr(player, "ToyOut", false)
	setPetAttr(player, "Ready", false)
end

local function makeDisc(owner: Player, launch: FrisbeeMath.Launch, launchAt: number): BasePart
	local disc = Instance.new("Part")
	disc.Name = DISC_NAME
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = DISC_SIZE
	disc.Color = DISC_COLOR
	disc.Material = Enum.Material.SmoothPlastic
	disc.Anchored = true -- moved by the flight model, not by Roblox physics
	disc.CanCollide = false
	disc.CanQuery = false
	disc.CanTouch = false
	disc.CFrame = FrisbeeMath.cframe(launch.origin, FrisbeeMath.start(launch))
	-- Everything a client needs to replay the same flight smoothly.
	disc:SetAttribute("OwnerUserId", owner.UserId)
	disc:SetAttribute("Flying", true)
	disc:SetAttribute("LaunchAt", launchAt)
	disc:SetAttribute("LaunchOrigin", launch.origin)
	disc:SetAttribute("LaunchVelocity", launch.velocity)
	disc:SetAttribute("LaunchNormal", launch.normal)
	disc:SetAttribute("LaunchSpin", launch.spin)
	disc.Parent = workspace
	Debris:AddItem(disc, 60)
	return disc
end

local function poof(disc: BasePart)
	local burst = Instance.new("ParticleEmitter")
	burst.Rate = 0
	burst.Speed = NumberRange.new(4, 8)
	burst.Lifetime = NumberRange.new(0.4, 0.7)
	burst.Size = NumberSequence.new(0.6, 0)
	burst.Parent = disc
	burst:Emit(18)
	disc.Transparency = 1
	Debris:AddItem(disc, 1)
end

local function rayParams(extra: { Instance }?): RaycastParams
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
	for _, d in workspace:GetChildren() do
		if d.Name == DISC_NAME or d.Name == "FetchBall" then
			table.insert(ignore, d)
		end
	end
	for _, e in extra or {} do
		table.insert(ignore, e)
	end
	params.FilterDescendantsInstances = ignore
	return params
end

local function groundBelow(p: Vector3, params: RaycastParams): number?
	local hit = workspace:Raycast(p + Vector3.new(0, 1, 0), Vector3.new(0, -60, 0), params)
	return hit and hit.Position.Y or nil
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function feet(player: Player): number
	local model = S.Pet.getModel(player)
	return model and model:GetAttribute("GroundOffset") or 1.5
end

local function pushState(player: Player, match: Game, extra: { [string]: any })
	local payload = { count = match.catches, goal = Activity.def(ACTIVITY_ID).goal, throws = match.throws }
	for k, v in extra do
		payload[k] = v
	end
	S.Net.push(player, Remotes.PushKinds.Frisbee, payload)
end

-- Everything the game made goes away. Does NOT touch the dog's state:
-- the caller (completion, or the session's interrupt handler) does that.
local function cleanup(player: Player, match: Game)
	if games[player] == match then
		games[player] = nil
	end
	match.phase = "done"
	if match.disc then
		match.disc:Destroy()
		match.disc = nil
	end
	match.chase:Destroy()
	match.spot:Destroy()
	setPetAttr(player, "Carrying", false)
	setPetAttr(player, "FaceOwner", false)
	removeTool(player)
end

local function stillOn(player: Player, match: Game): boolean
	return games[player] == match and Activity.current(player) == match.session
end

-- Where the dog waits: out in front of you along your last throw, inside the field.
local function waitSpot(player: Player, match: Game): Vector3?
	local hrp = Activity.hrp(player)
	local place = Places.get(PLACE_ID)
	if not hrp or not place then
		return nil
	end
	local p = hrp.Position + match.lastDir * WAIT_DISTANCE
	local hx, hz = place.size.X / 2 - 6, place.size.Z / 2 - 6
	local x = math.clamp(p.X, place.center.X - hx, place.center.X + hx)
	local z = math.clamp(p.Z, place.center.Z - hz, place.center.Z + hz)
	local ground = groundBelow(Vector3.new(x, hrp.Position.Y + 10, z), rayParams()) or place.center.Y
	return Vector3.new(x, ground + feet(player), z)
end

-- The dog runs out into the field and waits, facing you.
local function goOut(player: Player, match: Game)
	if not stillOn(player, match) then
		return
	end
	local spot = waitSpot(player, match)
	if not spot then
		return
	end
	match.phase = "out"
	match.spot.WorldPosition = spot
	local ok, _, token = S.Pet.setState(player, "MovingToTarget", { byActivity = true, target = match.spot, fast = true })
	if not ok then
		Activity.interrupt(player, "no pet", match.session)
		return
	end
	task.spawn(function()
		-- Once there, turn around and watch the thrower.
		local t = 0
		while t < 8 and S.Pet.isCurrent(player, token) and stillOn(player, match) do
			local pet = S.Pet.getActive(player)
			if pet and flatDistance(pet.root.Position, spot) < 2.5 then
				setPetAttr(player, "FaceOwner", true)
				return
			end
			t += task.wait(0.15)
		end
	end)
end

local function finishGame(player: Player, match: Game)
	cleanup(player, match)
	Activity.finish(player, match.session)
	S.Pet.settle(player)
	S.Pet.setState(player, "Idle", { duration = 1.4 })
	S.Pet.react(player, "love")
	pushState(player, match, { state = "end", done = true })
	Activity.complete(player, ACTIVITY_ID)
end

-- One throw, start to finish: flight, catch or pickup, return, go back out.
local function runThrow(player: Player, match: Game, launch: FrisbeeMath.Launch, launchAt: number, disc: BasePart)
	local pet = S.Pet.getActive(player)
	if not pet then
		Activity.interrupt(player, "no pet", match.session)
		return
	end
	local params = rayParams({ disc })
	local fieldY = groundBelow(launch.origin, params) or 0
	local dogFeet = feet(player)
	local path = FrisbeeMath.predict(launch, fieldY, MAX_FLIGHT, 2)
	setPetAttr(player, "FaceOwner", false)
	S.Pet.react(player, "excited")

	-- Flight: step the same model the clients draw, in fixed steps.
	local s = FrisbeeMath.start(launch)
	local caught, air, landed, unreachable = false, false, false, false
	local placed = false -- disc CFrame already set where it came to rest
	local chasing = false
	local token: number? = nil
	local catchCheckAfter = 0.25
	while true do
		if not stillOn(player, match) or not disc.Parent then
			return
		end
		if token and not S.Pet.isCurrent(player, token) then
			Activity.interrupt(player, "interrupted", match.session)
			return
		end
		local now = workspace:GetServerTimeNow() - launchAt
		-- The dog reads the flight, then sprints to where it can catch it.
		if not chasing and now >= REACTION then
			chasing = true
			setPetAttr(player, "Ready", false)
			local target = FrisbeeMath.pickIntercept(path, pet.root.Position, DOG_SPEED, REACTION, AIM_HEIGHT, MIN_FROM_THROWER)
			local goal = target and target.position or FrisbeeMath.worldPosition(launch, s)
			local g = groundBelow(Vector3.new(goal.X, goal.Y + 8, goal.Z), params) or fieldY
			match.chase.WorldPosition = Vector3.new(goal.X, g + dogFeet, goal.Z)
			local ok, _, t = S.Pet.setState(player, "Fetching", { byActivity = true, target = match.chase, fast = true })
			if not ok then
				Activity.interrupt(player, "no pet", match.session)
				return
			end
			token = t
		end
		while s.t + FrisbeeMath.DT <= now and not landed do
			local before = FrisbeeMath.worldPosition(launch, s)
			FrisbeeMath.step(s)
			local after = FrisbeeMath.worldPosition(launch, s)
			local hit = workspace:Raycast(before, after - before, params)
			if hit then
				-- Ground: it lands. Anything else (tree, wall, roof): it drops.
				local ground = if hit.Normal.Y > 0.6 then hit.Position.Y else groundBelow(hit.Position - (after - before).Unit * 0.5, params)
				landed = true
				if not ground or ground > fieldY + 3.5 then
					unreachable = true
				end
				local at = hit.Position
				disc.CFrame = CFrame.new(at.X, (ground or at.Y) + DISC_SIZE.X / 2, at.Z) * CFrame.Angles(0, 0, math.rad(90))
				placed = true
				break
			end
			if not FetchMath.inBounds(after, WORLD_HALF) or after.Y < fieldY - 20 or s.t > MAX_FLIGHT then
				landed, unreachable = true, true
				break
			end
			-- No disc.CFrame write here: clients replay the flight from the
			-- launch attributes, and a replicated CFrame would fight that.
			-- Catch: the dog is under the disc and it's low enough to snatch.
			if chasing and s.t > catchCheckAfter then
				local height = after.Y - fieldY
				if height < CATCH_HEIGHT and flatDistance(pet.root.Position, after) < CATCH_RADIUS then
					caught = true
					air = true
					if height > LEAP_ABOVE then
						pet.model:SetAttribute("LeapAt", workspace:GetServerTimeNow())
					end
					break
				end
			end
		end
		if caught or landed then
			break
		end
		RunService.Heartbeat:Wait()
	end
	if not placed then
		disc.CFrame = FrisbeeMath.cframe(FrisbeeMath.worldPosition(launch, s), s)
	end
	disc:SetAttribute("Flying", false)
	match.lastActive = os.clock()

	if unreachable then
		poof(disc)
		match.disc = nil
		S.Pet.react(player, "confused")
		setDiscInHand(player, true)
		pushState(player, match, { state = "lost", text = `Oops! {S.Pet.name(player)} can't reach that one. Here's another frisbee!` })
		goOut(player, match)
		return
	end

	if landed then
		-- Missed the catch: still go get it.
		match.phase = "fetching"
		pushState(player, match, { state = "landed" })
		local spot = disc.Position
		match.chase.WorldPosition = Vector3.new(spot.X, spot.Y - DISC_SIZE.X / 2 + dogFeet, spot.Z)
		if not token then
			-- It hit something before the dog even started running.
			local ok, _, t = S.Pet.setState(player, "Fetching", { byActivity = true, target = match.chase, fast = true })
			if not ok then
				Activity.interrupt(player, "no pet", match.session)
				return
			end
			token = t
		end
		local t = 0
		while flatDistance(pet.root.Position, spot) > 2.6 do
			if not stillOn(player, match) or (token and not S.Pet.isCurrent(player, token)) then
				if stillOn(player, match) then
					Activity.interrupt(player, "interrupted", match.session)
				end
				return
			end
			if t > PICKUP_TIMEOUT then
				pet.model:PivotTo(CFrame.new(spot.X, spot.Y + dogFeet, spot.Z + 1.5))
				break
			end
			t += task.wait(0.1)
		end
	end

	-- Grab it.
	local mouth = pet.model:FindFirstChild("MouthAttachment", true) :: Attachment?
	if mouth then
		disc.Size = DISC_SIZE * 0.75
		disc.CFrame = mouth.WorldCFrame * CFrame.new(0, -0.1, -0.7)
		local w = Instance.new("WeldConstraint")
		w.Part0 = mouth.Parent :: BasePart
		w.Part1 = disc
		w.Parent = disc
		disc.Massless = true
		disc.Anchored = false
		disc.Parent = pet.model
	end
	setPetAttr(player, "Carrying", true)
	if caught then
		match.catches += 1
		S.Pet.react(player, "love")
		pushState(player, match, { state = "caught", air = air })
	else
		S.Pet.react(player, "happy")
		pushState(player, match, { state = "grabbed" })
	end
	-- Hold still a beat to celebrate, then trot back.
	pet.hold.WorldPosition = pet.root.Position
	pet.alignPosition.Attachment1 = pet.hold
	task.wait(0.4)
	if not stillOn(player, match) then
		return
	end

	match.phase = "returning"
	local ok, _, token2 = S.Pet.setState(player, "Returning", { byActivity = true, fast = true })
	if not ok then
		Activity.interrupt(player, "interrupted", match.session)
		return
	end
	local back, t2 = false, 0
	while t2 < RETURN_TIMEOUT do
		if not S.Pet.isCurrent(player, token2) or not stillOn(player, match) then
			if stillOn(player, match) then
				Activity.interrupt(player, "interrupted", match.session)
			end
			return
		end
		local h = Activity.hrp(player)
		if h and (pet.root.Position - h.Position).Magnitude < 6 then
			back = true
			break
		end
		t2 += task.wait(0.1)
	end
	if not back then
		pet.model:PivotTo(pet.follow.WorldCFrame)
	end

	-- Drop it at your feet; it pops back into your hand.
	disc:Destroy()
	match.disc = nil
	setPetAttr(player, "Carrying", false)
	S.Pet.setState(player, "Idle", { byActivity = true })
	S.Pet.react(player, "happy")
	setDiscInHand(player, true)
	if caught then
		S.Bond.addXp(player, "fetch")
	end
	local goal = Activity.def(ACTIVITY_ID).goal
	pushState(player, match, { state = "returned", caught = caught })
	if match.catches >= goal then
		task.wait(0.5)
		if stillOn(player, match) then
			finishGame(player, match)
		end
		return
	end
	task.wait(0.7)
	goOut(player, match)
end

function Frisbee.isPlaying(player: Player): boolean
	return games[player] ~= nil
end

-- Starts a game (from the field's frisbee stack). Re-equips if one is on.
function Frisbee.startGame(player: Player): (boolean, string?)
	local existing = games[player]
	if existing and stillOn(player, existing) then
		pushState(player, existing, { state = "start" })
		return true, nil
	end
	local ok, reason = Activity.canStart(player, ACTIVITY_ID)
	if not ok then
		return false, reason
	end
	local pet = S.Pet.getActive(player)
	local hrp = Activity.hrp(player)
	if not pet or not hrp then
		return false, "Adopt a dog first!"
	end
	if Activity.current(player) then
		return false, "Finish what you're doing first!"
	end
	if not Activity.isAt(player, PLACE_ID, 6) then
		return false, "Head to the Frisbee Field to play!"
	end
	-- A dog left far away gets a lift so it doesn't run across the map.
	if S.Pet.distanceToOwner(player) > 60 then
		pet.model:PivotTo(pet.follow.WorldCFrame)
	end

	local chase = Instance.new("Attachment")
	chase.Name = `PetFrisbeeChase_{player.UserId}`
	chase.WorldPosition = hrp.Position
	chase.Parent = workspace.Terrain
	local spot = Instance.new("Attachment")
	spot.Name = `PetFrisbeeSpot_{player.UserId}`
	spot.WorldPosition = hrp.Position
	spot.Parent = workspace.Terrain

	local place = Places.get(PLACE_ID) :: Places.Place
	local match: Game
	local session = Activity.begin(player, SESSION_ID, function(reason)
		cleanup(player, match)
		-- Back to normal (a command that ended the game sets its own state right after).
		S.Pet.settle(player)
		pushState(player, match, { state = "end", reason = reason })
	end)
	match = {
		session = session,
		catches = 0,
		throws = 0,
		phase = "out",
		disc = nil,
		chase = chase,
		spot = spot,
		lastDir = FrisbeeMath.flatDirection(hrp.Position, place.center, hrp.CFrame.LookVector),
		lastActive = os.clock(),
		lastThrowAt = 0,
	}
	games[player] = match
	makeTool(player)
	pushState(player, match, { state = "start" })
	goOut(player, match)
	return true, nil
end

function Frisbee.throw(player: Player, payload: any): (boolean, string?)
	local match = games[player]
	if not match or not stillOn(player, match) then
		return false, "Grab a frisbee at the Frisbee Field first!"
	end
	local hrp = Activity.hrp(player)
	local character = player.Character
	local tool = toolOf(player)
	if not hrp or not character or not tool or tool.Parent ~= character then
		return false, nil
	end
	if match.phase ~= "out" or not discInHand(player) then
		return false, `{S.Pet.name(player)} is still on it!`
	end
	local now = os.clock()
	if now - match.lastThrowAt < 0.6 then
		return false, nil
	end
	match.lastThrowAt = now
	match.lastActive = now

	local p = typeof(payload) == "table" and payload or {}
	local dir = FrisbeeMath.flatDirection(hrp.Position, p.target, hrp.CFrame.LookVector)
	local elevation = FrisbeeMath.elevationFromPitch(p.pitch)
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local origin = (hand and (hand :: BasePart).Position or hrp.Position + Vector3.new(0, 1.5, 0)) + dir * 1.2
	local launch = FrisbeeMath.launch(origin, dir, elevation, p.power)
	local launchAt = workspace:GetServerTimeNow()

	match.throws += 1
	match.lastDir = dir
	match.phase = "flight"
	setDiscInHand(player, false)
	local disc = makeDisc(player, launch, launchAt)
	match.disc = disc
	task.spawn(runThrow, player, match, launch, launchAt, disc)
	return true, nil
end

function Frisbee.init(services, activity)
	S = services
	Activity = activity
end

function Frisbee.start()
	S.Net.on(Remotes.RequestKinds.FrisbeeThrow, function(player, payload)
		return Frisbee.throw(player, payload)
	end, 0.3)

	-- Walked away or went idle: the game ends (the dog comes back to you).
	task.spawn(function()
		while true do
			task.wait(1)
			for player, match in games do
				local hrp = Activity.hrp(player)
				local away = hrp ~= nil and not Places.isInside(PLACE_ID, hrp.Position, LEAVE_MARGIN)
				local idle = match.phase == "out" and os.clock() - match.lastActive > IDLE_TIMEOUT
				if (away or idle) and stillOn(player, match) then
					Activity.interrupt(player, away and "left" or "idle", match.session)
					S.Net.toast(player, "Frisbee game over. Grab a frisbee at the field to play again!", "info")
				end
			end
		end
	end)

	local function hook(player: Player)
		player.CharacterRemoving:Connect(function()
			local match = games[player]
			if match then
				Activity.interrupt(player, "respawn", match.session)
			end
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in Players:GetPlayers() do
		hook(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		games[player] = nil
	end)
end

return Frisbee
