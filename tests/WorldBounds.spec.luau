local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldBounds = require(ReplicatedStorage.Shared.WorldBounds)

return function(t)
	local expect = t.expect
	local L = WorldBounds.LANDING

	t.test("inside the map does not wrap", function()
		expect(WorldBounds.wrap(Vector3.new(0, 3, 0))).toBe(nil)
		expect(WorldBounds.wrap(Vector3.new(250, 3, -250))).toBe(nil)
	end)

	t.test("east edge wraps to west, keeping Y and Z", function()
		expect(WorldBounds.wrap(Vector3.new(255, 4, 12))).toBe(Vector3.new(-L, 4, 12))
	end)

	t.test("west edge wraps to east", function()
		expect(WorldBounds.wrap(Vector3.new(-255, 4, 12))).toBe(Vector3.new(L, 4, 12))
	end)

	t.test("Z edges wrap", function()
		expect(WorldBounds.wrap(Vector3.new(7, 3, 255))).toBe(Vector3.new(7, 3, -L))
		expect(WorldBounds.wrap(Vector3.new(7, 3, -255))).toBe(Vector3.new(7, 3, L))
	end)

	t.test("corner wraps both axes", function()
		expect(WorldBounds.wrap(Vector3.new(255, 3, 255))).toBe(Vector3.new(-L, 3, -L))
	end)

	t.test("landing spot is not a trigger (no ping-pong)", function()
		local landed = WorldBounds.wrap(Vector3.new(255, 3, -255)) :: Vector3
		expect(WorldBounds.wrap(landed)).toBe(nil)
	end)

	t.test("rescue puts a fallen character back on the floor", function()
		expect(WorldBounds.rescue(Vector3.new(10, -60, 20))).toBe(Vector3.new(10, 5, 20))
		expect(WorldBounds.rescue(Vector3.new(300, -60, 0))).toBe(Vector3.new(-L, 5, 0))
	end)
end
