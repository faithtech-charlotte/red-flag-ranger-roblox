--[[
	GroomingGestures: the hands-on Wash & Groom steps at the spa tub.

	The camera eases into a close shot of your dog in the tub (movement
	pauses). Each step is a gesture:
	  Brush   drag strokes along the dog's back       (fur fluffs: ✨ grow)
	  Wash    scrub in circles to fill the suds meter (bubbles build up)
	  Rinse   sweep across the dog                    (suds clear where you sweep)
	  Dry     hold to run the dryer                   (the dog shakes at the end)

	Inputs:
	  Mouse     hold the left button and move over the dog
	  Touch     drag your finger over the dog
	  Gamepad   hold A and steer the tool with the left stick; holding A
	            alone (or Space on a keyboard) moves the tool by itself
	  Stop      the Stop button, or B

	Like petting (PettingController), the dog's body is projected to the
	screen and the pointer's movement over it is what counts. The dog is cut
	into 5 zones from tail to head; each step fills zones, and how evenly
	they were covered is this client's "evenness" estimate. The client only
	reports 25/50/75/100 % milestones and that estimate; the server checks
	order, timing and the run id, measures the time and decides the shine.
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

local BINS = 5
local CAP = 2 -- one zone can count up to twice toward progress
local DRY_SECONDS = 3
local STICK_SPEED = 650 -- px per second at full tilt
local STICK_RECENT = 1.2 -- seconds a stick nudge keeps manual aim

type Info = { title: string, done: string, icon: string, tool: string, meter: string, how: { [string]: string } }
local STEP_INFO: { [string]: Info } = {
	brush = {
		title = "Brush",
		done = "Fluffy! ✔",
		icon = "✨",
		tool = "🪮",
		meter = "Brushed",
		how = {
			mouse = "Hold the mouse button and drag along {name}'s back",
			touch = "Drag your finger along {name}'s back",
			pad = "Hold A and steer along {name}'s back (or just hold A)",
			key = "Hold Space to brush",
		},
	},
	wash = {
		title = "Wash",
		done = "So sudsy! ✔",
		icon = "🫧",
		tool = "🧽",
		meter = "Suds",
		how = {
			mouse = "Hold the mouse button and scrub in little circles",
			touch = "Scrub in little circles with your finger",
			pad = "Hold A and circle the stick (or just hold A)",
			key = "Hold Space to scrub",
		},
	},
	rinse = {
		title = "Rinse",
		done = "All rinsed! ✔",
		icon = "🫧",
		tool = "🚿",
		meter = "Rinsed",
		how = {
			mouse = "Hold the mouse button and sweep across {name}",
			touch = "Sweep your finger across {name}",
			pad = "Hold A and sweep with the stick (or just hold A)",
			key = "Hold Space to rinse",
		},
	},
	dry = {
		title = "Dry",
		done = "Dry and fluffy! ✔",
		icon = "💨",
		tool = "💨",
		meter = "Dry",
		how = {
			mouse = "Hold the mouse button over {name} to run the dryer",
			touch = "Hold your finger on {name} to run the dryer",
			pad = "Hold A to run the dryer",
			key = "Hold Space to run the dryer",
		},
	},
}

local Gestures = {}
local ctl
local gui: ScreenGui
local layer: Frame
local toolLabel: TextLabel
local titleLabel: TextLabel
local howLabel: TextLabel
local meterLabel: TextLabel
local meterFill: Frame
local doneLabel: TextLabel
local binIcons: { TextLabel } = {}

local active = false
local runId: string? = nil
local steps: { string } = {}
local stepIndex = 0
local bins: { number } = {}
local progress = 0
local sentPct = 0 -- highest milestone queued for this step
local releases = 0
local wasApplying = false
local queue: { { step: number, pct: number, evenness: number? } } = {}
local sending = false
local lastPointer: Vector2? = nil
local lastHeading: number? = nil
local touchPos: Vector2? = nil
local holdKey = false
local stickDir = Vector2.zero
local stickAt = -math.huge
local cursor: Vector2? = nil

local function pet(): Model?
	return ctl.Pet.ownPet()
end

local function petName(): string
	local m = pet()
	return m and m:GetAttribute("PetName") or "your dog"
end

local function controls()
	local ok, module = pcall(function()
		local playerModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript) :: any
		return playerModule:GetControls()
	end)
	return ok and module or nil
end

local function setCharacterFade(amount: number)
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

local function inputKind(): string
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		return "touch"
	elseif last.Name:find("Gamepad") then
		return "pad"
	end
	return "mouse"
end

local function toScreen(p: Vector3): (Vector2, boolean)
	local v, onScreen = workspace.CurrentCamera:WorldToViewportPoint(p)
	local inset = GuiService:GetGuiInset()
	return Vector2.new(v.X, v.Y - inset.Y), onScreen
end

-- The dog's body on screen: rear (t = 0) to head (t = 1), and a radius.
local function dogAxis(): (Vector2?, Vector2?, number)
	local model = pet()
	local body = model and model:FindFirstChild("Body") :: BasePart?
	local head = model and model:FindFirstChild("Head") :: BasePart?
	if not body or not head then
		return nil, nil, 0
	end
	local back = body.Position - head.Position
	back = back.Magnitude > 0.01 and back.Unit or Vector3.new(0, 0, 1)
	local rear3 = body.Position + back * body.Size.Magnitude * 0.35
	local rear, a = toScreen(rear3)
	local front, b = toScreen(head.Position)
	if not a and not b then
		return nil, nil, 0
	end
	local length = (front - rear).Magnitude
	return rear, front, math.max(length * 0.42, 40)
end

local function cameraShot()
	local model = pet()
	local body = model and model:FindFirstChild("Body") :: BasePart?
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not body or not hrp then
		return
	end
	local camera = workspace.CurrentCamera
	local toward = Vector3.new(hrp.Position.X - body.Position.X, 0, hrp.Position.Z - body.Position.Z)
	toward = toward.Magnitude > 0.1 and toward.Unit or Vector3.new(0, 0, 1)
	local side = toward:Cross(Vector3.yAxis)
	local eye = body.Position + (side + toward * 0.35).Unit * 8 + Vector3.new(0, 3.4, 0)
	camera.CameraType = Enum.CameraType.Scriptable
	TweenService:Create(camera, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		CFrame = CFrame.lookAt(eye, body.Position),
	}):Play()
end

local function restoreCamera()
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

local function evenness(): number
	local step = steps[stepIndex]
	if step == "dry" then
		return math.max(0.4, 1 - 0.15 * releases)
	end
	local covered = 0
	for i = 1, BINS do
		covered += math.min(bins[i] or 0, 1)
	end
	return covered / BINS
end

local function renderMeter()
	meterFill.Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1)
	local info = STEP_INFO[steps[stepIndex]]
	meterLabel.Text = info and `{info.icon} {info.meter}: {math.floor(progress * 100 + 0.5)}%` or ""
end

local function sendQueue()
	if sending then
		return
	end
	sending = true
	task.spawn(function()
		while active and queue[1] do
			local item = queue[1]
			local myRun = runId
			local ok, err = false, nil
			for _ = 1, 12 do
				ok, err = State.request(Remotes.RequestKinds.GroomStep, {
					runId = myRun,
					step = item.step,
					pct = item.pct,
					evenness = item.evenness,
				})
				if ok or not active or runId ~= myRun then
					break
				end
				if err ~= "Keep scrubbing!" and err ~= "slow down" then
					break
				end
				task.wait(0.3)
			end
			if queue[1] == item then
				table.remove(queue, 1)
			end
			if not ok and err and err ~= "Keep scrubbing!" and err ~= "slow down" then
				ctl.HUD.toast(err)
			end
		end
		sending = false
	end)
end

local function beginStep(index: number)
	stepIndex = index
	local step = steps[index]
	local info = step and STEP_INFO[step]
	if not info then
		return
	end
	table.clear(bins)
	for i = 1, BINS do
		bins[i] = 0
	end
	progress, sentPct, releases = 0, 0, 0
	lastPointer, lastHeading = nil, nil
	titleLabel.Text = `Spa Day {index}/{#steps}: {info.title}`
	local kind = inputKind()
	local how = info.how[kind] or info.how.mouse
	if kind == "mouse" and UserInputService.KeyboardEnabled then
		how ..= `  ·  {info.how.key}`
	end
	howLabel.Text = (string.gsub(how, "{name}", petName()))
	toolLabel.Text = info.tool
	for _, icon in binIcons do
		icon.Text = info.icon
		icon.Visible = step ~= "dry"
	end
	if step == "wash" or step == "rinse" then
		Sounds.play("splash")
	end
	renderMeter()
end

local function cleanup()
	if not active then
		return
	end
	active = false
	runId = nil
	table.clear(queue)
	layer.Visible = false
	UserInputService.MouseIconEnabled = true
	setCharacterFade(0)
	ctl.HUD.setFocus(false)
	restoreCamera()
	local c = controls()
	if c then
		c:Enable()
	end
	holdKey, touchPos, cursor = false, nil, nil
end

-- Where is the tool, and is it being applied?
local function pointer(rear: Vector2, front: Vector2, radius: number, dt: number): (Vector2?, boolean, boolean)
	local now = os.clock()
	local step = steps[stepIndex]
	local t = os.clock()
	if now - stickAt < STICK_RECENT then
		local start = cursor or (rear + front) / 2
		cursor = start + stickDir * STICK_SPEED * dt
		return cursor, holdKey, false
	end
	if holdKey then
		-- Hands-free: the tool works the dog by itself (evenly).
		local axis = front - rear
		local perp = Vector2.new(-axis.Y, axis.X)
		perp = perp.Magnitude > 0 and perp.Unit or Vector2.new(0, 1)
		local along = 0.5 + 0.48 * math.sin(t * (step == "wash" and 0.9 or 2.2))
		local p = rear + axis * along
		if step == "wash" then
			p += Vector2.new(math.cos(t * 9), math.sin(t * 9)) * radius * 0.35
		elseif step == "rinse" then
			p += perp * math.sin(t * 5) * radius * 0.4
		end
		cursor = p
		return p, true, true
	end
	if touchPos then
		return touchPos, true, false
	end
	if UserInputService.MouseEnabled then
		local m = UserInputService:GetMouseLocation()
		local inset = GuiService:GetGuiInset()
		return Vector2.new(m.X, m.Y - inset.Y), UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1), false
	end
	return nil, false, false
end

local function stepFrame(dt: number)
	local model = pet()
	if not model or not model.Parent then
		return
	end
	local step = steps[stepIndex]
	if not step then
		return
	end
	local rear, front, radius = dogAxis()
	if not rear or not front then
		return
	end
	local axis = front - rear
	local length = math.max(axis.Magnitude, 1)
	local dir = axis / length

	-- Zone icons along the dog (bubbles build up, suds clear, fur fluffs).
	for i, icon in binIcons do
		local at = rear + axis * ((i - 0.5) / BINS) - Vector2.new(0, radius * 0.25)
		icon.Position = UDim2.fromOffset(at.X, at.Y)
		local fill = math.clamp(bins[i] or 0, 0, 1)
		local shown = step == "rinse" and 1 - fill or fill
		icon.TextTransparency = 1 - (0.15 + 0.85 * shown)
		icon.Size = UDim2.fromOffset(18 + shown * 26, 18 + shown * 26)
	end

	local p, applying, auto = pointer(rear, front, radius, dt)
	toolLabel.Visible = p ~= nil
	if not p then
		return
	end
	toolLabel.Position = UDim2.fromOffset(p.X, p.Y)
	local rel = p - rear
	local along = rel:Dot(dir) / length
	local perp = math.abs(rel.X * dir.Y - rel.Y * dir.X)
	local over = along >= -0.15 and along <= 1.15 and perp <= radius
	toolLabel.TextTransparency = (over or auto) and 0 or 0.4
	toolLabel.Rotation = applying and math.sin(os.clock() * 16) * 14 or 0

	if wasApplying and not applying and step == "dry" and progress > 0 and progress < 1 then
		releases += 1
	end
	wasApplying = applying

	local moved = lastPointer and (p - lastPointer) or Vector2.zero
	lastPointer = p
	if not applying or progress >= 1 then
		lastHeading = nil
		return
	end
	local zone = math.clamp(math.floor(math.clamp(along, 0, 0.999) * BINS) + 1, 1, BINS)
	local binWidth = length / BINS
	if step == "dry" then
		if over or auto then
			for i = 1, BINS do
				bins[i] += dt / DRY_SECONDS
			end
		end
	elseif over or auto then
		local distance = moved.Magnitude
		local gain = 0
		if step == "brush" then
			-- Strokes along the back count; side-to-side wiggles barely do.
			gain = math.abs(moved:Dot(dir)) / binWidth / 4
		elseif step == "wash" then
			-- Circles: the direction of travel keeps turning.
			if distance > 1 then
				local heading = math.atan2(moved.Y, moved.X)
				local turn = 0.15
				if lastHeading then
					local d = math.abs(heading - lastHeading)
					if d > math.pi then
						d = 2 * math.pi - d
					end
					turn = math.clamp(d / 0.25, 0.15, 1)
				end
				lastHeading = heading
				gain = distance * turn / binWidth / 5
			end
		elseif step == "rinse" then
			gain = distance / binWidth / 2.5
		end
		bins[zone] += gain
	end

	local sum = 0
	for i = 1, BINS do
		sum += math.min(bins[i], CAP)
	end
	progress = math.min(1, sum / BINS)
	renderMeter()

	-- Queue each milestone once, in order.
	while sentPct < 100 and progress * 100 >= sentPct + 25 do
		sentPct += 25
		table.insert(queue, {
			step = stepIndex,
			pct = sentPct,
			evenness = sentPct == 100 and evenness() or nil,
		})
		Sounds.play("pop", 0.8 + sentPct / 100)
		sendQueue()
	end
	if progress >= 1 then
		local info = STEP_INFO[step]
		doneLabel.Text = info.done
		doneLabel.Visible = true
		Theme.pop(doneLabel)
		Sounds.play("chime")
		task.delay(1.2, function()
			if doneLabel.Text == info.done then
				doneLabel.Visible = false
			end
		end)
	end
end

local function open(payload)
	if active then
		cleanup()
	end
	active = true
	runId = payload.runId
	steps = payload.steps or { "brush", "wash", "rinse", "dry" }
	ctl.ActionBar.close()
	if ctl.Petting.isActive() then
		ctl.Petting.stop()
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:UnequipTools()
	end
	local c = controls()
	if c then
		c:Disable()
	end
	GuiService.SelectedObject = nil
	setCharacterFade(0.6)
	ctl.HUD.setFocus(true)
	cameraShot()
	layer.Visible = true
	doneLabel.Visible = false
	UserInputService.MouseIconEnabled = inputKind() == "touch"
	beginStep(1)
end

local function showResult(stars: number?)
	local n = math.clamp(tonumber(stars) or 1, 1, 3)
	local card = Theme.label(`Sparkling clean!\n{string.rep("⭐", n)}  Shine: {n} of 3 stars`, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.64), -- below the celebration banner
		Size = UDim2.fromOffset(380, 84),
		BackgroundTransparency = 0.05,
		BackgroundColor3 = C.bg,
		Font = Theme.Fonts.title,
		TextSize = 26,
		Parent = gui,
		Children = { Theme.corner(18), Theme.stroke(C.purple, 3) },
	})
	Theme.pop(card)
	task.delay(3, function()
		card:Destroy()
	end)
end

function Gestures.isActive(): boolean
	return active
end

function Gestures.start(screenGui: ScreenGui, controllers)
	gui = screenGui
	ctl = controllers
	layer = new("Frame", { Name = "GroomGestures", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 20, Parent = gui }) :: Frame
	for i = 1, BINS do
		binIcons[i] = new("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(20, 20),
			BackgroundTransparency = 1,
			TextScaled = true,
			Text = "",
			ZIndex = 21,
			Parent = layer,
		}) :: TextLabel
	end
	toolLabel = new("TextLabel", {
		AnchorPoint = Vector2.new(0.3, 0.3),
		Size = UDim2.fromOffset(60, 60),
		BackgroundTransparency = 1,
		TextScaled = true,
		Text = "🪮",
		ZIndex = 23,
		Parent = layer,
	}) :: TextLabel
	local top = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(460, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.bg,
		BackgroundTransparency = 0.05,
		ZIndex = 21,
		Parent = layer,
		Children = { Theme.corner(16), Theme.stroke(C.purple, 3), Theme.padding(8), Theme.list(nil, 4), new("UISizeConstraint", { MaxSize = Vector2.new(460, 200) }) },
	})
	titleLabel = Theme.label("", { Font = Theme.Fonts.title, TextSize = 24, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = 1, ZIndex = 22, Parent = top })
	howLabel = Theme.label("", { TextSize = 16, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, ZIndex = 22, Parent = top })

	local bottom = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(360, 66),
		BackgroundColor3 = C.bg,
		BackgroundTransparency = 0.05,
		ZIndex = 21,
		Parent = layer,
		Children = { Theme.corner(16), Theme.stroke(C.purple, 3), Theme.padding(8) },
	})
	meterLabel = Theme.label("", { Font = Theme.Fonts.bold, TextSize = 16, Size = UDim2.new(1, 0, 0, 20), ZIndex = 22, Parent = bottom })
	local track = new("Frame", {
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundColor3 = Color3.fromRGB(230, 225, 240),
		ZIndex = 22,
		Parent = bottom,
		Children = { Theme.corner(11) },
	})
	meterFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.teal, ZIndex = 23, Parent = track, Children = { Theme.corner(11) } }) :: Frame
	for i = 1, 3 do
		-- Tick marks at 25 / 50 / 75 % (shape, not only color).
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(i / 4, 0), Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = C.ink, BackgroundTransparency = 0.4, ZIndex = 24, Parent = track })
	end
	doneLabel = Theme.label("", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromOffset(320, 50),
		Font = Theme.Fonts.title,
		TextSize = 34,
		TextColor3 = C.white,
		TextStrokeTransparency = 0.2,
		Visible = false,
		ZIndex = 24,
		Parent = layer,
	})
	Theme.button("Stop [B]", C.inkSoft, function()
		State.request(Remotes.RequestKinds.ActivityCancel)
	end, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -20),
		Size = UDim2.fromOffset(120, 46),
		TextSize = 20,
		ZIndex = 22,
		Parent = layer,
	})

	UserInputService.InputBegan:Connect(function(input, processed)
		if not active then
			return
		end
		if input.KeyCode == Enum.KeyCode.ButtonA or input.KeyCode == Enum.KeyCode.Space then
			holdKey = true
		elseif input.KeyCode == Enum.KeyCode.ButtonB then
			task.spawn(State.request, Remotes.RequestKinds.ActivityCancel)
		elseif input.UserInputType == Enum.UserInputType.Touch and not processed then
			local inset = GuiService:GetGuiInset()
			touchPos = Vector2.new(input.Position.X, input.Position.Y - inset.Y)
			lastPointer = touchPos
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not active then
			return
		end
		if input.UserInputType == Enum.UserInputType.Touch and touchPos then
			local inset = GuiService:GetGuiInset()
			touchPos = Vector2.new(input.Position.X, input.Position.Y - inset.Y)
		elseif input.KeyCode == Enum.KeyCode.Thumbstick1 then
			local v = Vector2.new(input.Position.X, -input.Position.Y)
			if v.Magnitude > 0.2 then
				stickDir = v
				stickAt = os.clock()
			else
				stickDir = Vector2.zero
			end
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
			stepFrame(dt)
		end
	end)

	State.push:Connect(function(kind, payload)
		if kind ~= Remotes.PushKinds.Grooming or typeof(payload) ~= "table" then
			return
		end
		if payload.state == "start" then
			open(payload)
		elseif payload.runId ~= runId then
			return -- a message about an older visit
		elseif payload.state == "step" then
			if active and typeof(payload.step) == "number" then
				beginStep(payload.step)
			end
		elseif payload.state == "done" then
			cleanup()
			showResult(payload.stars)
		elseif payload.state == "cancel" then
			cleanup()
		end
	end)
	player.CharacterRemoving:Connect(cleanup)
end

return Gestures
