--[[
	PetController (PetBehavior, client half): procedural animation for every
	dog, plus steering for your own dog.

	* Trot: legs swing with speed; head bobs.
	* Idle: sits after standing still for a moment; tail keeps wagging.
	* Moods (server sets attributes Mood + MoodAt): happy = hops,
	  love = hearts, sparkle = bubbles, comfort = slow wag + lean in.
	* Own dog: faces the way it's moving, or the way you face when still.
	  (We own its physics, so setting AlignOrientation locally is enough.)

	Motor6D.Transform is local-only, so every client animates every dog.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local PetController = {}

type Rig = {
	model: Model,
	root: BasePart,
	motors: { [string]: Motor6D },
	phase: number,
	stillFor: number,
	sit: number,
	lastMoodAt: number,
	own: boolean,
}

local rigs: { [Model]: Rig } = {}

local MOOD_SECONDS = 1.8
local MOOD_ICON = { happy = "⭐", love = "❤️", sparkle = "✨", comfort = "💙" }

local function floatIcon(rig: Rig, icon: string)
	local head = rig.model:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	for i = 1, 3 do
		task.delay((i - 1) * 0.18, function()
			local gui = Instance.new("BillboardGui")
			gui.Size = UDim2.fromOffset(40, 40)
			gui.StudsOffset = Vector3.new((i - 2) * 0.8, 1.5, 0)
			gui.Adornee = head
			gui.AlwaysOnTop = true
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.TextScaled = true
			label.Text = icon
			label.Parent = gui
			gui.Parent = head
			TweenService:Create(gui, TweenInfo.new(1.2), { StudsOffset = gui.StudsOffset + Vector3.new(0, 2.5, 0) }):Play()
			TweenService:Create(label, TweenInfo.new(1.2), { TextTransparency = 1 }):Play()
			task.delay(1.25, function()
				gui:Destroy()
			end)
		end)
	end
end

local function track(model: Instance)
	if not model:IsA("Model") or rigs[model] then
		return
	end
	local root = model:WaitForChild("Root", 5) :: BasePart?
	if not root then
		return
	end
	local motors = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			motors[d.Name] = d
		end
	end
	rigs[model] = {
		model = model,
		root = root,
		motors = motors,
		phase = 0,
		stillFor = 0,
		sit = 0,
		lastMoodAt = model:GetAttribute("MoodAt") or 0,
		own = model:GetAttribute("OwnerUserId") == player.UserId,
	}
end

local function untrack(model: Instance)
	rigs[model :: Model] = nil
end

local function steerOwnDog(rig: Rig, flatVel: Vector3)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local align = rig.root:FindFirstChildOfClass("AlignOrientation")
	if not hrp or not align then
		return
	end
	local dir
	if flatVel.Magnitude > 2 then
		dir = flatVel.Unit
	else
		local look = hrp.CFrame.LookVector
		dir = Vector3.new(look.X, 0, look.Z)
		if dir.Magnitude < 0.1 then
			return
		end
		dir = dir.Unit
	end
	align.CFrame = CFrame.lookAt(Vector3.zero, dir)
end

local function animate(rig: Rig, dt: number)
	local m = rig.motors
	local vel = rig.root.AssemblyLinearVelocity
	local flat = Vector3.new(vel.X, 0, vel.Z)
	local speed = flat.Magnitude
	if rig.own then
		steerOwnDog(rig, flat)
	end

	rig.phase += dt * math.clamp(speed, 0, 30) * 0.9
	if speed < 0.6 then
		rig.stillFor += dt
	else
		rig.stillFor = 0
	end
	local targetSit = rig.stillFor > 1.5 and 1 or 0
	rig.sit += (targetSit - rig.sit) * math.min(1, dt * 6)

	local now = workspace:GetServerTimeNow()
	local moodAt = rig.model:GetAttribute("MoodAt") or 0
	local mood = rig.model:GetAttribute("Mood")
	if moodAt ~= rig.lastMoodAt then
		rig.lastMoodAt = moodAt
		local icon = MOOD_ICON[mood]
		if icon then
			floatIcon(rig, icon)
		end
	end
	local moodActive = now - moodAt < MOOD_SECONDS
	local t = os.clock()

	local stride = math.sin(rig.phase) * 0.7 * math.clamp(speed / 12, 0, 1)
	local sit = rig.sit
	local hop = 0
	if moodActive and mood == "happy" then
		hop = math.abs(math.sin(t * 9)) * 0.9
		sit = 0
	end

	if m.LegFL then
		m.LegFL.Transform = CFrame.Angles(stride, 0, 0)
		m.LegBR.Transform = CFrame.Angles(stride - sit * 1.2, 0, 0)
		m.LegFR.Transform = CFrame.Angles(-stride, 0, 0)
		m.LegBL.Transform = CFrame.Angles(-stride - sit * 1.2, 0, 0)
	end
	if m.BodyJoint then
		local bob = math.abs(math.sin(rig.phase)) * 0.08 * math.clamp(speed / 12, 0, 1)
		m.BodyJoint.Transform = CFrame.new(0, bob + hop - sit * 0.35, sit * 0.15) * CFrame.Angles(sit * 0.35, 0, 0)
	end
	if m.Neck then
		local tilt = 0
		if moodActive and mood == "comfort" then
			tilt = math.sin(t * 2) * 0.25
		end
		m.Neck.Transform = CFrame.Angles(-sit * 0.25 + math.sin(rig.phase * 2) * 0.05, 0, tilt)
	end
	if m.Tail then
		local wagSpeed = (moodActive and (mood == "happy" or mood == "love")) and 22 or (moodActive and mood == "comfort") and 5 or 11
		m.Tail.Transform = CFrame.Angles(0, math.sin(t * wagSpeed) * 0.55, 0)
	end
end

function PetController.start()
	CollectionService:GetInstanceAddedSignal("Pet"):Connect(function(m)
		task.spawn(track, m)
	end)
	CollectionService:GetInstanceRemovedSignal("Pet"):Connect(untrack)
	for _, m in CollectionService:GetTagged("Pet") do
		task.spawn(track, m)
	end
	RunService.RenderStepped:Connect(function(dt)
		for model, rig in rigs do
			if model.Parent and rig.root.Parent then
				animate(rig, dt)
			else
				rigs[model] = nil
			end
		end
	end)
end

return PetController
