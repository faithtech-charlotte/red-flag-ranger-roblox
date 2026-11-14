--[[
	PettingController: hands-on petting.

	The camera eases into a close, cozy shot of your dog (you stay right
	there, movement pauses). Your cursor becomes a hand:
	  Mouse     move the hand over your dog to stroke it
	  Touch     drag your finger over your dog
	  Gamepad / keyboard   hold A (or Space) to pet gently
	The dog reacts instantly: leans into your hand, squints happily, wags
	harder the more you pet, and thumps a back leg when you rub its side.
	Hearts float up from your hand. After a few seconds of real petting the
	server confirms it (Bond XP) and your dog says thanks.

	Ends with Done, Q / B, walking away, 8 s without petting, or anything else
	taking over (a conversation, the dog being called away).
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local State = require(script.Parent.State)
local Sounds = require(script.Parent.Parent.UI.Sounds)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors
local new = Theme.new
local player = Players.LocalPlayer

local SEND_INTERVAL = 0.25
local IDLE_TIMEOUT = 12
local LOCAL_RATE = 0.5 -- matches the server's petting rate

local Petting = {}
local ctl
local gui: ScreenGui
local layer: Frame
local hand: TextLabel
local hint: TextLabel
local hearts: { TextLabel } = {}
local doneButton: TextButton

local active = false
local starting = false
local startedAt = 0
local lastStrokeAt = 0
local lastSendAt = 0
local sendSum, sendCount = 0, 0
local intensity = 0
local progress = 0
local bodyRubTime = 0
local lastHeartAt = 0
local lastPatAt = 0
local lastPointer: Vector2? = nil
local touchPos: Vector2? = nil
local holdKey = false
local savedCamera: { type: Enum.CameraType, cframe: CFrame }? = nil
local setCharacterFade: (number) -> ()

local function controls()
	local ok, module = pcall(function()
		local playerModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript) :: any
		return playerModule:GetControls()
	end)
	return ok and module or nil
end

local function pet(): Model?
	return ctl.Pet.ownPet()
end

local function petName(): string
	local m = pet()
	return m and m:GetAttribute("PetName") or "your dog"
end

-- Screen-space circle covering a part.
local function screenCircle(part: BasePart, scale: number): (Vector2?, number)
	local camera = workspace.CurrentCamera
	local center, onScreen = camera:WorldToViewportPoint(part.Position)
	if not onScreen then
		return nil, 0
	end
	local edge = camera:WorldToViewportPoint(part.Position + camera.CFrame.RightVector * part.Size.Magnitude * 0.5 * scale)
	local inset = GuiService:GetGuiInset()
	local c = Vector2.new(center.X, center.Y - inset.Y)
	return c, (Vector2.new(edge.X, edge.Y - inset.Y) - c).Magnitude
end

local function heart(at: Vector2, big: boolean?)
	local h = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(at.X, at.Y),
		Size = UDim2.fromOffset(big and 56 or 30, big and 56 or 30),
		BackgroundTransparency = 1,
		Text = "❤️",
		TextScaled = true,
		Rotation = math.random(-20, 20),
		Parent = layer,
	}) :: TextLabel
	local drift = Vector2.new(math.random(-50, 50), -math.random(80, 150))
	TweenService:Create(h, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromOffset(at.X + drift.X, at.Y + drift.Y),
		TextTransparency = 1,
		Rotation = h.Rotation + math.random(-30, 30),
	}):Play()
	task.delay(1.15, function()
		h:Destroy()
	end)
end

local function renderMeter()
	for i, h in hearts do
		local fill = math.clamp(progress * #hearts - (i - 1), 0, 1)
		h.TextTransparency = 0.75 - fill * 0.75
		h.Size = UDim2.fromOffset(28 + fill * 6, 28 + fill * 6)
	end
end

local function cameraShot(model: Model)
	local head = model:FindFirstChild("Head") :: BasePart?
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not head or not hrp then
		return
	end
	local camera = workspace.CurrentCamera
	savedCamera = { type = camera.CameraType, cframe = camera.CFrame }
	local toward = Vector3.new(hrp.Position.X - head.Position.X, 0, hrp.Position.Z - head.Position.Z)
	toward = toward.Magnitude > 0.1 and toward.Unit or Vector3.new(0, 0, 1)
	local side = toward:Cross(Vector3.yAxis)
	-- Mostly from the side, so your character never blocks the view.
	local offset = (side * 1 + toward * 0.35).Unit * 6.5
	local eye = head.Position + offset + Vector3.new(0, 2.4, 0)
	camera.CameraType = Enum.CameraType.Scriptable
	TweenService:Create(camera, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		CFrame = CFrame.lookAt(eye, head.Position - Vector3.new(0, 0.6, 0)),
	}):Play()
end

-- Fade your own character a little so it never hides the dog.
function setCharacterFade(amount: number)
	local character = player.Character
	if not character then
		return
	end
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			(d :: any).LocalTransparencyModifier = amount
		end
	end
end

local function restoreCamera()
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
	savedCamera = nil
end

function Petting.isActive(): boolean
	return active or starting
end

function Petting.stop()
	if not active then
		return
	end
	active = false
	ctl.Pet.setPetting(false)
	layer.Visible = false
	UserInputService.MouseIconEnabled = true
	setCharacterFade(0)
	ctl.HUD.setFocus(false)
	restoreCamera()
	local c = controls()
	if c then
		c:Enable()
	end
	task.spawn(State.request, Remotes.RequestKinds.PetEnd)
end

function Petting.begin()
	if active or starting then
		return
	end
	local model = pet()
	if not model then
		ctl.HUD.toast("Adopt a dog first!")
		return
	end
	starting = true
	local ok, err = State.request(Remotes.RequestKinds.PetAction, { action = "petStart" })
	starting = false
	if not ok then
		if err then
			ctl.HUD.toast(err)
		end
		return
	end
	ctl.ActionBar.close()
	active = true
	startedAt = os.clock()
	lastStrokeAt = os.clock()
	progress, intensity, bodyRubTime = 0, 0, 0
	sendSum, sendCount = 0, 0
	lastPointer = nil
	local c = controls()
	if c then
		c:Disable()
	end
	setCharacterFade(0.6)
	ctl.HUD.setFocus(true)
	cameraShot(model)
	layer.Visible = true
	renderMeter()
	local input = UserInputService:GetLastInputType()
	if input == Enum.UserInputType.Touch then
		hint.Text = `Drag your finger over {petName()}!`
	elseif input.Name:find("Gamepad") then
		hint.Text = `Hold A to pet {petName()}`
	else
		hint.Text = `Move your hand over {petName()} to pet (or hold Space)`
	end
	hint.TextTransparency = 0
	UserInputService.MouseIconEnabled = input == Enum.UserInputType.Touch
	Sounds.play("pat", 1.4)
end

local function step(dt: number)
	local model = pet()
	if not model or not model.Parent then
		Petting.stop()
		return
	end
	-- Something else took over (called away, conversation, walked off).
	if os.clock() - startedAt > 0.6 and model:GetAttribute("PetState") ~= "BeingPetted" then
		Petting.stop()
		return
	end
	local head = model:FindFirstChild("Head") :: BasePart?
	local body = model:FindFirstChild("Body") :: BasePart?
	if not head or not body then
		return
	end
	local headC, headR = screenCircle(head, 1.1)
	local bodyC, bodyR = screenCircle(body, 0.9)

	-- Where is the hand?
	local pointer: Vector2?
	local auto = holdKey
	if auto and headC then
		-- Accessible petting: the hand strokes the head by itself.
		local t = os.clock()
		pointer = headC + Vector2.new(math.sin(t * 5) * headR * 0.6, math.cos(t * 2.5) * headR * 0.2)
	elseif touchPos then
		pointer = touchPos
	elseif UserInputService.MouseEnabled then
		local m = UserInputService:GetMouseLocation()
		local inset = GuiService:GetGuiInset()
		pointer = Vector2.new(m.X, m.Y - inset.Y)
	end
	hand.Visible = pointer ~= nil
	if not pointer then
		return
	end
	hand.Position = UDim2.fromOffset(pointer.X, pointer.Y)

	local zone = nil
	if headC and (pointer - headC).Magnitude <= headR then
		zone = "head"
	elseif bodyC and (pointer - bodyC).Magnitude <= bodyR then
		zone = "body"
	end

	local moved = lastPointer and (pointer - lastPointer).Magnitude or 0
	lastPointer = pointer
	local target = 0
	if zone then
		target = math.clamp(moved / math.max(dt, 1 / 120) / 500, 0, 1)
		if auto then
			target = 0.7
		end
	end
	intensity += (target - intensity) * math.min(1, dt * (target > intensity and 10 or 3))
	hand.Rotation = zone and math.sin(os.clock() * 14) * 12 * intensity or 0
	hand.TextTransparency = zone and 0 or 0.35

	if intensity > 0.08 then
		lastStrokeAt = os.clock()
		progress = math.min(1, progress + intensity * dt * LOCAL_RATE)
		if hint.TextTransparency < 1 then
			TweenService:Create(hint, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
		end
	end
	if zone == "body" and intensity > 0.3 then
		bodyRubTime += dt
	else
		bodyRubTime = math.max(0, bodyRubTime - dt * 2)
	end
	local side = 0
	if headC then
		side = math.clamp((pointer.X - headC.X) / math.max(headR, 1), -1, 1)
	end
	ctl.Pet.setPetting(true, intensity, side, math.clamp((bodyRubTime - 0.8) * 2, 0, 1))

	local now = os.clock()
	if intensity > 0.3 and now - lastHeartAt > 0.4 - intensity * 0.2 then
		lastHeartAt = now
		heart(pointer + Vector2.new(math.random(-12, 12), -20))
	end
	if intensity > 0.25 and now - lastPatAt > 0.32 then
		lastPatAt = now
		Sounds.play("pat", 0.9 + progress * 0.9)
	end
	renderMeter()

	sendSum += intensity
	sendCount += 1
	if now - lastSendAt >= SEND_INTERVAL then
		lastSendAt = now
		local avg = sendCount > 0 and sendSum / sendCount or 0
		sendSum, sendCount = 0, 0
		task.spawn(State.request, Remotes.RequestKinds.PetAction, { action = "petStroke", amount = avg })
	end

	if now - lastStrokeAt > IDLE_TIMEOUT then
		Petting.stop()
	end
end

local function celebrate(xp: number?)
	local model = pet()
	local head = model and model:FindFirstChild("Head") :: BasePart?
	local center = head and screenCircle(head, 1)
	if center then
		for i = 1, 8 do
			task.delay(i * 0.04, function()
				heart(center + Vector2.new(math.random(-60, 60), math.random(-30, 20)), i % 3 == 0)
			end)
		end
	end
	Sounds.play("chime")
	if model then
		ctl.Pet.woof(model, math.random() < 0.5 and "♥ Woof! ♥" or "Arf arf!")
		if xp and xp > 0 then
			task.delay(0.3, function()
				ctl.Pet.floatText(model, `+{xp} ♥ bond`)
			end)
		end
	end
	progress = 0
end

function Petting.start(screenGui: ScreenGui, controllers)
	gui = screenGui
	ctl = controllers
	layer = new("Frame", { Name = "Petting", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 20, Parent = gui }) :: Frame
	hand = new("TextLabel", {
		AnchorPoint = Vector2.new(0.3, 0.2),
		Size = UDim2.fromOffset(64, 64),
		BackgroundTransparency = 1,
		Text = "🖐️",
		TextScaled = true,
		ZIndex = 22,
		Parent = layer,
	}) :: TextLabel
	hint = Theme.label("", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 90),
		Size = UDim2.fromOffset(520, 30),
		Font = Theme.Fonts.title,
		TextSize = 24,
		TextColor3 = C.white,
		TextStrokeTransparency = 0.3,
		Parent = layer,
	})
	local meter = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -22),
		Size = UDim2.fromOffset(220, 40),
		BackgroundTransparency = 1,
		Parent = layer,
		Children = { Theme.list(Enum.FillDirection.Horizontal, 4) },
	})
	for i = 1, 5 do
		hearts[i] = new("TextLabel", {
			LayoutOrder = i,
			Size = UDim2.fromOffset(28, 28),
			BackgroundTransparency = 1,
			Text = "❤️",
			TextScaled = true,
			TextTransparency = 0.75,
			Parent = meter,
		}) :: TextLabel
	end
	doneButton = Theme.button("Done", C.inkSoft, Petting.stop, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -20),
		Size = UDim2.fromOffset(110, 44),
		TextSize = 20,
		Parent = layer,
	})

	UserInputService.InputBegan:Connect(function(input, processed)
		if not active then
			return
		end
		if input.KeyCode == Enum.KeyCode.ButtonA or input.KeyCode == Enum.KeyCode.Space then
			holdKey = true
		elseif input.KeyCode == Enum.KeyCode.ButtonB or input.KeyCode == Enum.KeyCode.Q then
			Petting.stop()
		elseif input.UserInputType == Enum.UserInputType.Touch and not processed then
			local inset = GuiService:GetGuiInset()
			touchPos = Vector2.new(input.Position.X, input.Position.Y - inset.Y)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if active and input.UserInputType == Enum.UserInputType.Touch and touchPos then
			local inset = GuiService:GetGuiInset()
			touchPos = Vector2.new(input.Position.X, input.Position.Y - inset.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.ButtonA or input.KeyCode == Enum.KeyCode.Space then
			holdKey = false
		elseif input.UserInputType == Enum.UserInputType.Touch then
			touchPos = nil
			lastPointer = nil
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		if active then
			step(dt)
		end
	end)
	State.push:Connect(function(kind, payload)
		if kind == Remotes.PushKinds.Petted and active then
			celebrate(payload.xp)
		elseif kind == Remotes.PushKinds.Dialogue or kind == Remotes.PushKinds.OpenShop then
			Petting.stop()
		end
	end)
	player.CharacterRemoving:Connect(Petting.stop)
end

return Petting
