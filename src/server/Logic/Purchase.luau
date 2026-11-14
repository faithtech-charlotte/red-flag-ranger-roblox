--[[
	Purchase: pure rules for "can this player buy this item, and what do they
	get?" The EconomyService applies the result. Unit-tested.
]]

local Purchase = {}

export type Plan = {
	price: number,
	grants: { string }, -- item ids to add to inventory
	service: boolean, -- applied immediately, not stored
}

local function owns(profile, itemId): boolean
	return (profile.inventory[itemId] or 0) > 0
end
Purchase.owns = owns

-- Returns (plan?, reason?)
function Purchase.plan(profile, item, catalog, maxStack: number): (Plan?, string?)
	if not item then
		return nil, "That item doesn't exist."
	end
	if typeof(item.price) ~= "number" or item.price < 0 or item.price ~= math.floor(item.price) then
		return nil, "That item isn't for sale."
	end
	if item.target == "pet" and profile.activePetId == nil then
		return nil, "Adopt a dog first!"
	end

	local grants = {}
	if item.kind == "cosmetic" then
		if owns(profile, item.id) then
			return nil, "You already own this."
		end
		grants = { item.id }
	elseif item.kind == "bundle" then
		for _, id in item.contents or {} do
			local inner = catalog[id]
			if not inner or inner.kind ~= "cosmetic" then
				return nil, "That bundle is broken."
			end
			if inner.target == "pet" and profile.activePetId == nil then
				return nil, "Adopt a dog first!"
			end
			if not owns(profile, id) then
				table.insert(grants, id)
			end
		end
		if #grants == 0 then
			return nil, "You already own everything in this bundle."
		end
	elseif item.kind == "consumable" then
		if (profile.inventory[item.id] or 0) >= maxStack then
			return nil, "Your bag is full of these!"
		end
		grants = { item.id }
	elseif item.kind == "service" then
		grants = {}
	else
		return nil, "That item can't be bought."
	end

	local coins = profile.wallet.paw_coins or 0
	if coins < item.price then
		return nil, `You need {item.price - coins} more Paw Coins.`
	end

	return { price = item.price, grants = grants, service = item.kind == "service" }, nil
end

return Purchase
