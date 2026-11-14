--[[
	LearningProgress: the private evidence ledger (spec section 6). Pure logic.

	The ledger holds only fixed, bounded state:
	  evidence       slotId -> credited points (0..weight), slot ids from ScoreRules
	  encountered    beatId -> "live" | "roleplay"
	  seenFacts      beatId -> { factId -> true }, at most MAX_FACTS_PER_BEAT each
	  toldCara       beatId -> true
	  toldLee        beatId -> true
	  needsCoaching  beatId -> true (cleared by recovery; never gates anything)
	  review         { setIndex, presented = { cardId -> true },
	                   firstAttempt = { slotN -> { correct, label } },
	                   best = { slotN -> 0 | 1 } }   (keys "slot1".."slot6")
	  titles         titleId -> true (never revoked)

	No transcripts, no attempt lists, no risky-choice count.

	record(ledger, rules, event) mutates the ledger in place and returns
	whether anything changed. Every credit is max(old, new): replaying any
	event any number of times can never exceed a slot's weight or the total.
	Invalid input (unknown kind/beat/slot, oversized ids) changes nothing.
]]

local LearningProgress = {}

LearningProgress.MAX_ID_LENGTH = 40
LearningProgress.MAX_FACTS_PER_BEAT = 16
LearningProgress.MAX_PRESENTED_CARDS = 32
LearningProgress.MAX_SET_INDEX = 1000
LearningProgress.TITLES = { "rookie", "cadet", "ranger" }

local REVIEW_LABELS = { fresh = true, resumed = true, reused = true }
local TITLE_SET = { rookie = true, cadet = true, ranger = true }

-- Review state is keyed "slot1".."slot6" (string keys keep the saved
-- table DataStore-safe; integer keys with holes are not).
function LearningProgress.slotKey(slot: number): string
	return `slot{slot}`
end

local function validId(id: any): boolean
	return typeof(id) == "string" and #id > 0 and #id <= LearningProgress.MAX_ID_LENGTH
end

local function inList(list: { string }, value: any): boolean
	for _, v in list do
		if v == value then
			return true
		end
	end
	return false
end

local function isBeat(rules, beat: any): boolean
	return validId(beat) and inList(rules.beats, beat)
end

local function isAssessedBeat(rules, beat: any): boolean
	return validId(beat) and inList(rules.assessedBeats, beat)
end

local function isInteger(n: any, lo: number, hi: number): boolean
	return typeof(n) == "number" and n == n and n % 1 == 0 and n >= lo and n <= hi
end

local function count(set: { [any]: any }?): number
	local n = 0
	for _ in set or {} do
		n += 1
	end
	return n
end

-- Credits a slot with max(old, points). Returns true if the stored value rose.
local function credit(ledger, rules, slotId: string, points: number): boolean
	local slot = rules.slots[slotId]
	if not slot then
		return false
	end
	local new = math.clamp(points, 0, slot.weight)
	local old = ledger.evidence[slotId] or 0
	if new > old then
		ledger.evidence[slotId] = new
		return true
	end
	return false
end

-- Credits several slots; true if any rose.
local function creditAll(ledger, rules, slotIds: { string }): boolean
	local changed = false
	for _, id in slotIds do
		if credit(ledger, rules, id, rules.slots[id] and rules.slots[id].weight or 0) then
			changed = true
		end
	end
	return changed
end

function LearningProgress.default()
	return {
		rulesVersion = 1,
		evidence = {},
		encountered = {},
		seenFacts = {},
		toldCara = {},
		toldLee = {},
		needsCoaching = {},
		review = { setIndex = 1, presented = {}, firstAttempt = {}, best = {} },
		titles = {},
	}
end

-- Credit for a beat is only possible once it was actually encountered,
-- live or through a Cara roleplay.
local function canCredit(ledger, rules, beat: any): boolean
	return isAssessedBeat(rules, beat) and ledger.encountered[beat] ~= nil
end

local handlers: { [string]: (ledger: any, rules: any, event: any) -> boolean } = {}

handlers.beat_encountered = function(ledger, rules, e)
	if not isBeat(rules, e.beat) then
		return false
	end
	local how = if e.viaRoleplay == true then "roleplay" else "live"
	local old = ledger.encountered[e.beat]
	-- "live" outranks "roleplay"; never downgrade.
	if old == nil or (old == "roleplay" and how == "live") then
		ledger.encountered[e.beat] = how
		return true
	end
	return false
end

handlers.fact_seen = function(ledger, rules, e)
	if not isBeat(rules, e.beat) or not validId(e.fact) then
		return false
	end
	local facts = ledger.seenFacts[e.beat]
	if facts and facts[e.fact] then
		return false
	end
	if facts and count(facts) >= LearningProgress.MAX_FACTS_PER_BEAT then
		return false
	end
	if not facts then
		facts = {}
		ledger.seenFacts[e.beat] = facts
	end
	facts[e.fact] = true
	return true
end

handlers.recognized = function(ledger, rules, e)
	if not canCredit(ledger, rules, e.beat) then
		return false
	end
	return creditAll(ledger, rules, { `recognize.{e.beat}` })
end

handlers.protected_boundary = function(ledger, rules, e)
	if not canCredit(ledger, rules, e.beat) then
		return false
	end
	return creditAll(ledger, rules, { `respond.{e.beat}.boundary` })
end

handlers.ended_pressure = function(ledger, rules, e)
	if not canCredit(ledger, rules, e.beat) then
		return false
	end
	return creditAll(ledger, rules, { `respond.{e.beat}.end` })
end

-- Leaving, blocking, reporting or asking for help right after the concerning
-- request earns full Respond credit without enduring further pressure.
handlers.left_after_request = function(ledger, rules, e)
	if not canCredit(ledger, rules, e.beat) then
		return false
	end
	return creditAll(ledger, rules, { `respond.{e.beat}.boundary`, `respond.{e.beat}.end` })
end

handlers.told_cara = function(ledger, rules, e)
	if not canCredit(ledger, rules, e.beat) then
		return false
	end
	local changed = ledger.toldCara[e.beat] == nil
	ledger.toldCara[e.beat] = true
	if creditAll(ledger, rules, { `reach.{e.beat}.first` }) then
		changed = true
	end
	return changed
end

-- Direct Lee earns both Reach slots; after Cara it adds the second.
-- Either way the beat tops out at 2.
handlers.told_lee = function(ledger, rules, e)
	if not canCredit(ledger, rules, e.beat) then
		return false
	end
	local changed = ledger.toldLee[e.beat] == nil
	ledger.toldLee[e.beat] = true
	if creditAll(ledger, rules, { `reach.{e.beat}.first`, `reach.{e.beat}.second` }) then
		changed = true
	end
	return changed
end

handlers.review_presented = function(ledger, _rules, e)
	if not validId(e.cardId) then
		return false
	end
	local presented = ledger.review.presented
	if presented[e.cardId] then
		return false
	end
	if count(presented) >= LearningProgress.MAX_PRESENTED_CARDS then
		return false
	end
	presented[e.cardId] = true
	return true
end

handlers.review_answer = function(ledger, rules, e)
	if not isInteger(e.slot, 1, rules.reviewSlots) then
		return false
	end
	if typeof(e.correct) ~= "boolean" or not REVIEW_LABELS[e.label] then
		return false
	end
	local review = ledger.review
	local key = LearningProgress.slotKey(e.slot)
	local changed = false
	if review.firstAttempt[key] == nil then
		review.firstAttempt[key] = { correct = e.correct, label = e.label }
		changed = true
	end
	local score = if e.correct then 1 else 0
	local oldBest = review.best[key]
	if oldBest == nil or score > oldBest then
		review.best[key] = score
		changed = true
	end
	if e.correct and creditAll(ledger, rules, { `review.slot{e.slot}` }) then
		changed = true
	end
	return changed
end

-- Not in the original brief: lets the orchestrating service move the review
-- rotation through record() instead of writing the ledger directly.
handlers.review_set_index = function(ledger, _rules, e)
	if not isInteger(e.setIndex, 1, LearningProgress.MAX_SET_INDEX) then
		return false
	end
	if ledger.review.setIndex == e.setIndex then
		return false
	end
	ledger.review.setIndex = e.setIndex
	return true
end

handlers.rookie_case = function(ledger, rules, e)
	if not isInteger(e.case, 1, rules.rookieCases) or typeof(e.good) ~= "boolean" then
		return false
	end
	if not e.good then
		return false -- a coached retry is always allowed; a miss records nothing
	end
	return creditAll(ledger, rules, { `rookie.case{e.case}` })
end

handlers.listening_post = function(ledger, rules, e)
	if typeof(e.good) ~= "boolean" or not e.good then
		return false
	end
	return creditAll(ledger, rules, { "listening.post" })
end

handlers.coaching_needed = function(ledger, rules, e)
	if not isBeat(rules, e.beat) or ledger.needsCoaching[e.beat] then
		return false
	end
	ledger.needsCoaching[e.beat] = true
	return true
end

handlers.coaching_cleared = function(ledger, rules, e)
	if not isBeat(rules, e.beat) or not ledger.needsCoaching[e.beat] then
		return false
	end
	ledger.needsCoaching[e.beat] = nil
	return true
end

-- Recording only; the caller checks eligibleTitles first. Never revoked.
handlers.title_awarded = function(ledger, _rules, e)
	if not TITLE_SET[e.title] or ledger.titles[e.title] then
		return false
	end
	ledger.titles[e.title] = true
	return true
end

function LearningProgress.record(ledger, rules, event): boolean
	if typeof(ledger) ~= "table" or typeof(rules) ~= "table" or typeof(event) ~= "table" then
		return false
	end
	local handler = typeof(event.kind) == "string" and handlers[event.kind]
	if not handler then
		return false
	end
	return handler(ledger, rules, event)
end

function LearningProgress.total(ledger, rules): number
	local sum = 0
	for id, slot in rules.slots do
		sum += math.clamp(ledger.evidence[id] or 0, 0, slot.weight)
	end
	return math.min(sum, rules.maxPoints)
end

function LearningProgress.categories(ledger, rules): { recognize: number, respond: number, reach: number }
	local out = { recognize = 0, respond = 0, reach = 0 }
	for id, slot in rules.slots do
		out[slot.category] = (out[slot.category] or 0) + math.clamp(ledger.evidence[id] or 0, 0, slot.weight)
	end
	return out
end

local function reviewSlotsDemonstrated(ledger, rules): number
	local n = 0
	for i = 1, rules.reviewSlots do
		if (ledger.evidence[`review.slot{i}`] or 0) >= 1 then
			n += 1
		end
	end
	return n
end

local function leeReports(ledger, rules): number
	local n = 0
	for _, beat in rules.assessedBeats do
		if ledger.toldLee[beat] then
			n += 1
		end
	end
	return n
end

local function rookieCasesDone(ledger, rules): number
	local n = 0
	for i = 1, rules.rookieCases do
		if (ledger.evidence[`rookie.case{i}`] or 0) >= 1 then
			n += 1
		end
	end
	return n
end

-- Which titles the player currently qualifies for. Awarding is separate
-- (record "title_awarded"), and an award is never taken back.
function LearningProgress.eligibleTitles(ledger, rules, facts): { rookie: boolean, cadet: boolean, ranger: boolean }
	local points = LearningProgress.total(ledger, rules)
	local c = rules.thresholds.cadet
	local r = rules.thresholds.ranger

	local rookie = typeof(facts) == "table" and facts.showCompleted == true
	local cadet = rookie
		and points >= c.minPoints
		and leeReports(ledger, rules) >= c.minLeeReports
		and reviewSlotsDemonstrated(ledger, rules) >= c.minReviewSlots
	local ranger = cadet
		and points >= r.minPoints
		and reviewSlotsDemonstrated(ledger, rules) >= r.reviewSlots
		and ledger.toldLee[r.requireLeeReport] == true
		and rookieCasesDone(ledger, rules) >= r.rookieCases
		and (not r.listening or (ledger.evidence["listening.post"] or 0) >= 1)

	return { rookie = rookie, cadet = cadet, ranger = ranger }
end

-- Studio evaluation only: first-ever answers that were fresh and correct.
-- Resumed and reused answers are practice, not transfer evidence.
function LearningProgress.freshTransfer(ledger): number
	local n = 0
	for _, attempt in ledger.review.firstAttempt do
		if attempt.label == "fresh" and attempt.correct == true then
			n += 1
		end
	end
	return n
end

return LearningProgress
