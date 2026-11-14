--[[
	NPCService: builds NPC models from content and registers anything tagged
	"Interactable_NPC" (attributes NpcId, LocationId). Designers can also drop
	a hand-made model in the world with that tag and attributes; it will get
	a ProximityPrompt and work the same way.

	NPC models hold NO progress. Per-player state lives in each Profile.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Content = require(script.Parent.Parent.Content)

local TAG = "Interactable_NPC"
local PROMPT_DISTANCE = 10

local NPC = {}
NPC.TAG = TAG
local S
local folder: Folder

local function addPart(model: Model, props: { [string]: any }, weldTo: BasePart): BasePart
	local p = Instance.new("Part")
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.Anchored = true
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = model
	if weldTo then
		local w = Instance.new("WeldConstraint")
		w.Part0 = weldTo
		w.Part1 = p
		w.Parent = p
	end
	return p
end

-- Simple blocky figure. Used when avatar loading isn't available.
local function blockyModel(look): Model
	local model = Instance.new("Model")
	local root = addPart(model, { Name = "HumanoidRootPart", Size = Vector3.new(2, 2, 1), Transparency = 1 }, nil :: any)
	root.CFrame = CFrame.new(0, 3, 0)
	model.PrimaryPart = root
	local torso = addPart(model, { Name = "Torso", Size = Vector3.new(2, 2, 1), Color = look.shirt, CFrame = CFrame.new(0, 3, 0) }, root)
	addPart(model, { Name = "Head", Size = Vector3.new(1.3, 1.3, 1.3), Color = look.skin, CFrame = CFrame.new(0, 4.65, 0) }, root)
	addPart(model, { Name = "LeftArm", Size = Vector3.new(0.9, 2, 0.9), Color = look.shirt, CFrame = CFrame.new(-1.45, 3, 0) }, torso)
	addPart(model, { Name = "RightArm", Size = Vector3.new(0.9, 2, 0.9), Color = look.shirt, CFrame = CFrame.new(1.45, 3, 0) }, torso)
	addPart(model, { Name = "LeftLeg", Size = Vector3.new(0.95, 2, 1), Color = look.pants, CFrame = CFrame.new(-0.5, 1, 0) }, torso)
	addPart(model, { Name = "RightLeg", Size = Vector3.new(0.95, 2, 1), Color = look.pants, CFrame = CFrame.new(0.5, 1, 0) }, torso)
	return model
end

local function avatarModel(look): Model?
	local ok, model = pcall(function()
		local desc = Instance.new("HumanoidDescription")
		desc.HeadColor = look.skin
		desc.TorsoColor = look.shirt
		desc.LeftArmColor = look.shirt
		desc.RightArmColor = look.shirt
		desc.LeftLegColor = look.pants
		desc.RightLegColor = look.pants
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok then
		warn(`[NPC] avatar build failed, using blocky NPC: {model}`)
		return nil
	end
	return model
end

local function decorate(model: Model, def)
	local head = model:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local look = def.appearance
	local hair = addPart(model, {
		Name = "Hair",
		Size = Vector3.new(1.25, 0.45, 1.25),
		Color = look.hair,
		CFrame = head.CFrame * CFrame.new(0, head.Size.Y / 2, 0.05),
		Anchored = head.Anchored,
		Massless = true,
	}, head)
	if look.hat then
		addPart(model, {
			Name = "Hat",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.35, 1.9, 1.9),
			Color = look.hat,
			CFrame = hair.CFrame * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Anchored = head.Anchored,
			Massless = true,
		}, head)
		addPart(model, {
			Name = "HatTop",
			Size = Vector3.new(1.1, 0.6, 1.1),
			Color = look.hat,
			CFrame = hair.CFrame * CFrame.new(0, 0.55, 0),
			Anchored = head.Anchored,
			Massless = true,
		}, head)
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "NameTag"
	gui.Size = UDim2.fromOffset(200, 50)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 70
	gui.Adornee = head
	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, 0, 0.6, 0)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.3
	name.Text = def.displayName
	name.Parent = gui
	if def.subtitle then
		local sub = Instance.new("TextLabel")
		sub.Position = UDim2.fromScale(0, 0.6)
		sub.Size = UDim2.new(1, 0, 0.4, 0)
		sub.BackgroundTransparency = 1
		sub.Font = Enum.Font.GothamMedium
		sub.TextScaled = true
		sub.TextColor3 = Color3.fromRGB(255, 240, 200)
		sub.TextStrokeTransparency = 0.4
		sub.Text = def.subtitle
		sub.Parent = gui
	end
	gui.Parent = model
end

local function buildNPC(def, placement): Model
	local model = avatarModel(def.appearance) or blockyModel(def.appearance)
	model.Name = def.displayName
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		elseif d:IsA("Humanoid") then
			d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
	end
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") :: BasePart
	model.PrimaryPart = root
	-- Stand on the ground at the placement, facing the target.
	local box, size = model:GetBoundingBox()
	local pivotAboveFeet = model:GetPivot().Position.Y - (box.Position.Y - size.Y / 2)
	local pos = placement.position + Vector3.new(0, pivotAboveFeet, 0)
	local faces = Vector3.new(placement.faces.X, pos.Y, placement.faces.Z)
	model:PivotTo(CFrame.lookAt(pos, faces))
	decorate(model, def)
	model:SetAttribute("NpcId", def.id)
	model:SetAttribute("LocationId", placement.locationId)
	return model
end

local function register(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local npcId = model:GetAttribute("NpcId")
	local def = npcId and Content.npcs[npcId]
	if not def then
		warn(`[NPC] {model:GetFullName()} has unknown NpcId {npcId}`)
		return
	end
	local anchor = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if not anchor or anchor:FindFirstChild("TalkPrompt") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TalkPrompt"
	prompt.ActionText = def.promptText or "Talk"
	prompt.ObjectText = def.displayName
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Parent = anchor
	prompt.Triggered:Connect(function(player)
		S.Encounter.interact(player, model)
	end)
end

function NPC.getDefinition(npcId: string)
	return Content.npcs[npcId]
end

-- Is the player close enough to this NPC model to be talking to it?
function NPC.isNear(player: Player, model: Model, distance: number): boolean
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp or not model.Parent then
		return false
	end
	return (hrp.Position - model:GetPivot().Position).Magnitude <= distance
end

function NPC.init(services)
	S = services
end

function NPC.start()
	folder = Instance.new("Folder")
	folder.Name = "NPCs"
	folder.Parent = workspace
	CollectionService:GetInstanceAddedSignal(TAG):Connect(register)
	for _, existing in CollectionService:GetTagged(TAG) do
		register(existing)
	end
	for _, def in Content.npcs do
		for _, placement in def.placements or {} do
			task.spawn(function()
				local model = buildNPC(def, placement)
				model.Parent = folder
				CollectionService:AddTag(model, TAG)
			end)
		end
	end
end

return NPC
