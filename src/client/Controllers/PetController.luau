--[[
	PetController: makes every dog feel alive. Client-side, procedural.

	The server owns behavior and replicates it as attributes on each dog:
	  PetState, PetStateAt, Trick, FaceOwner   behavior state
	  Mood, MoodAt                             short flourish (hearts, "Woof!")
	  Joy (0..1)                               how much it's enjoying petting
	  ToyOut, Ready, Carrying                  fetch: ball out, wind-up, ball in mouth
	  GroomFx, ShinyUntil                      spa effects
	Every client animates every dog from those, so everyone sees the same
	behavior without streaming animation data.

	Layers, in order:
	  1. Locomotion: trot with speed, sit/lie when resting
	  2. State poses: eating, being petted, tricks, chasing, carrying
	  3. Life: blinking, looking at you (or the ball), and small spontaneous
	     moments (head tilt, sniff, scratch, play bow, hop, yawn, lie down)
	  4. Local petting reaction (owner only): leaning into your hand,
	     squinty eyes, the happy back-leg thump

	Uploaded animations in PetCatalog.AnimationIds replace layers 1-2 for a
	state when present; this procedural version is the fallback.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local PetCatalog = require(ReplicatedStorage.Shared.Catalogs.PetCatalog)

local player = Players.LocalPlayer

local PetController = {}

type Eye = { part: BasePart, size: Vector3 }
type Rig = {
	model: Model,
	root: BasePart,
	body: BasePart?,
	head: BasePart?,
	motors: { [string]: Motor6D },
	eyes: { Eye },
	shines: { BasePart },
	phase: number,
	stillFor: number,
	sit: number,
	lie: number,
	lookYaw: number,
	lookPitch: number,
	wagAmp: number,
	idle: { name: string, at: number, duration: number }?,
	nextIdleAt: number,
	nextBlinkAt: number,
	blinkUntil: number,
	lastMoodAt: number,
	toyOut: boolean,
	own: boolean,
	fx: ParticleEmitter?,
	fxName: string?,
	sparkles: Sparkles?,
	animator: Animator?,
	track: AnimationTrack?,
	trackState: string?,
	nextNomAt: number,
}

local rigs: { [Model]: Rig } = {}

-- Local petting input for your own dog (set by PettingController).
local petting = { active = false, intensity = 0, side = 0, scratch = 0 }

local MOOD_SECONDS = 1.8
local MOOD_ICON = { happy = "⭐", love = "❤️", sparkle = "✨", comfort = "💙", confused = "❓", sniff = "👃", shake = "💦" }
local WOOF = { excited = "Woof!", happy = "Arf!", love = "♥", confused = "...?", alert = "!", sniff = "sniff sniff" }

local IDLE_MOVES = {
	{ name = "tilt", weight = 3, duration = 1.3 },
	{ name = "look", weight = 4, duration = 2.2 },
	{ name = "sniff", weight = 3, duration = 1.6 },
	{ name = "scratch", weight = 1, duration = 1.4 },
	{ name = "bow", weight = 1, duration = 1.2 },
	{ name = "hop", weight = 1, duration = 0.7 },
	{ name = "yawn", weight = 1, duration = 1.4 },
}

local FX = {
	brush = { color = Color3.fromRGB(255, 250, 220), size = 0.35, rate = 18, speed = 2 },
	wash = { color = Color3.fromRGB(255, 255, 255), size = 0.8, rate = 26, speed = 1.5, transparency = 0.3 },
	rinse = { color = Color3.fromRGB(120, 190, 255), size = 0.3, rate = 40, speed = 6 },
	dry = { color = Color3.fromRGB(255, 230, 180), size = 0.5, rate = 20, speed = 4, transparency = 0.5 },
}

----------------------------------------------------------------------------
-- Little bubbles and icons above the head
----------------------------------------------------------------------------

local function bubble(head: BasePart, text: string, color: Color3?, size: number?, offset: Vector3?)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(size or 90, (size or 90) * 0.45)
	gui.StudsOffset = offset or Vector3.new(0, 2.2, 0)
	gui.Adornee = head
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.new(1, 1, 1)
	label.BackgroundTransparency = color and 1 or 0
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color or Color3.fromRGB(52, 44, 66)
	label.TextStrokeTransparency = color and 0.3 or 1
	label.Text = text
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = label
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = label
	label.Parent = gui
	gui.Parent = head
	TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(gui, TweenInfo.new(1.1), { StudsOffset = gui.StudsOffset + Vector3.new(0, 1.2, 0) }):Play()
	task.delay(0.8, function()
		TweenService:Create(label, TweenInfo.new(0.35), { TextTransparency = 1, BackgroundTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
	task.delay(1.2, function()
		gui:Destroy()
	end)
end

function PetController.floatText(model: Model, text: string, color: Color3?)
	local head = model:FindFirstChild("Head") :: BasePart?
	if head then
		bubble(head, text, color or Color3.fromRGB(255, 120, 190), 130, Vector3.new(0, 2.8, 0))
	end
end

function PetController.woof(model: Model, text: string?)
	local head = model:FindFirstChild("Head") :: BasePart?
	if head then
		bubble(head, text or "Woof!", nil, 80)
	end
end

local function floatIcons(rig: Rig, icon: string)
	local head = rig.head
	if not head then
		return
	end
	for i = 1, 3 do
		task.delay((i - 1) * 0.15, function()
			if head.Parent then
				bubble(head, icon, Color3.new(1, 1, 1), 46, Vector3.new((i - 2) * 0.9, 1.6, 0))
			end
		end)
	end
end

function PetController.ownPet(): Model?
	for model, rig in rigs do
		if rig.own and model.Parent then
			return model
		end
	end
	return nil
end

-- PettingController feeds hand input here for instant local reactions.
function PetController.setPetting(active: boolean, intensity: number?, side: number?, scratch: number?)
	petting.active = active
	petting.intensity = intensity or 0
	petting.side = side or 0
	petting.scratch = scratch or 0
end

----------------------------------------------------------------------------
-- Tracking
----------------------------------------------------------------------------

local function track(model: Instance)
	if not model:IsA("Model") or rigs[model] then
		return
	end
	local root = model:WaitForChild("Root", 5) :: BasePart?
	if not root then
		return
	end
	local motors, eyes, shines = {}, {}, {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			motors[d.Name] = d
		elseif d:IsA("BasePart") and d.Name == "Eye" then
			table.insert(eyes, { part = d, size = d.Size })
		elseif d:IsA("BasePart") and d.Name == "EyeShine" then
			table.insert(shines, d)
		end
	end
	local now = os.clock()
	rigs[model] = {
		model = model,
		root = root,
		body = model:FindFirstChild("Body") :: BasePart?,
		head = model:FindFirstChild("Head") :: BasePart?,
		motors = motors,
		eyes = eyes,
		shines = shines,
		phase = 0,
		stillFor = 0,
		sit = 0,
		lie = 0,
		lookYaw = 0,
		lookPitch = 0,
		wagAmp = 0.55,
		idle = nil,
		nextIdleAt = now + 2 + math.random() * 3,
		nextBlinkAt = now + 1 + math.random() * 3,
		blinkUntil = 0,
		lastMoodAt = model:GetAttribute("MoodAt") or 0,
		toyOut = model:GetAttribute("ToyOut") == true,
		own = model:GetAttribute("OwnerUserId") == player.UserId,
		nextNomAt = 0,
	}
end

local function untrack(model: Instance)
	local rig = rigs[model :: Model]
	if rig then
		if rig.track then
			rig.track:Stop(0)
		end
		rigs[model :: Model] = nil
	end
end

local function playAsset(rig: Rig, state: string): boolean
	local id = (PetCatalog.AnimationIds or {})[state]
	if not id then
		if rig.track then
			rig.track:Stop(0.15)
			rig.track = nil
			rig.trackState = nil
		end
		return false
	end
	if rig.trackState == state and rig.track then
		return true
	end
	local ok = pcall(function()
		if not rig.animator then
			local controller = Instance.new("AnimationController")
			controller.Parent = rig.model
			local animator = Instance.new("Animator")
			animator.Parent = controller
			rig.animator = animator
		end
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		if rig.track then
			rig.track:Stop(0.15)
		end
		rig.track = (rig.animator :: Animator):LoadAnimation(anim)
		rig.track.Looped = true
		rig.track:Play(0.15)
		rig.trackState = state
	end)
	return ok
end

local function updateFx(rig: Rig)
	local body = rig.body
	if not body then
		return
	end
	local fxName = rig.model:GetAttribute("GroomFx")
	if fxName ~= rig.fxName then
		rig.fxName = fxName
		if rig.fx then
			rig.fx.Enabled = false
			local old = rig.fx
			task.delay(1.5, function()
				old:Destroy()
			end)
			rig.fx = nil
		end
		local spec = fxName and FX[fxName]
		if spec then
			local e = Instance.new("ParticleEmitter")
			e.Color = ColorSequence.new(spec.color)
			e.Size = NumberSequence.new(spec.size, spec.size * 0.4)
			e.Transparency = NumberSequence.new(spec.transparency or 0, 1)
			e.Rate = spec.rate
			e.Speed = NumberRange.new(spec.speed * 0.5, spec.speed)
			e.Lifetime = NumberRange.new(0.6, 1.2)
			e.SpreadAngle = Vector2.new(180, 180)
			e.LightInfluence = 0
			e.Parent = body
			rig.fx = e
		end
	end
	local shiny = (rig.model:GetAttribute("ShinyUntil") or 0) > workspace:GetServerTimeNow()
	if shiny and not rig.sparkles then
		local sp = Instance.new("Sparkles")
		sp.SparkleColor = Color3.fromRGB(255, 240, 160)
		sp.Parent = body
		rig.sparkles = sp
	elseif not shiny and rig.sparkles then
		rig.sparkles:Destroy()
		rig.sparkles = nil
	end
end

----------------------------------------------------------------------------
-- Where should the dog look?
----------------------------------------------------------------------------

local function ownerOf(rig: Rig): Model?
	local userId = rig.model:GetAttribute("OwnerUserId")
	local owner = userId and Players:GetPlayerByUserId(userId)
	return owner and owner.Character
end

local function lookTarget(rig: Rig, state: string): Vector3?
	if state == "Fetching" then
		return nil -- eyes on the path ahead
	end
	local character = ownerOf(rig)
	if not character then
		return nil
	end
	if rig.toyOut then
		local hand = character:FindFirstChild("RightHand") :: BasePart?
		if hand then
			return hand.Position
		end
	end
	local head = character:FindFirstChild("Head") :: BasePart?
	return head and head.Position or nil
end

-- Keep your own dog's movement target on the ground (we simulate its
-- physics, so local changes steer it smoothly at frame rate):
--   following: when you jump, the dog stays on the ground instead of floating up
--   fetching: run to the spot under the ball, not to the ball in the air
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude

local function groundY(at: Vector3, extra: Instance?): number?
	local ignore: { Instance } = { extra :: Instance }
	if player.Character then
		table.insert(ignore, player.Character)
	end
	local pets = workspace:FindFirstChild("Pets")
	if pets then
		table.insert(ignore, pets)
	end
	groundParams.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(at + Vector3.new(0, 1, 0), Vector3.new(0, -40, 0), groundParams)
	return hit and hit.Position.Y or nil
end

local function groundTargets(rig: Rig, state: string)
	local feet = rig.model:GetAttribute("GroundOffset") or 1.5
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local follow = hrp and hrp:FindFirstChild("PetFollow") :: Attachment?
	if hrp and follow then
		local side = hrp.CFrame * Vector3.new(follow.Position.X, 0, follow.Position.Z)
		local g = groundY(Vector3.new(side.X, hrp.Position.Y, side.Z))
		if g then
			follow.Position = Vector3.new(follow.Position.X, g + feet - hrp.Position.Y, follow.Position.Z)
		end
	end
	if state == "Fetching" then
		local chase = workspace.Terrain:FindFirstChild(`PetChase_{player.UserId}`) :: Attachment?
		local ball = nil
		for _, b in workspace:GetChildren() do
			if b.Name == "FetchBall" and b:GetAttribute("OwnerUserId") == player.UserId then
				ball = b :: BasePart
			end
		end
		if chase and ball then
			local g = groundY(ball.Position, ball) or 0
			chase.WorldPosition = Vector3.new(ball.Position.X, g + feet, ball.Position.Z)
		end
	end
end

local function steerOwnDog(rig: Rig, state: string, flatVel: Vector3)
	if state == "Sitting" or state == "Staying" or state == "Grooming" then
		return
	end
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local align = rig.root:FindFirstChildOfClass("AlignOrientation")
	if not hrp or not align then
		return
	end
	local dir
	if rig.model:GetAttribute("FaceOwner") or (rig.toyOut and flatVel.Magnitude < 3) then
		local d = hrp.Position - rig.root.Position
		dir = Vector3.new(d.X, 0, d.Z)
	elseif flatVel.Magnitude > 2 then
		dir = flatVel
	else
		local look = hrp.CFrame.LookVector
		dir = Vector3.new(look.X, 0, look.Z)
	end
	if dir.Magnitude < 0.1 then
		return
	end
	align.CFrame = CFrame.lookAt(Vector3.zero, dir.Unit)
end

local function pickIdle(rig: Rig, now: number)
	local total = 0
	for _, m in IDLE_MOVES do
		total += m.weight
	end
	local r = math.random() * total
	for _, m in IDLE_MOVES do
		r -= m.weight
		if r <= 0 then
			rig.idle = { name = m.name, at = now, duration = m.duration }
			if m.name == "hop" and rig.head and math.random() < 0.5 then
				bubble(rig.head, "Arf!", nil, 70)
			end
			return
		end
	end
end

----------------------------------------------------------------------------
-- The pose
----------------------------------------------------------------------------

local function animate(rig: Rig, dt: number)
	local m = rig.motors
	local model = rig.model
	local state = model:GetAttribute("PetState") or "Following"
	local now = workspace:GetServerTimeNow()
	local st = now - (model:GetAttribute("PetStateAt") or 0)
	local t = os.clock()

	local vel = rig.root.AssemblyLinearVelocity
	local flat = Vector3.new(vel.X, 0, vel.Z)
	local speed = flat.Magnitude
	if rig.own then
		groundTargets(rig, state)
		steerOwnDog(rig, state, flat)
	end
	updateFx(rig)

	-- Reactions to attribute changes (everyone sees these).
	local moodAt = model:GetAttribute("MoodAt") or 0
	local mood = model:GetAttribute("Mood")
	if moodAt ~= rig.lastMoodAt then
		rig.lastMoodAt = moodAt
		if MOOD_ICON[mood] then
			floatIcons(rig, MOOD_ICON[mood])
		end
		if WOOF[mood] and rig.head and (mood ~= "love" or math.random() < 0.5) then
			bubble(rig.head, WOOF[mood], nil, 80)
		end
	end
	local toyOut = model:GetAttribute("ToyOut") == true
	if toyOut and not rig.toyOut and rig.head then
		bubble(rig.head, "Woof! Woof!", nil, 110)
	end
	rig.toyOut = toyOut
	local moodActive = now - moodAt < MOOD_SECONDS
	local joy = model:GetAttribute("Joy") or 0
	local ready = model:GetAttribute("Ready") == true
	local carrying = model:GetAttribute("Carrying") == true

	if playAsset(rig, state) then
		return
	end

	rig.phase += dt * math.clamp(speed, 0, 40) * 0.9
	if speed < 0.6 then
		rig.stillFor += dt
	else
		rig.stillFor = 0
		rig.idle = nil
	end

	-- Pose targets
	local sitTarget, lieTarget = 0, 0
	local headPitch, headRoll, headYawExtra = 0, 0, 0
	local bodyYaw, bodyPitch, bodyRoll, lift = 0, 0, 0, 0
	local wag, wagAmp = 11, 0.55
	local frontRightRaise, backKick = 0, 0
	local squint = false
	local lookWeight = 1

	local resting = speed < 0.6 and (state == "Following" or state == "Idle" or state == "Sitting" or state == "Staying")

	if state == "Sitting" then
		sitTarget = 1
	elseif state == "Following" and rig.stillFor > 2.5 then
		sitTarget = 0.85
		if rig.stillFor > 14 then
			lieTarget = 1 -- long rest: lie down
		end
	elseif state == "Idle" then
		sitTarget = 0.75
		wag = 15
	elseif state == "Staying" then
		headPitch = 0.08
		wag = 6
	elseif state == "Eating" then
		headPitch = -0.55 + math.sin(t * 11) * 0.14
		lookWeight = 0
		wag = 18
		if rig.head and t >= rig.nextNomAt then
			rig.nextNomAt = t + 0.55
			bubble(rig.head, math.random() < 0.5 and "nom" or "crunch", Color3.fromRGB(255, 200, 120), 60, Vector3.new(0.8, 1.2, 0))
		end
	elseif state == "BeingPetted" then
		sitTarget = 0.6
		bodyRoll = math.sin(t * 7) * 0.06 * (0.4 + joy)
		headPitch = 0.22
		wag = 12 + joy * 16
		wagAmp = 0.5 + joy * 0.3
		squint = joy > 0.35
	elseif state == "Grooming" then
		bodyRoll = math.sin(t * 14) * 0.05
		wag = 18
	elseif state == "Fetching" or state == "Returning" then
		-- Gallop: body rocks and bounces with each stride.
		local gallop = math.clamp((speed - 6) / 20, 0, 1)
		bodyPitch = -0.06 + math.sin(rig.phase) * 0.12 * gallop
		lift = math.abs(math.sin(rig.phase)) * 0.3 * gallop
		wag = 20
		-- A quick leap for mid-air catches.
		local leapT = now - (model:GetAttribute("LeapAt") or 0)
		if leapT < 0.45 then
			lift += math.sin(leapT / 0.45 * math.pi) * 1.3
			bodyPitch -= 0.25 * math.sin(leapT / 0.45 * math.pi)
		end
	elseif state == "PerformingTrick" then
		local trick = model:GetAttribute("Trick")
		wag = 22
		lookWeight = 0.3
		if trick == "spin" then
			bodyYaw = math.clamp(st / 1.1, 0, 1) * math.pi * 2
			lift = math.sin(math.clamp(st / 1.1, 0, 1) * math.pi) * 0.5
		elseif trick == "high_five" then
			sitTarget = 1
			frontRightRaise = math.clamp(st * 4, 0, 1) * (st < 1.4 and 1 or 0)
			headPitch = 0.3
		elseif trick == "play_bow" then
			bodyPitch = -0.35 * math.clamp(st * 4, 0, 1)
			lift = -0.15
			headPitch = 0.3
			wag = 26
		elseif trick == "zoomies" then
			bodyYaw = st * 7
			lift = math.abs(math.sin(t * 12)) * 0.6
			bodyPitch = -0.1
			lookWeight = 0
		elseif trick == "play_toy" then
			bodyPitch = -0.3 * math.abs(math.sin(t * 6))
			headPitch = -0.3 * math.abs(math.sin(t * 6))
			lift = math.abs(math.sin(t * 6)) * 0.3
			wag = 26
		end
	end

	-- Fetch anticipation
	if toyOut and (state == "Following" or state == "Idle") then
		sitTarget, lieTarget = 0, 0
		wag = 24
		wagAmp = 0.7
		if ready then
			bodyPitch = -0.32 -- crouch, ready to sprint
			lift = -0.2
			headPitch = 0.15
			wagAmp = 0.8
		elseif speed < 1 then
			lift = math.abs(math.sin(t * 7)) * 0.45 -- bouncing with excitement
		end
	end
	if carrying then
		headPitch = 0.25 -- proud, ball held high
		wag = 26
		lookWeight = 0
	end

	-- Spontaneous moments when resting.
	local idle = rig.idle
	if resting and not toyOut and not moodActive and not (rig.own and petting.active) then
		if not idle and t >= rig.nextIdleAt then
			pickIdle(rig, t)
			idle = rig.idle
		end
	else
		rig.idle = nil
		idle = nil
	end
	if idle then
		local p = (t - idle.at) / idle.duration
		if p >= 1 then
			rig.idle = nil
			rig.nextIdleAt = t + 3 + math.random() * 5
		else
			local e = math.sin(p * math.pi) -- ease in and out
			if idle.name == "tilt" then
				headRoll = 0.4 * e * (math.floor(idle.at) % 2 == 0 and 1 or -1)
			elseif idle.name == "sniff" then
				headPitch = -0.45 * e + math.sin(t * 18) * 0.05 * e
				lookWeight = 0
			elseif idle.name == "scratch" then
				sitTarget = 1
				backKick = e
				headRoll = 0.25 * e
				lookWeight = 0
			elseif idle.name == "bow" then
				bodyPitch = -0.3 * e
				lift = -0.12 * e
				wag = 24
			elseif idle.name == "hop" then
				lift = math.sin(p * math.pi) * 0.7
				wag = 24
			elseif idle.name == "yawn" then
				headPitch = 0.4 * e
				lookWeight = 0
			end
		end
	end

	if moodActive then
		if mood == "happy" and (state == "Following" or state == "Idle" or state == "Returning") then
			lift = math.max(lift, math.abs(math.sin(t * 9)) * 0.9)
			sitTarget, lieTarget = 0, 0
			wag = 24
		elseif mood == "love" then
			wag = 26
			squint = true
		elseif mood == "excited" or mood == "alert" then
			-- alert: heard the whistle, bounding back
			lift = math.max(lift, math.abs(math.sin(t * 10)) * 0.6)
			sitTarget, lieTarget = 0, 0
			wag = 26
		elseif mood == "comfort" then
			wag = 5
			headRoll = math.sin(t * 2) * 0.25
		elseif mood == "confused" then
			headRoll = 0.4
			wag = 3
		elseif mood == "shake" then
			-- Shaking off after the spa: a fast whole-body wiggle.
			local k = math.clamp(1 - (now - moodAt) / 1.2, 0, 1)
			bodyRoll += math.sin(t * 38) * 0.3 * k
			headRoll += math.sin(t * 38 + 0.6) * 0.45 * k
			wag = 30
		elseif mood == "sniff" then
			headPitch = -0.45 + math.sin(t * 18) * 0.06
			lookWeight = 0
		end
	end

	-- Local petting: lean into the hand, squint, thump a back leg.
	if rig.own and petting.active and state == "BeingPetted" then
		local k = petting.intensity
		bodyRoll += petting.side * 0.12 * k
		headRoll += petting.side * 0.3 * k
		headPitch += 0.1 * k
		wag = 14 + 18 * k
		squint = squint or k > 0.3
		backKick = math.max(backKick, petting.scratch)
	end

	rig.sit += (sitTarget - rig.sit) * math.min(1, dt * 6)
	rig.lie += (lieTarget - rig.lie) * math.min(1, dt * 2)
	rig.wagAmp += (wagAmp - rig.wagAmp) * math.min(1, dt * 4)
	local sit, lie = rig.sit, rig.lie

	-- Look at the target with the neck (limited, smoothed).
	local targetYaw, targetPitch = 0, 0
	local target = lookWeight > 0 and lookTarget(rig, state)
	if target and rig.head then
		local rel = rig.root.CFrame:PointToObjectSpace(target)
		local horizontal = math.sqrt(rel.X * rel.X + rel.Z * rel.Z)
		if horizontal > 0.5 and horizontal < 30 then
			targetYaw = math.clamp(math.atan2(-rel.X, -rel.Z), -0.9, 0.9) * lookWeight
			targetPitch = math.clamp(math.atan2(rel.Y - 1, horizontal), -0.3, 0.45) * lookWeight
		end
	end
	rig.lookYaw += (targetYaw - rig.lookYaw) * math.min(1, dt * 5)
	rig.lookPitch += (targetPitch - rig.lookPitch) * math.min(1, dt * 5)

	local moving = math.clamp(speed / 12, 0, 1)
	local strideAmp = (state == "Fetching" or state == "Returning") and 1.0 or 0.7
	local stride = math.sin(rig.phase) * strideAmp * moving

	if m.LegFL then
		local front = lie * 1.3 -- lying: front legs stretch forward
		m.LegFL.Transform = CFrame.Angles(stride + front, 0, 0)
		m.LegFR.Transform = CFrame.Angles(-stride - frontRightRaise * 1.9 + front, 0, frontRightRaise * 0.2)
		local kick = backKick > 0 and math.sin(t * 28) * 0.6 * backKick or 0
		m.LegBR.Transform = CFrame.Angles(stride - sit * 1.2 - lie * 0.3 + kick, 0, 0)
		m.LegBL.Transform = CFrame.Angles(-stride - sit * 1.2 - lie * 0.3, 0, 0)
	end
	if m.BodyJoint then
		local bob = math.abs(math.sin(rig.phase)) * 0.08 * moving
		local down = sit * 0.35 * (1 - lie) + lie * 0.75
		m.BodyJoint.Transform = CFrame.new(0, bob + lift - down, sit * 0.15 * (1 - lie))
			* CFrame.Angles(0, bodyYaw, 0)
			* CFrame.Angles(sit * 0.35 * (1 - lie) + bodyPitch, 0, bodyRoll)
	end
	if m.Neck then
		local breathe = math.sin(t * 2.2) * 0.02
		m.Neck.Transform = CFrame.Angles(-sit * 0.25 * (1 - lie) + headPitch + rig.lookPitch + breathe + math.sin(rig.phase * 2) * 0.05 * moving, rig.lookYaw + headYawExtra, headRoll)
	end
	if m.Tail then
		m.Tail.Transform = CFrame.Angles(carrying and -0.3 or 0, math.sin(t * wag) * rig.wagAmp, 0)
	end

	-- Eyes: blink now and then; happy squint when loved.
	if t >= rig.nextBlinkAt then
		rig.blinkUntil = t + 0.12
		rig.nextBlinkAt = t + 2.2 + math.random() * 3.5
	end
	local closed = squint or t < rig.blinkUntil
	for _, eye in rig.eyes do
		local want = closed and Vector3.new(eye.size.X, eye.size.Y * 0.2, eye.size.Z) or eye.size
		if eye.part.Size ~= want then
			eye.part.Size = want
		end
	end
	for _, shine in rig.shines do
		shine.LocalTransparencyModifier = closed and 1 or 0
	end
end

function PetController.start()
	CollectionService:GetInstanceAddedSignal("Pet"):Connect(function(m)
		task.spawn(track, m)
	end)
	CollectionService:GetInstanceRemovedSignal("Pet"):Connect(untrack)
	for _, m in CollectionService:GetTagged("Pet") do
		task.spawn(track, m)
	end
	RunService.RenderStepped:Connect(function(dt)
		for model, rig in rigs do
			if model.Parent and rig.root.Parent then
				animate(rig, dt)
			else
				untrack(model)
			end
		end
	end)
end

return PetController
