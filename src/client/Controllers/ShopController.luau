--[[
	ShopController: the Fluff & Puff Salon shop and the Wardrobe. Both are
	the same catalog view; the shop can buy, the wardrobe only equips.
	All buying and equipping is decided by the server.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local ItemCatalog = require(ReplicatedStorage.Shared.Catalogs.ItemCatalog)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local State = require(script.Parent.State)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors
local new = Theme.new

local Shop = {}
local hud
local overlay: Frame
local titleLabel: TextLabel
local subtitleLabel: TextLabel
local grid: ScrollingFrame
local tabButtons: { [string]: TextButton } = {}
local mode: "shop" | "wardrobe" = "shop"
local shopId = "salon"
local tab: string = "dog"
local busy = false
local tabRow: Frame

local TAB_LABELS = { dog = "🐶 Dog", me = "🧢 Me", care = "🫧 Care", treats = "🦴 Treats" }
local SHOPS = {
	salon = { title = "Fluff & Puff Salon", tabs = { "dog", "me", "care" } },
	treat_shop = { title = "Bo's Treat Shop", tabs = { "treats" } },
}
local WARDROBE_TABS = { "dog", "me", "treats" }

local function swatch(item: ItemCatalog.Item): (Color3, string)
	local v = item.visual
	if item.kind == "bundle" then
		return C.yellow, "🎁"
	elseif item.kind == "consumable" then
		return C.orange, "🦴"
	elseif item.kind == "service" then
		return Color3.fromRGB(150, 220, 255), "🫧"
	elseif v and v.kind == "fur" then
		return v.color, "🐕"
	elseif v and v.kind == "leash" then
		return v.color, "🦮"
	elseif v and (v.kind == "cap" or v.kind == "party_hat") then
		return v.color, "🎩"
	elseif v and v.kind == "vest" then
		return v.color, "🦺"
	end
	return v and v.color or C.teal, "⭐"
end

local function isEquipped(data, item: ItemCatalog.Item): boolean
	if item.kind ~= "cosmetic" or not item.slot then
		return false
	end
	if item.target == "pet" then
		return data.pet ~= nil and data.pet.equipped[item.slot] == item.id
	end
	return data.playerEquipped[item.slot] == item.id
end

local function owns(data, item: ItemCatalog.Item): boolean
	if item.kind == "bundle" then
		for _, id in item.contents or {} do
			if not data.inventory[id] then
				return false
			end
		end
		return true
	end
	return (data.inventory[item.id] or 0) > 0
end

local function act(kind: string, payload)
	if busy then
		return
	end
	busy = true
	local ok, err = State.request(kind, payload)
	busy = false
	if not ok and err and hud then
		hud.toast(err, "warn")
	end
end

local function card(data, item: ItemCatalog.Item, order: number)
	local color, icon = swatch(item)
	local frame = new("Frame", {
		LayoutOrder = order,
		BackgroundColor3 = C.panel,
		Parent = grid,
		Children = { Theme.corner(14), Theme.stroke(C.disabled, 2), Theme.padding(8), Theme.list(nil, 4) },
	}) :: Frame
	new("Frame", {
		Size = UDim2.fromOffset(56, 56),
		BackgroundColor3 = color,
		LayoutOrder = 1,
		Parent = frame,
		Children = {
			Theme.corner(28),
			Theme.stroke(C.ink, 2),
			Theme.label(icon, { Size = UDim2.fromScale(1, 1), TextSize = 28 }),
		},
	})
	Theme.label(item.name, { Font = Theme.Fonts.title, TextSize = 18, LayoutOrder = 2, Parent = frame })
	Theme.label(item.description, { TextSize = 13, TextColor3 = C.inkSoft, Size = UDim2.new(1, 0, 0, 32), LayoutOrder = 3, Parent = frame })

	local owned = owns(data, item)
	local equipped = isEquipped(data, item)
	local text, bg, onClick
	if item.kind == "cosmetic" and owned then
		if equipped then
			text, bg = "Wearing ✓", C.green
			onClick = function()
				act(Remotes.RequestKinds.Unequip, { target = item.target, slot = item.slot })
			end
		else
			text, bg = "Wear", C.teal
			onClick = function()
				act(Remotes.RequestKinds.Equip, { itemId = item.id })
			end
		end
	elseif item.kind == "bundle" and owned then
		text, bg, onClick = "Owned ✓", C.disabled, function() end
	elseif item.kind == "consumable" and mode == "wardrobe" then
		local count = data.inventory[item.id] or 0
		text, bg = `Give ({count})`, count > 0 and C.orange or C.disabled
		onClick = function()
			act(Remotes.RequestKinds.UseItem, { itemId = item.id })
		end
	elseif mode == "shop" then
		local affordable = data.coins >= item.price
		local count = item.kind == "consumable" and (data.inventory[item.id] or 0) or nil
		text = `🐾 {item.price}` .. (count and count > 0 and `  (have {count})` or "")
		bg = affordable and C.orange or C.disabled
		onClick = function()
			act(Remotes.RequestKinds.Purchase, { itemId = item.id })
		end
	else
		text, bg, onClick = item.unlockOnly and "Bond reward" or "Buy in town", C.disabled, function() end
	end
	Theme.button(text, bg, onClick, { Size = UDim2.new(1, 0, 0, 40), TextSize = 18, LayoutOrder = 4, Parent = frame })
end

local function render()
	if not overlay.Visible then
		return
	end
	for _, child in grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for id, b in tabButtons do
		b.BackgroundColor3 = id == tab and C.purple or C.disabled
	end
	local data = State.data
	if not data then
		return
	end
	local items = ItemCatalog.sorted(function(item)
		if item.tab ~= tab then
			return false
		end
		if mode == "shop" and (item.unlockOnly or ItemCatalog.shopOf(item) ~= shopId) then
			return false
		end
		if mode == "wardrobe" then
			if item.kind == "service" or item.kind == "bundle" then
				return false
			end
			return owns(data, item) or item.kind == "consumable"
		end
		return true
	end)
	for i, item in items do
		card(data, item, i)
	end
	if #items == 0 then
		Theme.label(mode == "wardrobe" and "Nothing here yet. Visit the shops in town!" or "Coming soon!", {
			Size = UDim2.new(1, 0, 0, 40),
			Parent = grid,
		})
	end
end

local function buildTabs(ids: { string })
	for _, b in tabButtons do
		b:Destroy()
	end
	table.clear(tabButtons)
	for i, id in ids do
		tabButtons[id] = Theme.button(TAB_LABELS[id] or id, C.disabled, function()
			tab = id
			render()
		end, { Size = UDim2.fromOffset(120, 44), LayoutOrder = i, TextSize = 20, Parent = tabRow })
	end
	tab = ids[1]
end

function Shop.open(which: "shop" | "wardrobe", line: string?, npcName: string?, whichShop: string?)
	mode = which
	shopId = whichShop or "salon"
	overlay.Visible = true
	local shop = SHOPS[shopId] or SHOPS.salon
	titleLabel.Text = which == "shop" and shop.title or "Wardrobe"
	buildTabs(which == "shop" and shop.tabs or WARDROBE_TABS)
	subtitleLabel.Text = line and `{npcName or "Shopkeeper"}: "{line}"` or (which == "shop" and "Pick something fun!" or "Mix and match your looks.")
	render()
	Theme.pop(overlay:FindFirstChild("Panel") :: GuiObject)
	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = tabButtons[tab]
	end
end

function Shop.close()
	overlay.Visible = false
end

function Shop.start(gui: ScreenGui, controllers)
	task.defer(function()
		require(script.Parent.PanelCoordinator).track("shop", overlay, Shop.close)
	end)
	hud = controllers.HUD
	overlay = new("Frame", {
		Name = "Shop",
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
		Size = UDim2.fromScale(0.92, 0.84),
		BackgroundColor3 = C.bg,
		Parent = overlay,
		Children = {
			Theme.corner(24),
			Theme.stroke(C.purple, 5),
			Theme.padding(16),
			new("UISizeConstraint", { MaxSize = Vector2.new(820, 640) }),
		},
	}) :: Frame
	titleLabel = Theme.label("", { Font = Theme.Fonts.title, TextSize = 30, Size = UDim2.new(1, -60, 0, 36), TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
	subtitleLabel = Theme.label("", { TextSize = 16, TextColor3 = C.inkSoft, Size = UDim2.new(1, -60, 0, 20), Position = UDim2.fromOffset(0, 38), TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
	Theme.button("✕", C.inkSoft, Shop.close, { Size = UDim2.fromOffset(48, 44), Position = UDim2.new(1, -48, 0, 0), Parent = panel })

	tabRow = new("Frame", {
		Size = UDim2.new(1, 0, 0, 44),
		Position = UDim2.fromOffset(0, 66),
		BackgroundTransparency = 1,
		Parent = panel,
		Children = { Theme.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left) },
	}) :: Frame

	grid = new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 120),
		Size = UDim2.new(1, 0, 1, -120),
		BackgroundTransparency = 1,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = panel,
		Children = {
			new("UIGridLayout", {
				CellSize = UDim2.fromOffset(176, 210),
				CellPadding = UDim2.fromOffset(10, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		},
	}) :: ScrollingFrame

	State.changed:Connect(render)
	State.push:Connect(function(kind, payload)
		if kind == Remotes.PushKinds.OpenShop then
			Shop.open("shop", payload and payload.line, payload and payload.npcName, payload and payload.shop)
		end
	end)
end

return Shop
