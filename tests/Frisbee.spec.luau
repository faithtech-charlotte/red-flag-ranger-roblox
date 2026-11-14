local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FrisbeeMath = require(ReplicatedStorage.Shared.FrisbeeMath)

return function(t)
	local expect = t.expect
	local EAST = Vector3.new(1, 0, 0)
	local HAND = Vector3.new(0, 3, 0) -- about hand height over ground at Y = 0

	local function fly(power: number, pitch: number)
		local launch = FrisbeeMath.launch(HAND, EAST, FrisbeeMath.elevationFromPitch(pitch), power)
		local points = FrisbeeMath.predict(launch, 0, 10)
		local maxHeight = 0
		for _, p in points do
			maxHeight = math.max(maxHeight, p.height)
		end
		return points[#points], maxHeight, launch, points
	end

	t.test("frisbee: launch speed follows power and clamps bad input", function()
		local soft = FrisbeeMath.launch(HAND, EAST, 10, 0)
		local hard = FrisbeeMath.launch(HAND, EAST, 10, 1)
		local junk = FrisbeeMath.launch(HAND, EAST, 0 / 0, 99)
		expect(math.abs(soft.velocity.Magnitude - FrisbeeMath.MIN_SPEED) < 1e-3).toBe(true)
		expect(math.abs(hard.velocity.Magnitude - FrisbeeMath.MAX_SPEED) < 1e-3).toBe(true)
		expect(math.abs(junk.velocity.Magnitude - FrisbeeMath.MAX_SPEED) < 1e-3).toBe(true)
		expect(math.abs(junk.normal.Magnitude - 1) < 1e-4).toBe(true)
	end)

	t.test("frisbee: aim pitch maps to a clamped launch angle", function()
		expect(FrisbeeMath.elevationFromPitch(-90)).toBe(FrisbeeMath.MIN_ELEVATION)
		expect(FrisbeeMath.elevationFromPitch(90)).toBe(FrisbeeMath.MAX_ELEVATION)
		expect(FrisbeeMath.elevationFromPitch("up") > 0).toBe(true)
		expect(FrisbeeMath.elevationFromPitch(10) > FrisbeeMath.elevationFromPitch(-10)).toBe(true)
	end)

	t.test("frisbee: distances fit the field (soft ~20, hard ~60 studs)", function()
		local soft = fly(0, -10)
		local hard = fly(1, -10)
		expect(soft.position.X > 12 and soft.position.X < 32).toBe(true)
		expect(hard.position.X > 45 and hard.position.X < 78).toBe(true)
		expect(hard.t > soft.t).toBe(true)
	end)

	t.test("frisbee: it glides (stays up longer than a thrown ball would)", function()
		local landing, _, launch = fly(0.5, -10)
		-- Same launch with gravity only: time to fall back to the ground.
		local v = launch.velocity
		local g = 9.81
		local y0 = HAND.Y / FrisbeeMath.STUDS_PER_METER
		local ballistic = (v.Y + math.sqrt(v.Y * v.Y + 2 * g * y0)) / g
		expect(landing.t > ballistic * 1.3).toBe(true)
	end)

	t.test("frisbee: aiming higher throws higher", function()
		local _, flat = fly(0.5, -20)
		local _, lofted = fly(0.5, 15)
		expect(lofted > flat + 2).toBe(true)
	end)

	t.test("frisbee: spinning disc curves sideways (turn and fade)", function()
		local soft = fly(0, 0)
		local hard = fly(1, -10)
		-- Right-hand backhand: slow throws fade left (-Z here), fast ones turn right (+Z).
		expect(soft.position.Z < -1).toBe(true)
		expect(hard.position.Z > 3).toBe(true)
	end)

	t.test("frisbee: replay is deterministic and lands on the ground", function()
		local landing, _, launch = fly(0.7, 0)
		expect(landing.height).toBe(0)
		local a, b = FrisbeeMath.start(launch), FrisbeeMath.start(launch)
		FrisbeeMath.advanceTo(a, 1.5)
		for i = 1, 10 do
			FrisbeeMath.advanceTo(b, 0.15 * i) -- in small hops, like a client frame by frame
		end
		expect(a.t).toBe(b.t)
		expect((a.offset - b.offset).Magnitude < 1e-6).toBe(true)
	end)

	t.test("frisbee: dog runs to a reachable catch point, or the landing spot", function()
		local landing, _, _, points = fly(0.5, -10)
		local near, okNear = FrisbeeMath.pickIntercept(points, landing.position, 30, 0.35, 3.4, 6)
		expect(okNear).toBe(true)
		expect(near ~= nil and near.height <= 3.4).toBe(true)
		local far, okFar = FrisbeeMath.pickIntercept(points, Vector3.new(-200, 0, 0), 30, 0.35, 3.4, 6)
		expect(okFar).toBe(false)
		expect(far).toBe(landing)
		local none, okNone = FrisbeeMath.pickIntercept({}, Vector3.zero, 30, 0.35, 3.4, 6)
		expect(none).toBe(nil)
		expect(okNone).toBe(false)
	end)

	t.test("frisbee: flat direction falls back to facing", function()
		local d = FrisbeeMath.flatDirection(Vector3.zero, "nope", Vector3.new(0, 0, -2))
		expect((d - Vector3.new(0, 0, -1)).Magnitude < 1e-6).toBe(true)
		local d2 = FrisbeeMath.flatDirection(Vector3.zero, Vector3.new(10, 50, 0), Vector3.new(0, 0, -1))
		expect((d2 - EAST).Magnitude < 1e-6).toBe(true)
	end)
end
