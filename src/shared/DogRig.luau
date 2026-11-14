--[[
	DogRig: builds the one shared dog rig ("dog_basic") out of parts, so the
	game needs no uploaded assets. Used by the server (real pets, display dogs)
	and the client (adoption previews in ViewportFrames).

	Rig contract (what other systems may rely on):
	  Model.PrimaryPart = "Root" (invisible, the physics/follow part)
	  Motor6D "BodyJoint"  Root -> Body   (hop / sit)
	  Motor6D "Neck"       Body -> Head
	  Motor6D "Tail"       Body -> Tail
	  Motor6D "LegFL","LegFR","LegBL","LegBR"  Body -> legs
	  Attachments: Head.HatAttachment, Head.CollarAttachment, Body.BackAttachment,
	               Root.RootAttachment, Head.MouthAttachment
	  Parts tagged with attribute FurRole = "main" | "accent" get recolored.
	The dog faces -Z (its LookVector). Root sits 1.5 studs above the ground.
]]

local DogRig = {}

DogRig.GROUND_OFFSET = 1.5 -- Root height above the floor at scale 1

local function part(props: { [string]: any }): BasePart
	local p = Instance.new("Part")
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = true
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

local function motor(name: string, p0: BasePart, p1: BasePart, c0: CFrame, c1: CFrame): Motor6D
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = p0
	m.Part1 = p1
	m.C0 = c0
	m.C1 = c1
	m.Parent = p0
	return m
end

local function attach(parentPart: BasePart, name: string, cf: CFrame)
	local a = Instance.new("Attachment")
	a.Name = name
	a.CFrame = cf
	a.Parent = parentPart
	return a
end

export type BuildOptions = {
	furColor: Color3,
	accentColor: Color3,
	earStyle: string?,
	scale: number?,
	anchored: boolean?,
}

function DogRig.build(opts: BuildOptions): Model
	local s = opts.scale or 1
	local fur = opts.furColor
	local accent = opts.accentColor
	local model = Instance.new("Model")
	model.Name = "Dog"

	local function v(x, y, z)
		return Vector3.new(x, y, z) * s
	end
	local function cf(x, y, z)
		return CFrame.new(x * s, y * s, z * s)
	end

	local root = part({ Name = "Root", Size = v(1.4, 1.2, 2.4), Transparency = 1, Massless = false, CastShadow = false })
	root.Parent = model
	model.PrimaryPart = root
	attach(root, "RootAttachment", CFrame.new())

	local body = part({ Name = "Body", Size = v(1.5, 1.3, 2.6), Color = fur })
	body:SetAttribute("FurRole", "main")
	body.Parent = model
	local belly = part({ Name = "Belly", Size = v(1.2, 0.3, 2.0), Color = accent })
	belly:SetAttribute("FurRole", "accent")
	belly.CFrame = body.CFrame * cf(0, -0.55, 0)
	belly.Parent = model
	weld(body, belly)
	motor("BodyJoint", root, body, CFrame.new(), CFrame.new())
	attach(body, "BackAttachment", cf(0, 0.66, 0.1))

	-- Head
	local head = part({ Name = "Head", Size = v(1.25, 1.15, 1.15), Color = fur })
	head:SetAttribute("FurRole", "main")
	head.Parent = model
	motor("Neck", body, head, cf(0, 0.55, -1.15), cf(0, -0.2, 0.4))
	head.CFrame = body.CFrame * cf(0, 0.55, -1.15) * cf(0, -0.2, 0.4):Inverse()
	attach(head, "HatAttachment", cf(0, 0.58, 0.05))
	attach(head, "CollarAttachment", cf(0, -0.5, 0.35))
	attach(head, "MouthAttachment", cf(0, -0.35, -0.95))

	local snout = part({ Name = "Snout", Size = v(0.75, 0.5, 0.6), Color = accent })
	snout:SetAttribute("FurRole", "accent")
	snout.CFrame = head.CFrame * cf(0, -0.22, -0.75)
	snout.Parent = model
	weld(head, snout)

	local nose = part({ Name = "Nose", Shape = Enum.PartType.Ball, Size = v(0.28, 0.28, 0.28), Color = Color3.fromRGB(35, 30, 35) })
	nose.CFrame = snout.CFrame * cf(0, 0.12, -0.3)
	nose.Parent = model
	weld(head, nose)

	for _, side in { -1, 1 } do
		local eye = part({ Name = "Eye", Shape = Enum.PartType.Ball, Size = v(0.24, 0.24, 0.24), Color = Color3.fromRGB(30, 25, 35) })
		eye.CFrame = head.CFrame * cf(0.3 * side, 0.18, -0.56)
		eye.Parent = model
		weld(head, eye)
		local shine = part({ Name = "EyeShine", Shape = Enum.PartType.Ball, Size = v(0.08, 0.08, 0.08), Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon })
		shine.CFrame = eye.CFrame * cf(0.04, 0.05, -0.1)
		shine.Parent = model
		weld(head, shine)

		local ear
		if opts.earStyle == "pointy" then
			ear = part({ Name = "Ear",Size = v(0.2, 0.6, 0.42), Color = fur })
			ear.CFrame = head.CFrame * cf(0.38 * side, 0.75, 0.05) * CFrame.Angles(0, 0, math.rad(-12 * side))
		else
			ear = part({ Name = "Ear", Size = v(0.18, 0.8, 0.5), Color = accent })
			ear.CFrame = head.CFrame * cf(0.68 * side, 0.05, 0.05) * CFrame.Angles(0, 0, math.rad(12 * side))
		end
		ear:SetAttribute("FurRole", opts.earStyle == "pointy" and "main" or "accent")
		ear.Parent = model
		weld(head, ear)
	end

	-- Legs: pivot at the hip so the client can swing them.
	local legs = {
		LegFL = Vector3.new(-0.45, -0.5, -0.85),
		LegFR = Vector3.new(0.45, -0.5, -0.85),
		LegBL = Vector3.new(-0.45, -0.5, 0.85),
		LegBR = Vector3.new(0.45, -0.5, 0.85),
	}
	for name, hip in legs do
		local leg = part({ Name = name, Size = v(0.42, 1.0, 0.42), Color = fur })
		leg:SetAttribute("FurRole", "main")
		leg.Parent = model
		motor(name, body, leg, cf(hip.X, hip.Y, hip.Z), cf(0, 0.5, 0))
		leg.CFrame = body.CFrame * cf(hip.X, hip.Y, hip.Z) * cf(0, 0.5, 0):Inverse()
		local paw = part({ Name = "Paw", Size = v(0.46, 0.18, 0.5), Color = accent })
		paw:SetAttribute("FurRole", "accent")
		paw.CFrame = leg.CFrame * cf(0, -0.45, -0.03)
		paw.Parent = model
		weld(leg, paw)
	end

	-- Tail: pivot at the base, angled up.
	local tail = part({ Name = "Tail", Size = v(0.25, 0.25, 0.9), Color = fur })
	tail:SetAttribute("FurRole", "main")
	tail.Parent = model
	local tailC0 = cf(0, 0.45, 1.25) * CFrame.Angles(math.rad(-40), 0, 0)
	motor("Tail", body, tail, tailC0, cf(0, 0, -0.45))
	tail.CFrame = body.CFrame * tailC0 * cf(0, 0, -0.45):Inverse()
	local tip = part({ Name = "TailTip", Size = v(0.26, 0.26, 0.3), Color = accent })
	tip:SetAttribute("FurRole", "accent")
	tip.CFrame = tail.CFrame * cf(0, 0, 0.45)
	tip.Parent = model
	weld(tail, tip)

	if opts.anchored then
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
	end

	return model
end

-- Recolor fur parts. Accent is derived when not given.
function DogRig.setFur(model: Model, main: Color3, accent: Color3?)
	local acc = accent or main:Lerp(Color3.new(1, 1, 1), 0.45)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local role = d:GetAttribute("FurRole")
			if role == "main" then
				d.Color = main
			elseif role == "accent" then
				d.Color = acc
			end
		end
	end
end

return DogRig
