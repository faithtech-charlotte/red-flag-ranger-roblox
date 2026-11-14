--[[
	TrailRules: the Trail Walk's server-side rules. Pure logic (no Roblox
	services, no clocks inside: every call takes `now`), so it is unit-tested
	in tests/TrailRules.spec.

	One run per walk, named by a run id. Everything a client sends names the
	run; a stale or cancelled run accepts nothing.

	  Markers    reached in order, by a position the server checked, each
	             once, no sooner than MIN_MARKER_SECONDS after the last one.
	  Sniffs     small bonus spots, each counted once.
	  Squirrels  the server opens a challenge (its own id) with a window.
	             The client says holdStart / holdEnd; the server measures the
	             hold with its own clock. A hold of HOLD_SECONDS or more that
	             ends inside the window is "steady". A hold that ends after
	             the window, or no hold at all, is a "miss". A short hold is
	             not a result: the player can hold again while the window is
	             open. Each challenge gets exactly one result.
	  Result     1-3 trail stars from markers in order, steady holds, time
	             and sniffs. Completing a run twice is refused. The walk
	             never fails: finishing always gives at least one star.
]]

local TrailRules = {}

TrailRules.HOLD_SECONDS = 1.8
TrailRules.WINDOW_SECONDS = 6
TrailRules.MIN_MARKER_SECONDS = 1.0
TrailRules.MARKER_RADIUS = 8
TrailRules.SNIFF_RADIUS = 7

export type Challenge = {
	openedAt: number,
	closesAt: number,
	holdAt: number?,
	result: string?, -- "steady" | "miss"
}

export type Run = {
	id: string,
	startedAt: number,
	markerCount: number,
	sniffCount: number,
	nextMarker: number,
	lastMarkerAt: number,
	sniffed: { [number]: boolean },
	challenges: { [string]: Challenge },
	open: string?, -- the challenge id currently open
	done: boolean,
	cancelled: boolean,
}

local function isNumber(v: any): boolean
	return typeof(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

function TrailRules.newRun(id: string, now: number, markerCount: number, sniffCount: number?): Run
	return {
		id = id,
		startedAt = now,
		markerCount = markerCount,
		sniffCount = sniffCount or 0,
		nextMarker = 1,
		lastMarkerAt = now,
		sniffed = {},
		challenges = {},
		open = nil,
		done = false,
		cancelled = false,
	}
end

-- Is this the live run the request names?
function TrailRules.isLive(run: Run?, runId: any): (boolean, string?)
	if run == nil or run.done or run.cancelled then
		return false, "inactive"
	end
	if runId ~= run.id then
		return false, "stale"
	end
	return true, nil
end

-- distance: the server-measured distance from the player to marker `index`.
function TrailRules.reachMarker(run: Run?, runId: any, index: any, distance: any, now: number): (boolean, string?)
	local live, why = TrailRules.isLive(run, runId)
	if not live then
		return false, why
	end
	local r = run :: Run
	if not isNumber(index) or index % 1 ~= 0 or index < 1 or index > r.markerCount then
		return false, "unknown"
	end
	if index < r.nextMarker then
		return false, "duplicate"
	end
	if index > r.nextMarker then
		return false, "order"
	end
	if not isNumber(distance) or distance > TrailRules.MARKER_RADIUS then
		return false, "far"
	end
	if now - r.lastMarkerAt < TrailRules.MIN_MARKER_SECONDS then
		return false, "fast"
	end
	r.nextMarker += 1
	r.lastMarkerAt = now
	return true, nil
end

function TrailRules.allMarkers(run: Run): boolean
	return run.nextMarker > run.markerCount
end

function TrailRules.sniff(run: Run?, runId: any, index: any): (boolean, string?)
	local live, why = TrailRules.isLive(run, runId)
	if not live then
		return false, why
	end
	local r = run :: Run
	if not isNumber(index) or index % 1 ~= 0 or index < 1 or index > r.sniffCount then
		return false, "unknown"
	end
	if r.sniffed[index] then
		return false, "duplicate"
	end
	r.sniffed[index] = true
	return true, nil
end

function TrailRules.openChallenge(run: Run?, runId: any, challengeId: string, now: number): (boolean, string?)
	local live, why = TrailRules.isLive(run, runId)
	if not live then
		return false, why
	end
	local r = run :: Run
	if r.challenges[challengeId] then
		return false, "duplicate"
	end
	if r.open then
		return false, "busy"
	end
	r.challenges[challengeId] = { openedAt = now, closesAt = now + TrailRules.WINDOW_SECONDS, holdAt = nil, result = nil }
	r.open = challengeId
	return true, nil
end

local function openChallengeFor(run: Run?, runId: any, challengeId: any): (Challenge?, string?)
	local live, why = TrailRules.isLive(run, runId)
	if not live then
		return nil, why
	end
	local r = run :: Run
	local c = typeof(challengeId) == "string" and r.challenges[challengeId] or nil
	if not c then
		return nil, "unknown"
	end
	if c.result ~= nil then
		return nil, "answered"
	end
	return c, nil
end

local function settle(run: Run, challengeId: string, result: string)
	run.challenges[challengeId].result = result
	if run.open == challengeId then
		run.open = nil
	end
end

function TrailRules.holdStart(run: Run?, runId: any, challengeId: any, now: number): (boolean, string?)
	local c, why = openChallengeFor(run, runId, challengeId)
	if not c then
		return false, why
	end
	if now < c.openedAt or now > c.closesAt then
		return false, "closed"
	end
	-- Pressing again while already holding restarts the hold (a dropped
	-- holdEnd must never let an old press count).
	c.holdAt = now
	return true, nil
end

-- Returns (ok, reason?, result?). result is "steady" or "miss" when the
-- challenge is decided, nil for a short hold the player may retry.
function TrailRules.holdEnd(run: Run?, runId: any, challengeId: any, now: number): (boolean, string?, string?)
	local c, why = openChallengeFor(run, runId, challengeId)
	if not c then
		return false, why, nil
	end
	if c.holdAt == nil then
		return false, "not holding", nil
	end
	local held = now - c.holdAt
	c.holdAt = nil
	if now > c.closesAt then
		settle(run :: Run, challengeId, "miss")
		return true, nil, "miss"
	end
	if held >= TrailRules.HOLD_SECONDS then
		settle(run :: Run, challengeId, "steady")
		return true, nil, "steady"
	end
	return true, "short", nil
end

-- The window ran out without a steady hold: a miss. Returns the result it
-- recorded, or nil if the challenge was already decided (or isn't over).
function TrailRules.expireChallenge(run: Run?, challengeId: string, now: number): string?
	if run == nil or run.done or run.cancelled then
		return nil
	end
	local c = run.challenges[challengeId]
	if not c or c.result ~= nil or now < c.closesAt then
		return nil
	end
	settle(run, challengeId, "miss")
	return "miss"
end

export type Facts = {
	markersInOrder: number?,
	markerTotal: number?,
	steady: number?,
	challenges: number?,
	seconds: number?,
	parSeconds: number?,
	sniffs: number?,
	sniffTotal: number?,
}

local function ratio(a: any, b: any, empty: number): number
	if not isNumber(b) or b <= 0 then
		return empty
	end
	if not isNumber(a) then
		return 0
	end
	return math.clamp(a / b, 0, 1)
end

-- 1-3 stars. Always within bounds, whatever the inputs.
function TrailRules.stars(f: Facts): number
	local markers = ratio(f.markersInOrder, f.markerTotal, 1)
	local holds = ratio(f.steady, f.challenges, 1)
	local sniffs = ratio(f.sniffs, f.sniffTotal, 0)
	local time = 0
	local seconds, par = f.seconds, f.parSeconds
	if isNumber(seconds) and isNumber(par) and (par :: number) > 0 then
		local s, p = seconds :: number, par :: number
		time = s <= p and 1 or math.clamp(1 - (s - p) / p, 0, 1)
	end
	local score = markers * (0.6 * holds + 0.3 * time + 0.1 * sniffs)
	if score >= 0.8 then
		return 3
	elseif score >= 0.5 then
		return 2
	end
	return 1
end

export type Summary = { stars: number, seconds: number, steady: number, challenges: number, sniffs: number }

-- Ends the run (once). Requires every marker. An open challenge counts as a miss.
function TrailRules.complete(run: Run?, runId: any, now: number, parSeconds: number?): (boolean, string?, Summary?)
	local live, why = TrailRules.isLive(run, runId)
	if not live then
		return false, why, nil
	end
	local r = run :: Run
	if not TrailRules.allMarkers(r) then
		return false, "markers", nil
	end
	if r.open then
		settle(r, r.open, "miss")
	end
	r.done = true
	local steady, total, sniffs = 0, 0, 0
	for _, c in r.challenges do
		total += 1
		if c.result == "steady" then
			steady += 1
		end
	end
	for _ in r.sniffed do
		sniffs += 1
	end
	local seconds = math.floor((now - r.startedAt) * 10) / 10
	local stars = TrailRules.stars({
		markersInOrder = r.nextMarker - 1,
		markerTotal = r.markerCount,
		steady = steady,
		challenges = total,
		seconds = seconds,
		parSeconds = parSeconds,
		sniffs = sniffs,
		sniffTotal = r.sniffCount,
	})
	return true, nil, { stars = stars, seconds = seconds, steady = steady, challenges = total, sniffs = sniffs }
end

-- Voids the run: nothing it receives afterwards counts.
function TrailRules.cancel(run: Run?)
	if run then
		run.cancelled = true
		run.open = nil
	end
end

--[[
	Which markers trigger a squirrel: `count` distinct markers between 2 and
	total - 2, at least 2 apart, in ascending order. `randInt(a, b)` is
	injected (math.random in the game, a fixed sequence in tests).
]]
function TrailRules.pickChallengeMarkers(total: number, count: number, randInt: (number, number) -> number): { number }
	local lo, hi = 2, total - 2
	local picked: { number } = {}
	if hi < lo then
		return picked
	end
	local function clear(m: number): boolean
		for _, p in picked do
			if math.abs(p - m) < 2 then
				return false
			end
		end
		return true
	end
	local tries = 0
	while #picked < count and tries < 50 do
		tries += 1
		local m = randInt(lo, hi)
		if m >= lo and m <= hi and clear(m) then
			table.insert(picked, m)
		end
	end
	-- Fallback: fill in order if random picks kept colliding.
	local m = lo
	while #picked < count and m <= hi do
		if clear(m) then
			table.insert(picked, m)
		end
		m += 1
	end
	table.sort(picked)
	return picked
end

return TrailRules
