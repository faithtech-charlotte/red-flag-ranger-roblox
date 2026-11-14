--[[
	FrisbeeMath: flight model for a thrown flying disc. Pure and deterministic,
	so the server (which decides catches) and every client (which draws the
	disc smoothly) run the same flight from the same launch. Unit-tested.

	The model is the standard rigid-disc one used in sports-physics papers:
	  lift  = 1/2 rho v^2 A (CL0 + CLa * alpha)              (perpendicular to velocity)
	  drag  = 1/2 rho v^2 A (CD0 + CDa * (alpha - alpha0)^2)  (against velocity)
	  pitching moment = 1/2 rho v^2 A d (CM0 + CMa * alpha)
	The disc is spinning, so the pitching moment does not flip it nose-up.
	Gyroscopic precession turns it into a slow ROLL instead (rate = M / (I w)).
	For a right-handed backhand throw (clockwise spin seen from above) this
	gives the familiar flight: a slight turn right while fast, then a fade
	left as it slows down and the angle of attack grows.

	Coefficients are the ones reported for a 175 g Ultrastar-class disc
	(Hummel, 2003, "Frisbee flight simulation and throw biomechanics").
	alpha is the angle between the velocity and the disc's plane. The model
	leaves out roll/pitch damping and spin-down torque, so treat it as a good
	approximation rather than a wind-tunnel match.

	Units: the simulation runs in meters and seconds. World positions are
	origin + offset * STUDS_PER_METER. Real gravity (9.81 m/s^2), not the
	Roblox workspace gravity: a disc floats, which is the whole point.
]]

local FrisbeeMath = {}

FrisbeeMath.STUDS_PER_METER = 3 -- a 5-stud avatar is about 1.7 m tall
FrisbeeMath.DT = 1 / 60 -- fixed step: server and clients stay in sync
FrisbeeMath.MIN_SPEED = 7 -- m/s, a soft toss
FrisbeeMath.MAX_SPEED = 13 -- m/s, a strong backhand
FrisbeeMath.MIN_ELEVATION = 4 -- degrees
FrisbeeMath.MAX_ELEVATION = 22
FrisbeeMath.NOSE_UP = 3 -- degrees of extra disc pitch over the flight path
FrisbeeMath.HYZER = 8 -- degrees of bank to the left at release (normal for casual throwers)
FrisbeeMath.SPIN_RATIO = 4.5 -- spin (rad/s) per m/s of speed: an advance ratio near 0.6

local RHO = 1.23 -- air density, kg/m^3
local MASS = 0.175 -- kg
local AREA = 0.0568 -- m^2 (27 cm diameter)
local DIAMETER = 0.269 -- m
local INERTIA = 0.00235 -- kg m^2, about the spin axis
local GRAVITY = 9.81
local CL0, CLA = 0.33, 1.91
local CD0, CDA = 0.18, 0.69
local ALPHA0 = math.rad(-4)
local CM0, CMA = -0.08, 0.43
local SPIN_DECAY = 0.02 -- fraction of spin lost per second

local UP = Vector3.new(0, 1, 0)

export type Launch = {
	origin: Vector3, -- world position (studs) at release
	velocity: Vector3, -- m/s
	normal: Vector3, -- unit, the disc's "up" (top face)
	spin: number, -- rad/s
}

export type FlightState = {
	t: number,
	offset: Vector3, -- meters from origin
	velocity: Vector3, -- m/s
	normal: Vector3,
	spin: number,
}

export type PathPoint = { t: number, position: Vector3, height: number }

local function finite(n: any): boolean
	return typeof(n) == "number" and n == n and math.abs(n) < 1e6
end

local function finiteVector(v: any): boolean
	return typeof(v) == "Vector3" and finite(v.X) and finite(v.Y) and finite(v.Z)
end

-- Launch angle (degrees above horizontal) from where the player aims. Aiming
-- at the ground near you gives a flat throw; aiming at the sky, a high,
-- floaty one. `pitch` is the aim ray's angle in degrees (negative = down).
function FrisbeeMath.elevationFromPitch(pitch: any): number
	local p = finite(pitch) and pitch or -10
	return math.clamp(11 + 0.6 * (p + 8), FrisbeeMath.MIN_ELEVATION, FrisbeeMath.MAX_ELEVATION)
end

-- Horizontal unit direction from `origin` toward `target`, or `facing`.
function FrisbeeMath.flatDirection(origin: Vector3, target: any, facing: Vector3): Vector3
	if finiteVector(target) then
		local flat = Vector3.new(target.X - origin.X, 0, target.Z - origin.Z)
		if flat.Magnitude > 0.5 then
			return flat.Unit
		end
	end
	local f = Vector3.new(facing.X, 0, facing.Z)
	return if f.Magnitude > 0.01 then f.Unit else Vector3.new(0, 0, -1)
end

--[[
	Builds a release from player input. Everything is clamped, so the server
	can pass client values straight in.
	  direction  horizontal unit vector
	  elevation  degrees above horizontal
	  power      0..1 (how long you wound up)
]]
function FrisbeeMath.launch(origin: Vector3, direction: Vector3, elevation: any, power: any): Launch
	local p = finite(power) and math.clamp(power, 0, 1) or 0.5
	local e = math.rad(finite(elevation) and math.clamp(elevation, FrisbeeMath.MIN_ELEVATION, FrisbeeMath.MAX_ELEVATION) or 10)
	local speed = FrisbeeMath.MIN_SPEED + (FrisbeeMath.MAX_SPEED - FrisbeeMath.MIN_SPEED) * p
	local fwd = Vector3.new(direction.X, 0, direction.Z)
	fwd = if fwd.Magnitude > 0.01 then fwd.Unit else Vector3.new(0, 0, -1)
	local right = fwd:Cross(UP)
	-- Disc attitude: nose up a little more than the flight path, then banked
	-- left (hyzer) the way most right-handed backhand throws leave the hand.
	local pitch = e + math.rad(FrisbeeMath.NOSE_UP)
	local nf, nu = -math.sin(pitch), math.cos(pitch)
	local h = math.rad(FrisbeeMath.HYZER)
	local normal = (fwd * nf + UP * (nu * math.cos(h)) - right * (nu * math.sin(h))).Unit
	return {
		origin = origin,
		velocity = (fwd * math.cos(e) + UP * math.sin(e)) * speed,
		normal = normal,
		spin = FrisbeeMath.SPIN_RATIO * speed,
	}
end

function FrisbeeMath.start(launch: Launch): FlightState
	return { t = 0, offset = Vector3.zero, velocity = launch.velocity, normal = launch.normal, spin = launch.spin }
end

-- Angle of attack (radians): positive when air hits the underside.
function FrisbeeMath.angleOfAttack(velocity: Vector3, normal: Vector3): number
	local speed = velocity.Magnitude
	if speed < 1e-4 then
		return 0
	end
	return math.asin(math.clamp(-(velocity / speed):Dot(normal), -1, 1))
end

-- Advances the flight by one fixed step (semi-implicit Euler). Mutates `s`.
function FrisbeeMath.step(s: FlightState, dt: number?)
	local h = dt or FrisbeeMath.DT
	local v = s.velocity
	local speed = v.Magnitude
	local accel = Vector3.new(0, -GRAVITY, 0)
	if speed > 1e-3 then
		local vhat = v / speed
		local n = s.normal
		local alpha = math.asin(math.clamp(-vhat:Dot(n), -1, 1))
		local q = 0.5 * RHO * speed * speed * AREA
		local lift = q * (CL0 + CLA * alpha)
		local drag = q * (CD0 + CDA * (alpha - ALPHA0) ^ 2)
		local liftDir = n - vhat * n:Dot(vhat)
		if liftDir.Magnitude > 1e-4 then
			accel += liftDir.Unit * (lift / MASS)
		end
		accel -= vhat * (drag / MASS)
		-- Gyroscopic roll from the pitching moment (see header).
		local inPlane = vhat - n * vhat:Dot(n)
		if inPlane.Magnitude > 1e-4 and s.spin > 1 then
			local rollAxis = inPlane.Unit:Cross(n)
			local moment = q * DIAMETER * (CM0 + CMA * alpha)
			s.normal = (n - rollAxis * (moment / (INERTIA * s.spin)) * h).Unit
		end
	end
	s.velocity = v + accel * h
	s.offset += s.velocity * h
	s.spin *= (1 - SPIN_DECAY * h)
	s.t += h
end

function FrisbeeMath.worldPosition(launch: Launch, s: FlightState): Vector3
	return launch.origin + s.offset * FrisbeeMath.STUDS_PER_METER
end

-- Steps `s` forward until it reaches time `t` (never backward).
function FrisbeeMath.advanceTo(s: FlightState, t: number)
	local limit = 1200 -- 20 s of flight; guards against bad clocks
	while s.t + FrisbeeMath.DT <= t and limit > 0 do
		FrisbeeMath.step(s)
		limit -= 1
	end
end

-- Orientation for a Cylinder part (its round faces are on the X axis).
function FrisbeeMath.cframe(position: Vector3, s: FlightState): CFrame
	local n = s.normal
	local along = s.velocity - n * s.velocity:Dot(n)
	if along.Magnitude < 1e-4 then
		along = math.abs(n.Y) < 0.9 and UP:Cross(n) or Vector3.new(1, 0, 0):Cross(n)
	end
	along = along.Unit
	return CFrame.fromMatrix(position, n, along, n:Cross(along))
end

--[[
	Predicts the whole flight over flat ground at height `groundY` (studs).
	Returns one point every `every` steps, ending on the ground (or at maxTime).
	Used for the aiming preview and for where the dog runs to.
]]
function FrisbeeMath.predict(launch: Launch, groundY: number, maxTime: number, every: number?): { PathPoint }
	local s = FrisbeeMath.start(launch)
	local points: { PathPoint } = {}
	local n = 0
	local stride = every or 1
	while s.t < maxTime do
		FrisbeeMath.step(s)
		n += 1
		local pos = FrisbeeMath.worldPosition(launch, s)
		local height = pos.Y - groundY
		if height <= 0 then
			-- Interpolate to the ground so the landing point is exact.
			local prev = points[#points]
			local landing = pos
			if prev and prev.height > 0 then
				local f = prev.height / (prev.height - height)
				landing = prev.position:Lerp(pos, f)
			end
			table.insert(points, { t = s.t, position = Vector3.new(landing.X, groundY, landing.Z), height = 0 })
			return points
		end
		if n % stride == 0 then
			table.insert(points, { t = s.t, position = pos, height = height })
		end
	end
	return points
end

--[[
	Where should the dog run to make the catch? The earliest point along the
	predicted path that is low enough to snatch (height <= catchHeight), far
	enough from the thrower, and that the dog can reach before the disc does.
	Returns (point, reachable). If no point can be reached in time, the dog
	heads for the landing spot (reachable = false).
]]
function FrisbeeMath.pickIntercept(
	points: { PathPoint },
	dogPosition: Vector3,
	dogSpeed: number,
	reactionTime: number,
	catchHeight: number,
	minFromThrower: number
): (PathPoint?, boolean)
	local first = points[1]
	if not first then
		return nil, false
	end
	local start = first.position
	for _, p in points do
		local fromThrower = Vector3.new(p.position.X - start.X, 0, p.position.Z - start.Z).Magnitude
		if p.height <= catchHeight and fromThrower >= minFromThrower then
			local run = Vector3.new(p.position.X - dogPosition.X, 0, p.position.Z - dogPosition.Z).Magnitude
			if reactionTime + run / dogSpeed <= p.t then
				return p, true
			end
		end
	end
	return points[#points], false
end

return FrisbeeMath
