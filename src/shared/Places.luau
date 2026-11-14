--[[
	Places: the named areas of the world. Shared so the server can validate
	"is the player at the dog park?" and the client can draw waypoints.

	Zones are axis-aligned boxes on the ground (center + size). The world builder
	reads the same numbers, so moving an area here moves it everywhere.
]]

export type Place = {
	id: string,
	displayName: string,
	center: Vector3,
	size: Vector3,
	color: Color3,
	entrance: Vector3, -- where waypoint arrows point
}

local Places: { [string]: Place } = {
	pet_store = {
		id = "pet_store",
		displayName = "Paws & Friends Pet Store",
		center = Vector3.new(0, 0, 50),
		size = Vector3.new(48, 30, 36),
		color = Color3.fromRGB(255, 159, 67),
		entrance = Vector3.new(0, 0, 30),
	},
	ranger_station = {
		id = "ranger_station",
		displayName = "Ranger Station",
		center = Vector3.new(24, 0, 5),
		size = Vector3.new(24, 30, 22),
		color = Color3.fromRGB(46, 160, 120),
		entrance = Vector3.new(15, 0, 5),
	},
	dog_park = {
		id = "dog_park",
		displayName = "Sunny Dog Park",
		center = Vector3.new(-90, 0, -40),
		size = Vector3.new(80, 40, 80),
		color = Color3.fromRGB(120, 200, 80),
		entrance = Vector3.new(-54, 0, -30),
	},
	salon = {
		id = "salon",
		displayName = "Fluff & Puff Salon",
		center = Vector3.new(85, 0, -30),
		size = Vector3.new(44, 30, 36),
		color = Color3.fromRGB(255, 120, 190),
		entrance = Vector3.new(60, 0, -30),
	},
	agility = {
		id = "agility",
		displayName = "Agility Course",
		center = Vector3.new(0, 0, -120),
		size = Vector3.new(100, 40, 60),
		color = Color3.fromRGB(80, 160, 255),
		entrance = Vector3.new(0, 0, -92),
	},
}

local M = {}
M.All = Places

function M.get(id: string): Place?
	return Places[id]
end

-- True when a world position lies inside the place's footprint (height is generous).
function M.isInside(id: string, position: Vector3, margin: number?): boolean
	local place = Places[id]
	if not place then
		return false
	end
	local m = margin or 0
	local d = position - place.center
	return math.abs(d.X) <= place.size.X / 2 + m
		and math.abs(d.Z) <= place.size.Z / 2 + m
		and d.Y >= -10
		and d.Y <= place.size.Y + m
end

-- Which place (if any) contains this position.
function M.locate(position: Vector3): string?
	for id in Places do
		if M.isInside(id, position) then
			return id
		end
	end
	return nil
end

return M
