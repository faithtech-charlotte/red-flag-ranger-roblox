--[[
	GroomRules: the Wash & Groom (spa) server-side rules. Pure logic (every
	call takes `now`), unit-tested in tests/GroomRules.spec.

	One run per spa visit, named by a run id. The four steps (brush, wash,
	rinse, dry) come in order. Each step reports its 25 / 50 / 75 / 100 %
	milestones, in order, each once, and no sooner than
	MIN_MILESTONE_SECONDS after the previous one. Nothing counts until the
	server has marked the run ready (the dog is in the tub).

	Shine (1-3 stars): the server-measured time per step sets the base. The
	client's own estimate of how evenly each step was done ("evenness",
	clamped to 0-1) can move it by at most one star. The shine is cosmetic,
	so gestures are not reconstructed on the server.
]]

local GroomRules = {}

GroomRules.STEPS = { "brush", "wash", "rinse", "dry" }
GroomRules.MILESTONE = 25 -- percent per report
GroomRules.MIN_MILESTONE_SECONDS = 0.5
-- Average seconds per step above which the base drops to one star (the
-- player wandered off mid-step or gave up).
GroomRules.SLOW_STEP_SECONDS = 12
GroomRules.EVEN_GOOD = 0.7
GroomRules.EVEN_POOR = 0.3

export type Run = {
	id: string,
	ready: boolean,
	step: number, -- the step being worked on (1..4; 5 once all are done)
	milestone: number, -- last accepted percent within the current step
	lastAt: number,
	stepStartedAt: number,
	stepSeconds: { number },
	evenness: { number },
	done: boolean,
	cancelled: boolean,
}

local function isNumber(v: any): boolean
	return typeof(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

function GroomRules.newRun(id: string, now: number): Run
	return {
		id = id,
		ready = false,
		step = 1,
		milestone = 0,
		lastAt = now,
		stepStartedAt = now,
		stepSeconds = {},
		evenness = {},
		done = false,
		cancelled = false,
	}
end

-- The dog is in the tub: steps may start now.
function GroomRules.setReady(run: Run, now: number)
	run.ready = true
	run.lastAt = now
	run.stepStartedAt = now
end

-- Any value to 0..1. A missing or broken estimate is neutral (0.5).
function GroomRules.clampEvenness(v: any): number
	if not isNumber(v) then
		return 0.5
	end
	return math.clamp(v, 0, 1)
end

function GroomRules.finished(run: Run): boolean
	return run.step > #GroomRules.STEPS
end

--[[
	A milestone report. Returns (ok, reason?, event?).
	reason: "inactive" | "stale" | "not ready" | "order" | "duplicate" |
	        "skip" | "fast"
	event:  "milestone" | "step" (a step reached 100 %) | "finished"
]]
function GroomRules.report(run: Run?, runId: any, step: any, pct: any, evenness: any, now: number): (boolean, string?, string?)
	if run == nil or run.done or run.cancelled then
		return false, "inactive", nil
	end
	if runId ~= run.id then
		return false, "stale", nil
	end
	if not run.ready then
		return false, "not ready", nil
	end
	if not isNumber(step) or not isNumber(pct) then
		return false, "order", nil
	end
	if step < run.step or (step == run.step and pct <= run.milestone) then
		return false, "duplicate", nil
	end
	if step > run.step then
		return false, "order", nil
	end
	if pct ~= run.milestone + GroomRules.MILESTONE then
		return false, "skip", nil
	end
	if now - run.lastAt < GroomRules.MIN_MILESTONE_SECONDS then
		return false, "fast", nil
	end
	run.milestone = pct
	run.lastAt = now
	if pct < 100 then
		return true, nil, "milestone"
	end
	run.stepSeconds[run.step] = now - run.stepStartedAt
	run.evenness[run.step] = GroomRules.clampEvenness(evenness)
	run.step += 1
	run.milestone = 0
	run.stepStartedAt = now
	if GroomRules.finished(run) then
		return true, nil, "finished"
	end
	return true, nil, "step"
end

-- Base stars from time: 2 for a normal pace, 1 for a very slow one.
function GroomRules.baseStars(stepSeconds: { number }): number
	local total, n = 0, 0
	for _, s in stepSeconds do
		if isNumber(s) then
			total += s
			n += 1
		end
	end
	if n == 0 then
		return 1
	end
	return total / n <= GroomRules.SLOW_STEP_SECONDS and 2 or 1
end

-- 1-3 stars: the time base, moved by at most one star by evenness.
function GroomRules.shine(stepSeconds: { number }, evenness: { any }): number
	local base = GroomRules.baseStars(stepSeconds)
	local total, n = 0, 0
	for _, e in evenness do
		total += GroomRules.clampEvenness(e)
		n += 1
	end
	local even = n > 0 and total / n or 0.5
	local shift = 0
	if even >= GroomRules.EVEN_GOOD then
		shift = 1
	elseif even <= GroomRules.EVEN_POOR then
		shift = -1
	end
	return math.clamp(base + shift, 1, 3)
end

-- Ends the run once all steps are done. A second call is refused.
function GroomRules.complete(run: Run?, runId: any): (boolean, string?, number?)
	if run == nil or run.done or run.cancelled then
		return false, "inactive", nil
	end
	if runId ~= run.id then
		return false, "stale", nil
	end
	if not GroomRules.finished(run) then
		return false, "steps", nil
	end
	run.done = true
	return true, nil, GroomRules.shine(run.stepSeconds, run.evenness)
end

function GroomRules.cancel(run: Run?)
	if run then
		run.cancelled = true
	end
end

return GroomRules
