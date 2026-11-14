local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local StateMachine = require(Server.Logic.PetStateMachine)
local FetchMath = require(Server.Logic.FetchMath)
local Purchase = require(Server.Logic.Purchase)
local ProfileSchema = require(Server.Data.ProfileSchema)
local Activities = require(Server.Content.Activities)
local BondCatalog = require(ReplicatedStorage.Shared.Catalogs.BondCatalog)
local ItemCatalog = require(ReplicatedStorage.Shared.Catalogs.ItemCatalog)
local PetActions = require(ReplicatedStorage.Shared.Catalogs.PetActions)
local QuestCatalog = require(ReplicatedStorage.Shared.Catalogs.QuestCatalog)
local Places = require(ReplicatedStorage.Shared.Places)

return function(t)
	local expect = t.expect

	-- Behavior state machine
	t.test("base commands always interrupt", function()
		for state in StateMachine.Kind do
			expect(StateMachine.canEnter(state, "Following")).toBe(true)
			expect(StateMachine.canEnter(state, "Sitting")).toBe(true)
		end
	end)

	t.test("players can't start reactions mid-fetch", function()
		expect(StateMachine.canEnter("Fetching", "BeingPetted")).toBe(false)
		expect(StateMachine.canEnter("Returning", "Eating")).toBe(false)
		expect(StateMachine.canEnter("Fetching", "Returning", true)).toBe(true)
	end)

	t.test("one reaction at a time, but attention can be replaced", function()
		expect(StateMachine.canEnter("Eating", "BeingPetted")).toBe(false)
		expect(StateMachine.canEnter("Idle", "BeingPetted")).toBe(true)
		expect(StateMachine.canEnter("Sitting", "PerformingTrick")).toBe(true)
	end)

	t.test("only activities can enter activity states", function()
		expect(StateMachine.canEnter("Following", "Fetching")).toBe(false)
		expect(StateMachine.canEnter("Following", "Fetching", true)).toBe(true)
	end)

	t.test("every state has a movement mode and settles to a base", function()
		for state in StateMachine.Kind do
			expect(StateMachine.Movement[state] ~= nil).toBe(true)
		end
		expect(StateMachine.settle("Staying")).toBe("Staying")
		expect(StateMachine.settle("Eating")).toBe("Following")
	end)

	-- Bond
	t.test("bond levels from XP", function()
		local level, into, need = BondCatalog.levelFor(0)
		expect(level).toBe(1)
		expect(into).toBe(0)
		expect(need).toBe(40)
		expect((BondCatalog.levelFor(40))).toBe(2)
		expect((BondCatalog.levelFor(99))).toBe(2)
		local max, _, none = BondCatalog.levelFor(999999)
		expect(max).toBe(BondCatalog.MaxLevel)
		expect(none).toBe(nil)
	end)

	t.test("level thresholds increase", function()
		for i = 2, #BondCatalog.LevelXp do
			expect(BondCatalog.LevelXp[i] > BondCatalog.LevelXp[i - 1]).toBe(true)
		end
	end)

	t.test("daily caps: full, then half, then zero", function()
		expect(BondCatalog.xpAfterCap(10, 0, 10)).toBe(10)
		expect(BondCatalog.xpAfterCap(10, 5, 10)).toBe(5)
		expect(BondCatalog.xpAfterCap(5, 6, 10)).toBe(3)
		expect(BondCatalog.xpAfterCap(10, 10, 10)).toBe(0)
	end)

	t.test("unlock gates", function()
		expect(BondCatalog.isUnlocked(1, "command", "stay")).toBe(false)
		expect(BondCatalog.isUnlocked(2, "command", "stay")).toBe(true)
		expect(BondCatalog.isUnlocked(4, "trick", "high_five")).toBe(false)
		expect(BondCatalog.isUnlocked(5, "trick", "high_five")).toBe(true)
		expect(BondCatalog.nextUnlock(2).id).toBe("spin")
	end)

	t.test("every unlock points at something real", function()
		for _, u in BondCatalog.Unlocks do
			if u.kind == "trick" then
				expect(PetActions.Tricks[u.id] ~= nil).toBe(true)
			elseif u.kind == "item" or u.kind == "gift" then
				expect(ItemCatalog.get(u.id) ~= nil).toBe(true)
			end
		end
		for _, id in PetActions.TrickOrder do
			expect(BondCatalog.requiredLevel("trick", id) ~= nil).toBe(true)
		end
		for _, a in PetActions.Actions do
			if a.unlock then
				expect(BondCatalog.requiredLevel(a.unlock.kind, a.unlock.id) ~= nil).toBe(true)
			end
		end
	end)

	t.test("activity rewards use real bond sources and places", function()
		for id, def in Activities do
			expect(def.id).toBe(id)
			if def.rewards.bond then
				expect(BondCatalog.Sources[def.rewards.bond] ~= nil).toBe(true)
			end
			if def.location then
				expect(Places.get(def.location) ~= nil).toBe(true)
			end
		end
	end)

	-- Saved data compatibility
	t.test("v1 profiles migrate to v2 without losing bond", function()
		local v1 = {
			schemaVersion = 1,
			wallet = { paw_coins = 70 },
			activePetId = "p",
			pets = { p = { id = "p", breedId = "husky", name = "Blizzard", displayName = "Blizzard", equipped = { collar = "collar_cherry" }, bond = 7, adoptedAt = 1 } },
			inventory = { collar_cherry = 1 },
		}
		local p = ProfileSchema.migrate(v1, 0)
		expect(p.schemaVersion).toBe(2)
		expect(p.wallet.paw_coins).toBe(70)
		expect(p.pets.p.bondXp).toBe(35)
		expect(p.pets.p.bond).toBe(nil)
		expect(p.pets.p.equipped.collar).toBe("collar_cherry")
		expect(typeof(p.pets.p.xpLog.counts)).toBe("table")
	end)

	t.test("new pets start with bond fields", function()
		local pet = ProfileSchema.newPet("x", "golden", "Sunny", 5)
		expect(pet.bondXp).toBe(0)
		expect(pet.xpLog.day).toBe(0)
	end)

	-- Shop
	t.test("bond reward items can't be bought", function()
		local p = ProfileSchema.default(0)
		p.activePetId = "x"
		p.wallet.paw_coins = 9999
		local plan = Purchase.plan(p, ItemCatalog.get("collar_best_friend"), ItemCatalog.Items, 99)
		expect(plan).toBe(nil)
	end)

	t.test("every shop item is sold at a real place", function()
		for _, item in ItemCatalog.Items do
			expect(Places.get(ItemCatalog.shopOf(item)) ~= nil).toBe(true)
		end
	end)

	-- Fetch
	t.test("throws are clamped to a safe distance", function()
		local origin = Vector3.new(0, 3, 0)
		local far = FetchMath.clampThrow(origin, Vector3.new(500, 0, 0), Vector3.new(0, 0, -1), 8, 42)
		expect(math.floor(far.X + 0.5)).toBe(42)
		local near = FetchMath.clampThrow(origin, Vector3.new(1, 0, 0), Vector3.new(0, 0, -1), 8, 42)
		expect(math.floor(near.X + 0.5)).toBe(8)
	end)

	t.test("bad aim falls back to facing direction", function()
		local origin = Vector3.new(0, 3, 0)
		local p = FetchMath.clampThrow(origin, "hello", Vector3.new(0, 0, -1), 8, 42)
		expect(p.Z < 0).toBe(true)
		local nan = FetchMath.clampThrow(origin, Vector3.new(0 / 0, 0, 0), Vector3.new(1, 0, 0), 8, 42)
		expect(nan.X > 0).toBe(true)
		expect(FetchMath.inBounds(Vector3.new(300, 0, 0), 250)).toBe(false)
	end)

	-- Quests
	t.test("quest events match real event payloads", function()
		local known = {
			["pet.adopted"] = true,
			["pet.interacted"] = true,
			["pet.levelUp"] = true,
			["activity.completed"] = true,
			["item.purchased"] = true,
			["item.equipped"] = true,
		}
		for _, q in QuestCatalog.Ordered do
			expect(known[q.completeOn.event]).toBe(true)
			if q.waypoint then
				expect(Places.get(q.waypoint) ~= nil).toBe(true)
			end
			local m = q.completeOn.match
			if m and m.activityId then
				expect(Activities[m.activityId] ~= nil).toBe(true)
			end
		end
	end)
end
