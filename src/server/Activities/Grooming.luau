--[[
	Grooming: Wash & Groom, the spa minigame at the Fluff & Puff Salon.

	Walk up to a grooming tub (tagged "GroomStation") and start. The dog hops
	in, and the player does four hands-on steps (Client.GroomingGestures):
	brush (drag strokes along the dog), wash (scrub in circles), rinse
	(sweep across), dry (hold).

	Server checks (rules in Logic/GroomRules):
	  * one run id per visit; every report names it
	  * nothing counts until the dog is in the tub (the run's ready flag)
	  * steps in order; each reports 25/50/75/100 % once, in order, no
	    faster than a minimum time apart
	  * the player stays near the tub (as before)
	The result is a 1-3 star shine: server-measured time per step sets the
	base, and the client's evenness estimate (clamped 0-1) moves it by at
	most one star. Finishing makes the dog sparkle for a few minutes
	(ShinyUntil attribute) and pays the "grooming" rewards with the shine as
	the rating.
]]

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local GroomRules = require(script.Parent.Parent.Logic.GroomRules)

local STEPS = GroomRules.STEPS
local LEASH = 24
local SHINE_SECONDS = 180

local Grooming = {}
local S, Activity

local function setFx(player: Player, fx: string?)
	local model = S.Pet.getModel(player)
	if model then
		model:SetAttribute("GroomFx", fx)
	end
end

local function begin(player: Player, station: BasePart)
	local ok, reason = Activity.canStart(player, "grooming")
	if not ok then
		S.Net.toast(player, reason or "Not right now.", "info")
		return
	end
	local hrp = Activity.hrp(player)
	if not hrp or (hrp.Position - station.Position).Magnitude > 14 then
		return
	end
	local spot = station:FindFirstChild("DogSpot") :: Attachment
	local run = GroomRules.newRun(HttpService:GenerateGUID(false), os.clock())
	local session
	session = Activity.begin(player, "grooming", function()
		GroomRules.cancel(run)
		setFx(player, nil)
		S.Pet.settle(player)
		S.Net.push(player, Remotes.PushKinds.Grooming, { state = "cancel", runId = run.id })
	end)
	session.data.run = run
	session.data.station = station

	local moved, _, token = S.Pet.setState(player, "MovingToTarget", { byActivity = true, target = spot })
	if not moved then
		Activity.interrupt(player, "no pet")
		return
	end
	task.spawn(function()
		local pet = S.Pet.getActive(player)
		if pet and (pet.root.Position - spot.WorldPosition).Magnitude > 30 then
			-- The dog was far away (e.g. left staying elsewhere): bring it over.
			pet.model:PivotTo(CFrame.new(spot.WorldPosition + Vector3.new(4, 0, 0)))
		end
		local t = 0
		while pet and t < 4 and S.Pet.isCurrent(player, token) do
			if (pet.root.Position - spot.WorldPosition).Magnitude < 1.5 then
				break
			end
			t += task.wait(0.1)
		end
		if pet and S.Pet.isCurrent(player, token) and (pet.root.Position - spot.WorldPosition).Magnitude >= 1.5 then
			pet.model:PivotTo(CFrame.new(spot.WorldPosition)) -- hop in if it got stuck
		end
		if Activity.current(player) == session and S.Pet.isCurrent(player, token) then
			S.Pet.setState(player, "Grooming", { byActivity = true })
			-- Hold the dog in the tub (hold = where it is now). Only now do
			-- step reports count.
			GroomRules.setReady(run, os.clock())
			setFx(player, STEPS[1])
			S.Net.push(player, Remotes.PushKinds.Grooming, {
				state = "start",
				runId = run.id,
				steps = STEPS,
				minSeconds = GroomRules.MIN_MILESTONE_SECONDS,
			})
		end
	end)
end

local REASONS = {
	fast = "Keep scrubbing!", -- the client waits a moment and resends
}

-- GroomStep request: { runId, step = 1..4, pct = 25 | 50 | 75 | 100, evenness = 0..1 }
local function step(player: Player, payload: any): (boolean, string?)
	local session = Activity.current(player)
	if not session or session.id ~= "grooming" or typeof(payload) ~= "table" then
		return false, nil
	end
	local hrp = Activity.hrp(player)
	if not hrp or (hrp.Position - session.data.station.Position).Magnitude > LEASH then
		Activity.interrupt(player, "walked away")
		return false, nil
	end
	local run = session.data.run
	local ok, why, event = GroomRules.report(run, payload.runId, payload.step, payload.pct, payload.evenness, os.clock())
	if not ok then
		return false, why and REASONS[why] or nil
	end
	if event == "milestone" then
		return true, nil
	end
	if event == "step" then
		-- Next step: its effect (bubbles, water, air) runs while you work.
		setFx(player, STEPS[run.step])
		S.Pet.react(player, "happy")
		S.Net.push(player, Remotes.PushKinds.Grooming, { state = "step", runId = run.id, step = run.step })
		return true, nil
	end
	-- All four steps done.
	local done, _, stars = GroomRules.complete(run, run.id)
	if not done then
		return true, nil
	end
	Activity.finish(player, session)
	local model = S.Pet.getModel(player)
	if model then
		model:SetAttribute("ShinyUntil", workspace:GetServerTimeNow() + SHINE_SECONDS)
	end
	S.Net.push(player, Remotes.PushKinds.Grooming, { state = "done", runId = run.id, stars = stars })
	-- The dog shakes off in the tub, then hops out sparkling and the rewards
	-- (with the shine as the rating) are paid once.
	S.Pet.react(player, "shake")
	task.delay(1.2, function()
		setFx(player, nil)
		if S.Pet.getState(player) == "Grooming" then
			S.Pet.settle(player)
		end
		Activity.complete(player, "grooming", { rating = stars })
	end)
	return true, nil
end

function Grooming.init(services, activity)
	S = services
	Activity = activity
end

function Grooming.start()
	local function setup(station: Instance)
		if not station:IsA("BasePart") or station:FindFirstChild("GroomPrompt") then
			return
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "GroomPrompt"
		prompt.ActionText = "Spa time"
		prompt.ObjectText = "Grooming Tub"
		prompt.HoldDuration = 0.25
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = station
		prompt.Triggered:Connect(function(player)
			begin(player, station)
		end)
	end
	CollectionService:GetInstanceAddedSignal("GroomStation"):Connect(setup)
	for _, s in CollectionService:GetTagged("GroomStation") do
		setup(s)
	end
	S.Net.on(Remotes.RequestKinds.GroomStep, step, 0.2)

	-- Walking away ends the spa session.
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, player in Players:GetPlayers() do
				local session = Activity.current(player)
				if session and session.id == "grooming" then
					local hrp = Activity.hrp(player)
					if not hrp or (hrp.Position - session.data.station.Position).Magnitude > LEASH then
						Activity.interrupt(player, "walked away")
					end
				end
			end
		end
	end)
end

return Grooming
