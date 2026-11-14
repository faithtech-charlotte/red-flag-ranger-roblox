local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local L = require(Server.Logic.LearningProgress)
local R = require(Server.Content.ScoreRules)

return function(t)
	local expect = t.expect

	local ASSESSED = { "e2", "e3", "e4", "e5" }

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

	local function rec(ledger, events)
		for _, e in events do
			L.record(ledger, R, e)
		end
		return ledger
	end

	-- First-try path for one beat: recognize, leave right after the ask, tell Lee.
	local function firstTryBeat(beat)
		return {
			{ kind = "beat_encountered", beat = beat },
			{ kind = "recognized", beat = beat },
			{ kind = "left_after_request", beat = beat },
			{ kind = "told_lee", beat = beat },
		}
	end

	-- Recovered path: simulated agreement, coaching, then the recovery choices.
	local function recoveredBeat(beat)
		return {
			{ kind = "beat_encountered", beat = beat },
			{ kind = "coaching_needed", beat = beat },
			{ kind = "protected_boundary", beat = beat },
			{ kind = "ended_pressure", beat = beat },
			{ kind = "recognized", beat = beat },
			{ kind = "told_cara", beat = beat },
			{ kind = "told_lee", beat = beat },
			{ kind = "coaching_cleared", beat = beat },
		}
	end

	local function firstTryReview(slots)
		local list = {}
		for i = 1, slots do
			table.insert(list, { kind = "review_answer", slot = i, correct = true, label = "fresh" })
		end
		return list
	end

	local function recoveredReview(slots)
		local list = {}
		for i = 1, slots do
			table.insert(list, { kind = "review_answer", slot = i, correct = false, label = "fresh" })
			table.insert(list, { kind = "review_answer", slot = i, correct = true, label = "reused" })
		end
		return list
	end

	local EXTRAS = {
		{ kind = "rookie_case", case = 1, good = true },
		{ kind = "rookie_case", case = 2, good = true },
		{ kind = "rookie_case", case = 3, good = true },
		{ kind = "listening_post", good = true },
	}

	local function everything(beatPath, reviewPath)
		local ledger = L.default()
		for _, beat in ASSESSED do
			rec(ledger, beatPath(beat))
		end
		rec(ledger, reviewPath(6))
		rec(ledger, EXTRAS)
		return ledger
	end

	local SHOW = { showCompleted = true }

	-- ScoreRules
	t.test("score rules: 30 slots of weight 1, split 10/8/12", function()
		local n, sum = 0, 0
		local byCat = { recognize = 0, respond = 0, reach = 0 }
		for id, slot in R.slots do
			n += 1
			sum += slot.weight
			expect(slot.weight).toBe(1)
			expect(slot.id).toBe(id)
			byCat[slot.category] += 1
		end
		expect(n).toBe(30)
		expect(sum).toBe(30)
		expect(R.maxPoints).toBe(30)
		expect(R.rulesVersion).toBe(1)
		expect(byCat).toEqual({ recognize = 10, respond = 8, reach = 12 })
		for _, id in { "recognize.e2", "review.slot6", "respond.e5.boundary", "respond.e3.end", "reach.e4.first", "reach.e2.second", "rookie.case3", "listening.post" } do
			expect(R.slots[id] ~= nil).toBe(true)
		end
		expect(R.slots["recognize.e1"]).toBe(nil)
		expect(R.slots["review.slot3"].reviewKind).toBe("benign")
		expect(R.slots["review.slot4"].reviewKind).toBe("concerning")
	end)

	t.test("ledger: default shape with no credit", function()
		expect(L.default()).toEqual({
			rulesVersion = 1,
			evidence = {},
			encountered = {},
			seenFacts = {},
			toldCara = {},
			toldLee = {},
			needsCoaching = {},
			review = { setIndex = 1, presented = {}, firstAttempt = {}, best = {} },
			titles = {},
		})
		expect(L.total(L.default(), R)).toBe(0)
	end)

	t.test("ledger: total caps at 30 under replays and repeated buttons", function()
		local ledger = everything(firstTryBeat, firstTryReview)
		expect(L.total(ledger, R)).toBe(30)
		for _ = 1, 3 do
			for _, beat in ASSESSED do
				rec(ledger, firstTryBeat(beat))
				rec(ledger, recoveredBeat(beat))
			end
			rec(ledger, recoveredReview(6))
			rec(ledger, EXTRAS)
		end
		expect(L.total(ledger, R)).toBe(30)
		expect(L.categories(ledger, R)).toEqual({ recognize = 10, respond = 8, reach = 12 })
		for id, v in ledger.evidence do
			expect(v <= R.slots[id].weight).toBe(true)
		end
	end)

	t.test("ledger: replaying an event reports no change", function()
		local ledger = L.default()
		expect(L.record(ledger, R, { kind = "beat_encountered", beat = "e2" })).toBe(true)
		expect(L.record(ledger, R, { kind = "recognized", beat = "e2" })).toBe(true)
		expect(L.record(ledger, R, { kind = "recognized", beat = "e2" })).toBe(false)
		expect(L.record(ledger, R, { kind = "left_after_request", beat = "e2" })).toBe(true)
		expect(L.record(ledger, R, { kind = "protected_boundary", beat = "e2" })).toBe(false)
		expect(L.record(ledger, R, { kind = "ended_pressure", beat = "e2" })).toBe(false)
	end)

	t.test("ledger: leaving right after the request earns full Respond", function()
		local ledger = rec(L.default(), {
			{ kind = "beat_encountered", beat = "e3" },
			{ kind = "left_after_request", beat = "e3" },
		})
		expect(L.categories(ledger, R)).toEqual({ recognize = 0, respond = 2, reach = 0 })
		expect(ledger.evidence["respond.e3.boundary"]).toBe(1)
		expect(ledger.evidence["respond.e3.end"]).toBe(1)
	end)

	t.test("ledger: agreement then recovery equals initial refusal", function()
		local refused = rec(L.default(), {
			{ kind = "beat_encountered", beat = "e2" },
			{ kind = "protected_boundary", beat = "e2" },
			{ kind = "ended_pressure", beat = "e2" },
			{ kind = "told_lee", beat = "e2" },
		})
		local recovered = rec(L.default(), {
			{ kind = "beat_encountered", beat = "e2" },
			{ kind = "coaching_needed", beat = "e2" },
			{ kind = "protected_boundary", beat = "e2" },
			{ kind = "ended_pressure", beat = "e2" },
			{ kind = "told_lee", beat = "e2" },
			{ kind = "coaching_cleared", beat = "e2" },
		})
		expect(recovered.evidence).toEqual(refused.evidence)
		expect(recovered.needsCoaching).toEqual({})
		expect(L.total(recovered, R)).toBe(4)
	end)

	t.test("ledger: Reach Out tops out at 2 per beat on every route", function()
		local cases = {
			{ name = "direct Lee", events = { "told_lee" }, want = 2 },
			{ name = "Cara then Lee", events = { "told_cara", "told_lee" }, want = 2 },
			{ name = "Lee twice", events = { "told_lee", "told_lee" }, want = 2 },
			{ name = "Lee then Cara", events = { "told_lee", "told_cara" }, want = 2 },
			{ name = "Cara only", events = { "told_cara", "told_cara", "told_cara" }, want = 1 },
		}
		for _, c in cases do
			local ledger = rec(L.default(), { { kind = "beat_encountered", beat = "e4" } })
			for _, kind in c.events do
				L.record(ledger, R, { kind = kind, beat = "e4" })
			end
			local reach = L.categories(ledger, R).reach
			if reach ~= c.want then
				error(`{c.name}: expected {c.want}, got {reach}`)
			end
		end
	end)

	t.test("ledger: no credit for a beat that was never encountered", function()
		local ledger = L.default()
		for _, kind in { "recognized", "protected_boundary", "ended_pressure", "left_after_request", "told_cara", "told_lee" } do
			expect(L.record(ledger, R, { kind = kind, beat = "e3" })).toBe(false)
		end
		expect(L.total(ledger, R)).toBe(0)
		expect(ledger.toldLee).toEqual({})
		-- Encountered but not an assessed beat: still nothing to credit.
		rec(ledger, { { kind = "beat_encountered", beat = "e1" } })
		expect(L.record(ledger, R, { kind = "told_lee", beat = "e1" })).toBe(false)
		expect(L.record(ledger, R, { kind = "recognized", beat = "green_riley" })).toBe(false)
		expect(L.total(ledger, R)).toBe(0)
	end)

	t.test("ledger: a Cara roleplay counts as encountering the beat", function()
		local ledger = L.default()
		expect(L.record(ledger, R, { kind = "beat_encountered", beat = "e3", viaRoleplay = true })).toBe(true)
		expect(ledger.encountered.e3).toBe("roleplay")
		rec(ledger, { { kind = "left_after_request", beat = "e3" }, { kind = "told_lee", beat = "e3" } })
		expect(L.total(ledger, R)).toBe(4)
		expect(L.record(ledger, R, { kind = "beat_encountered", beat = "e3" })).toBe(true)
		expect(ledger.encountered.e3).toBe("live")
		expect(L.record(ledger, R, { kind = "beat_encountered", beat = "e3", viaRoleplay = true })).toBe(false)
		expect(ledger.encountered.e3).toBe("live")
	end)

	t.test("ledger: review keeps the first attempt and improves best", function()
		local ledger = L.default()
		expect(L.record(ledger, R, { kind = "review_answer", slot = 1, correct = false, label = "fresh" })).toBe(true)
		expect(ledger.review.firstAttempt.slot1).toEqual({ correct = false, label = "fresh" })
		expect(ledger.review.best.slot1).toBe(0)
		expect(L.total(ledger, R)).toBe(0)

		expect(L.record(ledger, R, { kind = "review_answer", slot = 1, correct = true, label = "resumed" })).toBe(true)
		expect(ledger.review.firstAttempt.slot1).toEqual({ correct = false, label = "fresh" })
		expect(ledger.review.best.slot1).toBe(1)
		expect(ledger.evidence["review.slot1"]).toBe(1)

		expect(L.record(ledger, R, { kind = "review_answer", slot = 1, correct = false, label = "reused" })).toBe(false)
		expect(ledger.review.best.slot1).toBe(1)
		expect(L.total(ledger, R)).toBe(1)
	end)

	t.test("ledger: only fresh first answers count as transfer", function()
		local ledger = rec(L.default(), {
			{ kind = "review_answer", slot = 1, correct = false, label = "fresh" },
			{ kind = "review_answer", slot = 1, correct = true, label = "fresh" },
			{ kind = "review_answer", slot = 2, correct = true, label = "fresh" },
			{ kind = "review_answer", slot = 3, correct = true, label = "reused" },
			{ kind = "review_answer", slot = 4, correct = true, label = "resumed" },
			{ kind = "review_answer", slot = 3, correct = true, label = "fresh" },
		})
		expect(L.freshTransfer(ledger)).toBe(1)
		expect(L.total(ledger, R)).toBe(4)
	end)

	t.test("ledger: presented cards and set index are bounded", function()
		local ledger = L.default()
		expect(L.record(ledger, R, { kind = "review_presented", cardId = "A1" })).toBe(true)
		expect(L.record(ledger, R, { kind = "review_presented", cardId = "A1" })).toBe(false)
		for i = 1, 50 do
			L.record(ledger, R, { kind = "review_presented", cardId = `card{i}` })
		end
		local n = 0
		for _ in ledger.review.presented do
			n += 1
		end
		expect(n).toBe(L.MAX_PRESENTED_CARDS)
		expect(L.record(ledger, R, { kind = "review_set_index", setIndex = 2 })).toBe(true)
		expect(ledger.review.setIndex).toBe(2)
		expect(L.record(ledger, R, { kind = "review_set_index", setIndex = 2 })).toBe(false)
		expect(L.record(ledger, R, { kind = "review_set_index", setIndex = 0 })).toBe(false)
		expect(L.record(ledger, R, { kind = "review_set_index", setIndex = 1.5 })).toBe(false)
		expect(L.total(ledger, R)).toBe(0)
	end)

	t.test("titles: nothing without the show, Rookie with it", function()
		local ledger = everything(firstTryBeat, firstTryReview)
		expect(L.eligibleTitles(ledger, R, { showCompleted = false })).toEqual({ rookie = false, cadet = false, ranger = false })
		expect(L.eligibleTitles(ledger, R, nil)).toEqual({ rookie = false, cadet = false, ranger = false })
		expect(L.eligibleTitles(L.default(), R, SHOW)).toEqual({ rookie = true, cadet = false, ranger = false })
	end)

	t.test("titles: Ranger by the first-try path", function()
		local ledger = everything(firstTryBeat, firstTryReview)
		expect(L.eligibleTitles(ledger, R, SHOW)).toEqual({ rookie = true, cadet = true, ranger = true })
		expect(L.freshTransfer(ledger)).toBe(6)
	end)

	t.test("titles: Ranger by the recovered path", function()
		local ledger = L.default()
		for _, beat in ASSESSED do
			rec(ledger, recoveredBeat(beat))
		end
		rec(ledger, recoveredReview(6))
		rec(ledger, {
			{ kind = "rookie_case", case = 1, good = false },
			{ kind = "rookie_case", case = 2, good = false },
			{ kind = "rookie_case", case = 3, good = false },
			{ kind = "listening_post", good = false },
		})
		expect(L.eligibleTitles(ledger, R, SHOW).ranger).toBe(false)
		rec(ledger, EXTRAS)
		expect(L.total(ledger, R)).toBe(30)
		expect(L.eligibleTitles(ledger, R, SHOW)).toEqual({ rookie = true, cadet = true, ranger = true })
		expect(L.freshTransfer(ledger)).toBe(0)
	end)

	t.test("titles: Cadet by first-try and recovered paths, not Ranger", function()
		for _, path in { { firstTryBeat, firstTryReview }, { recoveredBeat, recoveredReview } } do
			local ledger = L.default()
			for _, beat in { "e2", "e3", "e4" } do
				rec(ledger, path[1](beat))
			end
			rec(ledger, path[2](4))
			expect(L.total(ledger, R)).toBe(19)
			expect(L.eligibleTitles(ledger, R, SHOW)).toEqual({ rookie = true, cadet = true, ranger = false })
		end
	end)

	t.test("titles: Cadet thresholds each matter", function()
		-- 18 points but only one Lee report.
		local oneLee = L.default()
		for _, beat in ASSESSED do
			rec(oneLee, {
				{ kind = "beat_encountered", beat = beat },
				{ kind = "recognized", beat = beat },
				{ kind = "left_after_request", beat = beat },
				{ kind = "told_cara", beat = beat },
			})
		end
		rec(oneLee, firstTryReview(6))
		expect(L.total(oneLee, R)).toBe(22)
		L.record(oneLee, R, { kind = "told_lee", beat = "e2" })
		expect(L.eligibleTitles(oneLee, R, SHOW).cadet).toBe(false)
		L.record(oneLee, R, { kind = "told_lee", beat = "e3" })
		expect(L.eligibleTitles(oneLee, R, SHOW).cadet).toBe(true)

		-- Enough points and reports but only 3 review slots.
		local fewReview = L.default()
		for _, beat in ASSESSED do
			rec(fewReview, firstTryBeat(beat))
		end
		rec(fewReview, firstTryReview(3))
		expect(L.total(fewReview, R)).toBe(23)
		expect(L.eligibleTitles(fewReview, R, SHOW).cadet).toBe(false)
	end)

	t.test("titles: Ranger needs the Dash report to Lee", function()
		local ledger = L.default()
		for _, beat in { "e2", "e3", "e4" } do
			rec(ledger, firstTryBeat(beat))
		end
		rec(ledger, {
			{ kind = "beat_encountered", beat = "e5" },
			{ kind = "recognized", beat = "e5" },
			{ kind = "left_after_request", beat = "e5" },
			{ kind = "told_cara", beat = "e5" },
		})
		rec(ledger, firstTryReview(6))
		rec(ledger, EXTRAS)
		expect(L.total(ledger, R)).toBe(29)
		expect(L.eligibleTitles(ledger, R, SHOW)).toEqual({ rookie = true, cadet = true, ranger = false })
		L.record(ledger, R, { kind = "told_lee", beat = "e5" })
		expect(L.eligibleTitles(ledger, R, SHOW).ranger).toBe(true)
	end)

	t.test("titles: once awarded, never revoked", function()
		local ledger = L.default()
		expect(L.record(ledger, R, { kind = "title_awarded", title = "cadet" })).toBe(true)
		expect(L.record(ledger, R, { kind = "title_awarded", title = "cadet" })).toBe(false)
		expect(L.record(ledger, R, { kind = "title_awarded", title = "admin" })).toBe(false)
		rec(ledger, {
			{ kind = "coaching_needed", beat = "e2" },
			{ kind = "review_answer", slot = 1, correct = false, label = "fresh" },
			{ kind = "title_revoked", title = "cadet" },
			{ kind = "title_awarded", title = nil },
		})
		expect(ledger.titles).toEqual({ cadet = true })
	end)

	t.test("coaching: set and clear, never gates", function()
		local ledger = everything(firstTryBeat, firstTryReview)
		local before = L.eligibleTitles(ledger, R, SHOW)
		expect(L.record(ledger, R, { kind = "coaching_needed", beat = "e2" })).toBe(true)
		expect(L.record(ledger, R, { kind = "coaching_needed", beat = "e2" })).toBe(false)
		for _, beat in R.beats do
			L.record(ledger, R, { kind = "coaching_needed", beat = beat })
		end
		expect(ledger.needsCoaching.e5).toBe(true)
		expect(L.eligibleTitles(ledger, R, SHOW)).toEqual(before)
		expect(L.total(ledger, R)).toBe(30)
		expect(L.record(ledger, R, { kind = "coaching_cleared", beat = "e2" })).toBe(true)
		expect(ledger.needsCoaching.e2).toBe(nil)
		expect(L.record(ledger, R, { kind = "coaching_cleared", beat = "e2" })).toBe(false)
		expect(L.record(ledger, R, { kind = "coaching_needed", beat = "e9" })).toBe(false)
	end)

	t.test("facts: bounded per beat, ids checked", function()
		local ledger = L.default()
		expect(L.record(ledger, R, { kind = "fact_seen", beat = "e2", fact = "asked_school" })).toBe(true)
		expect(L.record(ledger, R, { kind = "fact_seen", beat = "e2", fact = "asked_school" })).toBe(false)
		for i = 1, 30 do
			L.record(ledger, R, { kind = "fact_seen", beat = "e2", fact = `fact_{i}` })
		end
		local n = 0
		for _ in ledger.seenFacts.e2 do
			n += 1
		end
		expect(n).toBe(L.MAX_FACTS_PER_BEAT)
		expect(L.record(ledger, R, { kind = "fact_seen", beat = "e3", fact = string.rep("x", 41) })).toBe(false)
		expect(L.record(ledger, R, { kind = "fact_seen", beat = "e3", fact = string.rep("x", 40) })).toBe(true)
		expect(L.record(ledger, R, { kind = "fact_seen", beat = "e9", fact = "asked_school" })).toBe(false)
		expect(L.record(ledger, R, { kind = "fact_seen", beat = "e3", fact = "" })).toBe(false)
		expect(L.record(ledger, R, { kind = "fact_seen", beat = "e3", fact = 12 })).toBe(false)
		expect(L.total(ledger, R)).toBe(0)
	end)

	t.test("ledger: unknown or malformed inputs are rejected without change", function()
		local ledger = rec(L.default(), { { kind = "beat_encountered", beat = "e2" } })
		local snapshot = deepCopy(ledger)
		local bad = {
			{ kind = "made_up", beat = "e2" },
			{ kind = "recognized", beat = "e9" },
			{ kind = "recognized", beat = string.rep("e", 41) },
			{ kind = "recognized" },
			{ kind = "beat_encountered", beat = "jordan" },
			{ kind = "review_answer", slot = 7, correct = true, label = "fresh" },
			{ kind = "review_answer", slot = 0, correct = true, label = "fresh" },
			{ kind = "review_answer", slot = 1.5, correct = true, label = "fresh" },
			{ kind = "review_answer", slot = "1", correct = true, label = "fresh" },
			{ kind = "review_answer", slot = 1, correct = "yes", label = "fresh" },
			{ kind = "review_answer", slot = 1, correct = true, label = "new" },
			{ kind = "review_presented", cardId = string.rep("c", 41) },
			{ kind = "review_presented" },
			{ kind = "rookie_case", case = 4, good = true },
			{ kind = "rookie_case", case = 1, good = "yes" },
			{ kind = "rookie_case", case = 1, good = false },
			{ kind = "listening_post", good = 1 },
			{ kind = "title_awarded", title = "moderator" },
			{ kind = 42 },
			{},
		}
		for i, e in bad do
			if L.record(ledger, R, e) then
				error(`bad event #{i} was accepted`)
			end
		end
		expect(L.record(ledger, R, nil)).toBe(false)
		expect(L.record(ledger, R, "recognized")).toBe(false)
		expect(ledger).toEqual(snapshot)
	end)
end
