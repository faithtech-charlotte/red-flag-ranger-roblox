--[[
	WorldController: client-only world helpers.

	* Waypoint arrow: a glowing beam from you to where your next objective is
	  (or to the Ranger Station when help was asked for).
	* Blocked NPCs disappear for you only (the server also refuses to start
	  conversations with them).
	* Fetch button (in the Dog Park) and agility timer.
	* Wrap-around edges: walking off the map puts you on the opposite side.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Places = require(ReplicatedStorage.Shared.Places)
local QuestCatalog = require(ReplicatedStorage.Shared.Catalogs.QuestCatalog)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local WorldBounds = require(ReplicatedStorage.Shared.WorldBounds)
local State = require(script.Parent.State)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors
local player = Players.LocalPlayer

local WorldController = {}
local hud
local dialogue

----------------------------------------------------------------------------
-- Waypoint
----------------------------------------------------------------------------

local marker: Part
local markerAttachment: Attachment
local markerLabel: TextLabel
local beam: Beam
local override: { placeId: string, untilTime: number }? = nil

local function buildWaypoint()
	marker = Instance.new("Part")
	marker.Name = "WaypointMarker"
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.Transparency = 1
	marker.Size = Vector3.one
	markerAttachment = Instance.new("Attachment")
	markerAttachment.Parent = marker
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 60)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = true
	gui.Parent = marker
	markerLabel = Instance.new("TextLabel")
	markerLabel.Size = UDim2.fromScale(1, 1)
	markerLabel.BackgroundTransparency = 1
	markerLabel.Font = Theme.Fonts.title
	markerLabel.TextScaled = true
	markerLabel.TextColor3 = C.yellow
	markerLabel.TextStrokeTransparency = 0.2
	markerLabel.Parent = gui
	beam = Instance.new("Beam")
	beam.Attachment1 = markerAttachment
	beam.Color = ColorSequence.new(C.yellow)
	beam.Transparency = NumberSequence.new(0.35, 0.1)
	beam.Width0 = 0.5
	beam.Width1 = 0.5
	beam.FaceCamera = true
	beam.LightInfluence = 0
	beam.Parent = marker
	marker.Parent = workspace
end

local function currentTarget(): string?
	if override and os.clock() < override.untilTime then
		return override.placeId
	end
	override = nil
	local data = State.data
	if not data or not data.pet then
		return nil -- adoption screen is open; no arrow yet
	end
	for _, quest in QuestCatalog.Ordered do
		if not data.quests[quest.id] then
			return quest.waypoint
		end
	end
	return nil
end

local function updateWaypoint()
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local target = currentTarget()
	local place = target and Places.get(target)
	if not hrp or not place or Places.isInside(place.id, hrp.Position) then
		beam.Enabled = false
		markerLabel.Visible = false
		if override and place and hrp and Places.isInside(place.id, hrp.Position) then
			override = nil
		end
		return
	end
	local a0 = hrp:FindFirstChild("WaypointFrom") :: Attachment?
	if not a0 then
		a0 = Instance.new("Attachment")
		a0.Name = "WaypointFrom"
		a0.Position = Vector3.new(0, -2.2, 0)
		a0.Parent = hrp
	end
	beam.Attachment0 = a0
	beam.Enabled = true
	markerLabel.Visible = true
	markerLabel.Text = "▼ " .. place.displayName
	marker.Position = place.entrance + Vector3.new(0, 1, 0)
end

----------------------------------------------------------------------------
-- Blocked NPCs
----------------------------------------------------------------------------

local function applyBlocked()
	local blocked = State.data and State.data.blocked or {}
	for _, model in CollectionService:GetTagged("Interactable_NPC") do
		local hidden = blocked[model:GetAttribute("NpcId")] ~= nil
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = hidden and 1 or 0
			elseif d:IsA("BillboardGui") then
				d.Enabled = not hidden
			elseif d:IsA("ProximityPrompt") then
				d.Enabled = not hidden
			elseif d:IsA("Decal") then
				d.Transparency = hidden and 1 or 0
			end
		end
	end
end

----------------------------------------------------------------------------
-- Fetch button + agility timer
----------------------------------------------------------------------------

local fetchButton: TextButton
local fetchCount = 0
local fetchGoal = 3
local agilityLabel: TextLabel
local agilityRun: { started: number, ring: number, total: number }? = nil

local function throw()
	local ok, err = State.request(Remotes.RequestKinds.ThrowBall)
	if not ok and err and err ~= "slow down" then
		hud.toast(err)
	end
end

local function buildActivityUI(gui: ScreenGui)
	fetchButton = Theme.button("🎾 Throw!", C.green, throw, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(220, 64),
		TextSize = 28,
		Visible = false,
		Parent = gui,
	})
	agilityLabel = Theme.label("", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 96),
		Size = UDim2.fromOffset(320, 40),
		BackgroundTransparency = 0.1,
		BackgroundColor3 = C.blue,
		TextColor3 = C.white,
		Font = Theme.Fonts.title,
		TextSize = 24,
		Visible = false,
		Parent = gui,
	})
	Theme.corner(14).Parent = agilityLabel

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and fetchButton.Visible and (input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonX) then
			throw()
		end
	end)
end

local function updateActivityUI()
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local inPark = hrp ~= nil and Places.isInside("dog_park", hrp.Position)
	local hasPet = State.data ~= nil and State.data.pet ~= nil
	fetchButton.Visible = inPark and hasPet and not dialogue.isOpen()
	if fetchButton.Visible then
		local keyHint = UserInputService.KeyboardEnabled and " [F]" or ""
		fetchButton.Text = `🎾 Throw!  {fetchCount}/{fetchGoal}{keyHint}`
	end
	if agilityRun then
		local t = os.clock() - agilityRun.started
		agilityLabel.Text = `Rings {agilityRun.ring}/{agilityRun.total}  ·  {string.format("%.1f", t)}s`
		agilityLabel.Visible = true
		if t > 120 then
			agilityRun = nil
		end
	end
end

-- The client owns its character's physics, so wrapping here is instant and
-- smooth. Rotation and velocity are kept so running carries straight through.
local function wrapCharacter()
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end
	local wrapped = WorldBounds.wrap(hrp.Position)
	if wrapped then
		character:PivotTo(CFrame.new(wrapped) * hrp.CFrame.Rotation)
	end
end

function WorldController.start(gui: ScreenGui, controllers)
	hud = controllers.HUD
	dialogue = controllers.Dialogue
	buildWaypoint()
	buildActivityUI(gui)

	State.changed:Connect(applyBlocked)
	CollectionService:GetInstanceAddedSignal("Interactable_NPC"):Connect(function()
		task.defer(applyBlocked)
	end)
	applyBlocked()

	State.push:Connect(function(kind, payload)
		if kind == Remotes.PushKinds.Waypoint then
			override = { placeId = payload.placeId, untilTime = os.clock() + 90 }
		elseif kind == Remotes.PushKinds.Fetch then
			fetchCount = payload.count
			fetchGoal = payload.goal
			if payload.done then
				task.delay(1.5, function()
					fetchCount = 0
				end)
			end
		elseif kind == Remotes.PushKinds.Agility then
			if payload.state == "running" then
				if payload.ring == 0 or not agilityRun then
					agilityRun = { started = os.clock(), ring = payload.ring, total = payload.total }
				else
					agilityRun.ring = payload.ring
				end
			elseif payload.state == "finished" then
				agilityRun = nil
				agilityLabel.Text = `Finished in {payload.time}s!`
				agilityLabel.Visible = true
				task.delay(3, function()
					if not agilityRun then
						agilityLabel.Visible = false
					end
				end)
			end
		end
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		wrapCharacter()
		acc += dt
		if acc >= 0.1 then
			acc = 0
			updateWaypoint()
			updateActivityUI()
		end
	end)
end

return WorldController
