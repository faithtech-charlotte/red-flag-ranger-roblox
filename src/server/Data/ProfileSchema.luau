--[[
	ProfileSchema: the saved shape of a player, plus migrations. Pure logic,
	no Roblox services, so it is unit-tested.

	Rules:
	  * Store stable string ids only (breedId, itemId, npcId), never Instances.
	  * Bump CURRENT_VERSION and add a step to `migrations` for any shape change.
	  * reconcile() fills in keys added since the profile was saved.
]]

local ProfileSchema = {}

ProfileSchema.CURRENT_VERSION = 1

export type PetInstance = {
	id: string,
	breedId: string,
	name: string, -- raw name as typed; always filtered before display
	displayName: string, -- last filtered name (safe to show)
	equipped: { [string]: string }, -- slot -> itemId
	bond: number,
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
		stats = { sessions = 0, firstJoin = now or 0 },
	}
end

-- Migration steps: migrations[n] upgrades a version-n profile to n+1.
local migrations: { [number]: (any) -> any } = {
	-- [1] = function(data) ... return data end,
}

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
