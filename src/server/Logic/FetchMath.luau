--[[
	FetchMath: pure helpers for throwing a ball. Unit-tested.
]]

local FetchMath = {}

local function finite(v: Vector3): boolean
	return v.X == v.X and v.Y == v.Y and v.Z == v.Z and math.abs(v.X) < 1e6 and math.abs(v.Y) < 1e6 and math.abs(v.Z) < 1e6
end

--[[
	Turns a client-requested aim point into a safe throw target on the
	horizontal plane: between minDistance and maxDistance from the thrower,
	in the requested direction. Falls back to `facing` if the aim is
	unusable. Returns the target's X/Z (Y is set to origin.Y).
]]
function FetchMath.clampThrow(origin: Vector3, aim: any, facing: Vector3, minDistance: number, maxDistance: number): Vector3
	local dir: Vector3
	local dist: number
	if typeof(aim) == "Vector3" and finite(aim) then
		local flat = Vector3.new(aim.X - origin.X, 0, aim.Z - origin.Z)
		if flat.Magnitude > 0.5 then
			dir = flat.Unit
			dist = flat.Magnitude
		end
	end
	if not dir then
		local f = Vector3.new(facing.X, 0, facing.Z)
		dir = if f.Magnitude > 0.01 then f.Unit else Vector3.new(0, 0, -1)
		dist = (minDistance + maxDistance) / 2
	end
	dist = math.clamp(dist :: number, minDistance, maxDistance)
	local p = origin + dir * dist
	return Vector3.new(p.X, origin.Y, p.Z)
end

-- Inside the playable square?
function FetchMath.inBounds(p: Vector3, halfSize: number): boolean
	return math.abs(p.X) <= halfSize and math.abs(p.Z) <= halfSize
end

return FetchMath
