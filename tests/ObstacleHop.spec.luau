local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ObstacleHop = require(ReplicatedStorage.Shared.ObstacleHop)

return function(t)
	local expect = t.expect
	-- A hurdle-like box: 8 wide (Z), 0.6 deep (X), top at 3.2.
	local cf = CFrame.new(10, 1.6, 0)
	local size = Vector3.new(0.6, 3.2, 8)
	local PAD, MARGIN = 1.8, 0.4

	local function near(a: number, b: number)
		if math.abs(a - b) > 1e-4 then
			error(`expected {b}, got {a}`, 2)
		end
	end

	t.test("far from the box is 0", function()
		expect(ObstacleHop.lift(Vector3.new(0, 1.5, 0), 0, cf, size, PAD, MARGIN)).toBe(0)
	end)

	t.test("over the footprint lifts to top + margin", function()
		near(ObstacleHop.lift(Vector3.new(10, 1.5, 2), 0, cf, size, PAD, MARGIN), 3.6)
	end)

	t.test("within the pad lifts; just outside it does not", function()
		near(ObstacleHop.lift(Vector3.new(10 + 0.3 + 1.7, 1.5, 0), 0, cf, size, PAD, MARGIN), 3.6)
		expect(ObstacleHop.lift(Vector3.new(10 + 0.3 + 1.9, 1.5, 0), 0, cf, size, PAD, MARGIN)).toBe(0)
	end)

	t.test("feet already above the top is 0", function()
		expect(ObstacleHop.lift(Vector3.new(10, 6, 0), 5, cf, size, PAD, MARGIN)).toBe(0)
	end)

	t.test("partial lift when feet are part-way up", function()
		near(ObstacleHop.lift(Vector3.new(10, 3, 0), 2, cf, size, PAD, MARGIN), 1.6)
	end)

	t.test("rotated box uses its rotated footprint", function()
		-- A long rail along world X (local Z rotated 90 degrees around Y).
		local rail = CFrame.new(0, 2.5, 0) * CFrame.Angles(0, math.rad(90), 0)
		local railSize = Vector3.new(0.3, 0.4, 20)
		near(ObstacleHop.lift(Vector3.new(8, 1.5, 0), 0, rail, railSize, 0.5, 0), 2.7)
		expect(ObstacleHop.lift(Vector3.new(0, 1.5, 8), 0, rail, railSize, 0.5, 0)).toBe(0)
	end)

	t.test("crossing a long box needs motion across its thin axis", function()
		-- Hurdle: thin along X, long along Z.
		expect(ObstacleHop.crossing(Vector3.new(10, 0, 0), cf, size, 2)).toBe(true)
		expect(ObstacleHop.crossing(Vector3.new(-10, 0, 1), cf, size, 2)).toBe(true)
		expect(ObstacleHop.crossing(Vector3.new(0, 0, 10), cf, size, 2)).toBe(false)
	end)

	t.test("standing still is never crossing", function()
		expect(ObstacleHop.crossing(Vector3.new(1, 5, 0), cf, size, 2)).toBe(false)
	end)

	t.test("roundish boxes are crossed from any direction", function()
		local ball = Vector3.one * 3.6
		expect(ObstacleHop.crossing(Vector3.new(0, 0, 10), CFrame.new(), ball, 2)).toBe(true)
		expect(ObstacleHop.crossing(Vector3.new(7, 0, 7), CFrame.new(), ball, 2)).toBe(true)
	end)

	t.test("rotated rail is crossed along its rotated thin axis", function()
		local rail = CFrame.lookAt(Vector3.new(0, 2.5, 0), Vector3.new(10, 2.5, 0)) -- runs along world X
		local railSize = Vector3.new(0.3, 0.4, 20)
		expect(ObstacleHop.crossing(Vector3.new(0, 0, 10), rail, railSize, 2)).toBe(true)
		expect(ObstacleHop.crossing(Vector3.new(10, 0, 0), rail, railSize, 2)).toBe(false)
	end)

	-- height(): the per-frame pick over every obstacle.
	local hurdle = { cf = cf, size = size } -- thin along X at x = 10, top 3.2
	local bench = { cf = CFrame.new(10, 2, 0), size = Vector3.new(0.6, 4, 8) } -- top 4
	local cfg = { pad = PAD, margin = MARGIN, lead = 0.2, minSpeed = 2, maxLift = 4.5 }
	local runX = Vector3.new(10, 0, 0)

	t.test("height picks the largest lift", function()
		near(ObstacleHop.height({ hurdle, bench }, Vector3.new(10, 1.5, 0), runX, 0, false, cfg), 4.4)
	end)

	t.test("height looks ahead so the hop starts early", function()
		-- 2 studs ahead of the pad edge; the 0.2 s look-ahead at 10 studs/s reaches it.
		local pos = Vector3.new(10 - 0.3 - 1.8 - 1.5, 1.5, 0)
		expect(ObstacleHop.lift(pos, 0, cf, size, PAD, MARGIN)).toBe(0)
		near(ObstacleHop.height({ hurdle }, pos, runX, 0, false, cfg), 3.6)
		expect(ObstacleHop.height({ hurdle }, pos, Vector3.new(1, 0, 0), 0, false, cfg)).toBe(0)
	end)

	t.test("height does not start a hop when not crossing", function()
		local over = Vector3.new(10, 1.5, 2)
		expect(ObstacleHop.height({ hurdle }, over, Vector3.new(0, 0, 10), 0, false, cfg)).toBe(0)
		expect(ObstacleHop.height({ hurdle }, over, Vector3.zero, 0, false, cfg)).toBe(0)
	end)

	t.test("height keeps hopping while still over the obstacle", function()
		local over = Vector3.new(10, 1.5, 2)
		near(ObstacleHop.height({ hurdle }, over, Vector3.zero, 0, true, cfg), 3.6)
		expect(ObstacleHop.height({ hurdle }, Vector3.new(20, 1.5, 0), Vector3.zero, 0, true, cfg)).toBe(0)
	end)

	t.test("height drops a hop when beside, not over, a rail", function()
		local beside = Vector3.new(10 + 0.3 + 1.5, 1.5, 0) -- inside the pad, not over the bar
		expect(ObstacleHop.height({ hurdle }, beside, Vector3.new(0, 0, 10), 0, true, cfg)).toBe(0)
	end)

	t.test("thin posts are not crossed just by running past", function()
		local post = Vector3.new(0.6, 3.2, 0.6)
		expect(ObstacleHop.crossing(Vector3.new(0, 0, 10), CFrame.new(), post, 2)).toBe(false)
	end)

	t.test("height is capped so the dog never flies", function()
		local tower = { cf = CFrame.new(10, 10, 0), size = Vector3.new(1, 20, 1) }
		expect(ObstacleHop.height({ tower }, Vector3.new(10, 1.5, 0), runX, 0, false, cfg)).toBe(4.5)
	end)

	t.test("top accounts for rotation", function()
		-- Tipped on its side: the 4-stud axis now points up.
		local tipped = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(90))
		near(ObstacleHop.top(tipped, Vector3.new(4, 1, 1)), 2)
	end)
end
