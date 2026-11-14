--[[
	ScoreRules: the private Ranger Instinct evidence model (spec section 6).
	SERVER ONLY. Never move this to Shared or send any of it to a client.

	Version 1 uses fixed evidence slots, every one worth 1 point, 30 in total.
	A slot is credited at most once (max(old, new)), so retries and replays
	can never push a player past the cap.

	  recognize.<beat>            4   Recognize   correct pattern in E2-E5
	  review.slot1..slot6         6   Recognize   best answer per review slot
	                                              (slots 1-3 benign, 4-6 concerning)
	  respond.<beat>.boundary     4   Respond     protected the boundary
	  respond.<beat>.end          4   Respond     ended / rejected further pressure
	  reach.<beat>.first          4   Reach Out   told Cara or Lee
	  reach.<beat>.second         4   Reach Out   told Lee (direct Lee earns both)
	  rookie.case1..case3         3   Reach Out   Rookie Rescue cases
	  listening.post              1   Reach Out   Listening Post

	Thresholds are tunable game-design defaults, not validated measures.
]]

local BEATS = { "e1", "green_riley", "e2", "e3", "e4", "e5" }
local ASSESSED_BEATS = { "e2", "e3", "e4", "e5" }
local REVIEW_SLOTS = 6
local ROOKIE_CASES = 3

local slots = {}

local function add(id: string, category: string, extra: { [string]: any }?)
	local slot = { id = id, category = category, weight = 1 }
	for k, v in extra or {} do
		slot[k] = v
	end
	slots[id] = slot
end

for _, beat in ASSESSED_BEATS do
	add(`recognize.{beat}`, "recognize", { beat = beat })
end
for i = 1, REVIEW_SLOTS do
	add(`review.slot{i}`, "recognize", { reviewSlot = i, reviewKind = if i <= 3 then "benign" else "concerning" })
end
for _, beat in ASSESSED_BEATS do
	add(`respond.{beat}.boundary`, "respond", { beat = beat })
	add(`respond.{beat}.end`, "respond", { beat = beat })
end
for _, beat in ASSESSED_BEATS do
	add(`reach.{beat}.first`, "reach", { beat = beat })
	add(`reach.{beat}.second`, "reach", { beat = beat })
end
for i = 1, ROOKIE_CASES do
	add(`rookie.case{i}`, "reach", { rookieCase = i })
end
add("listening.post", "reach")

return {
	rulesVersion = 1,
	maxPoints = 30,
	slots = slots,
	thresholds = {
		cadet = { minPoints = 18, minLeeReports = 2, minReviewSlots = 4 },
		ranger = {
			minPoints = 26,
			reviewSlots = 6,
			requireLeeReport = "e5",
			rookieCases = 3,
			listening = true,
		},
	},

	-- Helpers for LearningProgress (not separate rules).
	beats = BEATS,
	assessedBeats = ASSESSED_BEATS,
	reviewSlots = REVIEW_SLOTS,
	rookieCases = ROOKIE_CASES,
	categories = { "recognize", "respond", "reach" },
}
