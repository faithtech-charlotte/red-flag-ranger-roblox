--[[
	BallController: playing fetch with the Ball tool.

	  Equip the ball (hotbar, the 🎾 button, or the park's ball bucket)
	    -> your dog bounces and barks, eyes on the ball
	  Hold (mouse / touch / RT) to wind up
	    -> a dotted arc and landing ring grow with power; your dog crouches
	  Release
	    -> arm swing, whoosh; the ball really flies, bounces, and rolls
	  Your dog sprints, grabs it (mid-air catches get extra fanfare),
	  trots back, drops it at your feet, and the ball pops back into your hand.

	Aim: mouse pointer, the spot you touch, or where the camera faces.
	The server decides the real throw; this only predicts it for the preview.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local ObstacleHop = require(ReplicatedStorage.Shared.ObstacleHop)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local State = require(script.Parent.State)
local Sounds = require(script.Parent.Parent.UI.Sounds)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors
local new = Theme.new
local player = Players.LocalPlayer

-- Must match Server/Activities/Fetch.luau
local MIN_THROW, MAX_THROW = 10, 46
local FULL_CHARGE = 0.9
local DOTS = 14

local Ball = {}
local ctl
local tool: Tool? = nil
local charging = false
local chargeStart = 0
local touchAim: Vector2? = nil
local equips = 0
local streak = 0

local hintPill: TextLabel
local powerBar: Frame
local powerFill: Frame
local burstLabel: TextLabel
local previewFolder: Folder
local dots: { BasePart } = {}
local ring: BasePart

local function hrp(): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function petName(): string
	local m = ctl.Pet.ownPet()
	return m and m:GetAttribute("PetName") or "your dog"
end

local function ballInHand(): boolean
	local handle = tool and tool:FindFirstChild("Handle") :: BasePart?
	return handle ~= nil and handle.Transparency < 0.5
end

local function power(): number
	if not charging then
		return 0
	end
	return math.clamp((os.clock() - chargeStart) / FULL_CHARGE, 0.12, 1)
end

local function aimPoint(): Vector3?
	local root = hrp()
	if not root then
		return nil
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
	if screen then
		local ray = camera:ViewportPointToRay(screen.X, screen.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local ignore: { Instance } = { previewFolder }
		if player.Character then
			table.insert(ignore, player.Character)
		end
		-- Aim at the ground past a fence or hurdle, not at its invisible blocker.
		params.FilterDescendantsInstances = ObstacleHop.groundIgnore(ignore)
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 400, params)
		if hit then
			return hit.Position
		end
	end
	local look = camera.CFrame.LookVector
	return root.Position + Vector3.new(look.X, 0, look.Z).Unit * 20
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

-- Predicts the arc with the same launch math as the server.
local function updatePreview()
	local root = hrp()
	local aim = aimPoint()
	if not root or not aim then
		return
	end
	local p = power()
	local flat = Vector3.new(aim.X - root.Position.X, 0, aim.Z - root.Position.Z)
	if flat.Magnitude < 0.5 then
		flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	end
	local dir = flat.Unit
	local distance = MIN_THROW + (MAX_THROW - MIN_THROW) * p
	local g = workspace.Gravity
	local T = 0.55 + distance / 70
	local v = dir * (distance / T) + Vector3.new(0, g * T / 2, 0)
	local start = root.Position + Vector3.new(0, 1.2, 0) + dir * 1.2
	for i, d in dots do
		local t = (i / DOTS) * T
		local pos = start + v * t + Vector3.new(0, -0.5 * g * t * t, 0)
		d.Position = pos
		d.Transparency = 0.15 + (i / DOTS) * 0.4
	end
	local landing = start + dir * distance
	ring.CFrame = CFrame.new(landing.X, 0.12, landing.Z) * CFrame.Angles(0, 0, math.rad(90))
	ring.Transparency = 0.3
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
	if charging or not ballInHand() then
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
	local aim = aimPoint()
	swingArm()
	Sounds.play("whoosh", 0.9 + p * 0.4)
	task.spawn(function()
		local ok, err = State.request(Remotes.RequestKinds.FetchThrow, { target = aim, power = p })
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
	task.delay(1.2, function()
		TweenService:Create(burstLabel, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
	end)
end

local function hookTool(t: Tool)
	tool = t
	t.Equipped:Connect(function()
		equips += 1
		ctl.ActionBar.close()
		if equips <= 3 then
			local input = UserInputService:GetLastInputType()
			if input == Enum.UserInputType.Touch then
				showHint("Press and hold, then let go to throw!")
			elseif input.Name:find("Gamepad") then
				showHint("Hold RT to wind up, release to throw!")
			else
				showHint("Hold the mouse button to wind up, release to throw!")
			end
			task.delay(5, function()
				if not charging then
					showHint(nil)
				end
			end)
		end
	end)
	t.Unequipped:Connect(function()
		charging = false
		clearPreview()
		showHint(nil)
	end)
	t.Activated:Connect(beginCharge)
	t.Deactivated:Connect(release)
end

-- Equip the ball from anywhere (action bar, ball bucket).
function Ball.equip()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local t = player.Backpack:FindFirstChild("Ball") or (character and character:FindFirstChild("Ball"))
	if humanoid and t and t:IsA("Tool") then
		humanoid:EquipTool(t)
	else
		ctl.HUD.toast("Adopt a dog to get a ball!")
	end
end

function Ball.isEquipped(): boolean
	return tool ~= nil and tool.Parent == player.Character
end

function Ball.start(gui: ScreenGui, controllers)
	ctl = controllers

	hintPill = Theme.label("", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.fromOffset(440, 34),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		TextColor3 = C.white,
		Font = Theme.Fonts.bold,
		TextSize = 18,
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
		Size = UDim2.fromOffset(500, 60),
		Font = Theme.Fonts.title,
		TextSize = 44,
		TextStrokeTransparency = 0.2,
		Visible = false,
		Parent = gui,
		Children = { new("UIScale", { Scale = 1 }) },
	})

	previewFolder = Instance.new("Folder")
	previewFolder.Name = "FetchPreview"
	previewFolder.Parent = workspace
	for i = 1, DOTS do
		local d = Instance.new("Part")
		d.Shape = Enum.PartType.Ball
		d.Size = Vector3.one * (0.6 - i * 0.02)
		d.Color = C.yellow
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
	ring.Color = C.yellow
	ring.Material = Enum.Material.Neon
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Transparency = 1
	ring.Parent = previewFolder

	local function watchBackpack()
		local backpack = player:WaitForChild("Backpack")
		local function check(child: Instance)
			if child.Name == "Ball" and child:IsA("Tool") and child ~= tool then
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

	-- Bounce sounds for balls in flight (everyone's, so the park sounds lively).
	local lastVy: { [BasePart]: number } = {}
	RunService.RenderStepped:Connect(function()
		if charging then
			updatePreview()
		end
		for _, b in workspace:GetChildren() do
			if b.Name == "FetchBall" and b:IsA("BasePart") then
				local vy = b.AssemblyLinearVelocity.Y
				local prev = lastVy[b]
				if prev and prev < -4 and vy > 1 then
					Sounds.play("bounce", 0.9 + math.random() * 0.3)
				end
				lastVy[b] = vy
			end
		end
		for b in lastVy do
			if not b.Parent then
				lastVy[b] = nil
			end
		end
	end)

	State.push:Connect(function(kind, payload)
		if kind == Remotes.PushKinds.FetchAim then
			Ball.equip()
		elseif kind == Remotes.PushKinds.Fetch then
			if payload.grabbed then
				Sounds.play("catch", payload.air and 1.4 or 1)
				if payload.air then
					burst("AIR CATCH!", C.yellow)
				end
			elseif payload.caught then
				streak = payload.streak or streak + 1
				Sounds.play("chime", 1 + math.min(streak, 6) * 0.06)
				local text = streak >= 3 and `Good dog! Streak x{streak}` or "Good dog!"
				if payload.done then
					text = "Park challenge done!"
				elseif payload.inPark and payload.count then
					text ..= `  ({payload.count}/{payload.goal})`
				end
				burst(text, streak >= 3 and C.orange or C.white)
				local model = ctl.Pet.ownPet()
				if model then
					ctl.Pet.woof(model, "Woof!")
				end
			elseif payload.lost then
				streak = 0
				ctl.HUD.toast(payload.text or `{petName()} couldn't reach it. Here's another ball!`)
			end
		end
	end)
end

return Ball
