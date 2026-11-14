--[[
	ProfileSchema: the saved shape of a player, plus migrations. Pure logic,
	no Roblox services, so it is unit-tested.

	Rules:
	  * Store stable string ids only (breedId, itemId, npcId), never Instances.
	  * Bump CURRENT_VERSION and add a step to `migrations` for any shape change.
	  * reconcile() fills in keys added since the profile was saved.
]]

local ProfileSchema = {}

ProfileSchema.CURRENT_VERSION = 3

export type PetInstance = {
	id: string,
	breedId: string,
	name: string, -- raw name as typed; always filtered before display
	displayName: string, -- last filtered name (safe to show)
	equipped: { [string]: string }, -- slot -> itemId
	bondXp: number, -- never decreases
	xpLog: { day: number, counts: { [string]: number } }, -- daily XP caps
	adoptedAt: number,
}

export type ArcProgress = {
	contentVersion: number,
	stage: string?, -- current stage id; nil once done
	completed: { [string]: boolean }, -- encounterId -> true
	decisions: { [string]: string }, -- encounterId -> outcome
	flags: { [string]: any },
	activitiesSinceStage: number,
	done: boolean,
}

export type Profile = {
	schemaVersion: number,
	wallet: { [string]: number },
	pets: { [string]: PetInstance },
	activePetId: string?,
	inventory: { [string]: number },
	playerEquipped: { [string]: string },
	quests: { [string]: boolean },
	activities: { [string]: { count: number, best: number? } },
	unlocks: { [string]: boolean },
	claims: { [string]: boolean },
	arcs: { [string]: ArcProgress },
	npcs: { [string]: { blocked: boolean?, reported: boolean? } },
	learning: { topicsSeen: { [string]: boolean }, toolsPracticed: { [string]: boolean } },
	-- v3: the practice-story campaign. Private, never sent to the client
	-- (see PlayerDataService.snapshot). Shapes are owned and normalized by
	-- Logic/LearningProgress and Logic/EncounterScheduler on load.
	learningV2: { [string]: any },
	campaign: { [string]: any },
	show: { completed: boolean, ribbon: boolean },
	visibleTitle: string?, -- the one learning-derived field others may see (owner decision)
	stats: { sessions: number, firstJoin: number },
}

function ProfileSchema.default(now: number?): Profile
	return {
		schemaVersion = ProfileSchema.CURRENT_VERSION,
		wallet = { paw_coins = 0 },
		pets = {},
		activePetId = nil,
		inventory = {},
		playerEquipped = {},
		quests = {},
		activities = {},
		unlocks = {},
		claims = {},
		arcs = {},
		npcs = {},
		learning = { topicsSeen = {}, toolsPracticed = {} },
		learningV2 = {
			rulesVersion = 1,
			evidence = {},
			encountered = {},
			seenFacts = {},
			toldCara = {},
			toldLee = {},
			needsCoaching = {},
			review = { setIndex = 1, presented = {}, firstAttempt = {}, best = {} },
			titles = {},
		},
		campaign = { version = 1, onboarded = false, completedActivities = 0, beats = {} },
		show = { completed = false, ribbon = false },
		stats = { sessions = 0, firstJoin = now or 0 },
	}
end

-- Migration steps: migrations[n] upgrades a version-n profile to n+1.
local migrations: { [number]: (any) -> any } = {
	-- v1 -> v2: pets get Bond XP. Old "bond" points convert at 5 XP each,
	-- so nobody loses progress.
	[1] = function(data)
		for _, pet in data.pets or {} do
			if pet.bondXp == nil then
				pet.bondXp = math.max(0, math.floor((tonumber(pet.bond) or 0) * 5))
			end
			pet.bond = nil
			pet.xpLog = pet.xpLog or { day = 0, counts = {} }
		end
		return data
	end,
	-- v2 -> v3: adds the campaign and learning state (filled with defaults by
	-- reconcile). Old `learning` booleans are kept but never converted into
	-- evidence: nobody gets credit they didn't earn in the new model.
	[2] = function(data)
		return data
	end,
}

-- A new pet record (used at adoption).
function ProfileSchema.newPet(id: string, breedId: string, name: string, now: number): PetInstance
	return {
		id = id,
		breedId = breedId,
		name = name,
		displayName = name,
		equipped = {},
		bondXp = 0,
		xpLog = { day = 0, counts = {} },
		adoptedAt = now,
	}
end

local function deepCopy(value: any): any
	if typeof(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end
ProfileSchema.deepCopy = deepCopy

-- Adds any missing keys from the default template (does not remove extras).
local function reconcile(target: { [any]: any }, template: { [any]: any })
	for k, v in template do
		if target[k] == nil then
			target[k] = deepCopy(v)
		elseif typeof(v) == "table" and typeof(target[k]) == "table" and next(v) ~= nil then
			reconcile(target[k], v)
		end
	end
end

-- Returns (profile, readOnly). readOnly is true when data comes from a newer
-- game version; we must not overwrite it.
function ProfileSchema.migrate(data: any, now: number?): (Profile, boolean)
	if typeof(data) ~= "table" then
		return ProfileSchema.default(now), false
	end
	local profile = deepCopy(data)
	local version = tonumber(profile.schemaVersion) or 1
	if version > ProfileSchema.CURRENT_VERSION then
		reconcile(profile, ProfileSchema.default(now))
		return profile, true
	end
	while version < ProfileSchema.CURRENT_VERSION do
		local step = migrations[version]
		assert(step, `missing migration from schema {version}`)
		profile = step(profile)
		version += 1
	end
	profile.schemaVersion = ProfileSchema.CURRENT_VERSION
	reconcile(profile, ProfileSchema.default(now))
	return profile, false
end

function ProfileSchema.activePet(profile: Profile): PetInstance?
	if not profile.activePetId then
		return nil
	end
	return profile.pets[profile.activePetId]
end

return ProfileSchema
