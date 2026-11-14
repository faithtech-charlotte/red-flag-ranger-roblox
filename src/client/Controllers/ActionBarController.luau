--[[
	ActionBarController: a small contextual action bar for your dog.

	It slides in at the bottom of the screen when you stop near your dog,
	and tucks away when you walk off or start playing (petting, fetch, a
	conversation, the spa). It never covers the dog.

	  ✋ Pet      hands-on petting (PettingController)
	  🎾 Ball     equip the ball (BallController)
	  🦴 Care     food and brushing (small popover)
	  🐕 Sit / 📣 Come   one button that does what makes sense now
	  ✋ Stay     once unlocked
	  ⭐ Tricks   once any trick is unlocked (small popover)

	Keyboard Q / gamepad Y open it from anywhere and select the first
	button; the HUD's 🐶 button does the same on touch screens.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local BondCatalog = require(ReplicatedStorage.Shared.Catalogs.BondCatalog)
local ItemCatalog = require(ReplicatedStorage.Shared.Catalogs.ItemCatalog)
local PetActions = require(ReplicatedStorage.Shared.Catalogs.PetActions)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local State = require(script.Parent.State)
local Sounds = require(script.Parent.Parent.UI.Sounds)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors
local new = Theme.new
local player = Players.LocalPlayer

local SHOW_DISTANCE = 12
local STILL_SECONDS = 0.5

local Bar = {}
local ctl
local root: Frame
local row: Frame
local popover: Frame
local bondChip: TextLabel
local bondFill: Frame
local statusLabel: TextLabel
local shown = false
local pinned = false -- opened on purpose (Q / Y / 🐶): stays until dismissed
local stillFor = 0
local busy = false
local buttons: { { button: TextButton, check: () -> (boolean, string?) } } = {}
local popButtons: { { button: TextButton, check: () -> (boolean, string?) } } = {}
local popKind: string? = nil

local function pet(): Model?
	return ctl.Pet.ownPet()
end

local function distance(): number
	local model = pet()
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not model or not model.PrimaryPart or not hrp then
		return math.huge
	end
	return (model.PrimaryPart.Position - hrp.Position).Magnitude
end

local function petState(): string
	local m = pet()
	return m and m:GetAttribute("PetState") or "Following"
end

local function level(): number
	return State.data and State.data.pet and State.data.pet.level or 1
end

local function cooldownLeft(key: string): number
	local t = State.data and State.data.cooldowns and State.data.cooldowns[key]
	return t and math.max(0, t - workspace:GetServerTimeNow()) or 0
end

local function busyOutside(): boolean
	return ctl.Dialogue.isOpen() or ctl.Petting.isActive() or ctl.Ball.isEquipped() or ctl.Activity.isBusy()
end

local function send(payload)
	if busy then
		return
	end
	busy = true
	Sounds.play("click")
	local ok, err = State.request(Remotes.RequestKinds.PetAction, payload)
	busy = false
	statusLabel.Text = (not ok and err) or ""
	if not ok and err then
		task.delay(2.5, function()
			if statusLabel.Text == err then
				statusLabel.Text = ""
			end
		end)
	end
end

-- Sit / Stay / Come cancel a running activity on the server, so they ask
-- first (same confirm as the whistle).
local function command(payload)
	if ctl.Whistle.confirmStop() then
		send(payload)
	end
end

local function roundButton(parent: Instance, list, icon: string, label: string, order: number, check: () -> (boolean, string?), onClick: () -> ())
	local b = new("TextButton", {
		Name = "Action_" .. label,
		LayoutOrder = order,
		Size = UDim2.fromOffset(62, 70),
		BackgroundTransparency = 1,
		Text = "",
		Parent = parent,
	}) :: TextButton
	local circle = new("Frame", {
		Name = "Circle",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(52, 52),
		BackgroundColor3 = C.white,
		Parent = b,
		Children = {
			Theme.corner(26),
			Theme.stroke(C.pink, 2),
			Theme.label(icon, { Name = "Icon", Size = UDim2.fromScale(1, 1), TextSize = 26 }),
			Theme.label("", {
				Name = "Badge",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.82, 0.12),
				Size = UDim2.fromOffset(30, 18),
				BackgroundColor3 = C.ink,
				BackgroundTransparency = 0.1,
				TextColor3 = C.white,
				TextSize = 11,
				Font = Theme.Fonts.bold,
				Visible = false,
				Children = { Theme.corner(9) },
			}),
		},
	})
	Theme.label(label, { Name = "Label", Position = UDim2.fromOffset(0, 53), Size = UDim2.new(1, 0, 0, 16), TextSize = 12, Font = Theme.Fonts.bold, TextColor3 = C.white, TextStrokeTransparency = 0.4, Parent = b })
	b.Activated:Connect(function()
		local ok = check()
		local scale = circle:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = circle })
		;(scale :: UIScale).Scale = 0.85
		TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		if ok then
			onClick()
		end
	end)
	table.insert(list, { button = b, check = check })
	return b
end

local function refresh(list)
	for _, entry in list do
		local ok, reason = entry.check()
		local circle = entry.button:FindFirstChild("Circle") :: Frame
		circle.BackgroundColor3 = ok and C.white or Color3.fromRGB(225, 220, 230)
		;(circle:FindFirstChild("Icon") :: TextLabel).TextTransparency = ok and 0 or 0.55
		local badge = circle:FindFirstChild("Badge") :: TextLabel
		badge.Visible = reason ~= nil
		badge.Text = reason or ""
	end
end

local function touchCheck(def): (boolean, string?)
	local state = petState()
	if state == "Fetching" or state == "Returning" or state == "MovingToTarget" then
		return false, "busy"
	end
	if def and def.touch and distance() > PetActions.TOUCH_DISTANCE then
		return false, "far"
	end
	local left = def and def.cooldown > 0 and cooldownLeft(def.id) or 0
	if left > 0 then
		return false, `{math.ceil(left)}s`
	end
	return true, nil
end

local function closePopover()
	popKind = nil
	popover.Visible = false
	for _, e in popButtons do
		e.button:Destroy()
	end
	table.clear(popButtons)
end

local function openPopover(kind: string)
	if popKind == kind then
		closePopover()
		return
	end
	closePopover()
	popKind = kind
	local order = 0
	local function add(icon, label, check, onClick)
		order += 1
		roundButton(popover, popButtons, icon, label, order, check, onClick)
	end
	if kind == "care" then
		add("🥣", "Kibble", function()
			local ok, reason = touchCheck(PetActions.Actions.feed)
			if not ok then
				return ok, reason
			end
			local left = cooldownLeft("kibble")
			return left <= 0, left > 0 and `{math.ceil(left)}s` or "free"
		end, function()
			send({ action = "feed", food = PetActions.FreeFood.id })
		end)
		for _, item in ItemCatalog.sorted(function(it)
			return it.kind == "consumable"
		end) do
			if (State.data.inventory[item.id] or 0) > 0 then
				add("🦴", item.name:match("%S+$") or item.name, function()
					local ok, reason = touchCheck(PetActions.Actions.feed)
					if not ok then
						return ok, reason
					end
					return true, `x{State.data.inventory[item.id] or 0}`
				end, function()
					send({ action = "feed", food = item.id })
				end)
			end
		end
		add("🪮", "Brush", function()
			return touchCheck(PetActions.Actions.brush)
		end, function()
			send({ action = "brush" })
		end)
	elseif kind == "tricks" then
		for _, id in PetActions.TrickOrder do
			local trick = PetActions.Tricks[id]
			local need = BondCatalog.requiredLevel("trick", id) or 99
			if level() >= need then
				add(trick.icon, trick.label, function()
					local ok, reason = touchCheck(PetActions.Actions.tricks)
					if not ok then
						return ok, reason
					end
					local left = cooldownLeft("trick")
					return left <= 0, left > 0 and `{math.ceil(left)}s` or nil
				end, function()
					send({ action = "trick", trick = id })
				end)
			end
		end
	end
	popover.Visible = true
	refresh(popButtons)
end

local function rebuild()
	for _, e in buttons do
		e.button:Destroy()
	end
	table.clear(buttons)
	local state = petState()
	roundButton(row, buttons, "✋", "Pet", 1, function()
		return touchCheck({ touch = true, cooldown = 0, id = "pet" })
	end, function()
		closePopover()
		ctl.Petting.begin()
	end)
	roundButton(row, buttons, "🎾", "Ball", 2, function()
		return true, nil
	end, function()
		closePopover()
		ctl.Ball.equip()
	end)
	roundButton(row, buttons, "🦴", "Care", 3, function()
		return true, nil
	end, function()
		openPopover("care")
	end)
	if state == "Sitting" or state == "Staying" then
		roundButton(row, buttons, "📣", "Come", 4, function()
			return true, nil
		end, function()
			command({ action = "come" })
		end)
	else
		roundButton(row, buttons, "🐕", "Sit", 4, function()
			return touchCheck(nil)
		end, function()
			command({ action = "sit" })
		end)
	end
	if BondCatalog.isUnlocked(level(), "command", "stay") and state ~= "Staying" then
		roundButton(row, buttons, "🛑", "Stay", 5, function()
			return true, nil
		end, function()
			command({ action = "stay" })
		end)
	end
	if BondCatalog.isUnlocked(level(), "trick", "spin") then
		roundButton(row, buttons, "⭐", "Tricks", 6, function()
			return touchCheck(PetActions.Actions.tricks)
		end, function()
			openPopover("tricks")
		end)
	end
	refresh(buttons)
end

local lastState = ""
local function renderBond()
	local p = State.data and State.data.pet
	if not p then
		return
	end
	bondChip.Text = `♥ {p.name} · Bond Lv {p.level}` .. (p.nextUnlock and `  →  {p.nextUnlock.label}` or "")
	bondFill.Size = UDim2.fromScale(p.xpNeed and math.clamp(p.xpInto / p.xpNeed, 0, 1) or 1, 1)
end

local function setShown(v: boolean)
	if shown == v then
		return
	end
	shown = v
	if v then
		lastState = petState()
		rebuild()
		renderBond()
		root.Visible = true
		root.Position = UDim2.new(0, -40, 1, -14)
		TweenService:Create(root, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0, 14, 1, -14) }):Play()
	else
		pinned = false
		closePopover()
		root.Visible = false
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(root) then
			GuiService.SelectedObject = nil
		end
	end
end

function Bar.close()
	setShown(false)
end

function Bar.open()
	if not (State.data and State.data.pet) then
		ctl.HUD.toast("Adopt a dog first!")
		return
	end
	if busyOutside() then
		if ctl.Ball.isEquipped() then
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid:UnequipTools()
			end
		else
			return
		end
	end
	pinned = true
	setShown(true)
	if UserInputService.GamepadEnabled and buttons[1] then
		GuiService.SelectedObject = buttons[1].button
	end
end

function Bar.toggle()
	if shown then
		Bar.close()
	else
		Bar.open()
	end
end

function Bar.start(gui: ScreenGui, controllers)
	ctl = controllers
	root = new("Frame", {
		Name = "PetActionBar",
		-- Bottom-left: clear of the dog (it trots on your right) and the hotbar.
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, -14),
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
		Children = { Theme.list(nil, 4, Enum.HorizontalAlignment.Left) },
	}) :: Frame
	statusLabel = Theme.label("", { LayoutOrder = 0, Size = UDim2.fromOffset(360, 20), TextSize = 15, Font = Theme.Fonts.bold, TextColor3 = C.white, TextStrokeTransparency = 0.3, Parent = root })
	popover = new("Frame", {
		Name = "Popover",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.55,
		Visible = false,
		Parent = root,
		Children = { Theme.corner(20), Theme.padding(6), Theme.list(Enum.FillDirection.Horizontal, 4) },
	}) :: Frame
	local chip = new("Frame", {
		Name = "BondChip",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		Parent = root,
		Children = { Theme.corner(13), new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }) },
	})
	bondChip = Theme.label("", { Size = UDim2.new(0, 0, 0, 20), AutomaticSize = Enum.AutomaticSize.X, TextSize = 14, Font = Theme.Fonts.bold, TextColor3 = C.white, TextWrapped = false, Parent = chip })
	local track = new("Frame", { Position = UDim2.new(0, 0, 1, -4), Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = Color3.fromRGB(90, 80, 100), BorderSizePixel = 0, Parent = chip })
	bondFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.pink, BorderSizePixel = 0, Parent = track }) :: Frame
	row = new("Frame", {
		Name = "Row",
		LayoutOrder = 3,
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.6,
		Parent = root,
		Children = { Theme.corner(24), Theme.padding(6), Theme.list(Enum.FillDirection.Horizontal, 4) },
	}) :: Frame

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if (input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonY) and not ctl.Petting.isActive() then
			Bar.toggle()
		elseif input.KeyCode == Enum.KeyCode.ButtonB and shown then
			Bar.close()
		end
	end)

	State.changed:Connect(function()
		if shown then
			renderBond()
			if popKind == "care" then
				local k = popKind
				popKind = nil
				openPopover(k)
			end
		end
	end)
	State.push:Connect(function(kind, payload)
		if kind == Remotes.PushKinds.Bond then
			local model = pet()
			if model and payload.gained and payload.gained > 0 then
				ctl.Pet.floatText(model, `+{payload.gained} ♥`)
			end
		elseif kind == Remotes.PushKinds.Celebrate and payload.title and payload.title:find("Bond Level") then
			Sounds.play("levelup")
		end
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local moving = hrp ~= nil and Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z).Magnitude > 1.5
		stillFor = moving and 0 or stillFor + dt
		acc += dt
		if acc < 0.2 then
			return
		end
		acc = 0
		local hasPet = State.data ~= nil and State.data.pet ~= nil and pet() ~= nil
		local near = distance() <= SHOW_DISTANCE
		if not hasPet or busyOutside() then
			setShown(false)
		elseif pinned then
			if moving and not near then
				setShown(false)
			end
		else
			setShown(near and stillFor >= STILL_SECONDS)
		end
		if shown then
			if petState() ~= lastState then
				lastState = petState()
				rebuild()
			else
				refresh(buttons)
			end
			if popKind then
				refresh(popButtons)
			end
		end
	end)
end

return Bar
