--[[
	MissionsController: the Ranger Journal. Opens from the HUD "Missions"
	button or the Mission Board at Ranger HQ. Lists every quest with its
	status and hint, so players always have something fun to do next.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QuestCatalog = require(ReplicatedStorage.Shared.Catalogs.QuestCatalog)
local Places = require(ReplicatedStorage.Shared.Places)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local State = require(script.Parent.State)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors
local new = Theme.new

local Missions = {}
local overlay: Frame
local list: ScrollingFrame
local summary: TextLabel

local function render()
	if not overlay.Visible then
		return
	end
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local data = State.data
	if not data then
		return
	end
	local done = 0
	for i, quest in QuestCatalog.Ordered do
		local complete = data.quests[quest.id] == true
		if complete then
			done += 1
		end
		local place = quest.waypoint and Places.get(quest.waypoint)
		new("Frame", {
			LayoutOrder = (complete and 1000 or 0) + i,
			Size = UDim2.new(1, -8, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = complete and Color3.fromRGB(232, 248, 236) or C.white,
			Parent = list,
			Children = {
				Theme.corner(12),
				Theme.stroke(complete and C.green or C.yellow, 2),
				Theme.padding(10),
				Theme.list(nil, 2, Enum.HorizontalAlignment.Left),
				Theme.label((complete and "✅ " or "⭐ ") .. quest.title, {
					Font = Theme.Fonts.title,
					TextSize = 19,
					TextXAlignment = Enum.TextXAlignment.Left,
					LayoutOrder = 1,
				}),
				Theme.label(complete and "Done!" or (quest.hint .. (place and `  ({place.displayName})` or "")), {
					TextSize = 14,
					TextColor3 = C.inkSoft,
					TextXAlignment = Enum.TextXAlignment.Left,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					LayoutOrder = 2,
				}),
			},
		})
	end
	local pet = data.pet
	summary.Text = `{done}/{#QuestCatalog.Ordered} missions done`
		.. (pet and `  ·  {pet.name}: Bond Level {pet.level}` or "")
end

function Missions.open()
	overlay.Visible = true
	render()
	Theme.pop(overlay:FindFirstChild("Panel") :: GuiObject)
end

function Missions.close()
	overlay.Visible = false
end

function Missions.start(gui: ScreenGui)
	overlay = new("Frame", {
		Name = "Missions",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		Visible = false,
		ZIndex = 8,
		Parent = gui,
	}) :: Frame
	local panel = new("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.82),
		BackgroundColor3 = C.bg,
		Parent = overlay,
		Children = { Theme.corner(24), Theme.stroke(C.green, 5), Theme.padding(16), new("UISizeConstraint", { MaxSize = Vector2.new(560, 640) }) },
	})
	Theme.label("📜 Ranger Journal", { Font = Theme.Fonts.title, TextSize = 30, Size = UDim2.new(1, -60, 0, 36), TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
	summary = Theme.label("", { TextSize = 15, TextColor3 = C.inkSoft, Size = UDim2.new(1, -60, 0, 20), Position = UDim2.fromOffset(0, 38), TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
	Theme.button("✕", C.inkSoft, Missions.close, { Size = UDim2.fromOffset(48, 44), Position = UDim2.new(1, -48, 0, 0), Parent = panel })
	list = new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 66),
		Size = UDim2.new(1, 0, 1, -66),
		BackgroundTransparency = 1,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = panel,
		Children = { Theme.list(nil, 8) },
	}) :: ScrollingFrame

	State.changed:Connect(render)
	State.push:Connect(function(kind)
		if kind == Remotes.PushKinds.OpenMissions then
			Missions.open()
		end
	end)
end

return Missions
