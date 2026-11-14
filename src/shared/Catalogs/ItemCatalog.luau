--[[
	ItemCatalog: every buyable thing, as data. Purchase, inventory, equip and
	visuals are handled generically by kind:

	  cosmetic   - owned forever, equipped into a slot (pet or player)
	  consumable - stackable, used up (treats)
	  service    - applied immediately on purchase, never stored (bubble bath)
	  bundle     - grants several items at once

	`visual` is read only by Shared.Accessories / PetAppearanceService. Nothing
	in purchasing looks at it.
]]

export type ItemKind = "cosmetic" | "consumable" | "service" | "bundle"

export type Item = {
	id: string,
	name: string,
	description: string,
	kind: ItemKind,
	price: number,
	target: ("pet" | "player")?,
	slot: string?,
	visual: { [string]: any }?,
	contents: { string }?,
	effect: { bond: number?, mood: string? }?,
	tab: "dog" | "me" | "care",
	sortOrder: number,
}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local Items: { [string]: Item } = {
	-- Collars
	collar_cherry = {
		id = "collar_cherry", name = "Cherry Collar", description = "A classic red collar with a gold tag.",
		kind = "cosmetic", price = 15, target = "pet", slot = "collar", tab = "dog", sortOrder = 10,
		visual = { kind = "collar", color = rgb(230, 57, 70), tag = rgb(255, 209, 102) },
	},
	collar_sky = {
		id = "collar_sky", name = "Sky Collar", description = "Bright blue, like a sunny day.",
		kind = "cosmetic", price = 15, target = "pet", slot = "collar", tab = "dog", sortOrder = 11,
		visual = { kind = "collar", color = rgb(72, 149, 239), tag = rgb(255, 255, 255) },
	},
	collar_glow = {
		id = "collar_glow", name = "Glow Collar", description = "It sparkles!",
		kind = "cosmetic", price = 40, target = "pet", slot = "collar", tab = "dog", sortOrder = 12,
		visual = { kind = "collar", color = rgb(155, 93, 229), tag = rgb(0, 245, 212), neon = true },
	},

	-- Fur colors (a grooming upgrade you keep)
	fur_cotton_candy = {
		id = "fur_cotton_candy", name = "Cotton Candy Fur", description = "A fluffy pink makeover.",
		kind = "cosmetic", price = 30, target = "pet", slot = "fur", tab = "dog", sortOrder = 20,
		visual = { kind = "fur", color = rgb(255, 175, 204) },
	},
	fur_mint = {
		id = "fur_mint", name = "Minty Fur", description = "Cool and fresh.",
		kind = "cosmetic", price = 30, target = "pet", slot = "fur", tab = "dog", sortOrder = 21,
		visual = { kind = "fur", color = rgb(152, 245, 200) },
	},
	fur_midnight = {
		id = "fur_midnight", name = "Midnight Fur", description = "Dark blue with a starry vibe.",
		kind = "cosmetic", price = 45, target = "pet", slot = "fur", tab = "dog", sortOrder = 22,
		visual = { kind = "fur", color = rgb(58, 66, 120) },
	},

	-- Hats and outfits
	hat_party = {
		id = "hat_party", name = "Party Hat", description = "Every day is a party.",
		kind = "cosmetic", price = 25, target = "pet", slot = "head", tab = "dog", sortOrder = 30,
		visual = { kind = "party_hat", color = rgb(255, 209, 102), dot = rgb(239, 71, 111) },
	},
	hat_sun_pet = {
		id = "hat_sun_pet", name = "Pup Sun Cap", description = "Keeps the sun out of puppy eyes.",
		kind = "cosmetic", price = 20, target = "pet", slot = "head", tab = "dog", sortOrder = 31,
		visual = { kind = "cap", color = rgb(255, 214, 10), brim = rgb(255, 255, 255) },
	},
	vest_ranger = {
		id = "vest_ranger", name = "Ranger Vest", description = "Official Red Flag Ranger gear.",
		kind = "cosmetic", price = 35, target = "pet", slot = "back", tab = "dog", sortOrder = 40,
		visual = { kind = "vest", color = rgb(46, 160, 120), trim = rgb(255, 209, 102) },
	},
	leash_rope = {
		id = "leash_rope", name = "Rope Leash", description = "Walk together in style.",
		kind = "cosmetic", price = 20, target = "pet", slot = "leash", tab = "dog", sortOrder = 50,
		visual = { kind = "leash", color = rgb(239, 71, 111) },
	},

	-- Player cosmetics
	hat_sun_player = {
		id = "hat_sun_player", name = "Sun Cap", description = "A cap for you!",
		kind = "cosmetic", price = 20, target = "player", slot = "player_head", tab = "me", sortOrder = 60,
		visual = { kind = "cap", color = rgb(255, 214, 10), brim = rgb(255, 255, 255) },
	},
	bundle_sun_caps = {
		id = "bundle_sun_caps", name = "Matching Sun Caps", description = "One for you, one for your pup!",
		kind = "bundle", price = 32, tab = "me", sortOrder = 61,
		contents = { "hat_sun_player", "hat_sun_pet" },
	},

	-- Care
	treat_biscuit = {
		id = "treat_biscuit", name = "Bone Biscuit", description = "A crunchy treat. Your dog will love it.",
		kind = "consumable", price = 5, target = "pet", tab = "care", sortOrder = 70,
		effect = { bond = 1, mood = "happy" },
	},
	groom_bubble_bath = {
		id = "groom_bubble_bath", name = "Bubble Bath", description = "Squeaky clean and extra fluffy.",
		kind = "service", price = 10, target = "pet", tab = "care", sortOrder = 71,
		effect = { bond = 2, mood = "sparkle" },
	},
}

local ItemCatalog = {}
ItemCatalog.Items = Items
ItemCatalog.MaxStack = 99

function ItemCatalog.get(id: any): Item?
	if typeof(id) ~= "string" then
		return nil
	end
	return Items[id]
end

function ItemCatalog.sorted(filter: ((Item) -> boolean)?): { Item }
	local list = {}
	for _, item in Items do
		if not filter or filter(item) then
			table.insert(list, item)
		end
	end
	table.sort(list, function(a, b)
		return a.sortOrder < b.sortOrder
	end)
	return list
end

return ItemCatalog
