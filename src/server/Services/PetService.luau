--[[
	PetService: adoption, naming, spawning, following, and care.

	Following (PetBehavior, server half):
	  The dog is one unanchored assembly that never collides. An AlignPosition
	  pulls its Root toward an attachment behind the owner's HumanoidRootPart.
	  The owner's client gets network ownership, so movement is smooth for the
	  owner and replicates to everyone; the client also turns the dog to face
	  where it's going and plays procedural animations (Client.PetController).
	  For fetch, the server points the AlignPosition at the ball instead.
	  Stuck recovery: if the dog ends up far away, it is teleported back.

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
local DogRig = require(ReplicatedStorage.Shared.DogRig)
local PetCatalog = require(ReplicatedStorage.Shared.Catalogs.PetCatalog)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local TELEPORT_DISTANCE = 45
local PET_PET_COOLDOWN = 3
local MAX_BOND = 9999

type Active = {
	model: Model,
	root: BasePart,
	alignPosition: AlignPosition,
	alignOrientation: AlignOrientation,
	follow: Attachment,
	busy: boolean, -- true while fetching (server is steering)
}

local Pet = {}
local S
local active: { [Player]: Active } = {}
local lastPetted: { [Player]: number } = {}
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
	gui.AlwaysOnTop = false
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

function Pet.despawn(player: Player)
	local a = active[player]
	if a then
		a.model:Destroy()
		if a.follow then
			a.follow:Destroy()
		end
		active[player] = nil
	end
end

function Pet.spawn(player: Player)
	Pet.despawn(player)
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
	nameTag(model, pet.displayName)
	S.Appearance.applyPet(model, pet, character)

	local root = model.PrimaryPart :: BasePart
	local follow = Instance.new("Attachment")
	follow.Name = "PetFollow"
	follow.Position = Vector3.new(2.4, groundOffset(character, hrp, breed.scale), 2.6)
	follow.Parent = hrp

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
		busy = false,
	}
end

function Pet.getModel(player: Player): Model?
	local a = active[player]
	return a and a.model
end

function Pet.getActive(player: Player): Active?
	return active[player]
end

-- Point the dog at something other than its owner (nil = back to following).
function Pet.setTarget(player: Player, attachment: Attachment?)
	local a = active[player]
	if not a then
		return
	end
	a.busy = attachment ~= nil
	a.alignPosition.Attachment1 = attachment or a.follow
end

-- Plays a mood animation on every client ("happy", "love", "sparkle", "comfort").
function Pet.react(player: Player, mood: string)
	local a = active[player]
	if a then
		a.model:SetAttribute("Mood", mood)
		a.model:SetAttribute("MoodAt", workspace:GetServerTimeNow())
	end
end

function Pet.applyCare(player: Player, effect: { bond: number?, mood: string? })
	local profile = S.Data.get(player)
	local pet = profile and ProfileSchema.activePet(profile)
	if not pet then
		return
	end
	pet.bond = math.min(pet.bond + (effect.bond or 0), MAX_BOND)
	if effect.mood then
		Pet.react(player, effect.mood)
	end
	S.Data.pushState(player)
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
	profile.pets[id] = {
		id = id,
		breedId = breed.id,
		name = name :: string,
		displayName = name :: string,
		equipped = {},
		bond = 0,
		adoptedAt = os.time(),
	}
	profile.activePetId = id
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
		lastPetted[player] = nil
	end)
	-- Profile may finish loading after the character exists.
	S.Data.onLoaded(function(player)
		if player.Character then
			onCharacter(player, player.Character)
		end
	end)

	-- Stuck recovery.
	task.spawn(function()
		while true do
			task.wait(0.5)
			for player, a in active do
				local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if hrp and a.root.Parent and not a.busy then
					if (a.root.Position - a.follow.WorldPosition).Magnitude > TELEPORT_DISTANCE then
						a.model:PivotTo(a.follow.WorldCFrame)
						a.root.AssemblyLinearVelocity = Vector3.zero
					end
				end
			end
		end
	end)

	S.Net.on(Remotes.RequestKinds.Adopt, Pet.adopt, 1)
	S.Net.on(Remotes.RequestKinds.PetPet, function(player)
		local now = os.clock()
		if lastPetted[player] and now - lastPetted[player] < PET_PET_COOLDOWN then
			return false, nil
		end
		lastPetted[player] = now
		Pet.applyCare(player, { bond = 1, mood = "love" })
		return true
	end, 0.5)
end

return Pet
