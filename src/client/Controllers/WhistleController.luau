--[[
	WhistleController: an always-on way to call your dog back from anywhere.

	  Keyboard   H ("here")
	  Gamepad    D-pad Up
	  Touch      a round 📣 button that sits just above the jump button

	The button is on screen whenever you have a dog (hidden during a
	conversation, so it can't cover a choice). Whistling plays a chirp right
	away; the server drops whatever the dog was doing, puts a "!" over it, and
	it runs back to you. See PetInteractionService handlers.whistle.
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

local Whistle = {}
local ctl
local gui: ScreenGui
local button: TextButton
local circle: Frame
local hint: TextLabel
local readyAt = 0

local function hasDog(): boolean
	return State.data ~= nil and State.data.pet ~= nil
end

local function bounce()
	local scale = circle:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = circle })
	;(scale :: UIScale).Scale = 0.8
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

function Whistle.blow()
	if not hasDog() then
		ctl.HUD.toast("Adopt a dog first!")
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
