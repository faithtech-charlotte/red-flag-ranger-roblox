--[[
	Props: interactive world objects, found by CollectionService tag so
	builders can place more of them anywhere.

	  FetchStation  "Grab a ball": starts the shared fetch aiming mode
	  PetToy        "Squeaky toy": the dog pounces and plays (Bond XP)
	  MissionBoard  "Missions": opens the Ranger Journal
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventBus = require(script.Parent.Parent.Core.EventBus)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Props = {}
local S, Activity

local function near(player: Player, part: BasePart, distance: number): boolean
	local hrp = Activity.hrp(player)
	return hrp ~= nil and (hrp.Position - part.Position).Magnitude <= distance
end

local HANDLERS = {
	FetchStation = {
		action = "Grab a ball",
		object = "Ball Bucket",
		run = function(player: Player)
			if not S.Pet.getActive(player) then
				S.Net.toast(player, "Adopt a dog first!", "info")
				return
			end
			S.Net.push(player, Remotes.PushKinds.FetchAim)
		end,
	},
	PetToy = {
		action = "Play",
		object = "Squeaky Toy",
		run = function(player: Player, part: BasePart)
			if not S.Pet.getActive(player) then
				S.Net.toast(player, "Adopt a dog first!", "info")
				return
			end
			if Activity.current(player) then
				return
			end
			if S.Pet.distanceToOwner(player) > 24 then
				S.Net.toast(player, "Call your dog over first!", "info")
				return
			end
			local ok = S.Pet.setState(player, "PerformingTrick", { trick = "play_toy", duration = 2.4 })
			if ok then
				S.Pet.react(player, "happy")
				S.Bond.addXp(player, "toy")
				EventBus.publish("pet.interacted", player, { action = "toy" })
				-- A little squish so everyone sees the toy being played with.
				local original = part.Size
				part.Size = original * Vector3.new(1.2, 0.7, 1.2)
				task.delay(0.25, function()
					part.Size = original
				end)
			end
		end,
	},
	MissionBoard = {
		action = "Missions",
		object = "Mission Board",
		run = function(player: Player)
			S.Net.push(player, Remotes.PushKinds.OpenMissions)
		end,
	},
}

function Props.init(services, activity)
	S = services
	Activity = activity
end

function Props.start()
	for tag, handler in HANDLERS do
		local function setup(part: Instance)
			if not part:IsA("BasePart") or part:FindFirstChild("PropPrompt") then
				return
			end
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "PropPrompt"
			prompt.ActionText = handler.action
			prompt.ObjectText = handler.object
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 10
			prompt.RequiresLineOfSight = false
			prompt.Parent = part
			prompt.Triggered:Connect(function(player)
				if near(player, part, 16) then
					handler.run(player, part)
				end
			end)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(setup)
		for _, p in CollectionService:GetTagged(tag) do
			setup(p)
		end
	end
end

return Props
