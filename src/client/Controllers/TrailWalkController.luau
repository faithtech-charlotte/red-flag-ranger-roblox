--[[
	TrailWalkController: the Trail Walk on screen.

	  * A walk panel (bottom center): paw prints found, time, Stop.
	  * The next paw marker glows: a ring on the ground, a "▼ 🐾 3" label
	    and a beam from you to it.
	  * Squirrel moments: a leash meter appears. HOLD to keep the needle in
	    the steady band until the hold bar fills:
	      Keyboard/mouse  hold Space or the left mouse button
	      Touch           hold the big HOLD button
	      Gamepad         hold R2 or A
	    The client only says holdStart / holdEnd; the server measures the
	    hold and decides steady or miss.
	Every cue has a shape or words (needle, band, bars, "Pulling!",
	"Steady!"), never color or sound alone.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local State = require(script.Parent.State)
local Sounds = require(script.Parent.Parent.UI.Sounds)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors
local new = Theme.new
local player = Players.LocalPlayer

local HOLD_ACTION = "TrailHoldLeash"
local BAND = 0.26 -- width of the steady band on the leash meter

local Trail = {}
local ctl
local gui: ScreenGui

local walk = {
	active = false,
	runId = nil :: string?,
	markers = {} :: { Vector3 },
	total = 0,
	found = 0,
	startedAt = 0,
}
type Challenge = {
	id: string,
	openedAt: number,
	window: number,
	hold: number,
	holding: boolean,
	holdAt: number,
	ended: boolean,
	result: string?,
}
local challenge: Challenge? = nil
local sources: { [string]: boolean } = {}
local sendQueue: { { [string]: any } } = {}
local sending = false

-- UI
local panel: Frame
local panelText: TextLabel
local meterPanel: Frame
local meterTitle: TextLabel
local meterHint: TextLabel
local needle: Frame
local holdFill: Frame
local windowFill: Frame
local stateLabel: TextLabel
local holdButton: TextButton
-- World highlight (local only)
local ring: Part?
local ringLabel: TextLabel?
local beam: Beam?

local function inputKind(): string
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		return "touch"
	elseif last.Name:find("Gamepad") then
		return "pad"
	end
	return "mouse"
end

local function holdHint(): string
	local kind = inputKind()
	if kind == "touch" then
		return "Hold the big HOLD button"
	elseif kind == "pad" then
		return "Hold R2 or A"
	end
	return "Hold Space or the left mouse button"
end

----------------------------------------------------------------------------
-- Next-marker highlight
----------------------------------------------------------------------------

local function clearHighlight()
	if ring then
		ring:Destroy()
		ring = nil
		ringLabel = nil
		beam = nil
	end
end

local function showMarker(index: number)
	clearHighlight()
	local at = walk.markers[index]
	if not at then
		return
	end
	local p = Instance.new("Part")
	p.Name = "TrailNextMarker"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(0.2, 5.5, 5.5)
	p.CFrame = CFrame.new(at.X, at.Y + 0.05, at.Z) * CFrame.Angles(0, 0, math.rad(90))
	p.Color = C.yellow
	p.Material = Enum.Material.Neon
	p.Transparency = 0.45
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(120, 50)
	bb.StudsOffset = Vector3.new(0, 4, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Theme.Fonts.title
	label.TextScaled = true
	label.TextColor3 = C.yellow
	label.TextStrokeTransparency = 0.2
	label.Text = `▼ 🐾 {index}`
	label.Parent = bb
	bb.Parent = p
	local target = Instance.new("Attachment")
	target.Parent = p
	local b = Instance.new("Beam")
	b.Attachment1 = target
	b.Color = ColorSequence.new(C.yellow)
	b.Transparency = NumberSequence.new(0.5, 0.2)
	b.Width0 = 0.4
	b.Width1 = 0.4
	b.FaceCamera = true
	b.LightInfluence = 0
	b.Parent = p
	p.Parent = workspace
	ring, ringLabel, beam = p, label, b
end

----------------------------------------------------------------------------
-- Hold input
----------------------------------------------------------------------------

local function flush()
	if sending then
		return
	end
	sending = true
	task.spawn(function()
		while sendQueue[1] do
			local item = table.remove(sendQueue, 1) :: { [string]: any }
			local ok, err, data = false, nil, nil
			for _ = 1, 5 do
				ok, err, data = State.request(Remotes.RequestKinds.TrailHold, item)
				if ok or err ~= "slow down" then
					break
				end
				task.wait(0.06)
			end
			local c = challenge
			if ok and item.phase == "end" and data and data.result == "short" and c and c.id == item.challengeId and not c.result then
				stateLabel.Text = "Hold a little longer!"
			end
		end
		sending = false
	end)
end

local function send(phase: string)
	local c = challenge
	if not c or not walk.runId then
		return
	end
	table.insert(sendQueue, { runId = walk.runId, challengeId = c.id, phase = phase })
	flush()
end

local function holdChanged()
	local c = challenge
	if not c or c.result then
		return
	end
	local holding = next(sources) ~= nil
	if holding and not c.holding then
		c.holding = true
		c.ended = false
		c.holdAt = os.clock()
		stateLabel.Text = "Steady…"
		send("start")
	elseif not holding and c.holding then
		c.holding = false
		if not c.ended then
			c.ended = true
			send("end")
		end
	end
end

local function onAction(_name: string, inputState: Enum.UserInputState, input: InputObject)
	local key = input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode.Name or input.UserInputType.Name
	if inputState == Enum.UserInputState.Begin then
		sources[key] = true
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		sources[key] = nil
	end
	holdChanged()
	return Enum.ContextActionResult.Sink
end

local function bindHold()
	table.clear(sources)
	ContextActionService:BindActionAtPriority(
		HOLD_ACTION,
		onAction,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.Space,
		Enum.KeyCode.ButtonR2,
		Enum.KeyCode.ButtonA,
		Enum.UserInputType.MouseButton1
	)
end

local function unbindHold()
	ContextActionService:UnbindAction(HOLD_ACTION)
	table.clear(sources)
end

----------------------------------------------------------------------------
-- Squirrel moments
----------------------------------------------------------------------------

local function closeChallenge()
	challenge = nil
	unbindHold()
	meterPanel.Visible = false
	holdButton.Visible = false
end

local function openChallenge(payload)
	closeChallenge()
	challenge = {
		id = payload.challengeId,
		openedAt = os.clock(),
		window = tonumber(payload.window) or 6,
		hold = tonumber(payload.hold) or 1.8,
		holding = false,
		holdAt = 0,
		ended = false,
		result = nil,
	}
	meterTitle.Text = "🐿️ Squirrel! Keep the leash steady!"
	meterHint.Text = holdHint()
	stateLabel.Text = "Pulling!"
	meterPanel.Visible = true
	Theme.pop(meterPanel)
	holdButton.Visible = UserInputService.TouchEnabled
	bindHold()
	Sounds.play("whoosh", 1.3)
end

local function showResult(result: string)
	local c = challenge
	if c then
		c.result = result
		c.holding = false
	end
	unbindHold()
	holdButton.Visible = false
	if result == "steady" then
		stateLabel.Text = "Steady! ✔ Good walking!"
		Sounds.play("chime")
	else
		stateLabel.Text = "Whoa, it pulled! That's okay, here it comes back."
	end
	local id = c and c.id
	task.delay(1.4, function()
		if challenge and challenge.id == id then
			closeChallenge()
		end
	end)
end

----------------------------------------------------------------------------

local function stopWalk()
	walk.active = false
	walk.runId = nil
	closeChallenge()
	clearHighlight()
	panel.Visible = false
	table.clear(sendQueue)
end

local function updatePanel()
	local t = math.floor(os.clock() - walk.startedAt)
	panelText.Text = `🐾 Trail Walk · Paw prints {walk.found}/{walk.total} · {string.format("%d:%02d", t // 60, t % 60)}`
end

local function showDone(payload)
	local n = math.clamp(tonumber(payload.stars) or 1, 1, 3)
	local lines = `Walk complete!\n{string.rep("⭐", n)}  Trail stars: {n} of 3`
	local detail = `Steady holds {payload.steady or 0}/{payload.challenges or 0} · Sniffs {payload.sniffs or 0}/{payload.sniffTotal or 0} · {payload.seconds or 0}s`
	local card = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.64), -- below the celebration banner
		Size = UDim2.fromOffset(400, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.bg,
		Parent = gui,
		Children = {
			Theme.corner(18),
			Theme.stroke(C.green, 3),
			Theme.padding(12),
			Theme.list(nil, 4),
			Theme.label(lines, { Font = Theme.Fonts.title, TextSize = 26, Size = UDim2.new(1, 0, 0, 64), LayoutOrder = 1 }),
			Theme.label(detail, { TextSize = 16, TextColor3 = C.inkSoft, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2 }),
		},
	}) :: Frame
	Theme.pop(card)
	task.delay(3.5, function()
		card:Destroy()
	end)
end

function Trail.isActive(): boolean
	return walk.active
end

function Trail.start(screenGui: ScreenGui, controllers)
	gui = screenGui
	ctl = controllers

	panel = new("Frame", {
		Name = "TrailWalkPanel",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(440, 54),
		BackgroundColor3 = C.bg,
		BackgroundTransparency = 0.05,
		Visible = false,
		Parent = gui,
		Children = { Theme.corner(16), Theme.stroke(C.green, 3), Theme.padding(6), new("UISizeConstraint", { MaxSize = Vector2.new(440, 54) }) },
	}) :: Frame
	panelText = Theme.label("", { Font = Theme.Fonts.bold, TextSize = 16, Size = UDim2.new(1, -96, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
	Theme.button("Stop", C.inkSoft, function()
		State.request(Remotes.RequestKinds.ActivityCancel)
	end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(88, 40), TextSize = 18, Parent = panel })

	meterPanel = new("Frame", {
		Name = "LeashMeter",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -84),
		Size = UDim2.fromOffset(420, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.bg,
		Visible = false,
		Parent = gui,
		Children = { Theme.corner(18), Theme.stroke(C.orange, 4), Theme.padding(10), Theme.list(nil, 6), new("UISizeConstraint", { MaxSize = Vector2.new(420, 300) }) },
	}) :: Frame
	meterTitle = Theme.label("", { Font = Theme.Fonts.title, TextSize = 22, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = 1, Parent = meterPanel })
	meterHint = Theme.label("", { Font = Theme.Fonts.bold, TextSize = 16, LayoutOrder = 2, Parent = meterPanel })
	-- Leash meter: a steady band in the middle (with edge marks) and a needle.
	local track = new("Frame", {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = Color3.fromRGB(240, 220, 210),
		LayoutOrder = 3,
		Parent = meterPanel,
		Children = { Theme.corner(10) },
	})
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(BAND, 1),
		BackgroundColor3 = C.green,
		Parent = track,
		Children = {
			Theme.corner(10),
			Theme.label("STEADY", { Size = UDim2.fromScale(1, 1), Font = Theme.Fonts.bold, TextSize = 12, TextColor3 = C.white }),
		},
	})
	for _, x in { 0.5 - BAND / 2, 0.5 + BAND / 2 } do
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(x, 0, 0, -4), Size = UDim2.new(0, 3, 1, 8), BackgroundColor3 = C.ink, Parent = track })
	end
	needle = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 8, 1, 14),
		BackgroundColor3 = C.ink,
		Parent = track,
		Children = { Theme.corner(4) },
	}) :: Frame
	stateLabel = Theme.label("", { Font = Theme.Fonts.title, TextSize = 20, LayoutOrder = 4, Parent = meterPanel })
	-- Hold progress (fills while you hold) and the time left (shrinks).
	local holdTrack = new("Frame", { Size = UDim2.new(1, 0, 0, 16), BackgroundColor3 = Color3.fromRGB(230, 225, 240), LayoutOrder = 5, Parent = meterPanel, Children = { Theme.corner(8) } })
	holdFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.teal, Parent = holdTrack, Children = { Theme.corner(8) } }) :: Frame
	Theme.label("HOLD BAR", { Size = UDim2.fromScale(1, 1), TextSize = 11, Font = Theme.Fonts.bold, TextColor3 = C.ink, ZIndex = 2, Parent = holdTrack })
	local windowTrack = new("Frame", { Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = Color3.fromRGB(230, 225, 240), LayoutOrder = 6, Parent = meterPanel, Children = { Theme.corner(3) } })
	windowFill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.orange, Parent = windowTrack, Children = { Theme.corner(3) } }) :: Frame

	holdButton = new("TextButton", {
		Name = "TrailHoldButton",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -170),
		Size = UDim2.fromOffset(150, 150),
		BackgroundColor3 = C.orange,
		Text = "HOLD\n🐕",
		Font = Theme.Fonts.title,
		TextSize = 34,
		TextColor3 = C.white,
		AutoButtonColor = true,
		Visible = false,
		Parent = gui,
		Children = { Theme.corner(75), Theme.stroke(C.white, 4) },
	}) :: TextButton
	holdButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			sources.button = true
			holdChanged()
		end
	end)
	holdButton.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			sources.button = nil
			holdChanged()
		end
	end)

	RunService.RenderStepped:Connect(function()
		if not walk.active then
			return
		end
		updatePanel()
		if ring and ringLabel then
			local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local from = hrp and hrp:FindFirstChild("TrailFrom") :: Attachment?
			if hrp and not from then
				local a = Instance.new("Attachment")
				a.Name = "TrailFrom"
				a.Position = Vector3.new(0, -2.2, 0)
				a.Parent = hrp
				from = a
			end
			if beam then
				beam.Attachment0 = from
			end
			ringLabel.Position = UDim2.fromScale(0, math.sin(os.clock() * 4) * 0.08)
		end
		local c = challenge
		if c then
			local t = os.clock()
			local held = c.holding and (t - c.holdAt) or 0
			local x
			if c.result == "steady" or (c.holding and not c.result) then
				x = 0.5 + math.sin(t * 6) * BAND * 0.25
			elseif c.result == "miss" then
				x = 0.5 + math.sin(t * 3) * 0.42
			else
				x = 0.5 + math.sin(t * 9) * 0.42 -- the dog pulls the needle out of the band
			end
			needle.Position = UDim2.fromScale(x, 0.5)
			holdFill.Size = UDim2.fromScale(c.result == "steady" and 1 or math.clamp(held / c.hold, 0, 1), 1)
			windowFill.Size = UDim2.fromScale(math.clamp(1 - (t - c.openedAt) / c.window, 0, 1), 1)
			if not c.result and not c.holding and stateLabel.Text == "Steady…" then
				stateLabel.Text = "Pulling!"
			end
			-- Full hold: tell the server now (it measures with its own clock).
			if c.holding and not c.ended and held >= c.hold + 0.2 then
				c.ended = true
				c.holding = false
				stateLabel.Text = "Steady…"
				send("end")
			end
		end
	end)

	State.push:Connect(function(kind, payload)
		if kind ~= Remotes.PushKinds.TrailWalk or typeof(payload) ~= "table" then
			return
		end
		if payload.state == "start" then
			stopWalk()
			walk.active = true
			walk.runId = payload.runId
			walk.markers = payload.markers or {}
			walk.total = payload.total or #walk.markers
			walk.found = 0
			walk.startedAt = os.clock()
			panel.Visible = true
			Theme.pop(panel)
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid:UnequipTools()
			end
			ctl.ActionBar.close()
			showMarker(1)
			ctl.HUD.toast("Leash on! Follow the glowing paw prints. 🐾", "success")
			Sounds.play("chime")
			return
		end
		if payload.runId ~= walk.runId then
			return -- about an older walk
		end
		if payload.state == "marker" then
			walk.found = payload.index
			Sounds.play("pop", 1 + payload.index / 20)
			if payload.index < walk.total then
				showMarker(payload.index + 1)
			else
				clearHighlight()
			end
		elseif payload.state == "sniff" then
			local model = ctl.Pet.ownPet()
			if model then
				ctl.Pet.floatText(model, "👃 Sniff sniff! Bonus!")
			end
		elseif payload.state == "squirrel" then
			openChallenge(payload)
		elseif payload.state == "challenge" then
			local c = challenge
			if c and c.id == payload.challengeId then
				showResult(payload.result)
			end
		elseif payload.state == "done" then
			stopWalk()
			showDone(payload)
		elseif payload.state == "cancel" then
			stopWalk()
		end
	end)
	player.CharacterRemoving:Connect(function()
		if walk.active then
			stopWalk()
		end
	end)
end

return Trail
