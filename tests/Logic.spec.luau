local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local Conditions = require(Server.Logic.Conditions)
local Purchase = require(Server.Logic.Purchase)
local ProfileSchema = require(Server.Data.ProfileSchema)
local ItemCatalog = require(ReplicatedStorage.Shared.Catalogs.ItemCatalog)
local PetCatalog = require(ReplicatedStorage.Shared.Catalogs.PetCatalog)
local QuestCatalog = require(ReplicatedStorage.Shared.Catalogs.QuestCatalog)

return function(t)
	local expect = t.expect

	local function withPet(coins)
		local p = ProfileSchema.default(0)
		p.activePetId = "pet1"
		p.pets.pet1 = { id = "pet1", breedId = "golden", name = "A", displayName = "A", equipped = {}, bond = 0, adoptedAt = 0 }
		p.wallet.paw_coins = coins
		return p
	end

	-- ProfileSchema
	t.test("migrate(nil) gives a default profile", function()
		local p, readOnly = ProfileSchema.migrate(nil, 5)
		expect(p.schemaVersion).toBe(ProfileSchema.CURRENT_VERSION)
		expect(p.wallet.paw_coins).toBe(0)
		expect(readOnly).toBe(false)
	end)

	t.test("migrate fills new keys without losing old ones", function()
		local p = ProfileSchema.migrate({ schemaVersion = 1, wallet = { paw_coins = 42 } }, 0)
		expect(p.wallet.paw_coins).toBe(42)
		expect(typeof(p.learning.toolsPracticed)).toBe("table")
		expect(typeof(p.arcs)).toBe("table")
	end)

	t.test("future schema versions are read-only", function()
		local _, readOnly = ProfileSchema.migrate({ schemaVersion = 999 }, 0)
		expect(readOnly).toBe(true)
	end)

	-- Purchase
	t.test("can buy an affordable cosmetic once", function()
		local p = withPet(100)
		local plan = Purchase.plan(p, ItemCatalog.get("collar_cherry"), ItemCatalog.Items, 99)
		expect(plan.price).toBe(15)
		p.inventory.collar_cherry = 1
		local again, reason = Purchase.plan(p, ItemCatalog.get("collar_cherry"), ItemCatalog.Items, 99)
		expect(again).toBe(nil)
		expect(reason).toBe("You already own this.")
	end)

	t.test("can't buy without enough coins", function()
		local plan, reason = Purchase.plan(withPet(3), ItemCatalog.get("hat_party"), ItemCatalog.Items, 99)
		expect(plan).toBe(nil)
		expect(reason:find("more Paw Coins") ~= nil).toBe(true)
	end)

	t.test("pet items need a pet", function()
		local p = ProfileSchema.default(0)
		p.wallet.paw_coins = 100
		local plan = Purchase.plan(p, ItemCatalog.get("collar_sky"), ItemCatalog.Items, 99)
		expect(plan).toBe(nil)
	end)

	t.test("bundles grant only what's missing", function()
		local p = withPet(100)
		p.inventory.hat_sun_player = 1
		local plan = Purchase.plan(p, ItemCatalog.get("bundle_sun_caps"), ItemCatalog.Items, 99)
		expect(#plan.grants).toBe(1)
		expect(plan.grants[1]).toBe("hat_sun_pet")
		p.inventory.hat_sun_pet = 1
		expect(Purchase.plan(p, ItemCatalog.get("bundle_sun_caps"), ItemCatalog.Items, 99)).toBe(nil)
	end)

	t.test("services are applied, not stored", function()
		local plan = Purchase.plan(withPet(100), ItemCatalog.get("groom_bubble_bath"), ItemCatalog.Items, 99)
		expect(plan.service).toBe(true)
		expect(#plan.grants).toBe(0)
	end)

	t.test("unknown items are rejected", function()
		expect(Purchase.plan(withPet(100), ItemCatalog.get("free_robux"), ItemCatalog.Items, 99)).toBe(nil)
	end)

	-- Catalog integrity
	t.test("every item is well-formed", function()
		for id, item in ItemCatalog.Items do
			expect(item.id).toBe(id)
			expect(item.price >= 0).toBe(true)
			if item.kind == "cosmetic" then
				expect(item.slot ~= nil).toBe(true)
				if item.target == "pet" then
					expect(PetCatalog.Slots[item.slot] ~= nil).toBe(true)
				end
			end
			for _, inner in item.contents or {} do
				expect(ItemCatalog.get(inner) ~= nil).toBe(true)
			end
		end
	end)

	t.test("quest ids are unique", function()
		local seen = {}
		for _, q in QuestCatalog.Ordered do
			expect(seen[q.id]).toBe(nil)
			seen[q.id] = true
		end
	end)

	-- Conditions
	t.test("conditions: all / any / not", function()
		local ctx = { profile = withPet(0), locationId = "dog_park" }
		expect(Conditions.evaluate({ { type = "hasPet" }, { type = "atLocation", locationId = "dog_park" } }, ctx)).toBe(true)
		expect(Conditions.evaluate({ { type = "any", conditions = { { type = "atLocation", locationId = "x" }, { type = "hasPet" } } } }, ctx)).toBe(true)
		expect(Conditions.evaluate({ { type = "not", condition = { type = "hasPet" } } }, ctx)).toBe(false)
		expect(Conditions.evaluate(nil, ctx)).toBe(true)
	end)

	-- Pet names
	t.test("pet name cleaning", function()
		expect(PetCatalog.cleanName("  Sunny   Boy ")).toBe("Sunny Boy")
		expect(PetCatalog.cleanName("")).toBe(nil)
		expect(PetCatalog.cleanName("abcdefghijklmnopq")).toBe(nil)
		expect(PetCatalog.cleanName("hi@there")).toBe(nil)
		expect(PetCatalog.cleanName(42)).toBe(nil)
	end)
end
