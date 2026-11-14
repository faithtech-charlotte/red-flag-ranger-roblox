--[[
	ObstacleHop: pure math for how high a dog must lift to clear an obstacle.

	An obstacle is a box (CFrame + Size), e.g. a part tagged "JumpObstacle".
	Only the box's horizontal footprint (its local X/Z) is used to decide
	whether something is over it, so obstacles should be upright (rotated
	around Y only), which every world obstacle is.

	Two tags (set in WorldBuilder; hand-built worlds can tag their own parts):
	  JumpObstacle   a visible part the dog hops over (its box is what it clears)
	  PlayerBlocker  an invisible box that stops players walking through a low
	                 obstacle, so they press Jump. Collides only with Characters.
	Ground raycasts must exclude both (see ObstacleHop.groundIgnore).
]]

local CollectionService = game:GetService("CollectionService")

local ObstacleHop = {}

ObstacleHop.JUMP_TAG = "JumpObstacle"
ObstacleHop.BLOCKER_TAG = "PlayerBlocker"
ObstacleHop.BLOCKER_GROUP = "PlayerBlocker"

export type Box = { cf: CFrame, size: Vector3 }
export type Config = {
	pad: number, -- studs around the footprint where the dog is "over" it
	margin: number, -- clearance above the top
	lead: number, -- seconds of look-ahead, so the hop starts before the obstacle
	minSpeed: number, -- slower than this never starts a hop
	maxLift: number, -- the dog hops; it never flies
}

ObstacleHop.DEFAULTS = table.freeze({
	pad = 1.8,
	margin = 0.4,
	lead = 0.18,
	minSpeed = 3,
	maxLift = 4.5,
}) :: Config

-- Appends every tagged obstacle and blocker to `list`, for a raycast's
-- exclude list (CanQuery = false is ignored on colliding parts).
function ObstacleHop.groundIgnore(list: { Instance }): { Instance }
	for _, tag in { ObstacleHop.JUMP_TAG, ObstacleHop.BLOCKER_TAG } do
		for _, p in CollectionService:GetTagged(tag) do
			table.insert(list, p)
		end
	end
	return list
end

-- Highest world Y of the box, accounting for rotation.
function ObstacleHop.top(cf: CFrame, size: Vector3): number
	local half = math.abs(cf.XVector.Y) * size.X / 2 + math.abs(cf.YVector.Y) * size.Y / 2 + math.abs(cf.ZVector.Y) * size.Z / 2
	return cf.Position.Y + half
end

-- How high (studs) something with feet at `feetY` must lift to clear the box
-- by `margin` when `point` is within `pad` studs of its footprint; else 0.
function ObstacleHop.lift(point: Vector3, feetY: number, cf: CFrame, size: Vector3, pad: number, margin: number): number
	local p = cf:PointToObjectSpace(point)
	if math.abs(p.X) > size.X / 2 + pad or math.abs(p.Z) > size.Z / 2 + pad then
		return 0
	end
	return math.max(0, ObstacleHop.top(cf, size) + margin - feetY)
end

-- Whether something moving at `vel` is crossing the box rather than
-- standing still or running alongside it. Long boxes (rails, bars, benches)
-- must be crossed along their thin axis; roundish ones (a ball) any way.
function ObstacleHop.crossing(vel: Vector3, cf: CFrame, size: Vector3, minSpeed: number): boolean
	local flat = Vector3.new(vel.X, 0, vel.Z)
	if flat.Magnitude < minSpeed then
		return false
	end
	if math.max(size.X, size.Z) < 1.5 * math.min(size.X, size.Z) then
		return true
	end
	local thin = size.X < size.Z and cf.XVector or cf.ZVector
	local thinFlat = Vector3.new(thin.X, 0, thin.Z)
	if thinFlat.Magnitude < 1e-3 then
		return true
	end
	return math.abs(flat.Unit:Dot(thinFlat.Unit)) > 0.35
end

--[[
	How high a dog at `pos` moving at `vel` should be lifted right now, given
	nearby obstacles. A hop starts only when the dog is crossing an obstacle
	(checked at `pos` and a look-ahead point). Once `hopping`, it continues
	while the dog is still over the obstacle, so it never drops into the bar
	halfway across. Capped at cfg.maxLift.
]]
function ObstacleHop.height(obstacles: { Box }, pos: Vector3, vel: Vector3, feetY: number, hopping: boolean, cfg: Config?): number
	local c = cfg or ObstacleHop.DEFAULTS
	local ahead = pos + Vector3.new(vel.X, 0, vel.Z) * c.lead
	local best = 0
	for _, o in obstacles do
		local here = ObstacleHop.lift(pos, feetY, o.cf, o.size, c.pad, c.margin)
		local h = 0
		if ObstacleHop.crossing(vel, o.cf, o.size, c.minSpeed) then
			h = math.max(here, ObstacleHop.lift(ahead, feetY, o.cf, o.size, c.pad, c.margin))
		elseif hopping then
			h = here
		end
		best = math.max(best, h)
	end
	return math.min(best, c.maxLift)
end

return ObstacleHop
