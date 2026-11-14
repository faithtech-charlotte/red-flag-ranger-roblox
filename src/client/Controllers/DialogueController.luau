--[[
	DialogueController: shows NPC lines and choices sent by the server, and
	sends back only the chosen id. It never decides what happens next.

	Conversations with other kids ("peer" NPCs) show practice Block / Report /
	Get help buttons, the same way real chat has those tools. "Walk away"
	(the ✕) is always available.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local State = require(script.Parent.State)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors
local new = Theme.new

local Dialogue = {}
local panel: Frame
local nameChip: Frame
local nameLabel: TextLabel
local textLabel: TextLabel
local choiceList: Frame
local safetyBar: Frame
local current: any = nil
local waiting = false
local typeStarted = 0
local choiceButtons: { TextButton } = {}

local TYPE_SPEED = 70 -- characters per second

local function send(kind: string, payload: any)
	if waiting then
		return
	end
	waiting = true
	local ok, err = State.request(kind, payload)
	waiting = false
	if not ok and err then
		-- Errors are rare (e.g. walked too far). Close quietly.
		panel.Visible = false
		current = nil
	end
end

local function clearChoices()
	for _, child in choiceList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	table.clear(choiceButtons)
end

local function show(view)
	current = view
	panel.Visible = true
	local isTip = view.speaker == "tip"
	panel.BackgroundColor3 = isTip and C.tip or C.panel
	;(panel:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = isTip and C.help or C.ink
	nameChip.BackgroundColor3 = isTip and C.help or C.orange
	nameLabel.Text = isTip and "💡 Ranger Tip" or (view.subtitle and `{view.npcName} · {view.subtitle}` or view.npcName)
	textLabel.TextColor3 = isTip and C.tipInk or C.ink
	textLabel.Text = view.text
	textLabel.MaxVisibleGraphemes = 0
	typeStarted = os.clock()

	clearChoices()
	for i, choice in view.choices do
		local b = Theme.button(`{i}.  {choice.text}`, C.white, function()
			if current and current.sessionId == view.sessionId then
				send(Remotes.RequestKinds.DialogueChoose, { sessionId = view.sessionId, choiceId = choice.id })
			end
		end, {
			LayoutOrder = i,
			TextColor3 = C.ink,
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Theme.Fonts.bold,
			TextSize = 20,
			Size = UDim2.new(1, 0, 0, 46),
			Parent = choiceList,
		})
		;(b:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = isTip and C.help or C.teal
		new("UIPadding", { PaddingLeft = UDim.new(0, 14), Parent = b })
		table.insert(choiceButtons, b)
	end

	safetyBar.Visible = view.safetyTools == true and not isTip
	Theme.pop(panel)
	if UserInputService.GamepadEnabled and choiceButtons[1] then
		GuiService.SelectedObject = choiceButtons[1]
	end
end

local function hide()
	current = nil
	panel.Visible = false
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(panel) then
		GuiService.SelectedObject = nil
	end
end

function Dialogue.isOpen(): boolean
	return current ~= nil
end

function Dialogue.start(gui: ScreenGui)
	panel = new("Frame", {
		Name = "Dialogue",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.new(0.94, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.panel,
		Visible = false,
		ZIndex = 5,
		Parent = gui,
		Children = {
			Theme.corner(20),
			Theme.stroke(C.ink, 3),
			new("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16), PaddingTop = UDim.new(0, 28), PaddingBottom = UDim.new(0, 14) }),
			Theme.list(nil, 10),
			new("UISizeConstraint", { MaxSize = Vector2.new(760, 700) }),
		},
	}) :: Frame

	nameChip = new("Frame", {
		Size = UDim2.new(0, 0, 0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = UDim2.fromOffset(0, -46),
		BackgroundColor3 = C.orange,
		ZIndex = 6,
		Parent = panel,
		Children = { Theme.corner(17), new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }) },
	}) :: Frame
	-- The chip floats above the panel edge, outside the list layout.
	local chipHolder = new("Frame", { Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, LayoutOrder = 0, Parent = panel })
	nameChip.Parent = chipHolder
	nameLabel = Theme.label("", { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Font = Theme.Fonts.title, TextSize = 20, TextColor3 = C.white, TextWrapped = false, ZIndex = 6, Parent = nameChip })

	local close = Theme.button("✕ Walk away", C.inkSoft, function()
		if current then
			send(Remotes.RequestKinds.DialogueClose, { sessionId = current.sessionId })
		end
	end, { Size = UDim2.fromOffset(130, 34), Position = UDim2.new(1, -130, 0, -46), TextSize = 16, ZIndex = 6, Parent = chipHolder })
	close.AnchorPoint = Vector2.new(0, 0)

	textLabel = Theme.label("", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 1,
		Parent = panel,
	})
	-- Tap the text to show it all at once.
	local skip = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Selectable = false, Parent = textLabel }) :: TextButton
	skip.Activated:Connect(function()
		textLabel.MaxVisibleGraphemes = -1
	end)

	choiceList = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = panel,
		Children = { Theme.list(nil, 6) },
	}) :: Frame

	safetyBar = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		Parent = panel,
		Children = { Theme.list(nil, 4) },
	}) :: Frame
	local toolRow = new("Frame", {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = safetyBar,
		Children = { Theme.list(Enum.FillDirection.Horizontal, 8) },
	})
	local function tool(text: string, color: Color3, id: string, order: number)
		Theme.button(text, color, function()
			if current then
				send(Remotes.RequestKinds.DialogueSafety, { sessionId = current.sessionId, tool = id })
			end
		end, { Size = UDim2.new(0.32, 0, 1, 0), TextSize = 17, LayoutOrder = order, Parent = toolRow })
	end
	tool("🚫 Block", C.inkSoft, "block", 1)
	tool("🚩 Report", C.orange, "report", 2)
	tool("💙 Get help", C.help, "help", 3)
	Theme.label("Practice tools: they don't contact Roblox.", { TextSize = 13, TextColor3 = C.inkSoft, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 2, Parent = safetyBar })

	RunService.RenderStepped:Connect(function()
		if current and textLabel.MaxVisibleGraphemes >= 0 then
			local n = math.floor((os.clock() - typeStarted) * TYPE_SPEED)
			if n >= #textLabel.Text then
				textLabel.MaxVisibleGraphemes = -1
			else
				textLabel.MaxVisibleGraphemes = n
			end
		end
	end)

	-- Number keys pick choices on keyboard.
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not current then
			return
		end
		local n = input.KeyCode.Value - Enum.KeyCode.One.Value + 1
		if n >= 1 and n <= #choiceButtons and input.UserInputType == Enum.UserInputType.Keyboard then
			local choice = current.choices[n]
			send(Remotes.RequestKinds.DialogueChoose, { sessionId = current.sessionId, choiceId = choice.id })
		end
	end)

	State.push:Connect(function(kind, payload)
		if kind == Remotes.PushKinds.Dialogue then
			show(payload)
		elseif kind == Remotes.PushKinds.DialogueClose then
			hide()
		end
	end)
end

return Dialogue
