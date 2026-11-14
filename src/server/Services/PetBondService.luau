--[[
	PetBondService: Bond XP and Bond Levels for the active pet.

	* XP comes only from positive interactions, via named sources in
	  BondCatalog.Sources (each with a cooldown and a soft daily cap).
	* Bond never goes down.
	* Level rewards (items, gifts) are granted once, tracked in
	  profile.claims, and re-checked on load so nothing is ever missed.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventBus = require(script.Parent.Parent.Core.EventBus)
local ProfileSchema = require(script.Parent.Parent.Data.ProfileSchema)
local BondCatalog = require(ReplicatedStorage.Shared.Catalogs.BondCatalog)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local MAX_SINGLE_GRANT = 60

local Bond = {}
local S
local lastAt: { [Player]: { [string]: number } } = {}

local function today(): number
	return math.floor(os.time() / 86400)
end

local function grantUnlocks(player: Player, profile, level: number): { string }
	local labels = {}
	for _, u in BondCatalog.Unlocks do
		if u.level <= level then
			local claim = `bond:{u.kind}:{u.id}`
			if (u.kind == "item" or u.kind == "gift") and not profile.claims[claim] then
				profile.claims[claim] = true
				S.Inventory.grant(player, u.id, u.count or 1)
			end
		end
		if u.level == level then
			table.insert(labels, u.label)
		end
	end
	return labels
end

function Bond.level(player: Player): number
	local profile = S.Data.get(player)
	local pet = profile and ProfileSchema.activePet(profile)
	if not pet then
		return 0
	end
	return (BondCatalog.levelFor(pet.bondXp))
end

function Bond.has(player: Player, kind: string, id: string): boolean
	return BondCatalog.isUnlocked(Bond.level(player), kind, id)
end

--[[
	Awards Bond XP from a named source. `amount` may override the source's
	base XP (e.g. a fancier treat); it is server-defined, never from a client.
	Returns the XP actually gained (0 when cooling down or capped for today).
]]
function Bond.addXp(player: Player, sourceId: string, amount: number?): number
	local profile = S.Data.get(player)
	local pet = profile and ProfileSchema.activePet(profile)
	local source = BondCatalog.Sources[sourceId]
	if not pet or not source then
		return 0
	end
	local now = os.clock()
	local times = lastAt[player]
	if not times then
		times = {}
		lastAt[player] = times
	end
	if times[sourceId] and now - times[sourceId] < source.cooldown then
		return 0
	end
	times[sourceId] = now

	if pet.xpLog.day ~= today() then
		pet.xpLog = { day = today(), counts = {} }
	end
	local count = pet.xpLog.counts[sourceId] or 0
	pet.xpLog.counts[sourceId] = count + 1
	local base = math.clamp(math.floor(amount or source.xp), 0, MAX_SINGLE_GRANT)
	local gained = BondCatalog.xpAfterCap(base, count, source.dailyCap)
	if gained <= 0 then
		S.Net.push(player, Remotes.PushKinds.Bond, { gained = 0 })
		return 0
	end

	local oldLevel = BondCatalog.levelFor(pet.bondXp)
	pet.bondXp += gained
	local newLevel, into, need = BondCatalog.levelFor(pet.bondXp)
	S.Net.push(player, Remotes.PushKinds.Bond, { gained = gained, level = newLevel, into = into, need = need })

	for level = oldLevel + 1, newLevel do
		local labels = grantUnlocks(player, profile, level)
		EventBus.publish("pet.levelUp", player, { level = level })
		local unlocked = #labels > 0 and ("Unlocked: " .. table.concat(labels, ", ")) or nil
		S.Net.push(player, Remotes.PushKinds.Celebrate, {
			title = `Bond Level {level}!`,
			subtitle = unlocked,
		})
		S.Pet.react(player, "love")
	end
	S.Data.pushState(player)
	return gained
end

function Bond.init(services)
	S = services
end

function Bond.start()
	S.Data.onLoaded(function(player, profile)
		local pet = ProfileSchema.activePet(profile)
		if pet then
			local level = BondCatalog.levelFor(pet.bondXp)
			grantUnlocks(player, profile, level)
			-- Let level-based quests catch up for pets that leveled before
			-- those quests existed (no celebration, just the event).
			for l = 2, level do
				EventBus.publish("pet.levelUp", player, { level = l, catchUp = true })
			end
		end
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastAt[player] = nil
	end)
end

return Bond
