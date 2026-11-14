--[[
	Theme: colors, fonts, and tiny helpers for building UI in code.
	Big touch targets (min 44 px) and high-contrast text for young players.
]]

local TweenService = game:GetService("TweenService")

local Theme = {}

Theme.Colors = {
	bg = Color3.fromRGB(255, 248, 236),
	panel = Color3.fromRGB(255, 255, 255),
	ink = Color3.fromRGB(52, 44, 66),
	inkSoft = Color3.fromRGB(110, 100, 125),
	orange = Color3.fromRGB(255, 140, 66),
	yellow = Color3.fromRGB(255, 209, 102),
	teal = Color3.fromRGB(46, 196, 182),
	green = Color3.fromRGB(60, 190, 110),
	blue = Color3.fromRGB(72, 149, 239),
	pink = Color3.fromRGB(255, 120, 190),
	purple = Color3.fromRGB(155, 93, 229),
	help = Color3.fromRGB(56, 128, 220),
	tip = Color3.fromRGB(232, 246, 255),
	tipInk = Color3.fromRGB(30, 80, 140),
	disabled = Color3.fromRGB(200, 196, 205),
	white = Color3.new(1, 1, 1),
}

Theme.Fonts = {
	title = Enum.Font.FredokaOne,
	body = Enum.Font.GothamMedium,
	bold = Enum.Font.GothamBold,
}

-- new("Frame", { Size = ..., Children = { ... } })
function Theme.new(className: string, props: { [string]: any }?): Instance
	local inst = Instance.new(className)
	local children = nil
	local parent = nil
	for k, v in props or {} do
		if k == "Children" then
			children = v
		elseif k == "Parent" then
			parent = v
		else
			(inst :: any)[k] = v
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function Theme.corner(radius: number?): UICorner
	return Theme.new("UICorner", { CornerRadius = UDim.new(0, radius or 14) }) :: UICorner
end

function Theme.stroke(color: Color3?, thickness: number?): UIStroke
	return Theme.new("UIStroke", {
		Color = color or Theme.Colors.ink,
		Thickness = thickness or 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}) :: UIStroke
end

function Theme.padding(px: number): UIPadding
	local u = UDim.new(0, px)
	return Theme.new("UIPadding", { PaddingLeft = u, PaddingRight = u, PaddingTop = u, PaddingBottom = u }) :: UIPadding
end

function Theme.list(direction: Enum.FillDirection?, gap: number?, align: Enum.HorizontalAlignment?): UIListLayout
	return Theme.new("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Center,
	}) :: UIListLayout
end

function Theme.label(text: string, props: { [string]: any }?): TextLabel
	local base = {
		BackgroundTransparency = 1,
		Font = Theme.Fonts.body,
		Text = text,
		TextColor3 = Theme.Colors.ink,
		TextSize = 18,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 24),
	}
	for k, v in props or {} do
		base[k] = v
	end
	return Theme.new("TextLabel", base) :: TextLabel
end

-- A chunky, friendly button. `onClick` runs on Activated (mouse, touch, gamepad).
function Theme.button(text: string, color: Color3, onClick: () -> (), props: { [string]: any }?): TextButton
	local base = {
		AutoButtonColor = true,
		BackgroundColor3 = color,
		Font = Theme.Fonts.title,
		Text = text,
		TextColor3 = Theme.Colors.white,
		TextSize = 22,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 48),
		Children = { Theme.corner(12), Theme.stroke(color:Lerp(Color3.new(0, 0, 0), 0.25), 2) },
	}
	for k, v in props or {} do
		base[k] = v
	end
	local b = Theme.new("TextButton", base) :: TextButton
	b.Activated:Connect(onClick)
	return b
end

function Theme.pop(gui: GuiObject)
	local scale = gui:FindFirstChildOfClass("UIScale") or Theme.new("UIScale", { Parent = gui })
	;(scale :: UIScale).Scale = 0.85
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

return Theme
