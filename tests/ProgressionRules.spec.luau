--[[
	Integration of ProgressionRules' translation with the real scheduler
	and ledger: the events ProgressionService sends must actually change
	state (a field-name mismatch once made them silently ignored).
]]

local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local Rules = require(Server.Logic.ProgressionRules)
local S = require(Server.Logic.EncounterScheduler)
local L = require(Server.Logic.LearningProgress)
local ScoreRules = require(Server.Content.ScoreRules)

local CONCERNING = { e2_school = true }
local function isConcerning(f: string): boolean
	return CONCERNING[f] == true
end

return function(t)
	local expect = t.expect

	t.test("progression: activity and active-time events change scheduler state", function()
		local s = S.apply(S.defaultState(), { kind = "onboarding_done" })
		s = S.apply(s, Rules.ACTIVITY_COMPLETED)
		expect(s.completedActivities).toBe(1)
		expect(S.status(s, "e1")).toBe("eligible")
		s = S.apply(s, { kind = "invited", beat = "e1" })
		s = S.apply(s, { kind = "accepted", beat = "e1" })
		local _, sched = Rules.exitEvents({ kind = "completed", facts = {} }, "e1", false, isConcerning)
		for _, e in sched do
			s = S.apply(s, e)
		end
		expect(S.status(s, "e1")).toBe("resolved")
		expect(s.remainingGap).toBe(90)
		s = S.apply(s, Rules.activeSeconds(30))
		expect(s.remainingGap).toBe(60)
	end)

	t.test("progression: leaving after a concerning fact earns both Respond slots", function()
		local ledger = L.default()
		for _, e in Rules.factEvents("e2", false, { "e2_school" }) do
			L.record(ledger, ScoreRules, e)
		end
		local led = Rules.exitEvents({ kind = "walk_away", facts = { "e2_school" } }, "e2", false, isConcerning)
		for _, e in led do
			L.record(ledger, ScoreRules, e)
		end
		expect(L.categories(ledger, ScoreRules).respond).toBe(2)
	end)

	t.test("progression: a benign or premature leave earns nothing", function()
		local led = Rules.exitEvents({ kind = "walk_away", facts = { "e2_hello" } }, "e2", false, isConcerning)
		expect(#led).toBe(0)
		led = Rules.exitEvents({ kind = "walk_away", facts = {} }, "e2", false, isConcerning)
		expect(#led).toBe(0)
	end)

	t.test("progression: interruptions return the beat; roleplays never move the campaign", function()
		local _, sched = Rules.exitEvents({ kind = "respawn", facts = {} }, "e2", false, isConcerning)
		expect(sched[1].kind).toBe("interrupted")
		_, sched = Rules.exitEvents({ kind = "completed", facts = {} }, "e2", true, isConcerning)
		expect(#sched).toBe(0)
	end)

	t.test("progression: respawn or disconnect right after the request credits like Leave", function()
		for _, kind in { "respawn", "disconnect", "replaced" } do
			local led, sched = Rules.exitEvents({ kind = kind, facts = { "e2_school" } }, "e2", false, isConcerning)
			expect(#led).toBe(1)
			expect(led[1].kind).toBe("left_after_request")
			expect(sched[1].kind).toBe("interrupted") -- the beat still comes back
		end
		local led = Rules.exitEvents({ kind = "respawn", facts = { "e2_hello" } }, "e2", false, isConcerning)
		expect(#led).toBe(0)
	end)

	t.test("progression: leaving from the recovery card earns no Respond", function()
		local led, sched = Rules.exitEvents({ kind = "walk_away", facts = { "e2_school" }, atRecovery = true }, "e2", false, isConcerning)
		expect(#led).toBe(0)
		expect(sched[1].kind).toBe("resolved")
	end)

	t.test("progression: blocking Sparkz through the rule event skips the remaining beats", function()
		local s = S.apply(S.defaultState(), { kind = "onboarding_done" })
		s = S.apply(s, Rules.blocked("sparkz"))
		expect(s.sparkzBlocked).toBe(true)
		expect(S.status(s, "e3")).toBe("skipped_by_block")
	end)
end
