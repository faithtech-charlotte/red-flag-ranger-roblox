--[[
	FrisbeeController: the Frisbee Field catch game.

	  Grab a frisbee at the field -> the Frisbee tool is equipped, a small
	    panel shows your catches (x/3) and a Stop button
	  Hold (mouse / touch / RT) to wind up
	    -> a dotted preview of the real flight (it curves: discs turn and
	       fade), a landing ring, and a power bar
	  Aim: the pointer (or where you touch / the camera faces) sets the
	    direction. Aim at the sky for a higher, floatier throw; aim at the
	    ground for a flat, fast one.
	  Release -> FrisbeeThrow { target, pitch, power }

	Flying discs are anchored parts the server moves. Every client replays
	the same flight (Shared/FrisbeeMath) from the launch attributes each
	frame, so the disc glides smoothly instead of stepping at network rate.
	The server still decides where it lands and whether the dog caught it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local FrisbeeMath = require(ReplicatedStorage.Shared.FrisbeeMath)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local State = require(script.Parent.State)
local Sounds = require(script.Parent.Parent.UI.Sounds)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors
local new = Theme.new
local player = Players.LocalPlayer

local TOOL_NAME = "Frisbee"
local DISC_NAME = "Frisbee"
local FULL_CHARGE = 1.0
local DOTS = 24
local PINK = Color3.fromRGB(255, 90, 140)

local Frisbee = {}
local ctl
local tool: Tool? = nil
local charging = false
local chargeStart = 0
local touchAim: Vector2? = nil
local active = false

local panel: Frame
local panelText: TextLabel
local hintPill: TextLabel
local powerBar: Frame
local powerFill: Frame
local burstLabel: TextLabel
local previewFolder: Folder
local dots: { BasePart } = {}
local ring: BasePart

-- Flights being replayed locally, keyed by disc part.
local flights: { [BasePart]: { launchAt: number, launch: FrisbeeMath.Launch, state: FrisbeeMath.FlightState } } = {}

local function hrp(): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function petName(): string
	local m = ctl.Pet.ownPet()
	return m and m:GetAttribute("PetName") or "your dog"
end

local function discInHand(): boolean
	return tool ~= nil and tool:GetAttribute("InHand") ~= false
end

local function power(): number
	if not charging then
		return 0
	end
	return math.clamp((os.clock() - chargeStart) / FULL_CHARGE, 0.1, 1)
end

local function rayParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { previewFolder }
	if player.Character then
		table.insert(ignore, player.Character)
	end
	local pets = workspace:FindFirstChild("Pets")
	if pets then
		table.insert(ignore, pets)
	end
	params.FilterDescendantsInstances = ignore
	return params
end

-- Where you're aiming: (target point, ray pitch in degrees).
local function aim(): (Vector3?, number)
	local root = hrp()
	if not root then
		return nil, -10
	end
	local camera = workspace.CurrentCamera
	local screen: Vector2?
	local input = UserInputService:GetLastInputType()
	if input == Enum.UserInputType.Touch then
		screen = touchAim
	elseif input.Name:find("Gamepad") then
		screen = nil
	else
		screen = UserInputService:GetMouseLocation()
	end
	local origin, direction
	if screen then
		local ray = camera:ViewportPointToRay(screen.X, screen.Y)
		origin, direction = ray.Origin, ray.Direction.Unit
	else
		origin, direction = camera.CFrame.Position, camera.CFrame.LookVector
	end
	local pitch = math.deg(math.asin(math.clamp(direction.Y, -1, 1)))
	local hit = workspace:Raycast(origin, direction * 400, rayParams())
	return hit and hit.Position or origin + direction * 400, pitch
end

local function showHint(text: string?)
	hintPill.Visible = text ~= nil
	hintPill.Text = text or ""
end

local function clearPreview()
	for _, d in dots do
		d.Transparency = 1
	end
	ring.Transparency = 1
	powerBar.Visible = false
end

-- Predicts the flight with the same model and inputs the server will use.
local function updatePreview()
	local root = hrp()
	local target, pitch = aim()
	if not root or not target then
		return
	end
	local dir = FrisbeeMath.flatDirection(root.Position, target, root.CFrame.LookVector)
	local character = player.Character
	local hand = character and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")) :: BasePart?
	local origin = (hand and hand.Position or root.Position + Vector3.new(0, 1.5, 0)) + dir * 1.2
	local p = power()
	local launch = FrisbeeMath.launch(origin, dir, FrisbeeMath.elevationFromPitch(pitch), p)
	local floor = workspace:Raycast(root.Position, Vector3.new(0, -20, 0), rayParams())
	local groundY = floor and floor.Position.Y or root.Position.Y - 3
	local points = FrisbeeMath.predict(launch, groundY, 7, 2)
	local n = #points
	for i, d in dots do
		local pt = points[math.max(1, math.floor(i / DOTS * n))]
		if pt then
			d.Position = pt.position
			d.Transparency = 0.15 + (i / DOTS) * 0.45
		else
			d.Transparency = 1
		end
	end
	local landing = points[n]
	if landing then
		ring.CFrame = CFrame.new(landing.position.X, groundY + 0.12, landing.position.Z) * CFrame.Angles(0, 0, math.rad(90))
		ring.Transparency = 0.3
	end
	powerBar.Visible = true
	powerFill.Size = UDim2.fromScale(p, 1)
	powerFill.BackgroundColor3 = C.yellow:Lerp(C.orange, p)
end

local function swingArm()
	if not tool then
		return
	end
	local anim = Instance.new("StringValue")
	anim.Name = "toolanim"
	anim.Value = "Slash" -- the default Animate script plays an arm swing
	anim.Parent = tool
	task.delay(0.4, function()
		anim:Destroy()
	end)
end

local function beginCharge()
	if charging or not discInHand() then
		return
	end
	charging = true
	chargeStart = os.clock()
	showHint(nil)
	task.spawn(State.request, Remotes.RequestKinds.FetchReady, { ready = true })
end

local function release()
	if not charging then
		return
	end
	local p = power()
	charging = false
	clearPreview()
	local target, pitch = aim()
	swingArm()
	Sounds.play("whoosh", 1.1 + p * 0.3)
	task.spawn(function()
		local ok, err = State.request(Remotes.RequestKinds.FrisbeeThrow, { target = target, pitch = pitch, power = p })
		if not ok then
			task.spawn(State.request, Remotes.RequestKinds.FetchReady, { ready = false })
			if err then
				ctl.HUD.toast(err)
			end
		end
	end)
end

local function burst(text: string, color: Color3)
	burstLabel.Text = text
	burstLabel.TextColor3 = color
	burstLabel.Visible = true
	burstLabel.TextTransparency = 0
	local scale = burstLabel:FindFirstChildOfClass("UIScale") :: UIScale
	scale.Scale = 0.4
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(1.4, function()
		TweenService:Create(burstLabel, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
	end)
end

local function setCount(count: number, goal: number)
	local marks = {}
	for i = 1, goal do
		table.insert(marks, i <= count and "🥏" or "○")
	end
	panelText.Text = `Catches  {table.concat(marks, " ")}  ({count}/{goal})`
end

local function hookTool(t: Tool)
	tool = t
	t.Equipped:Connect(function()
		ctl.ActionBar.close()
		local input = UserInputService:GetLastInputType()
		if input == Enum.UserInputType.Touch then
			showHint("Press and hold, then let go to throw! Aim up for a floaty throw.")
		elseif input.Name:find("Gamepad") then
			showHint("Hold RT to wind up, release to throw! Tilt the camera up for a floaty throw.")
		else
			showHint("Hold the mouse to wind up, release to throw! Aim at the sky for a floaty throw.")
		end
		task.delay(5, function()
			if not charging then
				showHint(nil)
			end
		end)
	end)
	t.Unequipped:Connect(function()
		charging = false
		clearPreview()
		showHint(nil)
	end)
	t.Activated:Connect(beginCharge)
	t.Deactivated:Connect(release)
	t.AncestryChanged:Connect(function()
		if not t:IsDescendantOf(game) and tool == t then
			tool = nil
			charging = false
			clearPreview()
			showHint(nil)
		end
	end)
end

local function equip()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local backpack = player:FindFirstChild("Backpack")
	local t = (backpack and backpack:WaitForChild(TOOL_NAME, 3)) or (character and character:FindFirstChild(TOOL_NAME))
	if humanoid and t and t:IsA("Tool") and t.Parent ~= character then
		humanoid:EquipTool(t)
	end
end

function Frisbee.isEquipped(): boolean
	return tool ~= nil and tool.Parent == player.Character
end

function Frisbee.isActive(): boolean
	return active
end

-- Replays every flying disc locally so it moves smoothly every frame.
local function renderDiscs()
	local now = workspace:GetServerTimeNow()
	for _, d in workspace:GetChildren() do
		if d.Name == DISC_NAME and d:IsA("BasePart") then
			local launchAt = d:GetAttribute("LaunchAt")
			if d:GetAttribute("Flying") == true and typeof(launchAt) == "number" then
				local f = flights[d]
				if not f or f.launchAt ~= launchAt then
					local launch: FrisbeeMath.Launch = {
						origin = d:GetAttribute("LaunchOrigin") :: Vector3,
						velocity = d:GetAttribute("LaunchVelocity") :: Vector3,
						normal = d:GetAttribute("LaunchNormal") :: Vector3,
						spin = d:GetAttribute("LaunchSpin") :: number,
					}
					if typeof(launch.origin) ~= "Vector3" or typeof(launch.velocity) ~= "Vector3" or typeof(launch.normal) ~= "Vector3" then
						continue
					end
					f = { launchAt = launchAt, launch = launch, state = FrisbeeMath.start(launch) }
					flights[d] = f
				end
				local flight = f :: any
				FrisbeeMath.advanceTo(flight.state, now - launchAt)
				d.CFrame = FrisbeeMath.cframe(FrisbeeMath.worldPosition(flight.launch, flight.state), flight.state)
			else
				flights[d] = nil
			end
		end
	end
	for d in flights do
		if d.Parent ~= workspace then
			flights[d] = nil
		end
	end
end

function Frisbee.start(gui: ScreenGui, controllers)
	ctl = controllers

	panel = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.fromOffset(0, 44),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = C.bg,
		Visible = false,
		Parent = gui,
		Children = { Theme.corner(14), Theme.stroke(PINK, 3), Theme.padding(6), Theme.list(Enum.FillDirection.Horizontal, 10) },
	}) :: Frame
	panelText = Theme.label("", {
		Size = UDim2.fromOffset(0, 32),
		AutomaticSize = Enum.AutomaticSize.X,
		Font = Theme.Fonts.title,
		TextSize = 20,
		LayoutOrder = 1,
		Parent = panel,
	})
	Theme.button("Stop", C.inkSoft, function()
		State.request(Remotes.RequestKinds.ActivityCancel)
	end, { Size = UDim2.fromOffset(70, 32), TextSize = 16, LayoutOrder = 2, Parent = panel })

	hintPill = Theme.label("", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.fromOffset(560, 34),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		TextColor3 = C.white,
		Font = Theme.Fonts.bold,
		TextSize = 17,
		Visible = false,
		Parent = gui,
		Children = { Theme.corner(17) },
	})
	powerBar = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.fromOffset(220, 14),
		BackgroundColor3 = Color3.fromRGB(40, 40, 50),
		BackgroundTransparency = 0.3,
		Visible = false,
		Parent = gui,
		Children = { Theme.corner(7) },
	}) :: Frame
	powerFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.yellow, Parent = powerBar, Children = { Theme.corner(7) } }) :: Frame
	burstLabel = Theme.label("", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(560, 60),
		Font = Theme.Fonts.title,
		TextSize = 42,
		TextStrokeTransparency = 0.2,
		Visible = false,
		Parent = gui,
		Children = { new("UIScale", { Scale = 1 }) },
	})

	previewFolder = Instance.new("Folder")
	previewFolder.Name = "FrisbeePreview"
	previewFolder.Parent = workspace
	for i = 1, DOTS do
		local d = Instance.new("Part")
		d.Shape = Enum.PartType.Ball
		d.Size = Vector3.one * (0.55 - i * 0.012)
		d.Color = PINK
		d.Material = Enum.Material.Neon
		d.Anchored = true
		d.CanCollide = false
		d.CanQuery = false
		d.CanTouch = false
		d.CastShadow = false
		d.Transparency = 1
		d.Parent = previewFolder
		dots[i] = d
	end
	ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.15, 4, 4)
	ring.Color = PINK
	ring.Material = Enum.Material.Neon
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Transparency = 1
	ring.Parent = previewFolder

	local function watchBackpack()
		local backpack = player:WaitForChild("Backpack")
		local function check(child: Instance)
			if child.Name == TOOL_NAME and child:IsA("Tool") and child ~= tool then
				hookTool(child)
			end
		end
		backpack.ChildAdded:Connect(check)
		for _, c in backpack:GetChildren() do
			check(c)
		end
	end
	player.CharacterAdded:Connect(function()
		tool = nil
		task.defer(watchBackpack)
	end)
	if player.Character then
		task.defer(watchBackpack)
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.Touch and not processed then
			touchAim = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch and charging then
			touchAim = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)

	RunService.RenderStepped:Connect(function()
		if charging then
			updatePreview()
		end
		renderDiscs()
	end)

	State.push:Connect(function(kind, payload)
		if kind ~= Remotes.PushKinds.Frisbee then
			return
		end
		local goal = payload.goal or 3
		local count = payload.count or 0
		local state = payload.state
		if state == "start" then
			active = true
			panel.Visible = true
			setCount(count, goal)
			task.spawn(equip)
			if (payload.throws or 0) == 0 then
				burst(`{petName()} runs out. Throw!`, PINK)
			end
		elseif state == "caught" then
			setCount(count, goal)
			Sounds.play("catch", payload.air and 1.4 or 1)
			burst(count >= goal and "AIR CATCH! 🏆" or `AIR CATCH! {count}/{goal}`, C.yellow)
		elseif state == "landed" then
			Sounds.play("bounce", 0.8)
			burst("It landed first!", C.white)
		elseif state == "grabbed" then
			Sounds.play("catch", 0.9)
		elseif state == "returned" then
			local model = ctl.Pet.ownPet()
			if model then
				ctl.Pet.woof(model, "Woof!")
			end
			if payload.caught then
				Sounds.play("chime", 1 + count * 0.08)
			elseif count < goal then
				ctl.HUD.toast(`Only mid-air catches count. Try a floatier throw so {petName()} can get under it!`)
			end
		elseif state == "lost" then
			ctl.HUD.toast(payload.text or "Lost that one. Here's another frisbee!")
		elseif state == "end" then
			active = false
			panel.Visible = false
			charging = false
			clearPreview()
			showHint(nil)
		end
	end)
end

return Frisbee
