--[[
	InventoryService: what a player owns and what is equipped. Visuals are
	delegated to PetAppearanceService; this service only changes data.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionService = require(script.Parent.Parent.Core.ActionService)
local EventBus = require(script.Parent.Parent.Core.EventBus)
local ProfileSchema = require(script.Parent.Parent.Data.ProfileSchema)
local ItemCatalog = require(ReplicatedStorage.Shared.Catalogs.ItemCatalog)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Inventory = {}
local S

function Inventory.owns(player: Player, itemId: string): boolean
	local profile = S.Data.get(player)
	return profile ~= nil and (profile.inventory[itemId] or 0) > 0
end

function Inventory.grant(player: Player, itemId: string, count: number?): boolean
	local profile = S.Data.get(player)
	local item = ItemCatalog.get(itemId)
	if not profile or not item or item.kind == "service" or item.kind == "bundle" then
		return false
	end
	local n = count or 1
	if item.kind == "cosmetic" then
		profile.inventory[itemId] = 1
	else
		profile.inventory[itemId] = math.min((profile.inventory[itemId] or 0) + n, ItemCatalog.MaxStack)
	end
	S.Data.pushState(player)
	return true
end

function Inventory.consume(player: Player, itemId: string): boolean
	local profile = S.Data.get(player)
	if not profile then
		return false
	end
	local have = profile.inventory[itemId] or 0
	if have <= 0 then
		return false
	end
	profile.inventory[itemId] = if have > 1 then have - 1 else nil
	S.Data.pushState(player)
	return true
end

function Inventory.equip(player: Player, itemId: any): (boolean, string?)
	local profile = S.Data.get(player)
	local item = ItemCatalog.get(itemId)
	if not profile or not item or item.kind ~= "cosmetic" or not item.slot then
		return false, "You can't wear that."
	end
	if (profile.inventory[item.id] or 0) <= 0 then
		return false, "You don't own that yet."
	end
	if item.target == "pet" then
		local pet = ProfileSchema.activePet(profile)
		if not pet then
			return false, "Adopt a dog first!"
		end
		pet.equipped[item.slot] = item.id
		S.Appearance.refreshPet(player)
	else
		profile.playerEquipped[item.slot] = item.id
		S.Appearance.refreshPlayer(player)
	end
	EventBus.publish("item.equipped", player, { itemId = item.id, slot = item.slot, target = item.target })
	S.Data.pushState(player)
	return true, nil
end

function Inventory.unequip(player: Player, target: any, slot: any): (boolean, string?)
	local profile = S.Data.get(player)
	if not profile or typeof(slot) ~= "string" then
		return false, "Nothing to take off."
	end
	if target == "pet" then
		local pet = ProfileSchema.activePet(profile)
		if pet then
			pet.equipped[slot] = nil
			S.Appearance.refreshPet(player)
		end
	elseif target == "player" then
		profile.playerEquipped[slot] = nil
		S.Appearance.refreshPlayer(player)
	else
		return false, "Nothing to take off."
	end
	S.Data.pushState(player)
	return true, nil
end

function Inventory.init(services)
	S = services
	ActionService.register("grant_item", function(player, spec)
		return Inventory.grant(player, spec.itemId, spec.count), "invalid item"
	end)
	ActionService.register("equip_item", function(player, spec)
		return Inventory.equip(player, spec.itemId)
	end)
end

function Inventory.start()
	S.Net.on(Remotes.RequestKinds.Equip, function(player, payload)
		return Inventory.equip(player, typeof(payload) == "table" and payload.itemId or nil)
	end, 0.2)
	S.Net.on(Remotes.RequestKinds.Unequip, function(player, payload)
		if typeof(payload) ~= "table" then
			return false, "bad request"
		end
		return Inventory.unequip(player, payload.target, payload.slot)
	end, 0.2)
	S.Net.on(Remotes.RequestKinds.UseItem, function(player, payload)
		local item = ItemCatalog.get(typeof(payload) == "table" and payload.itemId or nil)
		if not item or item.kind ~= "consumable" then
			return false, "You can't use that."
		end
		if not S.Pet.getActive(player) then
			return false, "Adopt a dog first!"
		end
		return S.Interaction.feed(player, item.id)
	end, 1)
end

return Inventory
