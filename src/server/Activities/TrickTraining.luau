--[[
	TrickTraining: a timing game on the Training Grounds' training mat.

	Three rounds. A marker sweeps across a bar; press when it's in the green
	zone. The SERVER decides hits from its own clock (with a small allowance
	for the player's ping), so clients can't fake success. Two hits out of
	three = success: the dog performs the move and the activity pays out.

	Difficulty rises with each completion (narrower zone, faster marker).
	Moves practiced: "sit" for everyone, plus every trick the dog has
	unlocked through Bond Levels.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BondCatalog = require(ReplicatedStorage.Shared.Catalogs.BondCatalog)
local PetActions = require(ReplicatedStorage.Shared.Catalogs.PetActions)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ROUNDS = 3
local NEEDED = 2
local LEASH = 22
local SLACK = 0.05 -- extra zone width to forgive tiny timing differences

local Training = {}
local S, Activity

local function movesFor(player: Player): { { id: string, label: string } }
	local moves = { { id = "sit", label = "Sit" } }
	local level = S.Bond.level(player)
	for _, id in PetActions.TrickOrder do
		if BondCatalog.isUnlocked(level, "trick", id) then
			table.insert(moves, { id = id, label = PetActions.Tricks[id].label })
		end
	end
	return moves
end

local function startRound(player: Player, session)
	local d = session.data
	d.round += 1
	d.pressed = false
	d.startAt = workspace:GetServerTimeNow() + 0.6
	local width = d.width
	d.zoneStart = 0.2 + math.random() * (0.75 - width)
	d.zoneEnd = d.zoneStart + width
	S.Net.push(player, Remotes.PushKinds.Training, {
		state = "round",
		round = d.round,
		rounds = ROUNDS,
		move = d.move.label,
		zoneStart = d.zoneStart,
		zoneEnd = d.zoneEnd,
		period = d.period,
		startAt = d.startAt,
	})
	local round = d.round
	-- No press in time counts as a miss.
	task.delay(0.6 + d.period * 3, function()
		if Activity.current(player) == session and d.round == round and not d.pressed then
			Training.press(player, true)
		end
	end)
end

local function finishSession(player: Player, session)
	local d = session.data
	Activity.finish(player, session)
	local success = d.hits >= NEEDED
	S.Net.push(player, Remotes.PushKinds.Training, { state = "done", success = success, hits = d.hits, rounds = ROUNDS })
	if success then
		if d.move.id == "sit" then
			S.Pet.setState(player, "Sitting", { force = true })
			task.delay(1.5, function()
				local state = S.Pet.getState(player)
				if state == "Sitting" then
					S.Pet.setState(player, "Following", { force = true })
				end
			end)
		else
			S.Pet.setState(player, "PerformingTrick", { force = true, trick = d.move.id, duration = PetActions.Tricks[d.move.id].duration })
		end
		Activity.complete(player, "trick_training")
	else
		S.Pet.settle(player)
		S.Net.toast(player, `So close! {S.Pet.name(player)} wants to try again.`, "info")
	end
end

-- Called by the TrainPress request (or by the timeout with missed = true).
function Training.press(player: Player, missed: boolean?): (boolean, string?)
	local session = Activity.current(player)
	if not session or session.id ~= "trick_training" then
		return false, nil
	end
	local d = session.data
	if d.pressed then
		return false, nil
	end
	d.pressed = true
	local hit = false
	if not missed then
		local ping = math.clamp(player:GetNetworkPing(), 0, 0.4)
		local t = workspace:GetServerTimeNow() - ping - d.startAt
		if t >= 0 then
			local pos = (t / d.period) % 1
			hit = pos >= d.zoneStart - SLACK and pos <= d.zoneEnd + SLACK
		end
	end
	if hit then
		d.hits += 1
		S.Pet.react(player, "happy")
	end
	S.Net.push(player, Remotes.PushKinds.Training, { state = "result", hit = hit, round = d.round })
	task.delay(1.1, function()
		if Activity.current(player) ~= session then
			return
		end
		if d.round >= ROUNDS then
			finishSession(player, session)
		else
			startRound(player, session)
		end
	end)
	return true, nil
end

local function begin(player: Player, mat: BasePart)
	local ok, reason = Activity.canStart(player, "trick_training")
	if not ok then
		S.Net.toast(player, reason or "Not right now.", "info")
		return
	end
	local hrp = Activity.hrp(player)
	if not hrp or (hrp.Position - mat.Position).Magnitude > 14 then
		return
	end
	local profile = S.Data.get(player)
	local done = profile and profile.activities.trick_training and profile.activities.trick_training.count or 0
	local tier = math.min(done, 4)
	local moves = movesFor(player)

	local session = Activity.begin(player, "trick_training", function()
		S.Net.push(player, Remotes.PushKinds.Training, { state = "cancel" })
		S.Pet.settle(player)
	end)
	session.data = {
		round = 0,
		hits = 0,
		pressed = false,
		move = moves[math.random(1, #moves)],
		width = math.max(0.12, 0.3 - 0.045 * tier),
		period = math.max(0.95, 1.6 - 0.15 * tier),
		mat = mat,
	}
	S.Pet.setState(player, "Idle", { force = true })
	S.Net.push(player, Remotes.PushKinds.Training, { state = "start", tier = tier + 1, move = session.data.move.label })
	startRound(player, session)
end

function Training.init(services, activity)
	S = services
	Activity = activity
end

function Training.start()
	local function setup(mat: Instance)
		if not mat:IsA("BasePart") or mat:FindFirstChild("TrainPrompt") then
			return
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "TrainPrompt"
		prompt.ActionText = "Practice tricks"
		prompt.ObjectText = "Training Mat"
		prompt.HoldDuration = 0.25
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = mat
		prompt.Triggered:Connect(function(player)
			begin(player, mat)
		end)
	end
	CollectionService:GetInstanceAddedSignal("TrainingMat"):Connect(setup)
	for _, m in CollectionService:GetTagged("TrainingMat") do
		setup(m)
	end
	S.Net.on(Remotes.RequestKinds.TrainPress, function(player)
		local session = Activity.current(player)
		local hrp = Activity.hrp(player)
		if session and session.id == "trick_training" and (not hrp or (hrp.Position - session.data.mat.Position).Magnitude > LEASH) then
			Activity.interrupt(player, "walked away")
			return false, nil
		end
		return Training.press(player, false)
	end, 0.2)
end

return Training
