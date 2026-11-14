--[[
	Grooming: the spa minigame at the Fluff & Puff Salon.

	Walk up to a grooming tub (tagged "GroomStation") and start. The dog hops
	in, and the player clears four steps on screen: brush, wash, rinse, dry.
	The server checks the steps arrive in order and not impossibly fast, and
	that the player stays nearby. Finishing makes the dog sparkle for a few
	minutes (ShinyUntil attribute) and pays the "grooming" activity rewards.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local STEPS = { "brush", "wash", "rinse", "dry" }
local MIN_STEP_SECONDS = 1.0
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
	local session
	session = Activity.begin(player, "grooming", function()
		setFx(player, nil)
		S.Pet.settle(player)
		S.Net.push(player, Remotes.PushKinds.Grooming, { state = "cancel" })
	end)
	session.data.step = 0
	session.data.stepAt = os.clock()
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
			-- Hold the dog in the tub (hold = where it is now).
			session.data.stepAt = os.clock()
			S.Net.push(player, Remotes.PushKinds.Grooming, { state = "start", steps = STEPS })
		end
	end)
end

local function step(player: Player, payload: any): (boolean, string?)
	local session = Activity.current(player)
	if not session or session.id ~= "grooming" or typeof(payload) ~= "table" then
		return false, nil
	end
	local n = payload.step
	if typeof(n) ~= "number" or n ~= session.data.step + 1 or n > #STEPS then
		return false, nil
	end
	local now = os.clock()
	if now - session.data.stepAt < MIN_STEP_SECONDS then
		return false, "Keep scrubbing!"
	end
	local hrp = Activity.hrp(player)
	if not hrp or (hrp.Position - session.data.station.Position).Magnitude > LEASH then
		Activity.interrupt(player, "walked away")
		return false, nil
	end
	session.data.step = n
	session.data.stepAt = now
	setFx(player, STEPS[n])
	S.Pet.react(player, n == #STEPS and "sparkle" or "happy")

	if n == #STEPS then
		Activity.finish(player, session)
		local model = S.Pet.getModel(player)
		if model then
			model:SetAttribute("ShinyUntil", workspace:GetServerTimeNow() + SHINE_SECONDS)
		end
		task.delay(1.2, function()
			setFx(player, nil)
		end)
		S.Pet.settle(player)
		S.Net.push(player, Remotes.PushKinds.Grooming, { state = "done" })
		Activity.complete(player, "grooming")
	end
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
