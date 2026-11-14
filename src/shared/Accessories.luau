--[[
	Accessories: turns an item's `visual` spec into parts welded to an
	attachment. Knows nothing about prices, ownership, or who equipped it.

	Each builder returns a list of (part, offset) pairs, where offset is
	relative to the attachment's frame.
]]

local Accessories = {}

local function newPart(props: { [string]: any }): BasePart
	local p = Instance.new("Part")
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

type Piece = { part: BasePart, offset: CFrame }

local Builders: { [string]: (visual: { [string]: any }, s: number) -> { Piece } } = {}

Builders.collar = function(visual, s)
	local band = newPart({
		Name = "Collar",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.24, 1.3, 1.3) * s,
		Color = visual.color,
		Material = visual.neon and Enum.Material.Neon or Enum.Material.SmoothPlastic,
	})
	local tag = newPart({
		Name = "Tag",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.3, 0.3, 0.3) * s,
		Color = visual.tag or Color3.fromRGB(255, 209, 102),
		Material = Enum.Material.Neon,
	})
	return {
		{ part = band, offset = CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, 0, 0) },
		{ part = tag, offset = CFrame.new(0, -0.62 * s, -0.25 * s) },
	}
end

Builders.party_hat = function(visual, s)
	local pieces = {}
	local tiers = { { 0.9, 0.25 }, { 0.65, 0.35 }, { 0.4, 0.6 }, { 0.2, 0.8 } }
	for i, t in tiers do
		local p = newPart({
			Name = "HatTier" .. i,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.25, t[1], t[1]) * s,
			Color = visual.color,
		})
		table.insert(pieces, { part = p, offset = CFrame.new(0, t[2] * s, 0) * CFrame.Angles(0, 0, math.rad(90)) })
	end
	local pom = newPart({ Name = "Pom", Shape = Enum.PartType.Ball, Size = Vector3.new(0.3, 0.3, 0.3) * s, Color = visual.dot or Color3.new(1, 1, 1) })
	table.insert(pieces, { part = pom, offset = CFrame.new(0, 1.0 * s, 0) })
	return pieces
end

Builders.cap = function(visual, s)
	local dome = newPart({ Name = "CapDome", Shape = Enum.PartType.Ball, Size = Vector3.new(1.15, 1.15, 1.15) * s, Color = visual.color })
	local brim = newPart({ Name = "CapBrim", Size = Vector3.new(0.9, 0.08, 0.6) * s, Color = visual.brim or visual.color })
	local button = newPart({ Name = "CapButton", Shape = Enum.PartType.Ball, Size = Vector3.new(0.18, 0.18, 0.18) * s, Color = visual.brim or Color3.new(1, 1, 1) })
	return {
		{ part = dome, offset = CFrame.new(0, -0.15 * s, 0) },
		{ part = brim, offset = CFrame.new(0, -0.12 * s, -0.75 * s) },
		{ part = button, offset = CFrame.new(0, 0.45 * s, 0) },
	}
end

Builders.vest = function(visual, s)
	local vest = newPart({ Name = "Vest", Size = Vector3.new(1.62, 0.35, 1.7) * s, Color = visual.color })
	local trim = newPart({ Name = "VestTrim", Size = Vector3.new(1.64, 0.37, 0.25) * s, Color = visual.trim or Color3.new(1, 1, 1) })
	local badge = newPart({ Name = "Badge", Shape = Enum.PartType.Ball, Size = Vector3.new(0.3, 0.3, 0.3) * s, Color = visual.trim or Color3.new(1, 1, 1), Material = Enum.Material.Neon })
	return {
		{ part = vest, offset = CFrame.new(0, -0.05 * s, 0) },
		{ part = trim, offset = CFrame.new(0, -0.05 * s, -0.4 * s) },
		{ part = badge, offset = CFrame.new(0.5 * s, 0.1 * s, 0.4 * s) },
	}
end

function Accessories.canBuild(visual: { [string]: any }?): boolean
	return visual ~= nil and Builders[visual.kind] ~= nil
end

-- Builds the visual and welds it to `attachment`. Returns the container model.
function Accessories.attach(container: Instance, attachment: Attachment, visual: { [string]: any }, scale: number?): Model?
	local builder = Builders[visual.kind]
	if not builder then
		return nil
	end
	local s = scale or 1
	local holder = Instance.new("Model")
	holder.Name = "Cosmetic"
	local base = attachment.WorldCFrame
	local anchor = attachment.Parent :: BasePart
	for _, piece in builder(visual, s) do
		piece.part.CFrame = base * piece.offset
		piece.part.Anchored = anchor.Anchored
		piece.part.Parent = holder
		local w = Instance.new("WeldConstraint")
		w.Part0 = anchor
		w.Part1 = piece.part
		w.Parent = piece.part
	end
	holder.Parent = container
	return holder
end

return Accessories
