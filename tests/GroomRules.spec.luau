local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local GroomRules = require(Server.Logic.GroomRules)

return function(t)
	local expect = t.expect
	local GAP = GroomRules.MIN_MILESTONE_SECONDS

	-- A ready run (ready at t = 0) and a clock that steps safely.
	local function readyRun()
		local run = GroomRules.newRun("g1", 0)
		GroomRules.setReady(run, 0)
		return run
	end

	-- Reports every milestone of every step; returns the final time.
	local function finishAll(run, secondsPerMilestone: number, evenness: number?): number
		local now = 0
		for step = 1, #GroomRules.STEPS do
			for pct = 25, 100, 25 do
				now += secondsPerMilestone
				local ok, why = GroomRules.report(run, "g1", step, pct, evenness, now)
				assert(ok, `setup step {step} {pct}: {why}`)
			end
		end
		return now
	end

	t.test("groom: a step before the dog is in the tub is rejected", function()
		local run = GroomRules.newRun("g1", 0)
		local ok, why = GroomRules.report(run, "g1", 1, 25, 0.5, 5)
		expect(ok).toBe(false)
		expect(why).toBe("not ready")
		GroomRules.setReady(run, 5)
		expect((GroomRules.report(run, "g1", 1, 25, 0.5, 5 + GAP))).toBe(true)
	end)

	t.test("groom: a stale run id is rejected", function()
		local run = readyRun()
		local ok, why = GroomRules.report(run, "older", 1, 25, 0.5, 5)
		expect(ok).toBe(false)
		expect(why).toBe("stale")
		expect(run.milestone).toBe(0)
	end)

	t.test("groom: milestones come in order, each once", function()
		local run = readyRun()
		expect((GroomRules.report(run, "g1", 1, 25, nil, 1))).toBe(true)
		local dup, why = GroomRules.report(run, "g1", 1, 25, nil, 2)
		expect(dup).toBe(false)
		expect(why).toBe("duplicate")
		local skip, why2 = GroomRules.report(run, "g1", 1, 75, nil, 3)
		expect(skip).toBe(false)
		expect(why2).toBe("skip")
		local early, why3 = GroomRules.report(run, "g1", 2, 25, nil, 4)
		expect(early).toBe(false)
		expect(why3).toBe("order") -- step 2 before step 1 is done
		expect((GroomRules.report(run, "g1", 1, 50, nil, 5))).toBe(true)
	end)

	t.test("groom: a finished step can't be reported again", function()
		local run = readyRun()
		for i, pct in { 25, 50, 75, 100 } do
			GroomRules.report(run, "g1", 1, pct, 0.8, i)
		end
		expect(run.step).toBe(2)
		local ok, why = GroomRules.report(run, "g1", 1, 100, 0.8, 10)
		expect(ok).toBe(false)
		expect(why).toBe("duplicate")
	end)

	t.test("groom: a too-fast milestone is rejected", function()
		local run = readyRun()
		local ok, why = GroomRules.report(run, "g1", 1, 25, nil, GAP * 0.5)
		expect(ok).toBe(false)
		expect(why).toBe("fast")
		expect((GroomRules.report(run, "g1", 1, 25, nil, GAP))).toBe(true)
		local ok2, why2 = GroomRules.report(run, "g1", 1, 50, nil, GAP + 0.1)
		expect(ok2).toBe(false)
		expect(why2).toBe("fast")
	end)

	t.test("groom: the last milestone finishes the run, then events stop", function()
		local run = readyRun()
		local _, _, event = GroomRules.report(run, "g1", 1, 25, nil, 1)
		expect(event).toBe("milestone")
		local _, _, stepEvent = GroomRules.report(run, "g1", 1, 50, nil, 2)
		expect(stepEvent).toBe("milestone")
		GroomRules.report(run, "g1", 1, 75, nil, 3)
		local _, _, done1 = GroomRules.report(run, "g1", 1, 100, nil, 4)
		expect(done1).toBe("step")
		local fresh = readyRun()
		finishAll(fresh, 1, 0.5)
		expect(GroomRules.finished(fresh)).toBe(true)
		expect((GroomRules.report(fresh, "g1", 4, 100, nil, 100))).toBe(false)
	end)

	t.test("groom: a second completion of the same run is rejected", function()
		local run = readyRun()
		local unfinished = GroomRules.complete(run, "g1")
		expect(unfinished).toBe(false)
		finishAll(run, 1, 0.5)
		local ok, _, stars = GroomRules.complete(run, "g1")
		expect(ok).toBe(true)
		expect(stars ~= nil and stars >= 1 and stars <= 3).toBe(true)
		local again, why = GroomRules.complete(run, "g1")
		expect(again).toBe(false)
		expect(why).toBe("inactive")
	end)

	t.test("groom: nothing counts after cancel", function()
		local run = readyRun()
		GroomRules.report(run, "g1", 1, 25, nil, 1)
		GroomRules.cancel(run)
		local ok, why = GroomRules.report(run, "g1", 1, 50, nil, 5)
		expect(ok).toBe(false)
		expect(why).toBe("inactive")
		local fin = readyRun()
		finishAll(fin, 1, 0.5)
		GroomRules.cancel(fin)
		expect((GroomRules.complete(fin, "g1"))).toBe(false)
	end)

	t.test("groom: evenness is clamped to 0-1", function()
		expect(GroomRules.clampEvenness(-3)).toBe(0)
		expect(GroomRules.clampEvenness(7)).toBe(1)
		expect(GroomRules.clampEvenness(0.25)).toBe(0.25)
		expect(GroomRules.clampEvenness(0 / 0)).toBe(0.5)
		expect(GroomRules.clampEvenness("lots")).toBe(0.5)
		expect(GroomRules.clampEvenness(nil)).toBe(0.5)
		expect(GroomRules.clampEvenness(math.huge)).toBe(0.5)
		local run = readyRun()
		finishAll(run, 1, 99)
		for _, e in run.evenness do
			expect(e).toBe(1)
		end
	end)

	t.test("groom: evenness moves the shine by at most one star", function()
		local normal = { 3, 3, 3, 3 }
		local slow = { 30, 30, 30, 30 }
		local base = GroomRules.baseStars(normal)
		expect(base).toBe(2)
		expect(GroomRules.baseStars(slow)).toBe(1)
		for _, e in { -100, 0, 0.3, 0.5, 0.7, 1, 100, 0 / 0 } do
			local s = GroomRules.shine(normal, { e, e, e, e })
			expect(math.abs(s - base) <= 1).toBe(true)
			expect(s >= 1 and s <= 3).toBe(true)
			local s2 = GroomRules.shine(slow, { e, e, e, e })
			expect(s2 >= 1 and s2 <= 2).toBe(true)
		end
		expect(GroomRules.shine(normal, { 1, 1, 1, 1 })).toBe(3)
		expect(GroomRules.shine(normal, { 0, 0, 0, 0 })).toBe(1)
		expect(GroomRules.shine(normal, { 0.5, 0.5, 0.5, 0.5 })).toBe(2)
	end)

	t.test("groom: server-measured step time sets the base", function()
		local quick = readyRun()
		finishAll(quick, 1, 0.5) -- 4 s per step
		expect(quick.stepSeconds[1]).toBe(4)
		local _, _, stars = GroomRules.complete(quick, "g1")
		expect(stars).toBe(2)
		local dawdle = readyRun()
		finishAll(dawdle, 5, 0.5) -- 20 s per step
		local _, _, slowStars = GroomRules.complete(dawdle, "g1")
		expect(slowStars).toBe(1)
	end)
end
