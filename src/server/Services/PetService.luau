--[[
	PetService: adoption, naming, spawning, and the dog's behavior state.

	Movement (one controller, no competing movers):
	  The dog is one unanchored, non-colliding assembly. A single AlignPosition
	  pulls its Root toward one attachment, chosen by the behavior state
	  (Logic.PetStateMachine): behind the owner ("follow"), where it stands
	  ("hold"), or an activity's target ("target"). The owner's client has
	  network ownership, so motion is smooth and replicates to everyone.

	Behavior state is replicated as model attributes:
	  PetState, PetStateAt, Trick, FaceOwner
	and every client animates it (Client.PetController). Temporary states
	(petting, eating, tricks...) return to the base state (Following,
	Sitting, Staying) automatically. A token guards each change so a late
	timer can never undo a newer state.

	Recovery: following dogs that fall far behind are teleported; a staying
	dog whose owner wanders very far comes running; temporary interactions
	end if the owner walks away; respawning rebuilds the dog cleanly.

	Names: filtered with TextService for all-ages broadcast. If filtering is
	unavailable, the dog gets a safe default name instead of unfiltered text.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")

local ActionService = require(script.Parent.Parent.Core.ActionService)
local EventBus = require(script.Parent.Parent.Core.EventBus)
local ProfileSchema = require(script.Parent.Parent.Data.ProfileSchema)
local StateMachine = require(script.Parent.Parent.Logic.PetStateMachine)
local DogRig = require(ReplicatedStorage.Shared.DogRig)
local PetCatalog = require(ReplicatedStorage.Shared.Catalogs.PetCatalog)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local TELEPORT_DISTANCE = 45
local STAY_RECALL_DISTANCE = 140
local INTERACTION_LEASH = 26
-- After a whistle the dog gets a few seconds to run back instead of being
-- popped next to you, unless it's so far away that the run would drag on.
local RECALL_SECONDS = 6
local RECALL_TELEPORT_DISTANCE = 200

type Active = {
	model: Model,
	root: BasePart,
	alignPosition: AlignPosition,
	alignOrientation: AlignOrientation,
	follow: Attachment,
	hold: Attachment,
	state: string,
	base: string,
	token: number,
	recallUntil: number?,
}

local Pet = {}
local S
local active: { [Player]: Active } = {}
-- Bumped on every spawn/despawn. A spawn that yielded (name filtering) and
-- finds the number changed has been superseded and must not build a dog.
local spawnGen: { [Player]: number } = {}
local petsFolder: Folder

-- Returns ("ok" | "rejected" | "unavailable", filteredText?)
local function filterName(player: Player, name: string): (string, string?)
	local ok, result = pcall(function()
		return TextService:FilterStringAsync(name, player.UserId, Enum.TextFilterContext.PublicChat)
	end)
	if not ok then
		warn(`[Pet] name filter unavailable: {result}`)
		return "unavailable", nil
	end
	local ok2, text = pcall(function()
		return (result :: TextFilterResult):GetNonChatStringForBroadcastAsync()
	end)
	if not ok2 then
		warn(`[Pet] name filter unavailable: {text}`)
		return "unavailable", nil
	end
	if text ~= name then
		return "rejected", text
	end
	return "ok", text
end

local function fallbackName(breedId: string): string
	local breed = PetCatalog.get(breedId)
	local names = breed and breed.defaultNames or { "Buddy" }
	return names[math.random(1, #names)]
end

local function groundOffset(character: Model, hrp: BasePart, scale: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, petsFolder }
	local hit = workspace:Raycast(hrp.Position, Vector3.new(0, -20, 0), params)
	local distance = hit and (hrp.Position.Y - hit.Position.Y) or 3
	return -distance + DogRig.GROUND_OFFSET * scale
end

local function nameTag(model: Model, text: string)
	local head = model:FindFirstChild("Head") :: BasePart
	local gui = Instance.new("BillboardGui")
	gui.Name = "NameTag"
	gui.Size = UDim2.fromOffset(160, 34)
	gui.StudsOffset = Vector3.new(0, 1.9, 0)
	gui.MaxDistance = 60
	gui.Adornee = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = text
	label.Parent = gui
	gui.Parent = model
end

local function ownerRoot(player: Player): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Point the single mover at the right attachment for a state.
local function applyMovement(a: Active, target: Attachment?)
	local mode = StateMachine.Movement[a.state] or "follow"
	if mode == "follow" then
		a.alignPosition.Attachment1 = a.follow
	elseif mode == "target" and target then
		a.alignPosition.Attachment1 = target
	else
		a.hold.WorldPosition = a.root.Position
		a.alignPosition.Attachment1 = a.hold
	end
end

function Pet.despawn(player: Player)
	spawnGen[player] = (spawnGen[player] or 0) + 1
	local a = active[player]
	if a then
		active[player] = nil
		a.token += 1
		a.model:Destroy()
		a.follow:Destroy()
		a.hold:Destroy()
	end
end

function Pet.spawn(player: Player)
	Pet.despawn(player)
	local gen = spawnGen[player]
	local profile = S.Data.get(player)
	local pet = profile and ProfileSchema.activePet(profile)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not pet or not character or not hrp then
		return
	end
	local breed = PetCatalog.get(pet.breedId) or (PetCatalog.get("golden") :: PetCatalog.Breed)

	-- Re-filter the name each spawn (filters improve over time).
	local status, text = filterName(player, pet.name)
	if status == "ok" then
		pet.displayName = text :: string
	elseif status == "rejected" then
		pet.displayName = breed.defaultNames[1]
	end
	if spawnGen[player] ~= gen or not player.Parent then
		return -- another spawn/despawn ran while we were filtering
	end
	if player.Character ~= character or not hrp.Parent then
		return -- respawned while we were filtering
	end

	local model = DogRig.build({
		furColor = breed.furColor,
		accentColor = breed.accentColor,
		earStyle = breed.earStyle,
		scale = breed.scale,
	})
	model.Name = `{player.Name}_Pet`
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("PetId", pet.id)
	model:SetAttribute("PetName", pet.displayName)
	model:SetAttribute("GroundOffset", DogRig.GROUND_OFFSET * breed.scale)
	model:SetAttribute("PetState", "Following")
	model:SetAttribute("PetStateAt", workspace:GetServerTimeNow())
	nameTag(model, pet.displayName)
	S.Appearance.applyPet(model, pet, character)

	local root = model.PrimaryPart :: BasePart
	local follow = Instance.new("Attachment")
	follow.Name = "PetFollow"
	-- Beside you, a little behind: visible from the default camera instead of
	-- hidden behind your character.
	follow.Position = Vector3.new(3.2, groundOffset(character, hrp, breed.scale), 0.8)
	follow.Parent = hrp

	local hold = Instance.new("Attachment")
	hold.Name = `PetHold_{player.UserId}`
	hold.Parent = workspace.Terrain

	local ap = Instance.new("AlignPosition")
	ap.Mode = Enum.PositionAlignmentMode.TwoAttachment
	ap.Attachment0 = root:FindFirstChild("RootAttachment") :: Attachment
	ap.Attachment1 = follow
	ap.MaxForce = 1e6
	ap.MaxVelocity = 60
	ap.Responsiveness = 16
	ap.Parent = root

	local ao = Instance.new("AlignOrientation")
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = root:FindFirstChild("RootAttachment") :: Attachment
	ao.MaxTorque = 1e6
	ao.Responsiveness = 20
	ao.CFrame = hrp.CFrame - hrp.Position
	ao.Parent = root

	model:PivotTo(follow.WorldCFrame)
	model.Parent = petsFolder
	CollectionService:AddTag(model, "Pet")
	pcall(function()
		root:SetNetworkOwner(player)
	end)

	active[player] = {
		model = model,
		root = root,
		alignPosition = ap,
		alignOrientation = ao,
		follow = follow,
		hold = hold,
		state = "Following",
		base = "Following",
		token = 0,
	}
end

function Pet.getModel(player: Player): Model?
	local a = active[player]
	return a and a.model
end

-- The dog's (filtered) display name, for messages.
function Pet.name(player: Player): string
	local model = Pet.getModel(player)
	return model and model:GetAttribute("PetName") or "Your dog"
end

function Pet.getActive(player: Player): Active?
	return active[player]
end

function Pet.getState(player: Player): (string?, string?)
	local a = active[player]
	if not a then
		return nil, nil
	end
	return a.state, a.base
end

function Pet.distanceToOwner(player: Player): number
	local a = active[player]
	local hrp = ownerRoot(player)
	if not a or not hrp then
		return math.huge
	end
	return (a.root.Position - hrp.Position).Magnitude
end

export type StateOptions = {
	duration: number?, -- temporary states: seconds before settling back
	target: Attachment?, -- "target" movement states
	byActivity: boolean?, -- activities may chain their own states
	trick: string?, -- PerformingTrick: which trick to animate
	force: boolean?, -- skip transition rules (internal recovery only)
	fast: boolean?, -- sprint (fetch chase / return)
}

--[[
	Changes the dog's behavior state. Returns (ok, reason?, token).
	The token identifies this change; activities pass it back to check they
	are still in charge before their next step.
]]
function Pet.setState(player: Player, state: string, opts: StateOptions?): (boolean, string?, number?)
	local a = active[player]
	if not a then
		return false, "No dog yet!", nil
	end
	local o = opts or {}
	if not o.force then
		local ok, reason = StateMachine.canEnter(a.state, state, o.byActivity)
		if not ok then
			return false, reason, nil
		end
	end
	a.token += 1
	local token = a.token
	a.state = state
	if StateMachine.isBase(state) then
		a.base = state
	end
	a.model:SetAttribute("PetState", state)
	a.model:SetAttribute("PetStateAt", workspace:GetServerTimeNow())
	a.model:SetAttribute("Trick", o.trick)
	a.model:SetAttribute("FaceOwner", StateMachine.FacesOwner[state] == true)
	applyMovement(a, o.target)
	-- Chasing and bringing back a toy is a sprint; everything else is a trot.
	-- Fast enough to beat you there, slow enough that you can watch the run.
	a.alignPosition.MaxVelocity = o.fast and 30 or 60
	a.alignPosition.Responsiveness = o.fast and 24 or 16

	if o.duration and StateMachine.isTemporary(state) then
		task.delay(o.duration, function()
			if active[player] == a and a.token == token then
				Pet.settle(player)
			end
		end)
	end
	return true, nil, token
end

-- Ends whatever the dog is doing and goes back to its base behavior.
function Pet.settle(player: Player)
	local a = active[player]
	if a then
		Pet.setState(player, StateMachine.settle(a.base), { force = true })
	end
end

-- Is `token` still the current state change? (Activities check this.)
function Pet.isCurrent(player: Player, token: number?): boolean
	local a = active[player]
	return a ~= nil and token ~= nil and a.token == token
end

-- Plays a mood flourish on every client ("happy", "love", "sparkle",
-- "comfort", "confused"). Separate from state so it never fights movement.
function Pet.react(player: Player, mood: string)
	local a = active[player]
	if a then
		a.model:SetAttribute("Mood", mood)
		a.model:SetAttribute("MoodAt", workspace:GetServerTimeNow())
	end
end

-- Whistled back: a "!" over the dog, and a few seconds to run home before
-- the stuck-recovery check would teleport it.
function Pet.recall(player: Player)
	local a = active[player]
	if a then
		a.recallUntil = workspace:GetServerTimeNow() + RECALL_SECONDS
		Pet.react(player, "alert")
	end
end

-- Positive care from items/services: a reaction plus Bond XP.
function Pet.applyCare(player: Player, effect: { xp: number?, mood: string? }, source: string?)
	if effect.mood then
		Pet.react(player, effect.mood)
	end
	S.Bond.addXp(player, source or "care", effect.xp)
end

function Pet.adopt(player: Player, payload: any): (boolean, string?, any?)
	local profile = S.Data.get(player)
	if not profile then
		return false, "Still loading."
	end
	if profile.activePetId then
		return false, "You already have a dog!"
	end
	if typeof(payload) ~= "table" then
		return false, "Pick a dog first."
	end
	local breed = PetCatalog.get(payload.breedId)
	if not breed then
		return false, "Pick a dog first."
	end
	local name, problem = PetCatalog.cleanName(payload.name)
	if not name then
		return false, problem
	end

	local status, _ = filterName(player, name)
	local notice = nil
	if status == "rejected" then
		return false, "That name isn't allowed here. Try a different one!"
	elseif status == "unavailable" then
		name = fallbackName(breed.id)
		notice = `We couldn't check names right now, so your pup is called {name} for now.`
	end
	if profile.activePetId then
		return false, "You already have a dog!" -- re-check after yielding
	end

	local id = HttpService:GenerateGUID(false)
	profile.pets[id] = ProfileSchema.newPet(id, breed.id, name :: string, os.time())
	profile.activePetId = id
	-- The Agility Course is open from day one (the first-fetch quest still
	-- completes and pays; its unlock reward becomes a harmless repeat).
	profile.unlocks.agility = true
	Pet.spawn(player)
	Pet.react(player, "love")
	EventBus.publish("pet.adopted", player, { petId = id, breedId = breed.id })
	S.Data.pushState(player)
	S.Net.push(player, Remotes.PushKinds.Celebrate, { title = `Welcome home, {name}!` })
	if notice then
		S.Net.toast(player, notice, "warn")
	end
	return true, nil, { name = name }
end

local function onCharacter(player: Player, character: Model)
	character:WaitForChild("HumanoidRootPart", 10)
	task.wait(0.3)
	if player.Character == character then
		Pet.spawn(player)
		local profile = S.Data.get(player)
		if profile then
			S.Appearance.applyPlayer(character, profile)
		end
	end
end

local function monitor()
	for player, a in active do
		local hrp = ownerRoot(player)
		if not hrp or not a.root.Parent then
			continue
		end
		local distance = (a.root.Position - hrp.Position).Magnitude
		local mode = StateMachine.Movement[a.state]
		local recalling = a.recallUntil ~= nil and workspace:GetServerTimeNow() < a.recallUntil
		local leash = recalling and RECALL_TELEPORT_DISTANCE or TELEPORT_DISTANCE
		if a.state == "Following" and distance > leash then
			-- Stuck or left behind: pop back next to the owner.
			a.model:PivotTo(a.follow.WorldCFrame)
			a.root.AssemblyLinearVelocity = Vector3.zero
		elseif StateMachine.isBase(a.state) and a.state ~= "Following" and distance > STAY_RECALL_DISTANCE then
			Pet.setState(player, "Following", { force = true })
			S.Net.toast(player, `{Pet.name(player)} missed you and came running!`, "info")
		elseif StateMachine.isTemporary(a.state) and distance > INTERACTION_LEASH then
			Pet.settle(player) -- owner walked away mid-interaction
		end
	end
end

function Pet.init(services)
	S = services
	petsFolder = Instance.new("Folder")
	petsFolder.Name = "Pets"
	petsFolder.Parent = workspace

	ActionService.register("pet_react", function(player, spec)
		Pet.react(player, spec.mood or "happy")
		return true
	end)
end

function Pet.start()
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		player.CharacterRemoving:Connect(function()
			Pet.despawn(player)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		Pet.despawn(player)
		spawnGen[player] = nil
	end)
	-- Profile may finish loading after the character exists.
	S.Data.onLoaded(function(player)
		-- Saves from before agility opened at adoption: open it for anyone
		-- who already has a dog.
		local profile = S.Data.get(player)
		if profile and profile.activePetId and not profile.unlocks.agility then
			profile.unlocks.agility = true
		end
		if player.Character then
			onCharacter(player, player.Character)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.5)
			monitor()
		end
	end)

	S.Net.on(Remotes.RequestKinds.Adopt, Pet.adopt, 1)
end

return Pet
