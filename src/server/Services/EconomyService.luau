--[[
	EconomyService: Paw Coins and purchases. Server-authoritative.

	Purchases are serialized per player (one at a time) so double-clicks or
	spammed requests can't buy twice or overspend. The buy rules live in
	Logic.Purchase; this service checks location and applies the result.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionService = require(script.Parent.Parent.Core.ActionService)
local EventBus = require(script.Parent.Parent.Core.EventBus)
local Purchase = require(script.Parent.Parent.Logic.Purchase)
local ItemCatalog = require(ReplicatedStorage.Shared.Catalogs.ItemCatalog)
local Places = require(ReplicatedStorage.Shared.Places)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local MAX_GRANT = 500

local Economy = {}
local S
local busy: { [Player]: boolean } = {}

local function validAmount(n: any): boolean
	return typeof(n) == "number" and n > 0 and n == math.floor(n) and n <= MAX_GRANT
end

function Economy.coins(player: Player): number
	local profile = S.Data.get(player)
	return profile and profile.wallet.paw_coins or 0
end

function Economy.grant(player: Player, amount: number, reason: string?): boolean
	local profile = S.Data.get(player)
	if not profile or not validAmount(amount) then
		return false
	end
	profile.wallet.paw_coins = (profile.wallet.paw_coins or 0) + amount
	S.Data.pushState(player)
	S.Net.toast(player, `+{amount} Paw Coins`, "coins")
	return true
end

function Economy.spend(player: Player, amount: number): boolean
	local profile = S.Data.get(player)
	if not profile or not validAmount(amount) then
		return false
	end
	local coins = profile.wallet.paw_coins or 0
	if coins < amount then
		return false
	end
	profile.wallet.paw_coins = coins - amount
	S.Data.pushState(player)
	return true
end

-- Items are bought at the store that sells them (ItemCatalog.shopOf).
local function atShop(player: Player, shopId: string): boolean
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return hrp ~= nil and Places.isInside(shopId, hrp.Position, 8)
end

function Economy.purchase(player: Player, itemId: any): (boolean, string?)
	if busy[player] then
		return false, "One thing at a time!"
	end
	local profile = S.Data.get(player)
	if not profile then
		return false, "Still loading."
	end
	local item = ItemCatalog.get(itemId)
	if item and not atShop(player, ItemCatalog.shopOf(item)) then
		local place = Places.get(ItemCatalog.shopOf(item))
		return false, `Visit {place and place.displayName or "the shop"} to buy this.`
	end
	local plan, reason = Purchase.plan(profile, item, ItemCatalog.Items, ItemCatalog.MaxStack)
	if not plan then
		return false, reason
	end
	busy[player] = true
	local ok, err = pcall(function()
		local it = item :: ItemCatalog.Item
		profile.wallet.paw_coins -= plan.price
		for _, grantId in plan.grants do
			profile.inventory[grantId] = (profile.inventory[grantId] or 0) + 1
		end
		if plan.service and it.effect then
			S.Pet.applyCare(player, it.effect, "care")
		end
		EventBus.publish("item.purchased", player, { itemId = it.id, kind = it.kind })
		-- Show new looks right away: equip what was just bought.
		for _, grantId in plan.grants do
			local granted = ItemCatalog.get(grantId)
			if granted and granted.kind == "cosmetic" then
				S.Inventory.equip(player, grantId)
			end
		end
		S.Net.toast(player, `You got {it.name}!`, "success")
	end)
	busy[player] = nil
	S.Data.pushState(player)
	if not ok then
		warn(`[Economy] purchase failed: {err}`)
		return false, "Something went wrong."
	end
	return true, nil
end

function Economy.init(services)
	S = services
	ActionService.register("grant_currency", function(player, spec)
		return Economy.grant(player, spec.amount, spec.reason), "invalid grant"
	end)
	ActionService.register("spend_currency", function(player, spec)
		return Economy.spend(player, spec.amount), "not enough coins"
	end)
end

function Economy.start()
	S.Net.on(Remotes.RequestKinds.Purchase, function(player, payload)
		local itemId = typeof(payload) == "table" and payload.itemId or nil
		return Economy.purchase(player, itemId)
	end, 0.3)
end

return Economy
