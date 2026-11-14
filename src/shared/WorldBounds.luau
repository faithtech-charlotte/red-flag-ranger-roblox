--[[
	WorldBounds: the size of the playable floor and the wrap-around rule.

	The world wraps like Pac-Man: walking off one edge puts you on the
	opposite edge instead of falling into the void. The floor is a square
	centered at the origin with its top at Y = 0.

	TRIGGER sits just inside the edge so players wrap before they start to
	fall. LANDING is further inside than TRIGGER so a wrapped player is not
	immediately wrapped back.
]]

local WorldBounds = {}

WorldBounds.HALF_SIZE = 256
WorldBounds.TRIGGER = WorldBounds.HALF_SIZE - 2
WorldBounds.LANDING = WorldBounds.HALF_SIZE - 8
WorldBounds.RESCUE_HEIGHT = -25 -- below this Y a character is considered fallen

local function wrapAxis(v: number): (number, boolean)
	if v > WorldBounds.TRIGGER then
		return -WorldBounds.LANDING, true
	elseif v < -WorldBounds.TRIGGER then
		return WorldBounds.LANDING, true
	end
	return v, false
end

-- The wrapped position, or nil when the position is inside the map.
-- X and Z wrap independently (so corners wrap both); Y is kept.
function WorldBounds.wrap(pos: Vector3): Vector3?
	local x, wrappedX = wrapAxis(pos.X)
	local z, wrappedZ = wrapAxis(pos.Z)
	if not (wrappedX or wrappedZ) then
		return nil
	end
	return Vector3.new(x, pos.Y, z)
end

-- Where to put a character that fell below the floor: wrapped across the
-- edge it went over, otherwise straight above where it fell.
function WorldBounds.rescue(pos: Vector3): Vector3
	local p = WorldBounds.wrap(pos) or pos
	local l = WorldBounds.LANDING
	return Vector3.new(math.clamp(p.X, -l, l), 5, math.clamp(p.Z, -l, l))
end

return WorldBounds
