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

local STORE_NAME = "RFR_PlayerProfiles_v1"
local SESSION_STALE_SECONDS = 300
local AUTOSAVE_SECONDS = 60
local LOAD_ATTEMPTS = 5

type Entry = {
	data: ProfileSchema.Profile,
	persistent: boolean,
	readOnly: boolean,
	pushQueued: boolean,
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
				local session = old and old.session
				local lockedElsewhere = session
					and session.jobId ~= game.JobId
					and os.time() - (session.updated or 0) < SESSION_STALE_SECONDS
				if lockedElsewhere and attempt < LOAD_ATTEMPTS then
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

local function saveProfile(player: Player, release: boolean)
	local entry = entries[player]
	if not entry or not entry.persistent or entry.readOnly or not store then
		return
	end
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(keyFor(player), function(old)
			local session = old and old.session
			if session and session.jobId ~= game.JobId then
				return nil -- another server took over; don't clobber its data
			end
			return {
				profile = entry.data,
				session = if release then nil else { jobId = game.JobId, updated = os.time() },
			}
		end)
	end)
	if not ok then
		warn(`[Data] save failed for {player.Name}: {err}`)
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
		saveProfile(player, true)
		entries[player] = nil
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
	Players.PlayerRemoving:Connect(function(player)
		saveProfile(player, true)
		entries[player] = nil
	end)
	game:BindToClose(function()
		local pending = 0
		for player in entries do
			pending += 1
			task.spawn(function()
				saveProfile(player, true)
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
			for player in entries do
				task.spawn(saveProfile, player, false)
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

-- The client's read-only view of its own profile.
function Data.snapshot(player: Player)
	local data = entries[player].data
	local pet = ProfileSchema.activePet(data)
	local blocked = {}
	for npcId, state in data.npcs do
		if state.blocked then
			local def = S.NPC.getDefinition(npcId)
			blocked[npcId] = def and def.displayName or npcId
		end
	end
	local activities = {}
	for id, a in data.activities do
		activities[id] = { count = a.count, best = a.best }
	end
	return {
		coins = data.wallet.paw_coins or 0,
		pet = pet and {
			id = pet.id,
			breedId = pet.breedId,
			name = pet.displayName,
			equipped = table.clone(pet.equipped),
			bond = pet.bond,
			breedName = (PetCatalog.get(pet.breedId) or { displayName = "Dog" }).displayName,
		},
		inventory = table.clone(data.inventory),
		playerEquipped = table.clone(data.playerEquipped),
		quests = table.clone(data.quests),
		activities = activities,
		unlocks = table.clone(data.unlocks),
		blocked = blocked,
		persistent = entries[player].persistent,
	}
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
