--[[
	EncounterScheduler: the campaign state machine (spec section 5). Pure logic.

	No clocks, no randomness. Time arrives as `active_seconds` events. Same
	starting state + same ordered events => same state and same decisions.

	Beat status:
	  not_started -> eligible -> invited -> active -> resolved
	                                \-> deferred (back to eligible after another activity)
	                                \-> skipped  (this scene only)
	  Sparkz beats e1-e4 may also become skipped_by_block.
	"Done" (lets the next beat open) = resolved, skipped or skipped_by_block.

	apply(state, event) returns a NEW state and never mutates its input.
	Unknown or invalid events return an unchanged copy.

	decide(state, ctx) returns at most one thing to do now:
	  { kind = "help" } | { kind = "replay", beat } | { kind = "recovery", beat }
	  | { kind = "campaign", beat } | { kind = "ambient", id } | nil
	It is read-only; the service applies `invited` once it actually shows an
	invitation, which starts the pacing gap and blocks any second invitation.
]]

local EncounterScheduler = {}

EncounterScheduler.BEATS = { "e1", "green_riley", "e2", "e3", "e4", "e5" }
EncounterScheduler.MIN_GAP_SECONDS = 90
EncounterScheduler.SHOW_ACTIVITIES = 4
EncounterScheduler.SPARKZ_BEATS = { "e1", "e2", "e3", "e4" }
-- NPC ids that count as Sparkz for blocking.
EncounterScheduler.SPARKZ_NPCS = { sparkz = true, sparkz_pup = true }

local STATUSES = {
	not_started = true,
	eligible = true,
	invited = true,
	active = true,
	resolved = true,
	deferred = true,
	skipped = true,
	skipped_by_block = true,
}
local DONE = { resolved = true, skipped = true, skipped_by_block = true }

local BEAT_SET = {}
for _, b in EncounterScheduler.BEATS do
	BEAT_SET[b] = true
end
local SPARKZ_SET = {}
for _, b in EncounterScheduler.SPARKZ_BEATS do
	SPARKZ_SET[b] = true
end

local function deepCopy(v)
	if typeof(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = deepCopy(x)
	end
	return out
end

local function isCount(n: any): boolean
	return typeof(n) == "number" and n == n and n >= 0 and n % 1 == 0 and n < math.huge
end

function EncounterScheduler.defaultState()
	return {
		version = 1,
		onboarded = false,
		-- Added beyond the brief: completed activities at onboarding, so E1
		-- waits for an activity completed AFTER onboarding.
		onboardedAtActivity = 0,
		completedActivities = 0,
		beats = {},
		resolvedAtActivity = {},
		deferredAtActivity = {},
		remainingGap = 0,
		dashIntroduced = false,
		sparkzBlocked = false,
		current = nil,
	}
end

function EncounterScheduler.status(state, beat: string): string
	return state.beats[beat] or "not_started"
end

function EncounterScheduler.isDone(state, beat: string): boolean
	return DONE[EncounterScheduler.status(state, beat)] == true
end

function EncounterScheduler.showEligible(state): boolean
	return state.completedActivities >= EncounterScheduler.SHOW_ACTIVITIES
end

-- True once `beat` is done and at least one activity completed after that.
local function doneWithNewActivity(state, beat: string): boolean
	if not EncounterScheduler.isDone(state, beat) then
		return false
	end
	local at = state.resolvedAtActivity[beat] or state.completedActivities
	return state.completedActivities > at
end

local function prerequisitesMet(state, beat: string): boolean
	if beat == "e1" then
		return state.onboarded and state.completedActivities > state.onboardedAtActivity
	elseif beat == "green_riley" then
		return doneWithNewActivity(state, "e1")
	elseif beat == "e2" then
		return doneWithNewActivity(state, "green_riley")
	elseif beat == "e3" then
		return doneWithNewActivity(state, "e2")
	elseif beat == "e4" then
		return doneWithNewActivity(state, "e3")
	elseif beat == "e5" then
		return EncounterScheduler.isDone(state, "e4")
			and state.dashIntroduced
			and EncounterScheduler.showEligible(state)
	end
	return false
end

local function finish(state, beat: string, status: string)
	state.beats[beat] = status
	state.resolvedAtActivity[beat] = state.completedActivities
	state.deferredAtActivity[beat] = nil
	if state.current == beat then
		state.current = nil
	end
end

-- Derived transitions, applied after every event (in fixed beat order).
local function refresh(state)
	for _, beat in EncounterScheduler.BEATS do
		local s = EncounterScheduler.status(state, beat)
		if state.sparkzBlocked and SPARKZ_SET[beat] and (s == "not_started" or s == "eligible" or s == "deferred") then
			finish(state, beat, "skipped_by_block")
		elseif s == "not_started" and prerequisitesMet(state, beat) then
			state.beats[beat] = "eligible"
		elseif s == "deferred" then
			local at = state.deferredAtActivity[beat] or state.completedActivities
			if state.completedActivities > at then
				state.beats[beat] = "eligible"
				state.deferredAtActivity[beat] = nil
			end
		end
	end
end

local function validBeat(beat: any): boolean
	return typeof(beat) == "string" and BEAT_SET[beat] == true
end

-- The beat named by an event must be the one currently invited or active.
local function isCurrent(state, beat: any): boolean
	if not validBeat(beat) or state.current ~= beat then
		return false
	end
	local s = EncounterScheduler.status(state, beat)
	return s == "invited" or s == "active"
end

local handlers: { [string]: (state: any, e: any) -> () } = {}

handlers.onboarding_done = function(state, _e)
	if not state.onboarded then
		state.onboarded = true
		state.onboardedAtActivity = state.completedActivities
	end
end

-- Completed rounds only; the service never sends throws or client claims.
handlers.activity_completed = function(state, _e)
	state.completedActivities += 1
end

handlers.active_seconds = function(state, e)
	local s = e.seconds
	if typeof(s) ~= "number" or s ~= s or s <= 0 or s == math.huge then
		return
	end
	state.remainingGap = math.max(0, state.remainingGap - s)
end

handlers.invited = function(state, e)
	if state.current ~= nil or not validBeat(e.beat) or EncounterScheduler.status(state, e.beat) ~= "eligible" then
		return
	end
	state.beats[e.beat] = "invited"
	state.current = e.beat
	state.remainingGap = EncounterScheduler.MIN_GAP_SECONDS
end

-- Added beyond the brief: an ordinary ambient invitation was shown. It uses
-- the same pacing gap but is not a campaign beat.
handlers.ambient_invited = function(state, _e)
	if state.current ~= nil then
		return
	end
	state.remainingGap = EncounterScheduler.MIN_GAP_SECONDS
end

-- Accepting an invitation, or walking up to the NPC of an open beat.
handlers.accepted = function(state, e)
	if not validBeat(e.beat) then
		return
	end
	if state.current ~= nil and state.current ~= e.beat then
		return
	end
	local s = EncounterScheduler.status(state, e.beat)
	if s == "invited" or s == "eligible" or s == "deferred" then
		state.beats[e.beat] = "active"
		state.current = e.beat
		state.deferredAtActivity[e.beat] = nil
	end
end

handlers.later = function(state, e)
	if not isCurrent(state, e.beat) then
		return
	end
	state.beats[e.beat] = "deferred"
	state.deferredAtActivity[e.beat] = state.completedActivities
	state.current = nil
end

handlers.skip = function(state, e)
	if isCurrent(state, e.beat) then
		finish(state, e.beat, "skipped")
	end
end

handlers.resolved = function(state, e)
	if isCurrent(state, e.beat) then
		finish(state, e.beat, "resolved")
	end
end

handlers.blocked = function(state, e)
	if typeof(e.npc) ~= "string" or not EncounterScheduler.SPARKZ_NPCS[e.npc] then
		return
	end
	state.sparkzBlocked = true
	local cur = state.current
	if cur and SPARKZ_SET[cur] then
		-- Blocking is a valid safe exit: the scene in progress resolves.
		finish(state, cur, "resolved")
	end
	-- refresh() marks every remaining Sparkz beat skipped_by_block.
end

-- No reset and no restart: blocked beats stay skipped_by_block.
handlers.unblocked = function(state, e)
	if typeof(e.npc) == "string" and EncounterScheduler.SPARKZ_NPCS[e.npc] then
		state.sparkzBlocked = false
	end
end

handlers.dash_introduced = function(state, _e)
	state.dashIntroduced = true
end

-- Respawn, disconnect, help preempt or activity start: the beat goes back
-- to eligible. Pacing (gap, activity counts) is untouched.
handlers.interrupted = function(state, e)
	if isCurrent(state, e.beat) then
		state.beats[e.beat] = "eligible"
		state.current = nil
	end
end

function EncounterScheduler.apply(state, event)
	local out = deepCopy(state)
	if typeof(event) ~= "table" or typeof(event.kind) ~= "string" then
		return out
	end
	local handler = handlers[event.kind]
	if not handler then
		return out
	end
	handler(out, event)
	refresh(out)
	return out
end

local function nonEmpty(v: any): boolean
	return typeof(v) == "string" and #v > 0
end

-- ctx = { busy, help, replay?, recovery?, recoveryRequested?, ambient? }
function EncounterScheduler.decide(state, ctx)
	ctx = if typeof(ctx) == "table" then ctx else {}
	local busy = ctx.busy == true

	-- Player-initiated: always answered, even while busy.
	if ctx.help == true then
		return { kind = "help" }
	end
	if nonEmpty(ctx.replay) then
		return { kind = "replay", beat = ctx.replay }
	end

	-- A pending recovery follow-up waits until the player is free, unless
	-- the player asked for it. It does not use the invitation gap.
	if nonEmpty(ctx.recovery) and (not busy or ctx.recoveryRequested == true) then
		return { kind = "recovery", beat = ctx.recovery }
	end

	-- Unsolicited invitations.
	if busy or state.remainingGap > 0 or state.current ~= nil then
		return nil
	end
	for _, beat in EncounterScheduler.BEATS do
		if EncounterScheduler.status(state, beat) == "eligible" then
			return { kind = "campaign", beat = beat }
		end
	end
	if nonEmpty(ctx.ambient) then
		return { kind = "ambient", id = ctx.ambient }
	end
	return nil
end

-- Normalizes loaded or partial saved state so it can be trusted.
-- A scene invited/active at save time cannot still be open after a
-- reconnect, so it returns to eligible (the gap persists, so no burst).
function EncounterScheduler.sanitize(raw)
	local s = EncounterScheduler.defaultState()
	if typeof(raw) ~= "table" then
		return s
	end

	if typeof(raw.onboarded) == "boolean" then
		s.onboarded = raw.onboarded
	end
	if isCount(raw.completedActivities) then
		s.completedActivities = raw.completedActivities
	end
	local n = s.completedActivities
	if s.onboarded and isCount(raw.onboardedAtActivity) and raw.onboardedAtActivity <= n then
		s.onboardedAtActivity = raw.onboardedAtActivity
	elseif s.onboarded then
		s.onboardedAtActivity = n
	end
	if typeof(raw.remainingGap) == "number" and raw.remainingGap == raw.remainingGap then
		s.remainingGap = math.clamp(raw.remainingGap, 0, EncounterScheduler.MIN_GAP_SECONDS)
	end
	if typeof(raw.dashIntroduced) == "boolean" then
		s.dashIntroduced = raw.dashIntroduced
	end
	if typeof(raw.sparkzBlocked) == "boolean" then
		s.sparkzBlocked = raw.sparkzBlocked
	end

	local beats = if typeof(raw.beats) == "table" then raw.beats else {}
	local resolvedAt = if typeof(raw.resolvedAtActivity) == "table" then raw.resolvedAtActivity else {}
	local deferredAt = if typeof(raw.deferredAtActivity) == "table" then raw.deferredAtActivity else {}

	for _, beat in EncounterScheduler.BEATS do
		local status = beats[beat]
		if typeof(status) == "string" and STATUSES[status] then
			if status == "invited" or status == "active" then
				status = "eligible"
			end
			if status ~= "not_started" then
				s.beats[beat] = status
			end
			if DONE[status] then
				local at = resolvedAt[beat]
				s.resolvedAtActivity[beat] = if isCount(at) and at <= n then at else n
			elseif status == "deferred" then
				local at = deferredAt[beat]
				s.deferredAtActivity[beat] = if isCount(at) and at <= n then at else n
			end
		end
	end

	refresh(s)
	return s
end

return EncounterScheduler
