local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local S = require(Server.Logic.EncounterScheduler)

return function(t)
	local expect = t.expect

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

	local function run(state, events)
		for _, e in events do
			state = S.apply(state, e)
		end
		return state
	end

	local ACT = { kind = "activity_completed" }
	local ONBOARD = { kind = "onboarding_done" }
	local DASH = { kind = "dash_introduced" }

	local function secs(n)
		return { kind = "active_seconds", seconds = n }
	end

	local function play(state, beat, ending)
		return run(state, {
			{ kind = "invited", beat = beat },
			{ kind = "accepted", beat = beat },
			{ kind = ending or "resolved", beat = beat },
		})
	end

	-- State where e2 has just become eligible (3 activities done).
	local function atE2()
		local s = run(S.defaultState(), { ONBOARD, ACT })
		s = play(s, "e1")
		s = run(s, { ACT })
		s = play(s, "green_riley")
		return run(s, { ACT })
	end

	local function free(s)
		return S.decide(s, { busy = false })
	end

	t.test("scheduler: default state", function()
		local s = S.defaultState()
		expect(s.version).toBe(1)
		expect(s.onboarded).toBe(false)
		expect(s.completedActivities).toBe(0)
		expect(s.remainingGap).toBe(0)
		expect(s.current).toBe(nil)
		expect(S.status(s, "e1")).toBe("not_started")
		expect(#S.BEATS).toBe(6)
		expect(S.MIN_GAP_SECONDS).toBe(90)
		expect(free(s)).toBe(nil)
	end)

	t.test("scheduler: e1 only after an activity completed after onboarding", function()
		local s = run(S.defaultState(), { ACT, ACT })
		expect(S.status(s, "e1")).toBe("not_started")
		s = run(s, { ONBOARD })
		expect(S.status(s, "e1")).toBe("not_started")
		expect(free(s)).toBe(nil)
		s = run(s, { ACT })
		expect(S.status(s, "e1")).toBe("eligible")
		expect(free(s)).toEqual({ kind = "campaign", beat = "e1" })
	end)

	t.test("scheduler: onboarding twice does not move the onboarding mark", function()
		local s = run(S.defaultState(), { ONBOARD, ACT, ONBOARD })
		expect(S.status(s, "e1")).toBe("eligible")
	end)

	t.test("scheduler: green_riley comes between e1 and e2", function()
		local s = run(S.defaultState(), { ONBOARD, ACT })
		s = play(s, "e1")
		expect(S.status(s, "green_riley")).toBe("not_started")
		s = run(s, { ACT })
		expect(S.status(s, "green_riley")).toBe("eligible")
		expect(S.status(s, "e2")).toBe("not_started")
		s = run(s, { ACT, ACT }) -- extra activities don't skip green_riley
		expect(S.status(s, "e2")).toBe("not_started")
		s = play(s, "green_riley")
		expect(S.status(s, "e2")).toBe("not_started")
		s = run(s, { ACT })
		expect(S.status(s, "e2")).toBe("eligible")
	end)

	t.test("scheduler: e2-e4 each need a new activity after the previous resolves", function()
		local s = atE2()
		for _, pair in { { "e2", "e3" }, { "e3", "e4" } } do
			local prev, nextBeat = pair[1], pair[2]
			expect(S.status(s, prev)).toBe("eligible")
			s = play(s, prev)
			expect(S.status(s, prev)).toBe("resolved")
			expect(S.status(s, nextBeat)).toBe("not_started")
			s = run(s, { ACT })
			expect(S.status(s, nextBeat)).toBe("eligible")
		end
	end)

	t.test("scheduler: skip counts as done for the next beat (this scene only)", function()
		local s = run(S.defaultState(), { ONBOARD, ACT })
		s = play(s, "e1", "skip")
		expect(S.status(s, "e1")).toBe("skipped")
		expect(s.current).toBe(nil)
		s = run(s, { ACT })
		expect(S.status(s, "green_riley")).toBe("eligible")
		expect(S.status(s, "e2")).toBe("not_started")
	end)

	t.test("scheduler: skip from the invitation, before accepting", function()
		local s = run(S.defaultState(), { ONBOARD, ACT, { kind = "invited", beat = "e1" }, { kind = "skip", beat = "e1" } })
		expect(S.status(s, "e1")).toBe("skipped")
	end)

	t.test("scheduler: later defers until another activity, no nagging in between", function()
		local s = run(S.defaultState(), { ONBOARD, ACT, { kind = "invited", beat = "e1" }, { kind = "later", beat = "e1" } })
		expect(S.status(s, "e1")).toBe("deferred")
		expect(s.current).toBe(nil)
		s = run(s, { secs(1000) })
		expect(s.remainingGap).toBe(0)
		expect(free(s)).toBe(nil)
		-- An invitation for a deferred beat is refused in the same interval.
		s = run(s, { { kind = "invited", beat = "e1" } })
		expect(S.status(s, "e1")).toBe("deferred")
		s = run(s, { ACT })
		expect(S.status(s, "e1")).toBe("eligible")
		expect(free(s)).toEqual({ kind = "campaign", beat = "e1" })
	end)

	t.test("scheduler: later after accepting also defers", function()
		local s = run(S.defaultState(), { ONBOARD, ACT })
		s = run(s, { { kind = "invited", beat = "e1" }, { kind = "accepted", beat = "e1" }, { kind = "later", beat = "e1" } })
		expect(S.status(s, "e1")).toBe("deferred")
		expect(s.deferredAtActivity.e1).toBe(1)
	end)

	t.test("scheduler: blocking Sparkz in e2 skips e3/e4 and keeps the show", function()
		local s = atE2()
		s = run(s, { { kind = "invited", beat = "e2" }, { kind = "accepted", beat = "e2" }, { kind = "blocked", npc = "sparkz" } })
		expect(S.status(s, "e2")).toBe("resolved")
		expect(S.status(s, "e3")).toBe("skipped_by_block")
		expect(S.status(s, "e4")).toBe("skipped_by_block")
		expect(s.current).toBe(nil)
		expect(s.sparkzBlocked).toBe(true)
		expect(S.showEligible(s)).toBe(false)
		s = run(s, { ACT })
		expect(S.showEligible(s)).toBe(true)
		s = run(s, { ACT, ACT, secs(1000) })
		expect(free(s)).toBe(nil)
	end)

	t.test("scheduler: blocking another npc does nothing", function()
		local s = atE2()
		local after = run(s, { { kind = "blocked", npc = "riley" } })
		expect(after).toEqual(s)
	end)

	t.test("scheduler: unblock neither resets nor restarts", function()
		local s = atE2()
		s = run(s, { { kind = "invited", beat = "e2" }, { kind = "accepted", beat = "e2" }, { kind = "blocked", npc = "sparkz" } })
		s = run(s, { { kind = "unblocked", npc = "sparkz" }, ACT, ACT, secs(500) })
		expect(s.sparkzBlocked).toBe(false)
		expect(S.status(s, "e2")).toBe("resolved")
		expect(S.status(s, "e3")).toBe("skipped_by_block")
		expect(S.status(s, "e4")).toBe("skipped_by_block")
		expect(free(s)).toBe(nil)
		-- Explicit attempts to reopen a blocked beat are refused too.
		s = run(s, { { kind = "accepted", beat = "e3" }, { kind = "invited", beat = "e3" } })
		expect(S.status(s, "e3")).toBe("skipped_by_block")
	end)

	t.test("scheduler: e5 waits for e4 done, Dash intro and the show", function()
		local function e4DoneByBlock()
			local s = run(S.defaultState(), { ONBOARD, ACT })
			return run(s, { { kind = "invited", beat = "e1" }, { kind = "accepted", beat = "e1" }, { kind = "blocked", npc = "sparkz" } })
		end
		local orders = {
			{ DASH, ACT, ACT, ACT },
			{ ACT, ACT, ACT, DASH },
			{ ACT, DASH, ACT, ACT },
		}
		for _, order in orders do
			local s = e4DoneByBlock()
			expect(S.status(s, "e4")).toBe("skipped_by_block")
			for i, e in order do
				s = S.apply(s, e)
				local expected = if i == #order then "eligible" else "not_started"
				expect(S.status(s, "e5")).toBe(expected)
			end
		end
	end)

	t.test("scheduler: e5 needs e4 even with Dash and the show", function()
		local s = atE2()
		s = run(s, { DASH, ACT, ACT })
		expect(S.showEligible(s)).toBe(true)
		expect(S.status(s, "e5")).toBe("not_started")
	end)

	t.test("scheduler: show eligibility is independent of every beat", function()
		local s = run(S.defaultState(), { ACT, ACT, ACT })
		expect(S.showEligible(s)).toBe(false)
		s = run(s, { ACT })
		expect(S.showEligible(s)).toBe(true)
		expect(s.onboarded).toBe(false)
	end)

	t.test("scheduler: grinding 10 activities gives exactly one invitation", function()
		local s = run(S.defaultState(), { ONBOARD })
		for _ = 1, 10 do
			s = S.apply(s, ACT)
		end
		local d = free(s)
		expect(d).toEqual({ kind = "campaign", beat = "e1" })
		s = S.apply(s, { kind = "invited", beat = d.beat })
		expect(free(s)).toBe(nil)
		expect(S.decide(s, { busy = false, ambient = "maya_wave" })).toBe(nil)
		-- Declining and grinding more cannot queue a burst: the gap holds.
		s = run(s, { { kind = "later", beat = "e1" }, ACT, ACT, ACT })
		expect(S.status(s, "e1")).toBe("eligible")
		expect(s.remainingGap).toBe(90)
		expect(free(s)).toBe(nil)
		s = run(s, { secs(89) })
		expect(free(s)).toBe(nil)
		s = run(s, { secs(1) })
		expect(free(s)).toEqual({ kind = "campaign", beat = "e1" })
	end)

	t.test("scheduler: active seconds floor at 0 and ignore bad values", function()
		local s = run(S.defaultState(), { ONBOARD, ACT, { kind = "invited", beat = "e1" } })
		expect(s.remainingGap).toBe(90)
		for _, bad in { -10, 0 / 0, math.huge, "30", nil } do
			s = S.apply(s, { kind = "active_seconds", seconds = bad })
			expect(s.remainingGap).toBe(90)
		end
		s = run(s, { secs(30) })
		expect(s.remainingGap).toBe(60)
		s = run(s, { secs(500) })
		expect(s.remainingGap).toBe(0)
	end)

	t.test("scheduler: ambient invitations share the gap", function()
		local s = run(S.defaultState(), { { kind = "ambient_invited" } })
		expect(s.remainingGap).toBe(90)
		expect(S.decide(s, { busy = false, ambient = "maya_wave" })).toBe(nil)
		s = run(s, { secs(90) })
		expect(S.decide(s, { busy = false, ambient = "maya_wave" })).toEqual({ kind = "ambient", id = "maya_wave" })
	end)

	t.test("scheduler: busy suppresses unsolicited invitations but not help or replay", function()
		local s = run(S.defaultState(), { ONBOARD, ACT })
		expect(S.decide(s, { busy = true })).toBe(nil)
		expect(S.decide(s, { busy = true, ambient = "maya_wave" })).toBe(nil)
		expect(S.decide(s, { busy = true, recovery = "e2" })).toBe(nil)
		expect(S.decide(s, { busy = true, help = true })).toEqual({ kind = "help" })
		expect(S.decide(s, { busy = true, replay = "e2" })).toEqual({ kind = "replay", beat = "e2" })
		expect(S.decide(s, { busy = true, recovery = "e2", recoveryRequested = true })).toEqual({ kind = "recovery", beat = "e2" })
		expect(S.decide(s, { busy = false })).toEqual({ kind = "campaign", beat = "e1" })
	end)

	t.test("scheduler: an open scene blocks any unsolicited invitation", function()
		local s = run(S.defaultState(), { ONBOARD, ACT, { kind = "accepted", beat = "e1" }, secs(1000) })
		expect(S.status(s, "e1")).toBe("active")
		expect(S.decide(s, { busy = false, ambient = "maya_wave" })).toBe(nil)
		expect(S.decide(s, { busy = false, help = true })).toEqual({ kind = "help" })
	end)

	t.test("scheduler: priority help > replay > recovery > campaign > ambient", function()
		local s = run(S.defaultState(), { ONBOARD, ACT })
		local cases = {
			{ ctx = { help = true, replay = "e2", recovery = "e3", ambient = "a" }, want = { kind = "help" } },
			{ ctx = { replay = "e2", recovery = "e3", ambient = "a" }, want = { kind = "replay", beat = "e2" } },
			{ ctx = { recovery = "e3", ambient = "a" }, want = { kind = "recovery", beat = "e3" } },
			{ ctx = { ambient = "a" }, want = { kind = "campaign", beat = "e1" } },
		}
		for _, c in cases do
			c.ctx.busy = false
			expect(S.decide(s, c.ctx)).toEqual(c.want)
		end
		local noBeat = run(S.defaultState(), { ONBOARD })
		expect(S.decide(noBeat, { busy = false, ambient = "a" })).toEqual({ kind = "ambient", id = "a" })
		expect(S.decide(noBeat, { busy = false })).toBe(nil)
		expect(S.decide(noBeat, nil)).toBe(nil)
	end)

	t.test("scheduler: interrupted returns the beat to eligible, pacing unchanged", function()
		local s = run(S.defaultState(), { ONBOARD, ACT, { kind = "invited", beat = "e1" }, { kind = "accepted", beat = "e1" }, secs(30) })
		local before = deepCopy(s)
		s = run(s, { { kind = "interrupted", beat = "e1" } })
		expect(S.status(s, "e1")).toBe("eligible")
		expect(s.current).toBe(nil)
		expect(s.remainingGap).toBe(before.remainingGap)
		expect(s.completedActivities).toBe(before.completedActivities)
		expect(s.resolvedAtActivity.e1).toBe(nil)
	end)

	t.test("scheduler: events for a beat that isn't current are ignored", function()
		local s = atE2()
		for _, kind in { "later", "skip", "resolved", "interrupted" } do
			expect(S.apply(s, { kind = kind, beat = "e2" })).toEqual(s)
		end
		expect(S.apply(s, { kind = "invited", beat = "e4" })).toEqual(s)
		expect(S.apply(s, { kind = "invited", beat = "nope" })).toEqual(s)
		local opened = run(s, { { kind = "invited", beat = "e2" } })
		expect(S.apply(opened, { kind = "accepted", beat = "e3" })).toEqual(opened)
	end)

	t.test("scheduler: unknown or malformed events leave state unchanged", function()
		local s = atE2()
		expect(S.apply(s, { kind = "explode" })).toEqual(s)
		expect(S.apply(s, nil)).toEqual(s)
		expect(S.apply(s, { kind = 5 })).toEqual(s)
		expect(S.apply(s, "activity_completed")).toEqual(s)
	end)

	t.test("scheduler: deterministic for the same ordered events", function()
		local events = {
			ONBOARD, ACT, secs(12), { kind = "invited", beat = "e1" }, { kind = "later", beat = "e1" },
			ACT, secs(100), { kind = "invited", beat = "e1" }, { kind = "accepted", beat = "e1" },
			{ kind = "resolved", beat = "e1" }, ACT, DASH, { kind = "invited", beat = "green_riley" },
			{ kind = "skip", beat = "green_riley" }, ACT, secs(45), ACT,
		}
		local a = run(S.defaultState(), events)
		local b = run(S.defaultState(), events)
		expect(a).toEqual(b)
		expect(S.decide(a, { busy = false, ambient = "x" })).toEqual(S.decide(b, { busy = false, ambient = "x" }))
	end)

	t.test("scheduler: apply never mutates its input", function()
		local s = run(atE2(), { { kind = "invited", beat = "e2" } })
		local snapshot = deepCopy(s)
		local events = {
			ONBOARD, ACT, secs(10), { kind = "invited", beat = "e2" }, { kind = "accepted", beat = "e2" },
			{ kind = "later", beat = "e2" }, { kind = "skip", beat = "e2" }, { kind = "resolved", beat = "e2" },
			{ kind = "blocked", npc = "sparkz" }, { kind = "unblocked", npc = "sparkz" }, DASH,
			{ kind = "interrupted", beat = "e2" }, { kind = "ambient_invited" }, { kind = "unknown" },
		}
		for _, e in events do
			S.apply(s, e)
			expect(s).toEqual(snapshot)
		end
		S.decide(s, { busy = false, help = true })
		expect(s).toEqual(snapshot)
	end)

	t.test("scheduler: sanitize repairs bad saved data", function()
		expect(S.sanitize(nil)).toEqual(S.defaultState())
		expect(S.sanitize("junk")).toEqual(S.defaultState())
		local s = S.sanitize({
			version = 7,
			onboarded = "yes",
			completedActivities = -3,
			beats = { e1 = "resolved", bogus = "eligible", e2 = "weird", e3 = "active" },
			resolvedAtActivity = { e1 = 99, bogus = 1 },
			deferredAtActivity = "x",
			remainingGap = 5000,
			dashIntroduced = 1,
			current = "e3",
			extra = true,
		})
		expect(s.version).toBe(1)
		expect(s.onboarded).toBe(false)
		expect(s.completedActivities).toBe(0)
		expect(s.beats.bogus).toBe(nil)
		expect(s.beats.e2).toBe(nil)
		expect(s.beats.e1).toBe("resolved")
		expect(s.resolvedAtActivity.e1).toBe(0)
		expect(s.resolvedAtActivity.bogus).toBe(nil)
		expect(s.beats.e3).toBe("eligible")
		expect(s.current).toBe(nil)
		expect(s.remainingGap).toBe(90)
		expect(s.dashIntroduced).toBe(false)
		expect(s.extra).toBe(nil)
		expect(S.sanitize({ remainingGap = -5 }).remainingGap).toBe(0)
		expect(S.sanitize({ completedActivities = 2.5 }).completedActivities).toBe(0)
	end)

	t.test("scheduler: sanitize keeps a valid state and closes stale scenes", function()
		local s = run(S.defaultState(), {
			ONBOARD, ACT, { kind = "invited", beat = "e1" }, { kind = "resolved", beat = "e1" }, ACT,
			{ kind = "invited", beat = "green_riley" }, { kind = "later", beat = "green_riley" }, secs(20),
		})
		expect(S.sanitize(s)).toEqual(s)
		local open = run(s, { ACT, secs(100), { kind = "invited", beat = "green_riley" } })
		local loaded = S.sanitize(open)
		expect(S.status(loaded, "green_riley")).toBe("eligible")
		expect(loaded.current).toBe(nil)
		expect(loaded.remainingGap).toBe(open.remainingGap)
		-- A blocked flag with unmarked Sparkz beats gets them marked.
		local blocked = S.sanitize({ sparkzBlocked = true })
		for _, beat in S.SPARKZ_BEATS do
			expect(S.status(blocked, beat)).toBe("skipped_by_block")
		end
		expect(S.status(blocked, "green_riley")).toBe("not_started")
	end)
end
