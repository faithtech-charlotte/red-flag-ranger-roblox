--[[
	WorldBuilder: builds the small, colorful world from code at server start,
	so the whole game lives in this repo (no binary place edits needed).

	If Workspace already contains a "World" model (for example, one a builder
	made by hand in Studio), it is used as-is and nothing is generated. To
	hand-edit: play once, copy Workspace.World, stop, paste it into Workspace,
	and save. Keep the named parts the game looks for:
	  World.Agility.AgilityStart / AgilityFinish / parts with RingIndex 1..N
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DogRig = require(ReplicatedStorage.Shared.DogRig)
local PetCatalog = require(ReplicatedStorage.Shared.Catalogs.PetCatalog)
local Places = require(ReplicatedStorage.Shared.Places)
local WorldBounds = require(ReplicatedStorage.Shared.WorldBounds)

local World = {}
local root: Model

local C = {
	grass = Color3.fromRGB(110, 196, 92),
	grassLight = Color3.fromRGB(140, 214, 104),
	path = Color3.fromRGB(240, 214, 160),
	wood = Color3.fromRGB(176, 122, 76),
	white = Color3.fromRGB(255, 252, 245),
	cream = Color3.fromRGB(255, 244, 222),
	trunk = Color3.fromRGB(122, 84, 52),
	leaf = Color3.fromRGB(70, 170, 80),
	leaf2 = Color3.fromRGB(96, 196, 96),
	orange = Color3.fromRGB(255, 159, 67),
	pink = Color3.fromRGB(255, 120, 190),
	purple = Color3.fromRGB(155, 93, 229),
	blue = Color3.fromRGB(80, 160, 255),
	yellow = Color3.fromRGB(255, 209, 102),
	red = Color3.fromRGB(239, 71, 111),
	green = Color3.fromRGB(46, 160, 120),
	dark = Color3.fromRGB(50, 45, 60),
}

local function part(parent: Instance, props: { [string]: any }): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

-- A part whose bottom sits at `y` (handy for walls and props).
local function block(parent, name, size: Vector3, x, y, z, color, extra: { [string]: any }?): BasePart
	local props = { Name = name, Size = size, CFrame = CFrame.new(x, y + size.Y / 2, z), Color = color }
	for k, v in extra or {} do
		props[k] = v
	end
	return part(parent, props)
end

local function folder(name: string, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function sign(parent: Instance, text: string, cf: CFrame, size: Vector2, color: Color3, textColor: Color3?)
	local board = part(parent, {
		Name = "Sign",
		Size = Vector3.new(size.X, size.Y, 0.4),
		CFrame = cf,
		Color = color,
		CanCollide = false,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = textColor or Color3.new(1, 1, 1)
	label.Text = text
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.04, 0)
	pad.PaddingRight = UDim.new(0.04, 0)
	pad.PaddingTop = UDim.new(0.1, 0)
	pad.PaddingBottom = UDim.new(0.1, 0)
	pad.Parent = label
	label.Parent = gui
	gui.Parent = board
	return board
end

local function tree(parent: Instance, x: number, z: number, scale: number, leafColor: Color3)
	local m = folder("Tree", parent)
	local h = 6 * scale
	part(m, {
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(h, 1.4 * scale, 1.4 * scale),
		CFrame = CFrame.new(x, h / 2, z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = C.trunk,
	})
	part(m, { Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.one * 7 * scale, CFrame = CFrame.new(x, h + 2 * scale, z), Color = leafColor, Material = Enum.Material.Grass })
	part(m, { Name = "Leaves2", Shape = Enum.PartType.Ball, Size = Vector3.one * 4.5 * scale, CFrame = CFrame.new(x + 2 * scale, h + 3.5 * scale, z - 1 * scale), Color = leafColor:Lerp(Color3.new(1, 1, 1), 0.12), Material = Enum.Material.Grass })
end

local function flowers(parent: Instance, x: number, z: number, rng: Random)
	local colors = { C.pink, C.yellow, C.red, C.purple, C.white }
	for _ = 1, 5 do
		local fx, fz = x + rng:NextNumber(-2, 2), z + rng:NextNumber(-2, 2)
		part(parent, { Name = "Stem", Size = Vector3.new(0.15, 0.8, 0.15), CFrame = CFrame.new(fx, 0.4, fz), Color = C.leaf, CanCollide = false })
		part(parent, { Name = "Flower", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.6, CFrame = CFrame.new(fx, 0.9, fz), Color = colors[rng:NextInteger(1, #colors)], CanCollide = false })
	end
end

local function bench(parent: Instance, x: number, z: number, rotY: number)
	local m = folder("Bench", parent)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(rotY), 0)
	part(m, { Name = "Seat", Size = Vector3.new(6, 0.4, 2), CFrame = base * CFrame.new(0, 1.6, 0), Color = C.wood })
	part(m, { Name = "Back", Size = Vector3.new(6, 1.6, 0.3), CFrame = base * CFrame.new(0, 2.6, 0.9), Color = C.wood })
	for _, sx in { -2.6, 2.6 } do
		part(m, { Name = "Leg", Size = Vector3.new(0.3, 1.4, 1.8), CFrame = base * CFrame.new(sx, 0.7, 0), Color = C.dark })
	end
end

local function fenceLine(parent: Instance, a: Vector3, b: Vector3, color: Color3)
	local dir = b - a
	local len = dir.Magnitude
	local n = math.max(1, math.floor(len / 6))
	for i = 0, n do
		local p = a + dir * (i / n)
		part(parent, { Name = "Post", Size = Vector3.new(0.6, 3.2, 0.6), CFrame = CFrame.new(p.X, 1.6, p.Z), Color = color })
	end
	local mid = (a + b) / 2
	for _, y in { 1.2, 2.5 } do
		part(parent, {
			Name = "Rail",
			Size = Vector3.new(0.3, 0.4, len),
			CFrame = CFrame.lookAt(Vector3.new(mid.X, y, mid.Z), Vector3.new(b.X, y, b.Z)),
			Color = color,
		})
	end
end

-- Four-walled building with a door gap on one side. `door` is "north" (-Z),
-- "west" (-X), etc. Returns the model.
local function building(parent: Instance, name: string, center: Vector3, size: Vector3, wallColor: Color3, roofColor: Color3, door: string, doorWidth: number)
	local m = folder(name, parent)
	local hx, hz, h = size.X / 2, size.Z / 2, size.Y
	local t = 1
	block(m, "Floor", Vector3.new(size.X, 0.3, size.Z), center.X, 0, center.Z, Color3.fromRGB(235, 200, 150), { Material = Enum.Material.WoodPlanks })
	local walls = {
		north = { Vector3.new(center.X, 0, center.Z - hz), Vector3.new(size.X, h, t), "x" },
		south = { Vector3.new(center.X, 0, center.Z + hz), Vector3.new(size.X, h, t), "x" },
		west = { Vector3.new(center.X - hx, 0, center.Z), Vector3.new(t, h, size.Z), "z" },
		east = { Vector3.new(center.X + hx, 0, center.Z), Vector3.new(t, h, size.Z), "z" },
	}
	for side, w in walls do
		local pos, wsize, axis = w[1], w[2], w[3]
		if side == door then
			local full = axis == "x" and wsize.X or wsize.Z
			local seg = (full - doorWidth) / 2
			for _, s in { -1, 1 } do
				local offset = (doorWidth / 2 + seg / 2) * s
				local segSize = axis == "x" and Vector3.new(seg, h, t) or Vector3.new(t, h, seg)
				local p = axis == "x" and pos + Vector3.new(offset, 0, 0) or pos + Vector3.new(0, 0, offset)
				block(m, "Wall", segSize, p.X, 0, p.Z, wallColor)
			end
			local lintel = axis == "x" and Vector3.new(doorWidth, h - 9, t) or Vector3.new(t, h - 9, doorWidth)
			block(m, "Lintel", lintel, pos.X, 9, pos.Z, wallColor)
		else
			block(m, "Wall", wsize, pos.X, 0, pos.Z, wallColor)
		end
	end
	block(m, "Roof", Vector3.new(size.X + 3, 1, size.Z + 3), center.X, h, center.Z, roofColor)
	-- Ceiling lights so interiors stay warm and welcoming. Kept soft because
	-- six of them overlap in each room.
	for lx = -1, 1 do
		for lz = -1, 1, 2 do
			local lamp = block(m, "CeilingLight", Vector3.new(3, 0.3, 3), center.X + lx * size.X / 3.2, h - 0.3, center.Z + lz * size.Z / 4.5, Color3.fromRGB(255, 240, 215), { Material = Enum.Material.Neon })
			local light = Instance.new("PointLight")
			light.Range = 18
			light.Brightness = 0.9
			light.Color = Color3.fromRGB(255, 244, 225)
			light.Parent = lamp
		end
	end
	-- Stripy awning trim
	for i = 0, 7 do
		local c = i % 2 == 0 and roofColor or C.white
		local x = center.X - hx - 1.5 + (size.X + 3) * (i + 0.5) / 8
		block(m, "Trim", Vector3.new((size.X + 3) / 8, 1.2, 0.4), x, h - 1.2, center.Z - hz - 1.6, c)
		block(m, "Trim", Vector3.new((size.X + 3) / 8, 1.2, 0.4), x, h - 1.2, center.Z + hz + 1.6, c)
	end
	return m
end

local function displayDog(parent: Instance, breedId: string, cf: CFrame)
	local breed = PetCatalog.get(breedId) :: PetCatalog.Breed
	local dog = DogRig.build({
		furColor = breed.furColor,
		accentColor = breed.accentColor,
		earStyle = breed.earStyle,
		scale = breed.scale,
		anchored = true,
	})
	dog.Name = "Display_" .. breedId
	dog:PivotTo(cf)
	dog.Parent = parent
end

local function buildPetStore(parent: Instance)
	local p = Places.get("pet_store") :: Places.Place
	local m = building(parent, "PetStore", p.center, Vector3.new(48, 14, 36), C.white, C.orange, "north", 12)
	sign(m, "Paws & Friends Pet Store", CFrame.new(p.center.X, 11.5, p.center.Z - 18.8), Vector2.new(22, 3), C.orange)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 0.4, 6)
	spawn.CFrame = CFrame.new(p.center.X, 0.35, p.center.Z - 2) * CFrame.Angles(0, 0, 0)
	spawn.Color = C.yellow
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = m

	block(m, "Counter", Vector3.new(14, 3.2, 2), p.center.X, 0, p.center.Z + 10, C.orange)
	block(m, "CounterTop", Vector3.new(14.4, 0.3, 2.4), p.center.X, 3.2, p.center.Z + 10, C.wood)

	-- Kennels with the three breeds on show.
	for i, breedId in PetCatalog.Order do
		local z = p.center.Z - 10 + (i - 1) * 9
		local x = p.center.X - 17
		block(m, "Pedestal", Vector3.new(6, 1.2, 6), x, 0, z, i == 1 and C.yellow or i == 2 and C.pink or C.blue)
		displayDog(m, breedId, CFrame.new(x, 1.2 + DogRig.GROUND_OFFSET, z) * CFrame.Angles(0, math.rad(-90), 0))
		local breed = PetCatalog.get(breedId) :: PetCatalog.Breed
		sign(m, breed.displayName, CFrame.new(x - 3.5, 4.5, z) * CFrame.Angles(0, math.rad(-90), 0), Vector2.new(5, 1.2), C.dark)
	end
	-- Right side: toys and bowls
	for i = 0, 2 do
		block(m, "Shelf", Vector3.new(2, 6, 7), p.center.X + 22, 0, p.center.Z - 8 + i * 9, C.wood)
		part(m, { Name = "Toy", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.2, CFrame = CFrame.new(p.center.X + 21.5, 6.6, p.center.Z - 8 + i * 9), Color = i == 1 and C.red or C.yellow })
	end
end

local function buildRangerHQ(parent: Instance)
	local p = Places.get("ranger_station") :: Places.Place
	local m = folder("RangerHQ", parent)
	local cx, cz = p.center.X, p.center.Z
	block(m, "Deck", Vector3.new(18, 0.6, 18), cx + 2, 0, cz, C.wood, { Material = Enum.Material.WoodPlanks })
	block(m, "BackWall", Vector3.new(1, 12, 18), cx + 10.5, 0.6, cz, C.green)
	block(m, "SideWall", Vector3.new(18, 12, 1), cx + 2, 0.6, cz - 8.5, C.green)
	block(m, "SideWall", Vector3.new(18, 12, 1), cx + 2, 0.6, cz + 8.5, C.green)
	block(m, "Roof", Vector3.new(21, 1, 21), cx + 2, 12.6, cz, C.wood)
	block(m, "RoofTrim", Vector3.new(21.4, 1.2, 0.5), cx + 2, 11.6, cz - 10.6, C.yellow)
	block(m, "RoofTrim", Vector3.new(21.4, 1.2, 0.5), cx + 2, 11.6, cz + 10.6, C.yellow)
	sign(m, "Ranger HQ  ♥  Help is always here", CFrame.new(cx - 7.2, 10, cz) * CFrame.Angles(0, math.rad(90), 0), Vector2.new(15, 2.4), C.green)
	block(m, "FlagPole", Vector3.new(0.4, 18, 0.4), cx - 6, 0, cz + 11, C.white)
	block(m, "Flag", Vector3.new(0.2, 2.5, 4), cx - 6, 15, cz + 13, C.yellow)

	-- Mission board: friendly adventure hub, not a classroom.
	local board = block(m, "MissionBoard", Vector3.new(0.6, 5, 7), cx + 9.6, 1.5, cz - 3, C.wood)
	CollectionService:AddTag(board, "MissionBoard")
	sign(m, "📜 MISSION BOARD", CFrame.new(cx + 9.2, 6, cz - 3) * CFrame.Angles(0, math.rad(90), 0), Vector2.new(6.6, 1.2), C.orange)
	for i = 0, 2 do
		block(m, "Note", Vector3.new(0.1, 1.2, 1.6), cx + 9.25, 2.4 + (i % 2) * 1.4, cz - 5.5 + i * 2.2, ({ C.yellow, C.pink, C.blue })[i + 1])
	end
	-- Campfire circle and logs (glowing "fire" is just a soft neon light).
	local fire = block(m, "Campfire", Vector3.new(1.6, 1, 1.6), cx - 2, 0.6, cz + 14, Color3.fromRGB(255, 140, 50), { Material = Enum.Material.Neon, Shape = Enum.PartType.Ball })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 170, 90)
	light.Range = 14
	light.Parent = fire
	for i = 0, 2 do
		local a = math.rad(i * 120)
		part(m, {
			Name = "Log",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(3.4, 1, 1),
			CFrame = CFrame.new(cx - 2 + math.cos(a) * 3, 0.5, cz + 14 + math.sin(a) * 3) * CFrame.Angles(0, -a + math.rad(90), 0),
			Color = C.trunk,
		})
	end
end

local function buildTreatShop(parent: Instance)
	local p = Places.get("treat_shop") :: Places.Place
	local m = building(parent, "TreatShop", p.center, Vector3.new(24, 12, 22), Color3.fromRGB(255, 236, 200), Color3.fromRGB(255, 159, 67), "east", 10)
	sign(m, "Bo's Treat Shop", CFrame.new(p.center.X + 12.8, 9.6, p.center.Z) * CFrame.Angles(0, math.rad(-90), 0), Vector2.new(13, 2.2), C.orange)
	block(m, "Counter", Vector3.new(2, 3.2, 10), p.center.X - 3, 0, p.center.Z, C.pink)
	block(m, "CounterTop", Vector3.new(2.4, 0.3, 10.4), p.center.X - 3, 3.2, p.center.Z, C.white)
	-- Treat displays
	local treatColors = { Color3.fromRGB(230, 190, 120), Color3.fromRGB(255, 140, 60), Color3.fromRGB(150, 95, 60) }
	for i, color in treatColors do
		local z = p.center.Z - 4 + (i - 1) * 4
		part(m, { Name = "Treat", Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 0.8, 1.2), CFrame = CFrame.new(p.center.X - 3, 3.75, z), Color = color })
	end
	for i = 0, 1 do
		block(m, "Shelf", Vector3.new(6, 5, 1.5), p.center.X - 4 + i * 8, 0, p.center.Z - 10, C.wood)
		block(m, "Jar", Vector3.new(1.2, 1.5, 1.2), p.center.X - 5 + i * 8, 5, p.center.Z - 10, Color3.fromRGB(200, 230, 255), { Material = Enum.Material.Glass, Transparency = 0.3 })
	end
end

local function buildDogPark(parent: Instance, rng: Random)
	local p = Places.get("dog_park") :: Places.Place
	local m = folder("DogPark", parent)
	local hx, hz = p.size.X / 2, p.size.Z / 2
	block(m, "Lawn", Vector3.new(p.size.X, 0.2, p.size.Z), p.center.X, 0, p.center.Z, C.grassLight, { Material = Enum.Material.Grass })
	local x0, x1, z0, z1 = p.center.X - hx, p.center.X + hx, p.center.Z - hz, p.center.Z + hz
	local gate = 8 -- half-width of the entrance on the east side, at the cross street
	fenceLine(m, Vector3.new(x0, 0, z0), Vector3.new(x1, 0, z0), C.white)
	fenceLine(m, Vector3.new(x0, 0, z1), Vector3.new(x1, 0, z1), C.white)
	fenceLine(m, Vector3.new(x0, 0, z0), Vector3.new(x0, 0, z1), C.white)
	fenceLine(m, Vector3.new(x1, 0, z0), Vector3.new(x1, 0, -30 - gate), C.white)
	fenceLine(m, Vector3.new(x1, 0, -30 + gate), Vector3.new(x1, 0, z1), C.white)
	sign(m, "Sunny Dog Park", CFrame.new(x1 + 1, 7, -30 - gate - 3) * CFrame.Angles(0, math.rad(-90), 0), Vector2.new(12, 2.6), C.green)
	block(m, "SignPost", Vector3.new(0.5, 6, 0.5), x1 + 1, 0, -30 - gate - 3, C.wood)
	sign(m, "Fetch Field: press Throw!", CFrame.new(p.center.X, 4, p.center.Z + 14) * CFrame.Angles(0, 0, 0), Vector2.new(10, 1.6), C.orange)
	block(m, "FetchPost", Vector3.new(0.4, 3.2, 0.4), p.center.X, 0, p.center.Z + 14.3, C.wood)

	tree(m, x0 + 8, z0 + 8, 1.2, C.leaf)
	tree(m, x0 + 10, z1 - 10, 1.0, C.leaf2)
	tree(m, x1 - 9, z0 + 9, 1.1, C.leaf2)
	tree(m, p.center.X - 22, p.center.Z + 4, 1.3, C.leaf) -- "the big tree"
	bench(m, -112, -8, 180)
	bench(m, -70, -12, 180)
	for _ = 1, 8 do
		flowers(m, rng:NextNumber(x0 + 3, x1 - 3), rng:NextNumber(z0 + 3, z0 + 10), rng)
	end
	-- Interactive props: ball bucket (fetch) and squeaky toys.
	local bucket = block(m, "BallBucket", Vector3.new(3, 2.4, 3), -60, 0, -22, C.blue, { Shape = Enum.PartType.Cylinder })
	bucket.CFrame = CFrame.new(-60, 1.2, -22) * CFrame.Angles(0, 0, math.rad(90))
	bucket.Size = Vector3.new(2.4, 3, 3)
	CollectionService:AddTag(bucket, "FetchStation")
	for i = 0, 3 do
		part(m, { Name = "Ball", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, CFrame = CFrame.new(-60.6 + (i % 2) * 1.2, 2.6, -22.6 + math.floor(i / 2) * 1.2), Color = Color3.fromRGB(200, 255, 60) })
	end
	sign(m, "🎾 Grab a ball!", CFrame.new(-60, 4.6, -22) * CFrame.Angles(0, math.rad(-90), 0), Vector2.new(4.5, 1), C.green)
	local duck = part(m, { Name = "SqueakyDuck", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.8, CFrame = CFrame.new(-96, 0.9, -56), Color = C.yellow })
	part(m, { Name = "DuckHead", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.1, CFrame = CFrame.new(-96, 2.1, -56.5), Color = C.yellow, CanCollide = false })
	part(m, { Name = "DuckBeak", Size = Vector3.new(0.5, 0.3, 0.6), CFrame = CFrame.new(-96, 2.0, -57.2), Color = C.orange, CanCollide = false })
	CollectionService:AddTag(duck, "PetToy")
	local bone = block(m, "ChewBone", Vector3.new(3, 0.6, 0.8), -74, 0, -62, C.white)
	part(m, { Name = "BoneEnd", Shape = Enum.PartType.Ball, Size = Vector3.one, CFrame = CFrame.new(-75.6, 0.5, -62), Color = C.white })
	part(m, { Name = "BoneEnd", Shape = Enum.PartType.Ball, Size = Vector3.one, CFrame = CFrame.new(-72.4, 0.5, -62), Color = C.white })
	CollectionService:AddTag(bone, "PetToy")

	-- Agility-style toys in the park
	part(m, { Name = "Tire", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 4, 4), CFrame = CFrame.new(-100, 2, -60), Color = C.dark })
	part(m, { Name = "BigBall", Shape = Enum.PartType.Ball, Size = Vector3.one * 3, CFrame = CFrame.new(-78, 1.5, -58), Color = C.red })
end

local function buildSalon(parent: Instance)
	local p = Places.get("salon") :: Places.Place
	local m = building(parent, "GroomingSalon", p.center, Vector3.new(44, 13, 34), C.pink, C.purple, "west", 12)
	sign(m, "Fluff & Puff Salon", CFrame.new(p.center.X - 22.8, 10.8, p.center.Z) * CFrame.Angles(0, math.rad(90), 0), Vector2.new(18, 2.6), C.purple)
	block(m, "Counter", Vector3.new(2, 3.2, 12), p.center.X + 10, 0, p.center.Z, C.purple)
	for i, z in { p.center.Z - 11, p.center.Z + 11 } do
		block(m, "Tub", Vector3.new(7, 2.5, 5), p.center.X + 2, 0, z, C.white)
		block(m, "Water", Vector3.new(6, 0.3, 4), p.center.X + 2, 2.3, z, Color3.fromRGB(150, 220, 255), { Material = Enum.Material.Glass, Transparency = 0.3, CanCollide = false })
		block(m, "Mirror", Vector3.new(6, 5, 0.3), p.center.X + 2, 3, z + (i == 1 and -2.9 or 2.9), Color3.fromRGB(200, 230, 255), { Material = Enum.Material.Glass, Reflectance = 0.3 })
		local station = block(m, "GroomStation", Vector3.new(7, 0.6, 5), p.center.X + 2, 2.5, z, C.white, { Transparency = 1, CanCollide = false })
		local spot = Instance.new("Attachment")
		spot.Name = "DogSpot"
		spot.Parent = station
		spot.WorldPosition = Vector3.new(p.center.X + 2, 2.4 + DogRig.GROUND_OFFSET, z)
		CollectionService:AddTag(station, "GroomStation")
		sign(m, "🛁 Spa Tub", CFrame.new(p.center.X + 2, 6.5, z + (i == 1 and -2.7 or 2.7)) * CFrame.Angles(0, i == 1 and 0 or math.rad(180), 0), Vector2.new(4, 1), C.purple)
	end
	for i = 0, 3 do
		part(m, { Name = "Bubble", Shape = Enum.PartType.Ball, Size = Vector3.one * (0.6 + i * 0.2), CFrame = CFrame.new(p.center.X + 1 + i, 3.4 + i * 0.6, p.center.Z - 11), Color = Color3.new(1, 1, 1), Transparency = 0.4, CanCollide = false })
	end
end

local function hurdle(parent: Instance, x: number, z: number, alongX: boolean)
	local width = 8
	local bar = alongX and Vector3.new(0.6, 0.6, width) or Vector3.new(width, 0.6, 0.6)
	block(parent, "HurdleBar", bar, x, 1.2, z, C.red)
	block(parent, "HurdleBase", alongX and Vector3.new(0.6, 1.2, width) or Vector3.new(width, 1.2, 0.6), x, 0, z, C.white, { Transparency = 0.2 })
	for _, s in { -1, 1 } do
		local px = alongX and x or x + s * width / 2
		local pz = alongX and z + s * width / 2 or z
		block(parent, "HurdlePost", Vector3.new(0.6, 2.4, 0.6), px, 0, pz, C.white)
	end
end

local function ring(parent: Instance, index: number, x: number, z: number, alongX: boolean)
	local w, h = 9, 8
	local color = ({ C.yellow, C.pink, C.blue, C.purple })[((index - 1) % 4) + 1]
	local function bar(size, ox, oy, oz)
		part(parent, { Name = "RingBar", Size = size, CFrame = CFrame.new(x + ox, oy, z + oz), Color = color, Material = Enum.Material.Neon, CanCollide = false })
	end
	if alongX then
		bar(Vector3.new(0.6, h, 0.6), 0, h / 2, -w / 2)
		bar(Vector3.new(0.6, h, 0.6), 0, h / 2, w / 2)
		bar(Vector3.new(0.6, 0.6, w), 0, h, 0)
	else
		bar(Vector3.new(0.6, h, 0.6), -w / 2, h / 2, 0)
		bar(Vector3.new(0.6, h, 0.6), w / 2, h / 2, 0)
		bar(Vector3.new(w, 0.6, 0.6), 0, h, 0)
	end
	local trigger = part(parent, {
		Name = "Ring" .. index,
		Size = alongX and Vector3.new(1.5, h, w) or Vector3.new(w, h, 1.5),
		CFrame = CFrame.new(x, h / 2, z),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	trigger:SetAttribute("RingIndex", index)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(60, 60)
	gui.StudsOffset = Vector3.new(0, h / 2 + 1.5, 0)
	gui.MaxDistance = 120
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Text = tostring(index)
	label.Parent = gui
	gui.Parent = trigger
end

local function buildAgility(parent: Instance)
	local p = Places.get("agility") :: Places.Place
	local m = folder("Agility", parent)
	block(m, "Turf", Vector3.new(p.size.X, 0.2, p.size.Z), p.center.X, 0, p.center.Z, Color3.fromRGB(120, 200, 245), { Material = Enum.Material.SmoothPlastic })
	-- Lanes
	block(m, "Lane1", Vector3.new(90, 0.25, 10), 0, 0, -100, Color3.fromRGB(240, 120, 90))
	block(m, "Lane2", Vector3.new(90, 0.25, 10), 0, 0, -136, Color3.fromRGB(240, 120, 90))
	block(m, "Turn", Vector3.new(10, 0.25, 46), 40, 0, -118, Color3.fromRGB(240, 120, 90))

	local start = block(m, "AgilityStart", Vector3.new(8, 0.4, 9), -40, 0.1, -100, Color3.fromRGB(60, 220, 120), { Material = Enum.Material.Neon, CanCollide = false })
	sign(m, "START", CFrame.new(-40, 6, -95) * CFrame.Angles(0, math.rad(180), 0), Vector2.new(6, 1.8), Color3.fromRGB(60, 200, 110))
	start:SetAttribute("Role", "start")

	hurdle(m, -27, -100, true)
	hurdle(m, -16, -100, true)
	ring(m, 1, -6, -100, true)
	hurdle(m, 5, -100, true)
	ring(m, 2, 16, -100, true)
	for i = 0, 4 do
		local wz = -100 + (i % 2 == 0 and -2.2 or 2.2)
		block(m, "WeavePole", Vector3.new(0.6, 4, 0.6), 22 + i * 3, 0, wz, i % 2 == 0 and C.yellow or C.white)
	end
	ring(m, 3, 40, -118, false)
	hurdle(m, 28, -136, true)
	hurdle(m, 16, -136, true)
	ring(m, 4, 2, -136, true)
	-- Tunnel
	block(m, "TunnelWall", Vector3.new(6, 6, 0.8), -12, 0, -140.6, C.purple)
	block(m, "TunnelWall", Vector3.new(6, 6, 0.8), -12, 0, -131.4, C.purple)
	block(m, "TunnelRoof", Vector3.new(6, 0.8, 10), -12, 6, -136, C.purple)

	local finish = folder("Finish", m)
	for i = 0, 3 do
		for j = 0, 3 do
			block(finish, "Check", Vector3.new(2, 0.3, 2.25), -33 + i * 2, 0.15, -140.5 + j * 2.25, (i + j) % 2 == 0 and C.white or C.dark, { CanCollide = false })
		end
	end
	block(m, "AgilityFinish", Vector3.new(8, 4, 9), -30, 0.1, -136, C.white, { Transparency = 1, CanCollide = false })
	sign(m, "FINISH", CFrame.new(-30, 7, -141) * CFrame.Angles(0, math.rad(180), 0), Vector2.new(6, 1.8), C.dark)

	sign(m, "Training Grounds", CFrame.new(-20, 8, -89) * CFrame.Angles(0, math.rad(180), 0), Vector2.new(14, 2.6), C.blue)

	-- Trick training mat in the infield.
	local mat = block(m, "TrainingMat", Vector3.new(10, 0.3, 8), -18, 0.1, -118, C.purple)
	CollectionService:AddTag(mat, "TrainingMat")
	for i = 0, 3 do
		block(m, "MatStar", Vector3.new(1, 0.32, 1), -21 + i * 2, 0.1, -118, C.yellow, { Material = Enum.Material.Neon })
	end
	sign(m, "⭐ Trick Training", CFrame.new(-18, 5, -122.5) * CFrame.Angles(0, math.rad(180), 0), Vector2.new(7, 1.4), C.purple)
	block(m, "MatSignPost", Vector3.new(0.4, 4.2, 0.4), -18, 0, -122.7, C.wood)
	block(m, "SignPost", Vector3.new(0.5, 7, 0.5), -20, 0, -89, C.wood)
	-- Bleachers
	for i = 0, 2 do
		block(m, "Bleacher", Vector3.new(16, 1, 2.4), 10, i * 1, -146 - i * 2.4 + 2.4, i % 2 == 0 and C.blue or C.white)
	end
end

-- Frisbee Field, east of the Training Grounds. Players throw from the line
-- at the west end toward +X. Markings don't collide or block raycasts, so
-- the disc flies over them; only real obstacles (trees, buildings) stop it.
local function buildFrisbeeField(parent: Instance)
	local p = Places.get("frisbee_field") :: Places.Place
	local m = folder("FrisbeeField", parent)
	local hx, hz = p.size.X / 2, p.size.Z / 2
	local x0, x1, z0, z1 = p.center.X - hx, p.center.X + hx, p.center.Z - hz, p.center.Z + hz
	local mark = { CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }
	block(m, "Lawn", Vector3.new(p.size.X, 0.2, p.size.Z), p.center.X, 0, p.center.Z, C.grassLight, { Material = Enum.Material.Grass })
	-- Mowing stripes
	for i = 0, math.floor(p.size.X / 8) - 1, 2 do
		block(m, "Stripe", Vector3.new(8, 0.21, p.size.Z), x0 + 4 + i * 8, 0, p.center.Z, C.grass, { Material = Enum.Material.Grass, CanCollide = false, CanQuery = false, CanTouch = false })
	end
	local lineX = x0 + 6
	block(m, "ThrowLine", Vector3.new(0.6, 0.24, p.size.Z - 6), lineX, 0, p.center.Z, C.white, mark)
	-- Distance markers every 20 studs: cones at both sidelines and a number.
	for i, d in { 20, 40, 60 } do
		local x = lineX + d
		block(m, "DistanceLine", Vector3.new(0.4, 0.23, p.size.Z - 6), x, 0, p.center.Z, C.white, { CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Transparency = 0.5 })
		for _, z in { z0 + 2, z1 - 2 } do
			block(m, "Cone", Vector3.new(1, 1.4, 1), x, 0, z, C.orange, mark)
		end
		sign(m, `{d}`, CFrame.new(x, 2.6, z1 - 2) * CFrame.Angles(0, math.rad(180), 0), Vector2.new(2.4, 1.4), ({ C.yellow, C.orange, C.red })[i])
	end
	for _, corner in { Vector3.new(x0, 0, z0), Vector3.new(x0, 0, z1), Vector3.new(x1, 0, z0), Vector3.new(x1, 0, z1) } do
		block(m, "FlagPole", Vector3.new(0.3, 5, 0.3), corner.X, 0, corner.Z, C.white)
		block(m, "Flag", Vector3.new(0.1, 1.2, 1.8), corner.X, 3.7, corner.Z + 0.9, C.pink, { CanCollide = false })
	end
	sign(m, "🥏 Frisbee Field", CFrame.new(x0 - 2, 7, p.center.Z + 10) * CFrame.Angles(0, math.rad(90), 0), Vector2.new(13, 2.6), C.pink)
	block(m, "SignPost", Vector3.new(0.5, 6, 0.5), x0 - 2, 0, p.center.Z + 10, C.wood)

	-- The frisbee stack: "Grab a frisbee" starts the game.
	local tx, tz = x0 + 3, p.center.Z - 8
	block(m, "FrisbeeTable", Vector3.new(3, 2.4, 3), tx, 0, tz, C.wood)
	local colors = { C.pink, C.yellow, C.blue, C.green }
	for i, color in colors do
		part(m, {
			Name = "StackedFrisbee",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.25, 2, 2),
			CFrame = CFrame.new(tx, 2.53 + (i - 1) * 0.26, tz) * CFrame.Angles(0, 0, math.rad(90)),
			Color = color,
			CanCollide = false,
		})
	end
	local station = block(m, "FrisbeeStation", Vector3.new(3.2, 3.6, 3.2), tx, 0, tz, C.white, { Transparency = 1, CanCollide = false })
	CollectionService:AddTag(station, "FrisbeeStation")
	sign(m, "🥏 Grab a frisbee!", CFrame.new(tx, 5.2, tz) * CFrame.Angles(0, math.rad(90), 0), Vector2.new(5, 1.1), C.pink)
	bench(m, x0 + 3, p.center.Z + 6, 90)
end

local function buildPaths(parent: Instance)
	local m = folder("Paths", parent)
	block(m, "Avenue", Vector3.new(10, 0.15, 124), 0, 0, -28, C.path)
	block(m, "CrossStreet", Vector3.new(114, 0.15, 10), 6, 0, -30, C.path)
	block(m, "StationPath", Vector3.new(10, 0.15, 6), 9, 0, 5, C.path)
	block(m, "TreatShopPath", Vector3.new(20, 0.15, 6), -14, 0, 14, C.path)

	-- Signpost at the crossroads, readable when walking out of the Pet Store.
	block(m, "SignPost", Vector3.new(0.6, 12, 0.6), 7, 0, -20, C.wood)
	local lines = {
		{ "▲ Training Grounds", C.blue },
		{ "◀ Sunny Dog Park", C.green },
		{ "Fluff & Puff Salon ▶", C.pink },
	}
	for i, line in lines do
		sign(m, line[1], CFrame.new(7, 11 - i * 1.7, -19.6) * CFrame.Angles(0, math.rad(180), 0), Vector2.new(7.5, 1.4), line[2])
	end
	sign(m, "◀ Bo's Treat Shop", CFrame.new(-7, 4.5, 20) * CFrame.Angles(0, math.rad(180), 0), Vector2.new(6.5, 1.3), C.orange)
	sign(m, "Ranger HQ ▶", CFrame.new(7, 4.5, 20) * CFrame.Angles(0, math.rad(180), 0), Vector2.new(6.5, 1.3), C.green)
	for z = 24, -84, -18 do
		for _, x in { -7, 7 } do
			block(m, "LampPost", Vector3.new(0.5, 8, 0.5), x, 0, z, C.dark)
			part(m, { Name = "Lamp", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.4, CFrame = CFrame.new(x, 8.6, z), Color = C.yellow, Material = Enum.Material.Neon })
		end
	end
end

local function scatter(parent: Instance, rng: Random)
	local m = folder("Scenery", parent)
	local placed = 0
	local tries = 0
	while placed < 46 and tries < 600 do
		tries += 1
		-- Stay well inside WorldBounds.LANDING so wrapped players never land in a tree.
		local x, z = rng:NextNumber(-200, 200), rng:NextNumber(-200, 160)
		local pos = Vector3.new(x, 0, z)
		local onPath = math.abs(x) < 10 or math.abs(z + 30) < 9
		local inPlace = false
		for id in Places.All do
			if Places.isInside(id, pos, 8) then
				inPlace = true
			end
		end
		if not onPath and not inPlace then
			if rng:NextNumber() < 0.6 then
				tree(m, x, z, rng:NextNumber(0.8, 1.4), rng:NextNumber() < 0.5 and C.leaf or C.leaf2)
			else
				flowers(m, x, z, rng)
			end
			placed += 1
		end
	end
end

-- Single source of truth for world lighting. Keep default.project.json's
-- Lighting block in sync so Studio edit mode matches what players see.
-- (Lighting.Technology can't be set from scripts; it lives in the project file.)
local function applyLighting()
	Lighting.ClockTime = 13
	Lighting.Brightness = 2
	Lighting.ExposureCompensation = -0.15
	Lighting.OutdoorAmbient = Color3.fromRGB(120, 120, 130)
	Lighting.Ambient = Color3.fromRGB(40, 40, 48)
end

function World.init(_services)
	applyLighting()
	local existing = workspace:FindFirstChild("World")
	if existing then
		root = existing :: Model
		return
	end
	root = Instance.new("Model")
	root.Name = "World"

	local baseplate = workspace:FindFirstChild("Baseplate")
	if not baseplate then
		baseplate = Instance.new("Part")
		baseplate.Name = "Baseplate"
		baseplate.Anchored = true
		baseplate.Locked = true
		baseplate.Parent = workspace
	end
	if baseplate and baseplate:IsA("BasePart") then
		-- The world is built on a floor whose top is at Y = 0.
		local size = WorldBounds.HALF_SIZE * 2
		baseplate.Size = Vector3.new(size, 20, size)
		baseplate.CFrame = CFrame.new(0, -10, 0)
		baseplate.Color = C.grass
		baseplate.Material = Enum.Material.Grass
	end
	local rng = Random.new(7)
	buildPaths(root)
	buildPetStore(root)
	buildRangerHQ(root)
	buildTreatShop(root)
	buildDogPark(root, rng)
	buildSalon(root)
	buildAgility(root)
	buildFrisbeeField(root)
	scatter(root, rng)
	root.Parent = workspace
end

-- Safety net for the wrap-around edges (the client wraps its own character):
-- anyone who still ends up below the floor is put back on it instead of dying.
-- (Don't set workspace.FallenPartsDestroyHeight here: scripts can't write it,
-- and the error would abort every later service's start(). Its default of
-- -500 is far below RESCUE_HEIGHT anyway.)
function World.start()
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if hrp and hrp.Position.Y < WorldBounds.RESCUE_HEIGHT then
					hrp.AssemblyLinearVelocity = Vector3.zero
					character:PivotTo(CFrame.new(WorldBounds.rescue(hrp.Position)) * hrp.CFrame.Rotation)
				end
			end
		end
	end)
end

function World.getAgilityCourse(): Instance?
	return root and root:FindFirstChild("Agility", true)
end

return World
