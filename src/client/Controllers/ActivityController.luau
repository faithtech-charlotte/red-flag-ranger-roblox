--[[
	ActivityController: on-screen parts of trick training, and the "is the
	player busy with an activity" answer for other controllers.

	Spa (grooming): the four steps are hands-on gestures now, handled by
	GroomingGestures (it listens for the Grooming push itself).

	Trick training: press when the moving marker is inside the green zone.
	The server times the press with its own clock.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local State = require(script.Parent.State)
local Sounds = require(script.Parent.Parent.UI.Sounds)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors
local new = Theme.new

local Activity = {}
local ctl
local gui: ScreenGui

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
	return training.active or ctl.GroomingGestures.isActive() or ctl.TrailWalk.isActive()
end

function Activity.start(screenGui: ScreenGui, controllers)
	gui = screenGui
	ctl = controllers

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
		local r = training.round
		if training.active and r then
			local t = workspace:GetServerTimeNow() - r.startAt
			local pos = t < 0 and 0 or (t / r.period) % 1
			cursor.Position = UDim2.new(pos, 0, 0, -4)
		end
	end)

	State.push:Connect(function(kind, payload)
		if kind == Remotes.PushKinds.Training then
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
