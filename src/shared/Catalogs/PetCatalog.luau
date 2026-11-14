--[[
	PetCatalog: PetDefinitions (breeds). Every breed shares one procedural rig
	("dog_basic", built by Shared.DogRig) and differs only by configuration.
	Adding a breed = adding an entry here.
]]

export type Breed = {
	id: string,
	displayName: string,
	description: string,
	rig: string,
	furColor: Color3,
	accentColor: Color3,
	earStyle: "floppy" | "pointy",
	scale: number,
	defaultNames: { string },
}

local Breeds: { [string]: Breed } = {
	golden = {
		id = "golden",
		displayName = "Golden Pup",
		description = "Sunny, loyal, and LOVES fetch.",
		rig = "dog_basic",
		furColor = Color3.fromRGB(230, 172, 82),
		accentColor = Color3.fromRGB(248, 220, 168),
		earStyle = "floppy",
		scale = 1,
		defaultNames = { "Sunny", "Goldie", "Biscuit" },
	},
	cocoa = {
		id = "cocoa",
		displayName = "Cocoa Lab",
		description = "Gentle, goofy, and always ready to play.",
		rig = "dog_basic",
		furColor = Color3.fromRGB(112, 74, 50),
		accentColor = Color3.fromRGB(160, 112, 80),
		earStyle = "floppy",
		scale = 1,
		defaultNames = { "Cocoa", "Mocha", "Bean" },
	},
	husky = {
		id = "husky",
		displayName = "Snowy Husky",
		description = "Fast, fluffy, and full of energy.",
		rig = "dog_basic",
		furColor = Color3.fromRGB(150, 160, 178),
		accentColor = Color3.fromRGB(250, 250, 252),
		earStyle = "pointy",
		scale = 1.05,
		defaultNames = { "Snowy", "Blizzard", "Luna" },
	},
}

local PetCatalog = {}

PetCatalog.Breeds = Breeds
PetCatalog.Order = { "golden", "cocoa", "husky" }

-- Rig conventions: every rig exposes these attachment names so cosmetics can
-- be attached without knowing anything about the breed.
PetCatalog.Slots = {
	head = { attachment = "HatAttachment", label = "Hats" },
	collar = { attachment = "CollarAttachment", label = "Collars" },
	back = { attachment = "BackAttachment", label = "Outfits" },
	leash = { attachment = "CollarAttachment", label = "Leashes" },
	fur = { attachment = nil, label = "Fur" },
}

--[[
	Optional uploaded animations, keyed by behavior state (e.g. Sitting,
	Eating, PerformingTrick). Animate the "dog_basic" rig's Motor6Ds
	(BodyJoint, Neck, Tail, LegFL/FR/BL/BR) and paste the asset ids here,
	e.g. Sitting = "rbxassetid://1234567890". Empty = procedural fallback.
]]
PetCatalog.AnimationIds = {} :: { [string]: string }

PetCatalog.NameRules = {
	minLength = 1,
	maxLength = 16,
}

function PetCatalog.get(id: string): Breed?
	return Breeds[id]
end

-- Trims and checks shape only. Text filtering happens on the server.
function PetCatalog.cleanName(raw: any): (string?, string?)
	if typeof(raw) ~= "string" then
		return nil, "Please type a name."
	end
	local name = raw:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
	if #name < PetCatalog.NameRules.minLength then
		return nil, "Please type a name."
	end
	if utf8.len(name) == nil or (utf8.len(name) :: number) > PetCatalog.NameRules.maxLength then
		return nil, `Names can be up to {PetCatalog.NameRules.maxLength} letters.`
	end
	if not name:match("^[%w ]+$") then
		return nil, "Use letters, numbers, and spaces only."
	end
	return name, nil
end

return PetCatalog
