--[[
	AdoptionController: choose a dog and name it. Opens automatically for a
	player without a dog, and when talking to Maya at the Pet Store.
	The server filters the name; this screen only checks the basics.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local DogRig = require(ReplicatedStorage.Shared.DogRig)
local PetCatalog = require(ReplicatedStorage.Shared.Catalogs.PetCatalog)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local State = require(script.Parent.State)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors
local new = Theme.new

local Adoption = {}
local overlay: Frame
local cards: { [string]: Frame } = {}
local selected = PetCatalog.Order[1]
local nameBox: TextBox
local errorLabel: TextLabel
local adoptButton: TextButton
local spinning: { Model } = {}
local busy = false

local function preview(parent: Instance, breed: PetCatalog.Breed)
	local vp = new("ViewportFrame", {
		Size = UDim2.new(1, 0, 0, 130),
		BackgroundColor3 = C.bg,
		LightDirection = Vector3.new(-1, -1, -1),
		Ambient = Color3.fromRGB(200, 200, 200),
		Parent = parent,
		Children = { Theme.corner(12) },
	}) :: ViewportFrame
	local dog = DogRig.build({ furColor = breed.furColor, accentColor = breed.accentColor, earStyle = breed.earStyle, scale = breed.scale, anchored = true })
	dog:PivotTo(CFrame.new())
	dog.Parent = vp
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.CFrame = CFrame.lookAt(Vector3.new(4.5, 2.5, -5.5), Vector3.new(0, 0.2, 0))
	cam.Parent = vp
	vp.CurrentCamera = cam
	table.insert(spinning, dog)
end

local function selectBreed(breedId: string)
	selected = breedId
	for id, card in cards do
		local stroke = card:FindFirstChildOfClass("UIStroke") :: UIStroke
		stroke.Color = id == breedId and C.orange or C.disabled
		stroke.Thickness = id == breedId and 5 or 2
	end
end

function Adoption.open()
	if State.data and State.data.pet then
		return
	end
	overlay.Visible = true
	errorLabel.Text = ""
	Theme.pop(overlay:FindFirstChild("Panel") :: GuiObject)
	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = cards[selected]:FindFirstChildOfClass("TextButton")
	end
end

function Adoption.close()
	overlay.Visible = false
end

local function submit()
	if busy then
		return
	end
	local name, problem = PetCatalog.cleanName(nameBox.Text)
	if not name then
		errorLabel.Text = problem or ""
		return
	end
	busy = true
	adoptButton.Text = "Adopting…"
	local ok, err = State.request(Remotes.RequestKinds.Adopt, { breedId = selected, name = name })
	busy = false
	adoptButton.Text = "Adopt!"
	if ok then
		Adoption.close()
	else
		errorLabel.Text = err or "Try again!"
	end
end

function Adoption.start(gui: ScreenGui)
	task.defer(function()
		require(script.Parent.PanelCoordinator).track("adoption", overlay, Adoption.close)
	end)
	overlay = new("Frame", {
		Name = "Adoption",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Visible = false,
		ZIndex = 10,
		Parent = gui,
	}) :: Frame
	local panel = new("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.bg,
		Parent = overlay,
		Children = {
			Theme.corner(24),
			Theme.stroke(C.orange, 5),
			Theme.padding(18),
			Theme.list(nil, 12),
			new("UISizeConstraint", { MaxSize = Vector2.new(720, 900) }),
		},
	}) :: Frame
	Theme.label("Choose your new best friend!", { Font = Theme.Fonts.title, TextSize = 32, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 1, Parent = panel })

	local row = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = panel,
		Children = {
			new("UIGridLayout", {
				CellSize = UDim2.new(0.31, 0, 0, 236),
				CellPadding = UDim2.new(0.03, 0, 0, 10),
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		},
	})
	for i, breedId in PetCatalog.Order do
		local breed = PetCatalog.get(breedId) :: PetCatalog.Breed
		local card = new("Frame", {
			LayoutOrder = i,
			BackgroundColor3 = C.panel,
			Parent = row,
			Children = { Theme.corner(16), Theme.stroke(C.disabled, 2) },
		}) :: Frame
		local content = new("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Parent = card,
			Children = { Theme.padding(8), Theme.list(nil, 4) },
		})
		preview(content, breed)
		Theme.label(breed.displayName, { Font = Theme.Fonts.title, TextSize = 20, Parent = content })
		Theme.label(breed.description, { TextSize = 14, TextColor3 = C.inkSoft, Size = UDim2.new(1, 0, 0, 36), Parent = content })
		-- The whole card is one button (works with mouse, touch, and gamepad).
		local hit = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 5, Parent = card }) :: TextButton
		hit.Activated:Connect(function()
			selectBreed(breedId)
		end)
		cards[breedId] = card
	end

	local nameRow = new("Frame", { Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1, LayoutOrder = 3, Parent = panel })
	nameBox = new("TextBox", {
		Size = UDim2.new(1, -64, 1, 0),
		BackgroundColor3 = C.panel,
		Font = Theme.Fonts.title,
		TextSize = 24,
		TextColor3 = C.ink,
		PlaceholderText = "Name your dog",
		PlaceholderColor3 = C.inkSoft,
		ClearTextOnFocus = false,
		Text = "",
		Parent = nameRow,
		Children = { Theme.corner(12), Theme.stroke(C.orange, 3) },
	}) :: TextBox
	nameBox:GetPropertyChangedSignal("Text"):Connect(function()
		if #nameBox.Text > PetCatalog.NameRules.maxLength then
			nameBox.Text = nameBox.Text:sub(1, PetCatalog.NameRules.maxLength)
		end
	end)
	Theme.button("🎲", C.teal, function()
		local breed = PetCatalog.get(selected) :: PetCatalog.Breed
		nameBox.Text = breed.defaultNames[math.random(1, #breed.defaultNames)]
	end, { Size = UDim2.fromOffset(56, 52), Position = UDim2.new(1, -56, 0, 0), Parent = nameRow })

	errorLabel = Theme.label("", { TextColor3 = C.orange, Font = Theme.Fonts.bold, LayoutOrder = 4, Parent = panel })
	adoptButton = Theme.button("Adopt!", C.green, submit, { LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 56), TextSize = 28, Parent = panel })

	selectBreed(selected)

	RunService.RenderStepped:Connect(function()
		if overlay.Visible then
			local t = os.clock()
			for _, dog in spinning do
				dog:PivotTo(CFrame.Angles(0, t * 0.8, 0))
			end
		end
	end)

	State.push:Connect(function(kind)
		if kind == Remotes.PushKinds.OpenAdoption then
			Adoption.open()
		end
	end)
	-- First visit: open as soon as we know there's no dog.
	local function check(data)
		if data and not data.pet and not overlay.Visible then
			Adoption.open()
		elseif data and data.pet then
			Adoption.close()
		end
	end
	State.changed:Connect(check)
	if State.data then
		check(State.data)
	end
end

return Adoption
