--[[
	Agility: the Training Grounds obstacle course. Step on START, pass rings
	1..N in order, reach FINISH. Times under the medal thresholds in
	Content/Activities earn one-time bonuses, so there's a reason to improve.

	The course is found by name inside the world (AgilityStart, AgilityFinish,
	parts with a RingIndex attribute), so builders can move pieces freely.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Agility = {}
local S, Activity
-- A run longer than this is abandoned (walked off the course).
local MAX_RUN_SECONDS = 120

type Run = { started: number, nextRing: number, session: any }
local runs: { [Player]: Run } = {}
local hintAt: { [Player]: number } = {}

local function hint(player: Player, text: string)
	local now = os.clock()
	if hintAt[player] and now - hintAt[player] < 3 then
		return
	end
	hintAt[player] = now
	S.Net.toast(player, text, "info")
end

local function playerFromHit(hit: BasePart): Player?
	local model = hit:FindFirstAncestorOfClass("Model")
	return model and Players:GetPlayerFromCharacter(model)
end

local function hook(course: Instance)
	local total = 0
	for _, d in course:GetDescendants() do
		if d:GetAttribute("RingIndex") then
			total += 1
		end
	end
	local start = course:FindFirstChild("AgilityStart", true) :: BasePart?
	local finish = course:FindFirstChild("AgilityFinish", true) :: BasePart?
	if not start or not finish or total == 0 then
		warn("[Agility] course parts missing")
		return
	end
	local def = Activity.def("agility")

	start.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if not player or not S.Data.get(player) then
			return
		end
		local ok = Activity.canStart(player, "agility")
		if not ok then
			hint(player, "Play fetch at Sunny Dog Park first to unlock the course!")
			return
		end
		local run = runs[player]
		if run and run.nextRing > 1 and os.clock() - run.started < 60 then
			return -- mid-run; ignore stepping back on start
		end
		if run and Activity.current(player) == run.session then
			-- Still on (or back at) the start pad: restart the same run.
			run.started = os.clock()
			run.nextRing = 1
		else
			-- A run is an activity session, so the rest of the game (dog
			-- commands, story invitations) knows the player is busy.
			-- Another activity, a dog command, or the timeout interrupts it.
			local newRun: Run = { started = os.clock(), nextRing = 1, session = nil :: any }
			newRun.session = Activity.begin(player, "agility", function()
				if runs[player] == newRun then
					runs[player] = nil
				end
				S.Net.push(player, Remotes.PushKinds.Agility, { state = "cancelled" })
			end)
			runs[player] = newRun
			run = newRun
		end
		local active = run :: Run
		local startedAt = active.started
		task.delay(MAX_RUN_SECONDS, function()
			if runs[player] == active and active.started == startedAt then
				Activity.interrupt(player, "timeout", active.session)
			end
		end)
		local medals = {}
		for _, m in def.medals do
			table.insert(medals, { label = m.label, under = m.under })
		end
		S.Net.push(player, Remotes.PushKinds.Agility, { state = "running", ring = 0, total = total, medals = medals })
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
		Activity.finish(player, run.session)
		if elapsed < def.minSeconds then
			return
		end
		local seconds = math.floor(elapsed * 10) / 10
		S.Net.push(player, Remotes.PushKinds.Agility, { state = "finished", time = seconds, total = total })
		Activity.complete(player, "agility", { timeSeconds = seconds })
	end)
end

function Agility.init(services, activity)
	S = services
	Activity = activity
end

function Agility.start()
	local course = S.World.getAgilityCourse()
	if course then
		hook(course)
	end
	Players.PlayerRemoving:Connect(function(player)
		runs[player] = nil
		hintAt[player] = nil
	end)
end

return Agility
