--[[
	Fetch: one shared, physics-based fetch game.

	The player owns a "Ball" Tool (given automatically once they have a dog).
	  Equip it         -> the dog gets excited (ToyOut attribute) and watches you
	  Hold to charge   -> the dog crouches, ready to sprint (Ready attribute)
	  Release          -> FetchThrow { target, power }

	The server launches a REAL physics ball (it bounces and rolls), lets the
	dog react for a beat, then sends it sprinting after the moving ball. The
	dog grabs it (mid-air catches are special), trots back proudly, drops it
	at your feet, and the ball pops back into your hand.

	Server authority: the server picks the launch velocity from a clamped aim
	and power, decides catches, and pays the (capped) Bond XP. Three catches
	in Sunny Dog Park complete the park challenge.

	Recovery: balls that fall out of the world, rest on a roof, or can't be
	reached in time "poof" and return to your hand. A command (Sit / Come),
	respawning, or leaving cleans everything up immediately.
]]

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local FetchMath = require(script.Parent.Parent.Logic.FetchMath)
local ObstacleHop = require(ReplicatedStorage.Shared.ObstacleHop)
local Places = require(ReplicatedStorage.Shared.Places)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local MIN_THROW, MAX_THROW = 10, 46
local WORLD_HALF = 250
local CHASE_DELAY = 0.45 -- the dog watches the ball leave before sprinting
local CHASE_TIMEOUT = 9
local RETURN_TIMEOUT = 10
local TOOL_NAME = "Ball"
local BALL_GROUP, CHAR_GROUP = "FetchBall", "Characters"

local Fetch = {}
local S, Activity
local parkCatches: { [Player]: number } = {}
local streaks: { [Player]: number } = {}
local lastThrow: { [Player]: number } = {}

local function petModel(player: Player): Model?
	return S.Pet.getModel(player)
end

local function setPetAttr(player: Player, name: string, value: any)
	local model = petModel(player)
	if model then
		model:SetAttribute(name, value)
	end
end

local function toolOf(player: Player): Tool?
	local c = player.Character
	local t = (c and c:FindFirstChild(TOOL_NAME)) or player.Backpack:FindFirstChild(TOOL_NAME)
	return t and t:IsA("Tool") and t or nil
end

local function setBallInHand(player: Player, visible: boolean)
	local tool = toolOf(player)
	local handle = tool and tool:FindFirstChild("Handle") :: BasePart?
	if handle then
		handle.Transparency = visible and 0 or 1
	end
end

local function makeTool(player: Player)
	if toolOf(player) then
		return
	end
	local tool = Instance.new("Tool")
	tool.Name = TOOL_NAME
	tool.ToolTip = "Hold to wind up, release to throw!"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.Grip = CFrame.new(0, 0, -0.2)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Shape = Enum.PartType.Ball
	handle.Size = Vector3.new(1, 1, 1)
	handle.Color = Color3.fromRGB(200, 255, 60)
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

local function charGroup(character: Model)
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = CHAR_GROUP
		end
	end
	character.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			d.CollisionGroup = CHAR_GROUP
		end
	end)
end

local function makeBall(position: Vector3, velocity: Vector3, owner: Player): (BasePart, Attachment)
	local ball = Instance.new("Part")
	ball.Name = "FetchBall"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(1.2, 1.2, 1.2)
	ball.Color = Color3.fromRGB(200, 255, 60)
	ball.Material = Enum.Material.SmoothPlastic
	ball.CustomPhysicalProperties = PhysicalProperties.new(0.4, 0.5, 0.62, 1, 1)
	ball.CollisionGroup = BALL_GROUP
	ball.CanQuery = false
	ball.CanTouch = false
	ball.Position = position
	ball:SetAttribute("OwnerUserId", owner.UserId)
	local hold = Instance.new("Attachment")
	hold.Name = "BallTarget"
	-- Center of the ball: the ball spins as it rolls, so an offset would orbit.
	hold.Parent = ball
	ball.Parent = workspace
	ball.AssemblyLinearVelocity = velocity
	ball.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), 0, math.random(-8, 8))
	pcall(function()
		ball:SetNetworkOwner(owner) -- smooth bounces for the thrower
	end)
	Debris:AddItem(ball, 45)
	return ball, hold
end

local function poof(ball: BasePart)
	local burst = Instance.new("ParticleEmitter")
	burst.Rate = 0
	burst.Speed = NumberRange.new(4, 8)
	burst.Lifetime = NumberRange.new(0.4, 0.7)
	burst.Size = NumberSequence.new(0.6, 0)
	burst.Parent = ball
	burst:Emit(18)
	ball.Anchored = true
	ball.Transparency = 1
	Debris:AddItem(ball, 1)
end

-- Height of the ground under a point. `ball` must be excluded: a colliding
-- part is always hit by raycasts (CanQuery only works on non-colliding parts).
local function groundBelow(p: Vector3, ball: BasePart?): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true -- not trigger volumes or decorations
	local ignore: { Instance } = { workspace:FindFirstChild("Pets") :: Instance }
	if ball then
		table.insert(ignore, ball)
	end
	ObstacleHop.groundIgnore(ignore) -- the ground under a hurdle, not its bar
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(p + Vector3.new(0, 1, 0), Vector3.new(0, -60, 0), params)
	return hit and hit.Position.Y or nil
end

-- Launch velocity that lands a ball `distance` away (flat ground) in `dir`.
local function launch(dir: Vector3, distance: number): Vector3
	local g = workspace.Gravity
	local t = 0.55 + distance / 70 -- longer throws fly a bit longer
	return dir * (distance / t) + Vector3.new(0, g * t / 2, 0)
end

function Fetch.isBusy(player: Player): boolean
	local session = Activity.current(player)
	return session ~= nil and session.id == "fetch_play"
end

function Fetch.setReady(player: Player, ready: boolean)
	if not Fetch.isBusy(player) then
		setPetAttr(player, "Ready", ready == true)
	end
end

local function done(player: Player, session, inHand: boolean)
	setPetAttr(player, "Carrying", false)
	setPetAttr(player, "Ready", false)
	Activity.finish(player, session)
	if inHand then
		setBallInHand(player, true)
	end
end

function Fetch.throw(player: Player, aim: any, power: any): (boolean, string?)
	local profile = S.Data.get(player)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not profile or not profile.activePetId or not S.Pet.getActive(player) then
		return false, "Adopt a dog first!"
	end
	if not hrp then
		return false, nil
	end
	if Fetch.isBusy(player) then
		return false, `{S.Pet.name(player)} is still on it!`
	end
	if Activity.current(player) then
		return false, "Finish what you're doing first!"
	end
	local now = os.clock()
	if lastThrow[player] and now - lastThrow[player] < 0.6 then
		return false, nil
	end
	lastThrow[player] = now

	local p = typeof(power) == "number" and power == power and math.clamp(power, 0, 1) or 0.6
	-- Aim gives the direction; how long you wound up (power) gives the distance.
	local distance = MIN_THROW + (MAX_THROW - MIN_THROW) * p
	local flat = FetchMath.clampThrow(hrp.Position, aim, hrp.CFrame.LookVector, MIN_THROW, MAX_THROW)
	local dir = Vector3.new(flat.X - hrp.Position.X, 0, flat.Z - hrp.Position.Z).Unit

	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local start = (hand and (hand :: BasePart).Position or hrp.Position + Vector3.new(0, 1.5, 0)) + dir * 1.2
	local ball: BasePart? = nil
	-- The dog chases a point ON THE GROUND under the ball, so it runs
	-- instead of flying up to meet a ball in the air.
	local chase = Instance.new("Attachment")
	chase.Name = `PetChase_{player.UserId}`
	chase.WorldPosition = hrp.Position
	chase.Parent = workspace.Terrain
	local session = Activity.begin(player, "fetch_play", function()
		if ball then
			ball:Destroy()
		end
		chase:Destroy()
		setPetAttr(player, "Carrying", false)
		setPetAttr(player, "Ready", false)
		setBallInHand(player, true)
		-- Don't leave the dog stuck mid-fetch when another activity takes
		-- over (it would refuse other interactions as "Busy playing!").
		-- Commands that interrupt set their own state right after this.
		local state = S.Pet.getState(player)
		if state == "Fetching" or state == "Returning" then
			S.Pet.setState(player, "Following")
		end
	end)
	setBallInHand(player, false)
	local b, hold = makeBall(start, launch(dir, distance), player)
	ball = b
	S.Pet.react(player, "excited")

	task.spawn(function()
		task.wait(CHASE_DELAY)
		if Activity.current(player) ~= session then
			return
		end
		setPetAttr(player, "Ready", false)
		local pet = S.Pet.getActive(player)
		if not pet then
			Activity.interrupt(player, "no pet", session)
			return
		end
		local feet = pet.model:GetAttribute("GroundOffset") or 1.5
		local function aimChase(pos: Vector3, ground: number?)
			chase.WorldPosition = Vector3.new(pos.X, (ground or 0) + feet, pos.Z)
		end
		aimChase(b.Position, groundBelow(b.Position, b))
		local ok, _, token = S.Pet.setState(player, "Fetching", { byActivity = true, target = chase, fast = true })
		if not ok then
			Activity.interrupt(player, "no pet", session)
			return
		end

		-- Chase the moving ball.
		local t, restingHigh = 0, 0
		local caught, air, unreachable = false, false, false
		while t < CHASE_TIMEOUT do
			if not S.Pet.isCurrent(player, token) or Activity.current(player) ~= session or not b.Parent then
				Activity.interrupt(player, "interrupted", session)
				return
			end
			local pos = b.Position
			if not FetchMath.inBounds(pos, WORLD_HALF) or pos.Y < -20 then
				unreachable = true
				break
			end
			local ground = groundBelow(pos, b)
			aimChase(pos, ground)
			local slow = b.AssemblyLinearVelocity.Magnitude < 1.5
			if slow and pos.Y > 3.5 then
				restingHigh += 0.1 -- stuck on a roof, sign, or treetop
				if restingHigh > 1.2 then
					unreachable = true
					break
				end
			end
			-- Catch when the dog is under the ball and the ball is low enough
			-- to snatch (a little hop for balls still in the air).
			local flatGap = Vector3.new(pet.root.Position.X - pos.X, 0, pet.root.Position.Z - pos.Z).Magnitude
			local height = pos.Y - (ground or 0)
			if flatGap < 2.4 and height < 3.2 then
				caught = true
				air = height > 1.4
				if air then
					pet.model:SetAttribute("LeapAt", workspace:GetServerTimeNow())
				end
				break
			end
			t += task.wait(0.1)
		end

		if unreachable or not caught then
			if not unreachable and b.Parent and b.Position.Y < 3.5 then
				-- Reachable but the dog got stuck somewhere: help it over.
				local g = groundBelow(b.Position, b) or 0
				pet.model:PivotTo(CFrame.new(b.Position.X, g + feet, b.Position.Z + 1.5))
				caught = true
			else
				poof(b)
				ball = nil
				chase:Destroy()
				S.Pet.react(player, "confused")
				S.Pet.settle(player)
				streaks[player] = 0
				done(player, session, true)
				S.Net.push(player, Remotes.PushKinds.Fetch, { ready = true, lost = true, text = `Oops! {S.Pet.name(player)} can't reach that one. Here's another ball!` })
				return
			end
		end

		-- Grab it.
		b.Anchored = true
		local mouth = pet.model:FindFirstChild("MouthAttachment", true) :: Attachment?
		if mouth then
			b.Size = Vector3.new(0.8, 0.8, 0.8)
			b.CanCollide = false
			b.Massless = true
			b.CFrame = mouth.WorldCFrame
			local w = Instance.new("WeldConstraint")
			w.Part0 = mouth.Parent :: BasePart
			w.Part1 = b
			w.Parent = b
			b.Anchored = false
			b.Parent = pet.model
		end
		setPetAttr(player, "Carrying", true)
		S.Pet.react(player, air and "love" or "happy")
		S.Net.push(player, Remotes.PushKinds.Fetch, { grabbed = true, air = air })
		-- A beat to celebrate the grab before trotting back.
		local grabPos = pet.root.Position
		pet.hold.WorldPosition = grabPos
		pet.alignPosition.Attachment1 = pet.hold
		task.wait(0.4)
		if Activity.current(player) ~= session then
			return
		end

		chase:Destroy()
		local ok2, _, token2 = S.Pet.setState(player, "Returning", { byActivity = true, fast = true })
		if not ok2 then
			Activity.interrupt(player, "interrupted", session)
			return
		end
		local back = false
		local t2 = 0
		while t2 < RETURN_TIMEOUT do
			if not S.Pet.isCurrent(player, token2) or Activity.current(player) ~= session then
				Activity.interrupt(player, "interrupted", session)
				return
			end
			local h = character:FindFirstChild("HumanoidRootPart") :: BasePart?
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
		b.Parent = workspace
		for _, w in b:GetChildren() do
			if w:IsA("WeldConstraint") then
				w:Destroy()
			end
		end
		b.Massless = false
		b.CanCollide = true
		b.AssemblyLinearVelocity = Vector3.new(0, 6, 0)
		ball = nil
		Debris:AddItem(b, 0.8)
		S.Pet.settle(player)
		-- Proud moment: sit, look up at you, wag.
		S.Pet.setState(player, "Idle", { duration = 1.1 })
		S.Pet.react(player, "happy")
		done(player, session, false)
		task.delay(0.7, function()
			if not Fetch.isBusy(player) then
				setBallInHand(player, true)
			end
		end)

		streaks[player] = (streaks[player] or 0) + 1
		local xp = S.Bond.addXp(player, "fetch")
		local goal = Activity.def("fetch").goal
		local inPark = Activity.isAt(player, "dog_park", 4)
		if inPark then
			parkCatches[player] = (parkCatches[player] or 0) + 1
		end
		local count = parkCatches[player] or 0
		S.Net.push(player, Remotes.PushKinds.Fetch, {
			ready = true,
			caught = true,
			air = air,
			streak = streaks[player],
			xp = xp,
			count = count,
			goal = goal,
			inPark = inPark,
			done = inPark and count >= goal,
		})
		if inPark and count >= goal then
			parkCatches[player] = 0
			Activity.complete(player, "fetch")
		end
	end)
	return true, nil
end

function Fetch.init(services, activity)
	S = services
	Activity = activity
	pcall(function()
		PhysicsService:RegisterCollisionGroup(BALL_GROUP)
		PhysicsService:RegisterCollisionGroup(CHAR_GROUP)
		PhysicsService:CollisionGroupSetCollidable(BALL_GROUP, CHAR_GROUP, false)
		PhysicsService:CollisionGroupSetCollidable(BALL_GROUP, BALL_GROUP, false)
	end)
end

function Fetch.start()
	local function giveIfReady(player: Player)
		local profile = S.Data.get(player)
		if profile and profile.activePetId and player.Character then
			makeTool(player)
		end
	end
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character)
			charGroup(character)
			task.wait(0.5)
			giveIfReady(player)
		end)
		if player.Character then
			charGroup(player.Character)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in Players:GetPlayers() do
		hook(p)
	end
	S.Data.onLoaded(giveIfReady)
	require(script.Parent.Parent.Core.EventBus).subscribe("pet.adopted", function(player)
		task.wait(1)
		giveIfReady(player)
	end)

	S.Net.on(Remotes.RequestKinds.FetchThrow, function(player, payload)
		if typeof(payload) ~= "table" then
			return false, nil
		end
		return Fetch.throw(player, payload.target, payload.power)
	end, 0.3)
	S.Net.on(Remotes.RequestKinds.FetchReady, function(player, payload)
		Fetch.setReady(player, typeof(payload) == "table" and payload.ready == true)
		return true
	end, 0.1)
	Players.PlayerRemoving:Connect(function(player)
		parkCatches[player] = nil
		streaks[player] = nil
		lastThrow[player] = nil
	end)
end

return Fetch
