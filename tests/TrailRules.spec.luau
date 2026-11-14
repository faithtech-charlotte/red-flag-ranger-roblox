local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local TrailRules = require(Server.Logic.TrailRules)

return function(t)
	local expect = t.expect
	local HOLD = TrailRules.HOLD_SECONDS
	local WINDOW = TrailRules.WINDOW_SECONDS
	local GAP = TrailRules.MIN_MARKER_SECONDS

	-- A run with every marker reached on time, starting at t = 0.
	local function walked(markers: number)
		local run = TrailRules.newRun("r1", 0, markers, 3)
		for i = 1, markers do
			assert(TrailRules.reachMarker(run, "r1", i, 1, i * GAP * 2), "setup marker")
		end
		return run
	end

	t.test("trail: a stale run id is rejected", function()
		local run = TrailRules.newRun("r1", 0, 10, 3)
		local ok, why = TrailRules.reachMarker(run, "old", 1, 1, 5)
		expect(ok).toBe(false)
		expect(why).toBe("stale")
		expect(run.nextMarker).toBe(1)
		expect((TrailRules.holdStart(run, "old", "c1", 1))).toBe(false)
	end)

	t.test("trail: markers count in order, each once", function()
		local run = TrailRules.newRun("r1", 0, 10, 3)
		local ok, why = TrailRules.reachMarker(run, "r1", 2, 1, 5)
		expect(ok).toBe(false)
		expect(why).toBe("order")
		expect((TrailRules.reachMarker(run, "r1", 1, 1, 5))).toBe(true)
		local again, why2 = TrailRules.reachMarker(run, "r1", 1, 1, 10)
		expect(again).toBe(false)
		expect(why2).toBe("duplicate")
		expect(run.nextMarker).toBe(2)
	end)

	t.test("trail: a marker reached too fast or from too far is rejected", function()
		local run = TrailRules.newRun("r1", 0, 10, 3)
		local ok, why = TrailRules.reachMarker(run, "r1", 1, 1, GAP * 0.5)
		expect(ok).toBe(false)
		expect(why).toBe("fast")
		local ok2, why2 = TrailRules.reachMarker(run, "r1", 1, TrailRules.MARKER_RADIUS + 1, 5)
		expect(ok2).toBe(false)
		expect(why2).toBe("far")
		expect((TrailRules.reachMarker(run, "r1", 1, 0 / 0, 5))).toBe(false) -- NaN distance
		expect((TrailRules.reachMarker(run, "r1", 1, 2, 5))).toBe(true)
	end)

	t.test("trail: sniff spots count once each", function()
		local run = TrailRules.newRun("r1", 0, 10, 3)
		expect((TrailRules.sniff(run, "r1", 2))).toBe(true)
		local again, why = TrailRules.sniff(run, "r1", 2)
		expect(again).toBe(false)
		expect(why).toBe("duplicate")
		expect((TrailRules.sniff(run, "r1", 4))).toBe(false)
	end)

	t.test("trail: the server measures the hold (>= 1.8 s inside the window)", function()
		local run = TrailRules.newRun("r1", 0, 10, 3)
		expect((TrailRules.openChallenge(run, "r1", "c1", 10))).toBe(true)
		expect((TrailRules.holdStart(run, "r1", "c1", 10.5))).toBe(true)
		local ok, why, result = TrailRules.holdEnd(run, "r1", "c1", 10.5 + HOLD - 0.3)
		expect(ok).toBe(true)
		expect(why).toBe("short") -- too short: not a result, try again
		expect(result).toBe(nil)
		expect((TrailRules.holdStart(run, "r1", "c1", 12))).toBe(true)
		local ok2, _, result2 = TrailRules.holdEnd(run, "r1", "c1", 12 + HOLD + 0.01)
		expect(ok2).toBe(true)
		expect(result2).toBe("steady")
	end)

	t.test("trail: a hold that ends after the window is a miss", function()
		local run = TrailRules.newRun("r1", 0, 10, 3)
		TrailRules.openChallenge(run, "r1", "c1", 10)
		TrailRules.holdStart(run, "r1", "c1", 10 + WINDOW - 1)
		local ok, _, result = TrailRules.holdEnd(run, "r1", "c1", 10 + WINDOW + 1.5)
		expect(ok).toBe(true)
		expect(result).toBe("miss")
		-- Starting a hold after the window closed is refused.
		TrailRules.openChallenge(run, "r1", "c2", 30)
		expect((TrailRules.holdStart(run, "r1", "c2", 30 + WINDOW + 0.1))).toBe(false)
	end)

	t.test("trail: each challenge accepts exactly one result", function()
		local run = TrailRules.newRun("r1", 0, 10, 3)
		TrailRules.openChallenge(run, "r1", "c1", 10)
		TrailRules.holdStart(run, "r1", "c1", 10)
		local _, _, first = TrailRules.holdEnd(run, "r1", "c1", 10 + HOLD + 0.1)
		expect(first).toBe("steady")
		expect((TrailRules.holdStart(run, "r1", "c1", 12.5))).toBe(false)
		local ok, why = TrailRules.holdEnd(run, "r1", "c1", 13)
		expect(ok).toBe(false)
		expect(why).toBe("answered")
		expect(TrailRules.expireChallenge(run, "c1", 100)).toBe(nil)
		expect(run.challenges.c1.result).toBe("steady")
		-- The same challenge id can't be opened twice.
		expect((TrailRules.openChallenge(run, "r1", "c1", 20))).toBe(false)
	end)

	t.test("trail: no hold before the window ends is a miss, once", function()
		local run = TrailRules.newRun("r1", 0, 10, 3)
		TrailRules.openChallenge(run, "r1", "c1", 10)
		expect(TrailRules.expireChallenge(run, "c1", 10 + WINDOW - 0.5)).toBe(nil) -- not over yet
		expect(TrailRules.expireChallenge(run, "c1", 10 + WINDOW)).toBe("miss")
		expect(TrailRules.expireChallenge(run, "c1", 10 + WINDOW + 1)).toBe(nil)
		expect(run.open).toBe(nil)
	end)

	t.test("trail: holdEnd without holdStart is rejected", function()
		local run = TrailRules.newRun("r1", 0, 10, 3)
		TrailRules.openChallenge(run, "r1", "c1", 10)
		local ok, why = TrailRules.holdEnd(run, "r1", "c1", 12)
		expect(ok).toBe(false)
		expect(why).toBe("not holding")
		expect((TrailRules.holdStart(run, "r1", "nope", 11))).toBe(false)
	end)

	t.test("trail: a cancelled run accepts nothing more", function()
		local run = TrailRules.newRun("r1", 0, 10, 3)
		TrailRules.openChallenge(run, "r1", "c1", 10)
		TrailRules.holdStart(run, "r1", "c1", 10)
		TrailRules.cancel(run)
		expect((TrailRules.holdEnd(run, "r1", "c1", 12))).toBe(false)
		expect((TrailRules.reachMarker(run, "r1", 1, 1, 20))).toBe(false)
		expect(TrailRules.expireChallenge(run, "c1", 100)).toBe(nil)
		local ok, why = TrailRules.complete(run, "r1", 50, 60)
		expect(ok).toBe(false)
		expect(why).toBe("inactive")
	end)

	t.test("trail: completion needs every marker and happens once", function()
		local partial = TrailRules.newRun("r1", 0, 3, 0)
		TrailRules.reachMarker(partial, "r1", 1, 1, 5)
		local ok0, why0 = TrailRules.complete(partial, "r1", 10, 60)
		expect(ok0).toBe(false)
		expect(why0).toBe("markers")

		local run = walked(3)
		local ok, _, summary = TrailRules.complete(run, "r1", 30, 60)
		expect(ok).toBe(true)
		expect(summary ~= nil).toBe(true)
		local again = TrailRules.complete(run, "r1", 31, 60)
		expect(again).toBe(false)
		-- Stale id on a finished run is also refused.
		expect((TrailRules.complete(walked(3), "other", 30, 60))).toBe(false)
	end)

	t.test("trail: an open challenge at the finish counts as a miss", function()
		local run = walked(3)
		TrailRules.openChallenge(run, "r1", "c1", 20)
		local _, _, summary = TrailRules.complete(run, "r1", 21, 60)
		expect(summary and summary.challenges).toBe(1)
		expect(summary and summary.steady).toBe(0)
		expect(run.challenges.c1.result).toBe("miss")
	end)

	t.test("trail: stars stay within 1-3", function()
		local empty = TrailRules.stars({})
		expect(empty >= 1 and empty <= 3).toBe(true)
		expect(TrailRules.stars({ steady = 3, challenges = 3, seconds = 30, parSeconds = 60, markersInOrder = 10, markerTotal = 10 })).toBe(3)
		expect(TrailRules.stars({ steady = 0, challenges = 3, seconds = 999, parSeconds = 60, markersInOrder = 10, markerTotal = 10 })).toBe(1)
		expect(TrailRules.stars({ steady = 2, challenges = 3, seconds = 40, parSeconds = 60, markersInOrder = 10, markerTotal = 10 })).toBe(2)
		-- Garbage never escapes the bounds.
		local weird = { 0 / 0, -5, math.huge, 1e9 }
		for _, v in weird do
			local s = TrailRules.stars({ steady = v, challenges = v, seconds = v, parSeconds = v, markersInOrder = v, markerTotal = v, sniffs = v, sniffTotal = v })
			expect(s >= 1 and s <= 3).toBe(true)
			expect(s % 1).toBe(0)
		end
	end)

	t.test("trail: squirrel markers are distinct, spaced, inside the walk", function()
		local seq = { 3, 3, 4, 9, 6 }
		local i = 0
		local picked = TrailRules.pickChallengeMarkers(10, 3, function(a, b)
			i += 1
			return math.clamp(seq[((i - 1) % #seq) + 1], a, b)
		end)
		expect(#picked).toBe(3)
		for k = 1, #picked do
			expect(picked[k] >= 2 and picked[k] <= 8).toBe(true)
			if k > 1 then
				expect(picked[k] - picked[k - 1] >= 2).toBe(true)
			end
		end
		expect(#TrailRules.pickChallengeMarkers(3, 2, math.random)).toBe(0)
	end)
end
