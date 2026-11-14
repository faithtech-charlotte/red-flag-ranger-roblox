--[[
	WhistleController: an always-on way to call your dog back from anywhere.

	  Keyboard   H ("here")
	  Gamepad    D-pad Up
	  Touch      a round 📣 button that sits just above the jump button

	The button is on screen whenever you have a dog (hidden during a
	conversation, so it can't cover a choice). Whistling plays a chirp right
	away; the server drops whatever the dog was doing, puts a "!" over it, and
	it runs back to you. See PetInteractionService handlers.whistle.

	During an activity (fetch, agility, spa, training, trail walk) the first
	press asks "Stop <activity>? Press again" for CONFIRM_SECONDS; a second
	press inside that window cancels it and the dog comes. The same confirm
	guards the Sit / Stay / Come commands (Whistle.confirmStop). The check is
	client-side UX only: the server is unchanged and still decides (a
	whistle or command always interrupts the activity there).
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local PetActions = require(ReplicatedStorage.Shared.Catalogs.PetActions)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local State = require(script.Parent.State)
local Sounds = require(script.Parent.Parent.UI.Sounds)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors
local new = Theme.new
local player = Players.LocalPlayer

local KEY = Enum.KeyCode.H
local PAD = Enum.KeyCode.DPadUp
local SIZE = 60
local GAP = 10 -- space between the jump button and the whistle
local CONFIRM_SECONDS = 3

local Whistle = {}
local ctl
local gui: ScreenGui
local button: TextButton
local circle: Frame
local hint: TextLabel
local readyAt = 0
local confirmUntil = 0
local confirmPanel: Frame
local confirmText: TextLabel
local confirmFill: Frame

local function hasDog(): boolean
	return State.data ~= nil and State.data.pet ~= nil
end

local function bounce()
	local scale = circle:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = circle })
	;(scale :: UIScale).Scale = 0.8
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

local function hideConfirm()
	confirmUntil = 0
	confirmPanel.Visible = false
end

--[[
	Call before a whistle or a dog command. Returns true when it should go
	ahead: no activity is running, or this is the second press within the
	confirm window. Otherwise shows "Stop <activity>? Press again" and
	returns false. `again` names the control to press again (e.g. "H").
]]
function Whistle.confirmStop(again: string?): boolean
	local name = player:GetAttribute("ActivityName")
	if typeof(name) ~= "string" then
		hideConfirm()
		return true
	end
	local now = os.clock()
	if now < confirmUntil then
		hideConfirm()
		return true
	end
	confirmUntil = now + CONFIRM_SECONDS
	local press = again and `Press {again} again` or "Press again"
	confirmText.Text = `✋ Stop {name}?\n{press} to stop and call your dog.`
	confirmPanel.Visible = true
	Theme.pop(confirmPanel)
	Sounds.play("click")
	return false
end

local function againLabel(): string
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		return "📣"
	elseif last.Name:find("Gamepad") then
		return "D-pad ↑"
	end
	return "H"
end

function Whistle.blow()
	if not hasDog() then
		ctl.HUD.toast("Adopt a dog first!")
		return
	end
	if not Whistle.confirmStop(againLabel()) then
		return
	end
	local now = os.clock()
	if now < readyAt then
		return
	end
	readyAt = now + PetActions.Actions.whistle.cooldown
	bounce()
	-- Two quick rising chirps: instant feedback before the server answers.
	Sounds.play("whistle")
	task.delay(0.14, Sounds.play, "whistle", 1.25)
	if ctl.Petting.isActive() then
		ctl.Petting.stop()
	end
	task.spawn(function()
		local ok, err = State.request(Remotes.RequestKinds.PetAction, { action = "whistle" })
		if not ok and err then
			ctl.HUD.toast(err)
		end
	end)
end

-- Keyboard shows "H", gamepad shows the D-pad, touch shows nothing.
local function updateHint()
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		hint.Visible = false
	elseif last.Name:find("Gamepad") then
		hint.Visible = true
		hint.Text = "D-pad ↑"
	else
		hint.Visible = true
		hint.Text = "H"
	end
end

local function jumpButton(): GuiObject?
	local touchGui = player.PlayerGui:FindFirstChild("TouchGui")
	local jump = touchGui and touchGui:FindFirstChild("JumpButton", true)
	if jump and jump:IsA("GuiObject") and jump.Visible and jump.AbsoluteSize.X > 0 then
		return jump
	end
	return nil
end

-- Above the jump button on touch screens; bottom-right otherwise.
local function place()
	local jump = jumpButton()
	if jump then
		local origin = gui.AbsolutePosition
		local x = jump.AbsolutePosition.X + jump.AbsoluteSize.X / 2 - origin.X
		local y = jump.AbsolutePosition.Y - GAP - origin.Y
		button.AnchorPoint = Vector2.new(0.5, 1)
		button.Position = UDim2.fromOffset(x, y)
	else
		button.AnchorPoint = Vector2.new(1, 1)
		button.Position = UDim2.new(1, -16, 1, -16)
	end
end

local function updateVisible()
	local v = hasDog() and not ctl.Dialogue.isOpen()
	button.Visible = v
	if not v and GuiService.SelectedObject == button then
		GuiService.SelectedObject = nil
	end
end

function Whistle.start(screenGui: ScreenGui, controllers)
	ctl = controllers
	gui = screenGui
	button = new("TextButton", {
		Name = "WhistleButton",
		Size = UDim2.fromOffset(SIZE, SIZE),
		BackgroundTransparency = 1,
		Text = "",
		Visible = false,
		Parent = gui,
	}) :: TextButton
	circle = new("Frame", {
		Name = "Circle",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.white,
		BackgroundTransparency = 0.05,
		Parent = button,
		Children = {
			Theme.corner(SIZE / 2),
			Theme.stroke(C.pink, 3),
			Theme.label("📣", { Name = "Icon", Size = UDim2.fromScale(1, 1), TextSize = 28 }),
		},
	}) :: Frame
	hint = Theme.label("H", {
		Name = "Hint",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(46, 18),
		BackgroundColor3 = C.ink,
		BackgroundTransparency = 0.1,
		TextColor3 = C.white,
		TextSize = 12,
		Font = Theme.Fonts.bold,
		Parent = button,
		Children = { Theme.corner(9) },
	})
	button.Activated:Connect(Whistle.blow)

	-- "Stop <activity>? Press again" (with a shrinking bar for the time left).
	confirmPanel = new("Frame", {
		Name = "StopActivityConfirm",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.fromOffset(380, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.bg,
		Visible = false,
		ZIndex = 30,
		Parent = gui,
		Children = { Theme.corner(16), Theme.stroke(C.orange, 4), Theme.padding(10), Theme.list(nil, 6), new("UISizeConstraint", { MaxSize = Vector2.new(380, 200) }) },
	}) :: Frame
	confirmText = Theme.label("", { Font = Theme.Fonts.title, TextSize = 20, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, ZIndex = 31, Parent = confirmPanel })
	local track = new("Frame", { Size = UDim2.new(1, 0, 0, 8), BackgroundColor3 = Color3.fromRGB(230, 225, 240), LayoutOrder = 2, ZIndex = 31, Parent = confirmPanel, Children = { Theme.corner(4) } })
	confirmFill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.orange, ZIndex = 32, Parent = track, Children = { Theme.corner(4) } }) :: Frame
	RunService.RenderStepped:Connect(function()
		if confirmPanel.Visible then
			local left = confirmUntil - os.clock()
			if left <= 0 or player:GetAttribute("ActivityName") == nil then
				hideConfirm()
			else
				confirmFill.Size = UDim2.fromScale(left / CONFIRM_SECONDS, 1)
			end
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		-- processed: typing in chat, or D-pad navigating a selected menu.
		if processed then
			return
		end
		if input.KeyCode == KEY or input.KeyCode == PAD then
			Whistle.blow()
		end
	end)
	UserInputService.LastInputTypeChanged:Connect(updateHint)
	updateHint()

	-- The touch controls appear (and move) on their own schedule, so
	-- re-place a couple of times a second rather than tracking them.
	local acc = 1
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.5 then
			acc = 0
			place()
			updateVisible()
		end
	end)
end

return Whistle
