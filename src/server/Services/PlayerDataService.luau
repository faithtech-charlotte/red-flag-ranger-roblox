--[[
	PlayerDataService: loads, holds, and saves the authoritative Profile.

	* DataStore key "player_<UserId>" stores { profile, session }.
	* Session lock: a server marks the record as in use. Another server waits
	  for it to be released (or to go stale) before loading, so two servers
	  never write the same player at once.
	* If DataStores are unavailable (e.g. Studio without API access), the
	  player gets a temporary profile and a notice; we never overwrite saved
	  data we failed to load.
	* Autosaves every 60 s and on leave / shutdown.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileSchema = require(script.Parent.Parent.Data.ProfileSchema)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PetCatalog = require(ReplicatedStorage.Shared.Catalogs.PetCatalog)
local BondCatalog = require(ReplicatedStorage.Shared.Catalogs.BondCatalog)
local SessionRules = require(script.Parent.Parent.Logic.SessionRules)

local STORE_NAME = "RFR_PlayerProfiles_v1"
local SESSION_STALE_SECONDS = 300
local AUTOSAVE_SECONDS = 60
local LOAD_ATTEMPTS = 5
local RELEASE_ATTEMPTS = 3
-- Checkpoint saves are coalesced to at most one write per player this often.
local CHECKPOINT_SECONDS = 6

type Entry = {
	data: ProfileSchema.Profile,
	persistent: boolean,
	readOnly: boolean,
	pushQueued: boolean,
	saving: boolean?, -- a write is in flight
	saveQueued: boolean?, -- a checkpoint writer loop is running
	dirty: boolean?, -- changed since the last write started
	lastSaved: number?, -- os.clock() of the last write attempt
	removed: boolean?, -- player left; final release in progress
}

local Data = {}
local S
local store: DataStore? = nil
local entries: { [Player]: Entry } = {}
local loadedCallbacks: { (Player, ProfileSchema.Profile) -> () } = {}

local function keyFor(player: Player): string
	return "player_" .. player.UserId
end

local function isFatal(err: string): boolean
	-- Studio without "Enable Studio Access to API Services", or no permission.
	return err:find("StudioAccessToApisNotAllowed") ~= nil
		or err:find("403") ~= nil
		or err:find("Place has to be opened with Edit button") ~= nil
		or err:find("must publish") ~= nil
end

local function loadProfile(player: Player): (ProfileSchema.Profile?, boolean)
	if not store then
		return nil, false
	end
	for attempt = 1, LOAD_ATTEMPTS do
		local result
		local ok, err = pcall(function()
			(store :: DataStore):UpdateAsync(keyFor(player), function(old)
				-- Never take over a live lock, even on the last attempt: after
				-- LOAD_ATTEMPTS the player gets a temporary (non-saving) profile.
				if SessionRules.lockedElsewhere(old and old.session, game.JobId, os.time(), SESSION_STALE_SECONDS) then
					result = "locked"
					return nil -- cancel write; retry shortly
				end
				local profile, readOnly = ProfileSchema.migrate(old and old.profile, os.time())
				result = { profile = profile, readOnly = readOnly }
				if readOnly then
					return nil
				end
				return { profile = profile, session = { jobId = game.JobId, updated = os.time() } }
			end)
		end)
		if ok and typeof(result) == "table" then
			return result.profile, result.readOnly
		end
		if not ok then
			warn(`[Data] load attempt {attempt} failed for {player.Name}: {err}`)
			if isFatal(tostring(err)) then
				return nil, false
			end
		end
		task.wait(attempt * 1.5)
	end
	return nil, false
end

-- Outcome of one save attempt: "committed" (written), "lost" (another
-- server owns the save; stop saving), "skipped" (nothing to save here) or
-- "failed" (DataStore error; safe to retry).
type SaveResult = "committed" | "lost" | "skipped" | "failed"

local function saveProfile(player: Player, release: boolean): SaveResult
	local entry = entries[player]
	if not entry or not entry.persistent or entry.readOnly or not store then
		return "skipped"
	end
	-- One write per player at a time (autosave, checkpoint and release
	-- would otherwise race).
	while entry.saving do
		task.wait(0.1)
	end
	if not entry.persistent then
		return "skipped"
	end
	entry.saving = true
	entry.dirty = false -- changes made from here on need another write
	entry.lastSaved = os.clock()
	local lost, written = false, false
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(keyFor(player), function(old)
			if not SessionRules.ownsLock(old and old.session, game.JobId) then
				lost = true
				return nil -- another server took over (or released); don't clobber its data
			end
			written = true
			return {
				profile = entry.data,
				session = if release then nil else { jobId = game.JobId, updated = os.time() },
			}
		end)
	end)
	entry.saving = false
	entry.lastSaved = os.clock()
	if not ok then
		warn(`[Data] save failed for {player.Name}: {err}`)
		return "failed"
	elseif lost then
		-- Ownership is gone for good: stop saving this session.
		entry.persistent = false
		warn(`[Data] {player.Name}'s save is owned by another server; no longer saving here`)
		return "lost"
	end
	return if written then "committed" else "failed"
end

-- The final save when a player leaves (or the server shuts down): retried
-- with backoff so one DataStore hiccup doesn't lose the session.
local function releaseProfile(player: Player)
	local entry = entries[player]
	if not entry then
		return
	end
	entry.removed = true -- cancels any queued checkpoint
	for attempt = 1, RELEASE_ATTEMPTS do
		local result = saveProfile(player, true)
		if result ~= "failed" then
			break
		end
		if attempt < RELEASE_ATTEMPTS then
			task.wait(2 ^ (attempt - 1))
		end
	end
	if entries[player] == entry then
		entries[player] = nil
	end
end

local function onPlayerAdded(player: Player)
	local profile, readOnly = loadProfile(player)
	local persistent = profile ~= nil
	if not profile then
		profile = ProfileSchema.default(os.time())
	end
	if player.Parent == nil then
		-- Left while loading: release the lock we just took.
		entries[player] = { data = profile :: any, persistent = persistent, readOnly = readOnly, pushQueued = false }
		releaseProfile(player) -- same retried release as a normal leave
		return
	end
	local data = profile :: ProfileSchema.Profile
	data.stats.sessions += 1
	entries[player] = { data = data, persistent = persistent, readOnly = readOnly, pushQueued = false }
	for _, cb in loadedCallbacks do
		task.spawn(cb, player, data)
	end
	Data.pushState(player)
	if not persistent then
		task.delay(3, function()
			S.Net.toast(player, "Heads up: progress can't be saved right now, but you can still play!", "warn")
		end)
	end
end

function Data.init(services)
	S = services
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn(`[Data] DataStores unavailable: {result}`)
	end
end

function Data.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(releaseProfile)
	game:BindToClose(function()
		local pending = 0
		for player in entries do
			pending += 1
			task.spawn(function()
				releaseProfile(player)
				pending -= 1
			end)
		end
		local waited = 0
		while pending > 0 and waited < 25 do
			waited += task.wait(0.2)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for player, entry in entries do
				if not entry.removed then
					task.spawn(saveProfile, player, false)
				end
			end
		end
	end)

	S.Net.on(Remotes.RequestKinds.GetState, function(player)
		if not entries[player] then
			return false, "loading"
		end
		return true, nil, Data.snapshot(player)
	end, 0.5, false)
end

-- Call after any meaningful in-memory change (a story transition, earned
-- evidence). The in-memory profile is already authoritative for this
-- server; this queues a durable write, coalesced to one per
-- CHECKPOINT_SECONDS per player. Never wait on it before showing feedback.
function Data.checkpoint(player: Player, _reason: string?)
	local entry = entries[player]
	if not entry or entry.removed or not entry.persistent or entry.readOnly then
		return
	end
	if entry.saveQueued then
		entry.dirty = true -- the running writer loop will pick it up
		return
	end
	entry.dirty = true
	entry.saveQueued = true
	-- One writer loop per player: it waits out the spacing (measured from
	-- the start of the last write, whoever made it), lets an in-flight write
	-- finish, and writes again only if something changed meanwhile.
	task.spawn(function()
		while entries[player] == entry and not entry.removed and entry.persistent and entry.dirty do
			local wait = CHECKPOINT_SECONDS - (os.clock() - (entry.lastSaved or 0))
			if wait > 0 then
				task.wait(wait)
			elseif entry.saving then
				task.wait(0.2)
			else
				saveProfile(player, false)
			end
		end
		entry.saveQueued = false
	end)
end

function Data.get(player: Player): ProfileSchema.Profile?
	local entry = entries[player]
	return entry and entry.data
end

function Data.isPersistent(player: Player): boolean
	local entry = entries[player]
	return entry ~= nil and entry.persistent
end

function Data.onLoaded(cb: (Player, ProfileSchema.Profile) -> ())
	table.insert(loadedCallbacks, cb)
	for player, entry in entries do
		task.spawn(cb, player, entry.data)
	end
end

-- The client's read-only view of a profile. An explicit allowlist: nothing
-- from the private campaign or learning state (learningV2, campaign) is
-- ever included; the only learning-derived field is the visible title.
-- Pure apart from catalogs, so tests can check it (tests/Privacy.spec).
-- `present` (story-only NPCs this player can see, npcId -> boolean) is
-- presence, not progress: it carries no beat, score, fact or answer.
function Data.view(data: ProfileSchema.Profile, extras: { blocked: { [string]: string }, cooldowns: any, persistent: boolean, present: { [string]: boolean }? })
	local pet = ProfileSchema.activePet(data)
	local activities = {}
	for id, a in data.activities do
		activities[id] = { count = a.count, best = a.best }
	end
	local petView = nil
	if pet then
		local level, into, need = BondCatalog.levelFor(pet.bondXp)
		local nextUnlock = BondCatalog.nextUnlock(level)
		petView = {
			id = pet.id,
			breedId = pet.breedId,
			name = pet.displayName,
			equipped = table.clone(pet.equipped),
			bondXp = pet.bondXp,
			level = level,
			xpInto = into,
			xpNeed = need,
			nextUnlock = nextUnlock and { level = nextUnlock.level, label = nextUnlock.label } or nil,
			breedName = (PetCatalog.get(pet.breedId) or { displayName = "Dog" }).displayName,
		}
	end
	return {
		coins = data.wallet.paw_coins or 0,
		pet = petView,
		cooldowns = extras.cooldowns,
		inventory = table.clone(data.inventory),
		playerEquipped = table.clone(data.playerEquipped),
		quests = table.clone(data.quests),
		activities = activities,
		unlocks = table.clone(data.unlocks),
		blocked = extras.blocked,
		present = extras.present,
		persistent = extras.persistent,
		visibleTitle = data.visibleTitle,
		showRibbon = data.show and data.show.ribbon == true or nil,
	}
end

-- The client's read-only view of its own profile.
function Data.snapshot(player: Player)
	local data = entries[player].data
	local blocked = {}
	for npcId, state in data.npcs do
		if state.blocked then
			local def = S.NPC.getDefinition(npcId)
			blocked[npcId] = def and def.displayName or npcId
		end
	end
	return Data.view(data, {
		blocked = blocked,
		cooldowns = S.Interaction.cooldowns(player),
		persistent = entries[player].persistent,
		present = S.Story and S.Story.presence(player) or nil,
	})
end

-- Coalesces many changes in one frame into one state push.
function Data.pushState(player: Player)
	local entry = entries[player]
	if not entry or entry.pushQueued then
		return
	end
	entry.pushQueued = true
	task.defer(function()
		entry.pushQueued = false
		if entries[player] == entry then
			S.Net.push(player, Remotes.PushKinds.State, Data.snapshot(player))
		end
	end)
end

return Data
