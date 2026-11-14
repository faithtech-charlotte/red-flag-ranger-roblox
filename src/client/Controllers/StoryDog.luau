--[[
	StoryDog: Sparkz_Pup's dog, built on this client only, as a copy of the
	local player's own breed (campaign-script 6: "Sparkz's dog is the
	player's own breed, shown only to that player"). It is a DogRig visual,
	never a registered pet: no server model, no physics, no owner.

	WorldController calls update() from its one visibility rule, so the dog
	shows exactly when its NPC does.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DogRig = require(ReplicatedStorage.Shared.DogRig)
local PetCatalog = require(ReplicatedStorage.Shared.Catalogs.PetCatalog)

local SIDE_OFFSET = Vector3.new(3, 0, -1.5) -- beside the NPC, in its space

local StoryDog = {}
local dogs: { [Model]: { model: Model, breedId: string } } = {}
local folder: Folder? = nil
local watched: { [Model]: boolean } = {}

local function container(): Folder
	if folder and folder.Parent then
		return folder
	end
	local f = Instance.new("Folder")
	f.Name = "StoryDogs"
	f.Parent = workspace
	folder = f
	return f
end

local function remove(npc: Model)
	local current = dogs[npc]
	if current then
		current.model:Destroy()
		dogs[npc] = nil
	end
end

function StoryDog.update(npc: Model, visible: boolean, breedId: string?)
	local breed = breedId and PetCatalog.get(breedId)
	if not visible or not breed or not npc.Parent then
		remove(npc)
		return
	end
	local current = dogs[npc]
	if current and current.breedId == breed.id then
		return
	end
	remove(npc)
	local dog = DogRig.build({
		furColor = breed.furColor,
		accentColor = breed.accentColor,
		earStyle = breed.earStyle,
		scale = breed.scale,
		anchored = true,
	})
	dog.Name = "StoryDog"
	local box, size = npc:GetBoundingBox()
	local groundY = box.Position.Y - size.Y / 2
	local pivot = npc:GetPivot()
	local side = pivot:PointToWorldSpace(SIDE_OFFSET)
	local pos = Vector3.new(side.X, groundY + DogRig.GROUND_OFFSET * breed.scale, side.Z)
	dog:PivotTo(CFrame.new(pos) * pivot.Rotation)
	dog.Parent = container()
	dogs[npc] = { model = dog, breedId = breed.id }
	if not watched[npc] then
		watched[npc] = true
		npc.Destroying:Once(function()
			remove(npc)
			watched[npc] = nil
		end)
	end
end

return StoryDog
