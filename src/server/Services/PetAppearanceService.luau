--[[
	PetAppearanceService: makes a pet model (and the owner's character) look
	like the saved data says. Rebuilds cosmetics from scratch each time, which
	is cheap at this scale and can't drift out of sync.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Accessories = require(ReplicatedStorage.Shared.Accessories)
local DogRig = require(ReplicatedStorage.Shared.DogRig)
local ItemCatalog = require(ReplicatedStorage.Shared.Catalogs.ItemCatalog)
local PetCatalog = require(ReplicatedStorage.Shared.Catalogs.PetCatalog)
local ProfileSchema = require(script.Parent.Parent.Data.ProfileSchema)

local Appearance = {}
local S

local function clearCosmetics(container: Instance)
	for _, child in container:GetChildren() do
		if child.Name == "Cosmetic" or child.Name == "Leash" then
			child:Destroy()
		end
	end
end

local function visualFor(itemId: string?): { [string]: any }?
	local item = itemId and ItemCatalog.get(itemId)
	return item and item.visual or nil
end

-- Applies fur + accessories to any dog model built by DogRig.
function Appearance.applyPet(model: Model, pet: ProfileSchema.PetInstance, owner: Model?)
	local breed = PetCatalog.get(pet.breedId) or PetCatalog.get("golden")
	assert(breed, "missing default breed")
	clearCosmetics(model)

	local fur = visualFor(pet.equipped.fur)
	if fur and fur.color then
		DogRig.setFur(model, fur.color)
	else
		DogRig.setFur(model, breed.furColor, breed.accentColor)
	end

	for slot, itemId in pet.equipped do
		local visual = visualFor(itemId)
		local slotDef = PetCatalog.Slots[slot]
		if visual and slotDef and slotDef.attachment and Accessories.canBuild(visual) then
			local attachment = model:FindFirstChild(slotDef.attachment, true)
			if attachment and attachment:IsA("Attachment") then
				Accessories.attach(model, attachment, visual, breed.scale)
			end
		end
	end

	-- Leash: a beam from the owner's hand to the collar.
	local leash = visualFor(pet.equipped.leash)
	if leash and owner then
		local hand = owner:FindFirstChild("RightGripAttachment", true)
		local collar = model:FindFirstChild("CollarAttachment", true)
		if hand and collar then
			local beam = Instance.new("Beam")
			beam.Name = "Leash"
			beam.Attachment0 = hand :: Attachment
			beam.Attachment1 = collar :: Attachment
			beam.Color = ColorSequence.new(leash.color)
			beam.Width0 = 0.15
			beam.Width1 = 0.15
			beam.CurveSize0 = -1.5
			beam.CurveSize1 = 1.5
			beam.Segments = 12
			beam.FaceCamera = true
			beam.LightInfluence = 0
			beam.Parent = model
		end
	end
end

function Appearance.applyPlayer(character: Model, profile: ProfileSchema.Profile)
	clearCosmetics(character)
	for slot, itemId in profile.playerEquipped do
		local visual = visualFor(itemId)
		if slot == "player_head" and visual and Accessories.canBuild(visual) then
			local attachment = character:FindFirstChild("HatAttachment", true)
			if attachment and attachment:IsA("Attachment") then
				Accessories.attach(character, attachment, visual, 1.15)
			end
		end
	end
end

function Appearance.refreshPet(player: Player)
	local profile = S.Data.get(player)
	local model = S.Pet.getModel(player)
	local pet = profile and ProfileSchema.activePet(profile)
	if model and pet then
		Appearance.applyPet(model, pet, player.Character)
	end
end

function Appearance.refreshPlayer(player: Player)
	local profile = S.Data.get(player)
	if profile and player.Character then
		Appearance.applyPlayer(player.Character, profile)
	end
	-- The leash attaches to the character, so refresh the pet too.
	Appearance.refreshPet(player)
end

function Appearance.init(services)
	S = services
end

function Appearance.start() end

return Appearance
