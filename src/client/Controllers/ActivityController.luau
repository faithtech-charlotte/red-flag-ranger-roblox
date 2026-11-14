--[[
	ActivityController: on-screen parts of the spa and trick-training games.

	Spa (grooming): four steps (brush, wash, rinse, dry). Spots appear around
	your dog on screen; clear each one by tapping/clicking it or by sweeping
	over it with the mouse button held. Gamepad: move the selection and
	press A. Each finished step is sent to the server, which checks order
	and timing.

	Trick training: press when the moving marker is inside the green zone.
	The server times the press with its own clock.
]]

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local State = require(script.Parent.State)
local Sounds = require(script.Parent.Parent.UI.Sounds)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors
local new = Theme.new

local STEP_INFO = {
	brush = { label = "Brush out the tangles", icon = "🪮", color = C.yellow },
	wash = { label = "Scrub-a-dub with bubbles", icon = "🫧", color = Color3.fromRGB(180, 220, 255) },
	rinse = { label = "Rinse off the suds", icon = "💧", color = C.blue },
	dry = { label = "Fluff dry!", icon = "💨", color = C.orange },
}
local SPOTS_PER_STEP = 5

local Activity = {}
local ctl
local gui: ScreenGui

----------------------------------------------------------------------------
-- Spa
----------------------------------------------------------------------------

local spa = {
	active = false,
	steps = {} :: { string },
	index = 0,
	spots = {} :: { { button: TextButton, offset: Vector2, cleared: boolean } },
	sending = false,
}
local spaPanel: Frame
local spaTitle: TextLabel
local spaLayer: Frame

local function clearSpots()
	for _, s in spa.spots do
		s.button:Destroy()
	end
	table.clear(spa.spots)
end

local function sendStep()
	if spa.sending then
		return
	end
	spa.sending = true
	task.spawn(function()
		for _ = 1, 6 do
			local ok, err = State.request(Remotes.RequestKinds.GroomStep, { step = spa.index })
			if ok or not spa.active then
				break
			end
			if err ~= "Keep scrubbing!" then
				break
			end
			task.wait(0.4)
		end
		spa.sending = false
		if spa.active and spa.index < #spa.steps then
			Activity.nextSpaStep()
		end
	end)
end

local function clearSpot(spot)
	if spot.cleared then
		return
	end
	spot.cleared = true
	spot.button.Visible = false
	Sounds.play("pop")
	for _, s in spa.spots do
		if not s.cleared then
			if UserInputService.GamepadEnabled then
				GuiService.SelectedObject = s.button
			end
			return
		end
	end
	sendStep()
end

function Activity.nextSpaStep()
	clearSpots()
	spa.index += 1
	local stepName = spa.steps[spa.index]
	if not stepName then
		return
	end
	local info = STEP_INFO[stepName]
	spaTitle.Text = `Spa Day {spa.index}/{#spa.steps}: {info.label}`
	if stepName == "wash" or stepName == "rinse" then
		Sounds.play("splash")
	end
	for i = 1, SPOTS_PER_STEP do
		local angle = (i / SPOTS_PER_STEP) * math.pi * 2 + math.random() * 0.6
		local radius = 50 + math.random() * 70
		local b = new("TextButton", {
			Size = UDim2.fromOffset(64, 64),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = info.color,
			BackgroundTransparency = 0.15,
			Text = info.icon,
			TextSize = 34,
			AutoButtonColor = true,
			Parent = spaLayer,
			Children = { Theme.corner(32), Theme.stroke(C.white, 3) },
		}) :: TextButton
		local spot = { button = b, offset = Vector2.new(math.cos(angle) * radius, math.sin(angle) * radius * 0.7), cleared = false }
		b.Activated:Connect(function()
			clearSpot(spot)
		end)
		b.MouseEnter:Connect(function()
			if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
				clearSpot(spot)
			end
		end)
		table.insert(spa.spots, spot)
	end
	if UserInputService.GamepadEnabled and spa.spots[1] then
		GuiService.SelectedObject = spa.spots[1].button
	end
end

local function endSpa()
	spa.active = false
	clearSpots()
	spaPanel.Visible = false
end

----------------------------------------------------------------------------
-- Trick training
----------------------------------------------------------------------------

local training = { active = false, round = nil :: any, pressed = false }
local trainPanel: Frame
local trainTitle: TextLabel
local trainInfo: TextLabel
local zone: Frame
local cursor: Frame
local pressButton: TextButton

local function press()
	if not training.active or not training.round or training.pressed then
		return
	end
	training.pressed = true
	pressButton.BackgroundColor3 = C.disabled
	task.spawn(State.request, Remotes.RequestKinds.TrainPress)
end

local function endTraining()
	training.active = false
	training.round = nil
	trainPanel.Visible = false
end

----------------------------------------------------------------------------

function Activity.isBusy(): boolean
	return spa.active or training.active
end

function Activity.start(screenGui: ScreenGui, controllers)
	gui = screenGui
	ctl = controllers

	-- Spa UI
	spaLayer = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = gui }) :: Frame
	spaPanel = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -20),
		Size = UDim2.fromOffset(420, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.bg,
		Visible = false,
		Parent = gui,
		Children = { Theme.corner(18), Theme.stroke(C.purple, 3), Theme.padding(10), Theme.list(nil, 8) },
	}) :: Frame
	spaTitle = Theme.label("", { Font = Theme.Fonts.title, TextSize = 22, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = 1, Parent = spaPanel })
	Theme.label("Tap each spot, or hold the mouse button and sweep over them!", { TextSize = 14, TextColor3 = C.inkSoft, LayoutOrder = 2, Parent = spaPanel })
	Theme.button("Stop", C.inkSoft, function()
		State.request(Remotes.RequestKinds.ActivityCancel)
	end, { Size = UDim2.new(0.4, 0, 0, 40), TextSize = 18, LayoutOrder = 3, Parent = spaPanel })

	-- Training UI
	trainPanel = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -20),
		Size = UDim2.fromOffset(440, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.bg,
		Visible = false,
		Parent = gui,
		Children = { Theme.corner(18), Theme.stroke(C.purple, 3), Theme.padding(12), Theme.list(nil, 8) },
	}) :: Frame
	trainTitle = Theme.label("", { Font = Theme.Fonts.title, TextSize = 22, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = 1, Parent = trainPanel })
	trainInfo = Theme.label("", { TextSize = 16, Font = Theme.Fonts.bold, LayoutOrder = 2, Parent = trainPanel })
	local track = new("Frame", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = Color3.fromRGB(230, 225, 240),
		LayoutOrder = 3,
		Parent = trainPanel,
		Children = { Theme.corner(10) },
	})
	zone = new("Frame", { BackgroundColor3 = C.green, Size = UDim2.fromScale(0.2, 1), Parent = track, Children = { Theme.corner(10) } }) :: Frame
	cursor = new("Frame", { BackgroundColor3 = C.ink, AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(0, 6, 1, 8), Position = UDim2.new(0, 0, 0, -4), Parent = track, Children = { Theme.corner(3) } }) :: Frame
	local row = new("Frame", { Size = UDim2.new(1, 0, 0, 54), BackgroundTransparency = 1, LayoutOrder = 4, Parent = trainPanel, Children = { Theme.list(Enum.FillDirection.Horizontal, 10) } })
	pressButton = Theme.button("Now! [F]", C.purple, press, { Size = UDim2.new(0.62, 0, 1, 0), TextSize = 24, LayoutOrder = 1, Parent = row })
	Theme.button("Stop", C.inkSoft, function()
		State.request(Remotes.RequestKinds.ActivityCancel)
	end, { Size = UDim2.new(0.32, 0, 1, 0), TextSize = 18, LayoutOrder = 2, Parent = row })

	UserInputService.InputBegan:Connect(function(input, processed)
		if training.active and (input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonR2) and not processed then
			press()
		end
	end)

	RunService.RenderStepped:Connect(function()
		if spa.active then
			local model = ctl.Pet.ownPet()
			local body = model and model:FindFirstChild("Body") :: BasePart?
			if body then
				local screen, onScreen = workspace.CurrentCamera:WorldToViewportPoint(body.Position)
				local inset = GuiService:GetGuiInset()
				for _, s in spa.spots do
					s.button.Position = UDim2.fromOffset(screen.X + s.offset.X, screen.Y - inset.Y + s.offset.Y)
					s.button.Visible = not s.cleared and onScreen
				end
			end
		end
		local r = training.round
		if training.active and r then
			local t = workspace:GetServerTimeNow() - r.startAt
			local pos = t < 0 and 0 or (t / r.period) % 1
			cursor.Position = UDim2.new(pos, 0, 0, -4)
		end
	end)

	State.push:Connect(function(kind, payload)
		if kind == Remotes.PushKinds.Grooming then
			if payload.state == "start" then
				spa.active = true
				spa.steps = payload.steps
				spa.index = 0
				spaPanel.Visible = true
				spaLayer.Visible = true
				Activity.nextSpaStep()
			elseif payload.state == "done" or payload.state == "cancel" then
				endSpa()
				spaLayer.Visible = false
			end
		elseif kind == Remotes.PushKinds.Training then
			if payload.state == "start" then
				training.active = true
				trainPanel.Visible = true
				trainTitle.Text = `Trick Training · Level {payload.tier}`
				trainInfo.Text = `Practice: {payload.move}`
			elseif payload.state == "round" then
				training.round = payload
				training.pressed = false
				pressButton.BackgroundColor3 = C.purple
				zone.Position = UDim2.fromScale(payload.zoneStart, 0)
				zone.Size = UDim2.fromScale(payload.zoneEnd - payload.zoneStart, 1)
				trainInfo.Text = `Round {payload.round}/{payload.rounds}: press when the line is in the green!  ({payload.move})`
			elseif payload.state == "result" then
				trainInfo.Text = payload.hit and "Nice timing! ⭐" or "Missed. You've got this!"
				if payload.hit then
					Sounds.play("chime")
				end
			elseif payload.state == "done" then
				trainInfo.Text = payload.success and `Great job! {payload.hits}/{payload.rounds}` or `{payload.hits}/{payload.rounds}. Try again!`
				task.delay(1.6, endTraining)
			elseif payload.state == "cancel" then
				endTraining()
			end
		end
	end)
end

return Activity
