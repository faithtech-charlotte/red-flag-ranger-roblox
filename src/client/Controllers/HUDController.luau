--[[
	HUDController: coins, next objective, toasts, celebrations, and the side
	buttons (My Dog, Missions, Wardrobe, Help). Help is ALWAYS visible.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QuestCatalog = require(ReplicatedStorage.Shared.Catalogs.QuestCatalog)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local State = require(script.Parent.State)
local Sounds = require(script.Parent.Parent.UI.Sounds)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors
local new = Theme.new

local HUD = {}
local controllers
local gui: ScreenGui
local coinLabel: TextLabel
local saveChip: Frame
local objectiveTitle: TextLabel
local objectiveHint: TextLabel
local lastObjective = ""
local objectiveShownAt = 0
local toastList: Frame
local helpPanel: Frame
local petButton: TextButton

local function playChime()
	Sounds.play("chime")
end

function HUD.toast(text: string, style: string?)
	local color = ({
		coins = C.yellow,
		success = C.green,
		warn = C.orange,
		info = C.white,
	})[style or "info"] or C.white
	local dark = style == "info" or style == "coins" or style == nil
	local toast = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = color,
		Children = {
			Theme.corner(12),
			Theme.padding(8),
			Theme.label(text, {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Font = Theme.Fonts.bold,
				TextColor3 = dark and C.ink or C.white,
			}),
		},
	}) :: Frame
	toast.Parent = toastList
	Theme.pop(toast)
	task.delay(3.5, function()
		toast:Destroy()
	end)
end

function HUD.celebrate(title: string, coins: number?, subtitle: string?)
	playChime()
	local banner = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.38),
		Size = UDim2.fromOffset(440, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.yellow,
		Parent = gui,
		Children = {
			Theme.corner(20),
			Theme.stroke(C.orange, 4),
			Theme.padding(14),
			Theme.list(nil, 4),
			new("UISizeConstraint", { MaxSize = Vector2.new(440, 400) }),
			Theme.label("🎉 " .. title, { Font = Theme.Fonts.title, TextSize = 30, Size = UDim2.new(1, 0, 0, 38), LayoutOrder = 1 }),
			subtitle and Theme.label(subtitle, { Font = Theme.Fonts.bold, TextSize = 18, LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }) or nil,
			coins and Theme.label(`+{coins} Paw Coins`, { Font = Theme.Fonts.title, TextSize = 22, TextColor3 = C.orange, LayoutOrder = 3 }) or nil,
		},
	}) :: Frame
	Theme.pop(banner)
	task.delay(2.4, function()
		banner:Destroy()
	end)
end

local function sideButton(text: string, color: Color3, order: number, onClick): TextButton
	return Theme.button(text, color, onClick, {
		Size = UDim2.fromOffset(150, 50),
		LayoutOrder = order,
		TextSize = 20,
	})
end

local function popup(title: string, color: Color3): (Frame, Frame)
	local frame = new("Frame", {
		Name = title,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -176, 0.5, 0),
		Size = UDim2.fromOffset(330, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.panel,
		Visible = false,
		Parent = gui,
		Children = {
			Theme.corner(18),
			Theme.stroke(color, 4),
			Theme.padding(14),
			Theme.list(nil, 8),
		},
	}) :: Frame
	local header = new("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, LayoutOrder = 0, Parent = frame }) :: Frame
	Theme.label(title, { Font = Theme.Fonts.title, TextSize = 26, TextColor3 = color, Size = UDim2.new(1, -44, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Parent = header })
	Theme.button("✕", C.inkSoft, function()
		frame.Visible = false
	end, { Size = UDim2.fromOffset(40, 34), Position = UDim2.new(1, -40, 0, 0), Parent = header })
	local body = new("Frame", {
		Name = "Body",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = frame,
		Children = { Theme.list(nil, 8) },
	}) :: Frame
	return frame, body
end

local function clear(body: Instance)
	for _, child in body:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

local function renderHelp()
	local data = State.data
	local body = helpPanel:FindFirstChild("Body") :: Frame
	clear(body)
	Theme.label("If anything feels weird, worrying, or pressuring, in this game or anywhere online, you can talk to a trusted adult.", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = body,
	})
	Theme.button("Talk to Ranger Lee", C.help, function()
		helpPanel.Visible = false
		State.request(Remotes.RequestKinds.RequestHelp)
	end, { LayoutOrder = 2, Parent = body })
	Theme.label("A trusted adult could be a parent, caregiver, teacher, coach, or school counselor.", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextColor3 = C.inkSoft,
		TextSize = 16,
		LayoutOrder = 3,
		Parent = body,
	})
	local blocked = data and data.blocked or {}
	if next(blocked) then
		Theme.label("Blocked in this game", { Font = Theme.Fonts.bold, LayoutOrder = 4, Parent = body })
		for npcId, name in blocked do
			Theme.button(`Unblock {name}`, C.inkSoft, function()
				State.request(Remotes.RequestKinds.Unblock, { npcId = npcId })
			end, { LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 40), TextSize = 18, Parent = body })
		end
	end
	Theme.label("Block and Report in this game are for practice and don't contact Roblox. On real Roblox, you can block or report someone from the menu or their profile.", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextColor3 = C.inkSoft,
		TextSize = 14,
		LayoutOrder = 6,
		Parent = body,
	})
end

-- Hide the HUD's buttons and objective during hands-on play (petting).
-- The Help button is never in this list.
local focusFrames: { GuiObject } = {}
function HUD.setFocus(on: boolean)
	for _, f in focusFrames do
		f.Visible = not on
	end
end

function HUD.showObjectiveHint()
	objectiveHint.Visible = true
	objectiveShownAt = os.clock()
	local at = objectiveShownAt
	task.delay(7, function()
		if objectiveShownAt == at then
			objectiveHint.Visible = false
		end
	end)
end

local function renderObjective()
	local data = State.data
	if not data then
		return
	end
	coinLabel.Text = `🐾 {data.coins}`
	saveChip.Visible = data.persistent == false
	petButton.Text = data.pet and `🐶 {data.pet.name}` or "🐶 My Dog"
	local nextQuest = nil
	for _, quest in QuestCatalog.Ordered do
		if not data.quests[quest.id] then
			nextQuest = quest
			break
		end
	end
	if nextQuest then
		objectiveTitle.Text = "NEXT: " .. nextQuest.title
		objectiveHint.Text = nextQuest.hint
	else
		objectiveTitle.Text = "Explore with your dog!"
		objectiveHint.Text = "Earn Paw Coins for new looks. Jordan, Riley and friends are around."
	end
	-- Show the hint when the objective changes, then tuck it away so the
	-- screen stays clear. Tapping the card shows it again.
	if objectiveTitle.Text ~= lastObjective then
		lastObjective = objectiveTitle.Text
		HUD.showObjectiveHint()
	end
	if helpPanel.Visible then
		renderHelp()
	end
end

function HUD.start(screenGui: ScreenGui, ctl)
	task.defer(function()
		require(script.Parent.PanelCoordinator).track("help", helpPanel, function()
			helpPanel.Visible = false
		end)
	end)
	gui = screenGui
	controllers = ctl

	-- Coins (top-left)
	local coins = new("Frame", {
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(150, 48),
		BackgroundColor3 = C.yellow,
		Parent = gui,
		Children = { Theme.corner(24), Theme.stroke(C.orange, 3) },
	}) :: Frame
	coinLabel = Theme.label("🐾 0", { Size = UDim2.fromScale(1, 1), Font = Theme.Fonts.title, TextSize = 26, Parent = coins })
	saveChip = new("Frame", {
		Position = UDim2.fromOffset(12, 66),
		Size = UDim2.fromOffset(150, 26),
		BackgroundColor3 = C.orange,
		Visible = false,
		Parent = gui,
		Children = { Theme.corner(13), Theme.label("Not saving", { Size = UDim2.fromScale(1, 1), TextColor3 = C.white, Font = Theme.Fonts.bold, TextSize = 14 }) },
	}) :: Frame

	-- Objective (top-center)
	local objective = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.new(0.5, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.panel,
		BackgroundTransparency = 0.05,
		Parent = gui,
		Children = {
			Theme.corner(16),
			Theme.stroke(C.teal, 3),
			Theme.padding(8),
			Theme.list(nil, 2),
			new("UISizeConstraint", { MinSize = Vector2.new(280, 0), MaxSize = Vector2.new(520, 200) }),
		},
	}) :: Frame
	objectiveTitle = Theme.label("Loading…", { Font = Theme.Fonts.title, TextSize = 22, LayoutOrder = 1, Parent = objective, Size = UDim2.new(1, 0, 0, 26) })
	objectiveHint = Theme.label("", { TextSize = 16, TextColor3 = C.inkSoft, LayoutOrder = 2, Parent = objective, Size = UDim2.new(1, 0, 0, 20) })
	objective.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			HUD.showObjectiveHint()
		end
	end)

	toastList = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 100),
		Size = UDim2.fromOffset(380, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = gui,
		Children = { Theme.list(nil, 6) },
	}) :: Frame

	-- Side buttons (right)
	local side = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(150, 240),
		BackgroundTransparency = 1,
		Parent = gui,
		Children = { Theme.list(nil, 10) },
	})
	helpPanel = popup("Help & Safety", C.help)
	petButton = sideButton("🐶 My Dog", C.pink, 1, function()
		helpPanel.Visible = false
		controllers.ActionBar.toggle()
	end)
	petButton.Parent = side
	local missionsButton = sideButton("📜 Missions", C.green, 2, function()
		controllers.Missions.open()
	end)
	missionsButton.Parent = side
	local wardrobeButton = sideButton("👕 Wardrobe", C.purple, 3, function()
		controllers.Shop.open("wardrobe")
	end)
	wardrobeButton.Parent = side
	sideButton("💙 Help", C.help, 4, function()
		controllers.ActionBar.close()
		helpPanel.Visible = not helpPanel.Visible
		renderHelp()
	end).Parent = side

	-- Help stays out of this list: it must never be hidden, even while petting.
	focusFrames = { objective :: GuiObject, petButton :: GuiObject, missionsButton :: GuiObject, wardrobeButton :: GuiObject }
	State.changed:Connect(renderObjective)
	if State.data then
		renderObjective()
	end
	State.push:Connect(function(kind, payload)
		if kind == Remotes.PushKinds.Toast then
			HUD.toast(payload.text, payload.style)
		elseif kind == Remotes.PushKinds.Celebrate then
			HUD.celebrate(payload.title, payload.coins, payload.subtitle)
		end
	end)
end

return HUD
