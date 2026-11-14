--[[
	ActivityService: fetch and the agility course. All timing, counting, and
	rewards happen here; the client only asks to throw and shows progress.

	Anti-farming:
	  * One fetch at a time; each throw needs the dog to actually return.
	  * Agility rings must be passed in order and the run must take a
	    plausible minimum time.
	  * First-completion bonuses are claimed once (profile.claims).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local ActionService = require(script.Parent.Parent.Core.ActionService)
local EventBus = require(script.Parent.Parent.Core.EventBus)
local Places = require(ReplicatedStorage.Shared.Places)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Activities = {
	fetch = { name = "Fetch", reward = 8, firstBonus = 17, goal = 3 },
	agility = { name = "Agility Course", reward = 12, firstBonus = 18, minSeconds = 6 },
}

local THROW_DISTANCE = 24
local FETCH_TIMEOUT = 8

local Activity = {}
local S
local fetchState: { [Player]: { count: number, busy: boolean } } = {}
local runs: { [Player]: { started: number, nextRing: number } } = {}
local hintAt: { [Player]: number } = {}

local function hrpOf(player: Player): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function hint(player: Player, text: string)
	local now = os.clock()
	if hintAt[player] and now - hintAt[player] < 3 then
		return
	end
	hintAt[player] = now
	S.Net.toast(player, text, "info")
end

function Activity.complete(player: Player, activityId: string, data: { [string]: any }?)
	local def = Activities[activityId]
	local profile = S.Data.get(player)
	if not def or not profile then
		return
	end
	local record = profile.activities[activityId] or { count = 0 }
	record.count += 1
	if data and data.timeSeconds and (record.best == nil or data.timeSeconds < record.best) then
		record.best = data.timeSeconds
	end
	profile.activities[activityId] = record

	local reward = def.reward
	local claim = "first:" .. activityId
	if not profile.claims[claim] then
		profile.claims[claim] = true
		reward += def.firstBonus
	end
	S.Economy.grant(player, reward, activityId)
	S.Pet.react(player, "happy")
	S.Net.push(player, Remotes.PushKinds.Celebrate, {
		title = `{def.name} complete!`,
		coins = reward,
	})
	EventBus.publish("activity.completed", player, {
		activityId = activityId,
		count = record.count,
		timeSeconds = data and data.timeSeconds,
	})
	S.Data.pushState(player)
end

----------------------------------------------------------------------------
-- Fetch
----------------------------------------------------------------------------

local function waitUntil(predicate: () -> boolean, timeout: number): boolean
	local t = 0
	while t < timeout do
		if predicate() then
			return true
		end
		t += task.wait(0.1)
	end
	return false
end

local function throwBall(player: Player): (boolean, string?)
	local profile = S.Data.get(player)
	local hrp = hrpOf(player)
	local pet = S.Pet.getActive(player)
	if not profile or not profile.activePetId or not pet then
		return false, "Adopt a dog first!"
	end
	if not hrp or not Places.isInside("dog_park", hrp.Position) then
		return false, "Fetch works at Sunny Dog Park."
	end
	local state = fetchState[player] or { count = 0, busy = false }
	fetchState[player] = state
	if state.busy then
		return false, "Wait for your dog to bring the ball back!"
	end
	state.busy = true

	task.spawn(function()
		local park = Places.get("dog_park") :: Places.Place
		local flat = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
		if flat.Magnitude < 0.1 then
			flat = Vector3.new(0, 0, -1)
		end
		local target = hrp.Position + flat.Unit * THROW_DISTANCE
		local half = park.size / 2 - Vector3.new(5, 0, 5)
		target = Vector3.new(
			math.clamp(target.X, park.center.X - half.X, park.center.X + half.X),
			0.6,
			math.clamp(target.Z, park.center.Z - half.Z, park.center.Z + half.Z)
		)

		local ball = Instance.new("Part")
		ball.Name = "FetchBall"
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.new(1.2, 1.2, 1.2)
		ball.Color = Color3.fromRGB(200, 255, 60)
		ball.Material = Enum.Material.SmoothPlastic
		ball.Anchored = true
		ball.CanCollide = false
		ball.CanQuery = false
		ball.CanTouch = false
		ball.Position = hrp.Position + Vector3.new(0, 1.5, 0) + flat.Unit * 2
		local hold = Instance.new("Attachment")
		hold.Name = "BallTarget"
		hold.Position = Vector3.new(0, 0.9, 0.9)
		hold.Parent = ball
		ball.Parent = workspace
		Debris:AddItem(ball, 30)

		local mid = (ball.Position + target) / 2 + Vector3.new(0, 9, 0)
		local up = TweenService:Create(ball, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = mid })
		up:Play()
		up.Completed:Wait()
		local down = TweenService:Create(ball, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = target })
		down:Play()
		down.Completed:Wait()

		local active = S.Pet.getActive(player)
		if not active then
			state.busy = false
			ball:Destroy()
			return
		end
		S.Pet.setTarget(player, hold)
		waitUntil(function()
			return (active.root.Position - ball.Position).Magnitude < 3.5
		end, FETCH_TIMEOUT)

		-- Ball in mouth, run back.
		local mouth = active.model:FindFirstChild("MouthAttachment", true) :: Attachment?
		if mouth and ball.Parent then
			ball.Size = Vector3.new(0.8, 0.8, 0.8)
			ball.Anchored = false
			ball.Massless = true
			ball.CFrame = mouth.WorldCFrame
			local w = Instance.new("WeldConstraint")
			w.Part0 = mouth.Parent :: BasePart
			w.Part1 = ball
			w.Parent = ball
			ball.Parent = active.model
		end
		S.Pet.setTarget(player, nil)
		local back = waitUntil(function()
			local h = hrpOf(player)
			return h ~= nil and (active.root.Position - h.Position).Magnitude < 8
		end, FETCH_TIMEOUT)
		ball:Destroy()
		state.busy = false
		if not back or not player.Parent then
			S.Net.push(player, Remotes.PushKinds.Fetch, { count = state.count, goal = Activities.fetch.goal })
			return
		end
		state.count += 1
		S.Pet.react(player, "happy")
		if state.count >= Activities.fetch.goal then
			state.count = 0
			S.Net.push(player, Remotes.PushKinds.Fetch, { count = Activities.fetch.goal, goal = Activities.fetch.goal, done = true })
			Activity.complete(player, "fetch")
		else
			S.Net.push(player, Remotes.PushKinds.Fetch, { count = state.count, goal = Activities.fetch.goal })
		end
	end)
	return true, nil
end

----------------------------------------------------------------------------
-- Agility
----------------------------------------------------------------------------

local function playerFromHit(hit: BasePart): Player?
	local model = hit:FindFirstAncestorOfClass("Model")
	return model and Players:GetPlayerFromCharacter(model)
end

local function ringCount(course: Instance): number
	local n = 0
	for _, d in course:GetDescendants() do
		if d:GetAttribute("RingIndex") then
			n += 1
		end
	end
	return n
end

local function hookAgility(course: Instance)
	local total = ringCount(course)
	local start = course:FindFirstChild("AgilityStart", true) :: BasePart?
	local finish = course:FindFirstChild("AgilityFinish", true) :: BasePart?
	if not start or not finish or total == 0 then
		warn("[Activity] agility course parts missing")
		return
	end

	start.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if not player then
			return
		end
		local profile = S.Data.get(player)
		if not profile then
			return
		end
		if not profile.unlocks.agility then
			hint(player, "Play fetch at Sunny Dog Park first to unlock the course!")
			return
		end
		local run = runs[player]
		if run and run.nextRing > 1 and os.clock() - run.started < 60 then
			return -- mid-run; ignore stepping back on start
		end
		runs[player] = { started = os.clock(), nextRing = 1 }
		S.Net.push(player, Remotes.PushKinds.Agility, { state = "running", ring = 0, total = total })
	end)

	for _, d in course:GetDescendants() do
		local index = d:GetAttribute("RingIndex")
		if index and d:IsA("BasePart") then
			d.Touched:Connect(function(hit)
				local player = playerFromHit(hit)
				local run = player and runs[player]
				if run and run.nextRing == index then
					run.nextRing += 1
					S.Net.push(player :: Player, Remotes.PushKinds.Agility, { state = "running", ring = index, total = total })
				end
			end)
		end
	end

	finish.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		local run = player and runs[player]
		if not player or not run then
			return
		end
		if run.nextRing <= total then
			hint(player, `Go through every ring first! ({run.nextRing - 1}/{total})`)
			return
		end
		local elapsed = os.clock() - run.started
		runs[player] = nil
		if elapsed < Activities.agility.minSeconds then
			return
		end
		local seconds = math.floor(elapsed * 10) / 10
		S.Net.push(player, Remotes.PushKinds.Agility, { state = "finished", time = seconds, total = total })
		Activity.complete(player, "agility", { timeSeconds = seconds })
	end)
end

function Activity.init(services)
	S = services
	ActionService.register("unlock_activity", function(player, spec)
		local profile = S.Data.get(player)
		if not profile or not Activities[spec.activityId] then
			return false, "unknown activity"
		end
		if not profile.unlocks[spec.activityId] then
			profile.unlocks[spec.activityId] = true
			S.Net.toast(player, `New activity unlocked: {Activities[spec.activityId].name}!`, "success")
			S.Data.pushState(player)
		end
		return true
	end)
end

function Activity.start()
	S.Net.on(Remotes.RequestKinds.ThrowBall, throwBall, 0.5)
	task.spawn(function()
		local course = S.World.getAgilityCourse()
		if course then
			hookAgility(course)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		fetchState[player] = nil
		runs[player] = nil
		hintAt[player] = nil
	end)
end

return Activity
