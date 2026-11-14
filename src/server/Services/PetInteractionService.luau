--[[
	PetInteractionService: everything the pet menu can ask for.

	Request: petAction { action, food?, trick? }
	There is no pet id in the request: a player can only ever act on their
	own active dog. Every action is checked for: having a dog, the action
	existing, Bond Level unlocks, distance (for hands-on actions), cooldowns,
	the dog's current behavior state, and owned items (treats).

	The menu also tells the dog to pay attention ("attend") while it's open,
	so it doesn't wander off, and lets it go again ("dismiss").
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local EventBus = require(script.Parent.Parent.Core.EventBus)
local BondCatalog = require(ReplicatedStorage.Shared.Catalogs.BondCatalog)
local ItemCatalog = require(ReplicatedStorage.Shared.Catalogs.ItemCatalog)
local PetActions = require(ReplicatedStorage.Shared.Catalogs.PetActions)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ATTEND_SECONDS = 25

local Interaction = {}
local S
local readyAt: { [Player]: { [string]: number } } = {} -- server time

local function coolingDown(player: Player, key: string): boolean
	local t = readyAt[player] and readyAt[player][key]
	return t ~= nil and workspace:GetServerTimeNow() < t
end

local function startCooldown(player: Player, key: string, seconds: number)
	readyAt[player] = readyAt[player] or {}
	readyAt[player][key] = workspace:GetServerTimeNow() + seconds
end

-- For the client's menu: { key = readyAtServerTime }.
function Interaction.cooldowns(player: Player): { [string]: number }
	local out = {}
	local now = workspace:GetServerTimeNow()
	for key, t in readyAt[player] or {} do
		if t > now then
			out[key] = t
		end
	end
	return out
end

local function bowl(player: Player, color: Color3)
	local pet = S.Pet.getActive(player)
	if not pet then
		return
	end
	local mouth = pet.model:FindFirstChild("MouthAttachment", true) :: Attachment?
	if not mouth then
		return
	end
	local base = mouth.WorldPosition
	local dish = Instance.new("Part")
	dish.Name = "FoodBowl"
	dish.Shape = Enum.PartType.Cylinder
	dish.Size = Vector3.new(0.35, 1.4, 1.4)
	dish.Color = Color3.fromRGB(80, 160, 255)
	dish.Anchored = true
	dish.CanCollide = false
	dish.CanQuery = false
	dish.CFrame = CFrame.new(base.X, base.Y - 0.9, base.Z) * CFrame.Angles(0, 0, math.rad(90))
	local food = Instance.new("Part")
	food.Name = "Food"
	food.Shape = Enum.PartType.Ball
	food.Size = Vector3.new(0.9, 0.5, 0.9)
	food.Color = color
	food.Anchored = true
	food.CanCollide = false
	food.CanQuery = false
	food.CFrame = CFrame.new(base.X, base.Y - 0.65, base.Z)
	food.Parent = dish
	dish.Parent = workspace
	Debris:AddItem(dish, 2.8)
end

-- Feeding is shared by the menu and the wardrobe's "Give" button.
function Interaction.feed(player: Player, food: any): (boolean, string?)
	if S.Pet.distanceToOwner(player) > PetActions.TOUCH_DISTANCE then
		return false, `Get closer to {S.Pet.name(player)} first.`
	end
	local item = nil
	if food ~= PetActions.FreeFood.id then
		item = ItemCatalog.get(food)
		if not item or item.kind ~= "consumable" then
			return false, "That isn't food!"
		end
		if not S.Inventory.owns(player, item.id) then
			return false, `You're out of {item.name}. The Treat Shop has more!`
		end
		-- Don't spend a treat that would give no Bond XP.
		if S.Bond.coolingDown(player, "feed_treat") then
			return false, `{S.Pet.name(player)} is still full. Try again in a few seconds!`
		end
	elseif coolingDown(player, "kibble") then
		return false, "The kibble bowl is refilling."
	end
	local ok, reason = S.Pet.setState(player, "Eating", { duration = 2.6 })
	if not ok then
		return false, reason
	end
	if item then
		S.Inventory.consume(player, item.id)
		bowl(player, Color3.fromRGB(240, 190, 120))
		local effect = item.effect or {}
		S.Pet.react(player, effect.mood or "happy")
		S.Bond.addXp(player, "feed_treat", effect.xp)
	else
		startCooldown(player, "kibble", PetActions.FreeFood.cooldown)
		bowl(player, Color3.fromRGB(150, 100, 60))
		S.Pet.react(player, "happy")
		S.Bond.addXp(player, "feed_kibble")
	end
	EventBus.publish("pet.interacted", player, { action = "feed", food = item and item.id or "kibble" })
	S.Data.pushState(player)
	return true, nil
end

local handlers: { [string]: (Player, any) -> (boolean, string?) } = {}

handlers.attend = function(player)
	local state = S.Pet.getState(player)
	if state == "Following" or state == "Sitting" then
		if S.Pet.distanceToOwner(player) <= PetActions.TOUCH_DISTANCE then
			S.Pet.setState(player, "Idle", { duration = ATTEND_SECONDS })
		end
	end
	return true, nil
end

handlers.dismiss = function(player)
	if S.Pet.getState(player) == "Idle" then
		S.Pet.settle(player)
	end
	return true, nil
end

--[[
	Petting is a hands-on session, not a button:
	  petStart   the dog settles in front of you (BeingPetted, no timer)
	  petStroke  { amount = 0..1 } a few times a second while you stroke it
	  petEnd     you're done (or walked away, or 30 s passed)
	The server limits how fast "petting" can accumulate, so XP only comes
	from a few seconds of real interaction. The Joy attribute (0..1) lets
	everyone nearby see how happy the dog is.
]]
local PET_SESSION_MAX = 30
local PET_MIN_SECONDS = 2.5
local PET_RATE = 0.5 -- progress per second at full intensity (2+ s of real petting)
local petting: { [Player]: { started: number, last: number, progress: number, token: number? } } = {}

local function endPetting(player: Player)
	local session = petting[player]
	petting[player] = nil
	local model = S.Pet.getModel(player)
	if model and (model:GetAttribute("Joy") or 0) ~= 0 then
		model:SetAttribute("Joy", 0) -- skip the replicated write when nothing changes
	end
	if session and S.Pet.getState(player) == "BeingPetted" then
		S.Pet.settle(player)
	end
end

handlers.petStart = function(player)
	if S.Pet.distanceToOwner(player) > PetActions.TOUCH_DISTANCE then
		return false, `Get closer to {S.Pet.name(player)} first.`
	end
	S.Activity.interrupt(player, "petting")
	local ok, reason, token = S.Pet.setState(player, "BeingPetted", {})
	if not ok then
		return false, reason
	end
	local now = os.clock()
	petting[player] = { started = now, last = now, progress = 0, token = token }
	S.Pet.react(player, "excited")
	task.delay(PET_SESSION_MAX, function()
		local session = petting[player]
		if session and session.started == now then
			endPetting(player)
		end
	end)
	return true, nil
end

handlers.petStroke = function(player, payload)
	local session = petting[player]
	if not session or not S.Pet.isCurrent(player, session.token) then
		petting[player] = nil
		return false, nil
	end
	local amount = typeof(payload.amount) == "number" and payload.amount == payload.amount and math.clamp(payload.amount, 0, 1) or 0
	local now = os.clock()
	local dt = math.min(now - session.last, 0.5)
	session.last = now
	session.progress += amount * dt * PET_RATE
	local model = S.Pet.getModel(player)
	if model then
		model:SetAttribute("Joy", math.clamp(amount * 1.5, 0, 1))
	end
	if session.progress >= 1 and now - session.started >= PET_MIN_SECONDS then
		session.progress = 0
		local gained = S.Bond.addXp(player, "pet")
		S.Pet.react(player, "love")
		EventBus.publish("pet.interacted", player, { action = "pet" })
		S.Net.push(player, Remotes.PushKinds.Petted, { xp = gained })
		S.Data.pushState(player)
	end
	return true, nil
end

handlers.feed = function(player, payload)
	return Interaction.feed(player, payload.food)
end

handlers.brush = function(player)
	local ok, reason = S.Pet.setState(player, "Grooming", { duration = 2.6 })
	if not ok then
		return false, reason
	end
	local model = S.Pet.getModel(player)
	if model then
		model:SetAttribute("GroomFx", "brush")
		local shine = workspace:GetServerTimeNow() + 30
		if (model:GetAttribute("ShinyUntil") or 0) < shine then
			model:SetAttribute("ShinyUntil", shine)
		end
		task.delay(2.6, function()
			if model.Parent and model:GetAttribute("GroomFx") == "brush" then
				model:SetAttribute("GroomFx", nil)
			end
		end)
	end
	S.Pet.react(player, "sparkle")
	S.Bond.addXp(player, "brush")
	return true, nil
end

local function command(state: string)
	return function(player)
		S.Activity.interrupt(player, "command")
		S.Pet.setState(player, state)
		return true, nil
	end
end
handlers.sit = command("Sitting")
handlers.stay = command("Staying")
handlers.come = command("Following")

-- The whistle always works: whatever the dog is doing (fetching, eating,
-- staying across the park), it drops it and runs back to you.
handlers.whistle = function(player)
	S.Activity.interrupt(player, "command")
	local ok, reason = S.Pet.setState(player, "Following", { force = true })
	if not ok then
		return false, reason
	end
	S.Pet.recall(player)
	return true, nil
end

handlers.trick = function(player, payload)
	local trick = PetActions.Tricks[payload.trick]
	if not trick then
		return false, "Unknown trick."
	end
	local need = BondCatalog.requiredLevel("trick", trick.id)
	if not need or S.Bond.level(player) < need then
		return false, `Reach Bond Level {need or "?"} to learn {trick.label}.`
	end
	if coolingDown(player, "trick") then
		return false, nil
	end
	local ok, reason = S.Pet.setState(player, "PerformingTrick", { duration = trick.duration, trick = trick.id })
	if not ok then
		return false, reason
	end
	startCooldown(player, "trick", trick.duration + 0.3)
	S.Pet.react(player, "happy")
	S.Bond.addXp(player, "trick")
	return true, nil
end

local function handle(player: Player, payload: any): (boolean, string?)
	if typeof(payload) ~= "table" or typeof(payload.action) ~= "string" then
		return false, nil
	end
	if not S.Pet.getActive(player) then
		return false, "Adopt a dog first!"
	end
	local action = payload.action
	local handler = handlers[action]
	if not handler then
		return false, nil
	end
	local def = PetActions.Actions[action == "trick" and "tricks" or action]
	if def then
		if def.unlock and not S.Bond.has(player, def.unlock.kind, def.unlock.id) then
			local need = BondCatalog.requiredLevel(def.unlock.kind, def.unlock.id)
			return false, `{def.label} unlocks at Bond Level {need}.`
		end
		if def.touch and S.Pet.distanceToOwner(player) > PetActions.TOUCH_DISTANCE then
			return false, `Get closer to {S.Pet.name(player)} first.`
		end
		if def.cooldown > 0 and coolingDown(player, def.id) then
			return false, nil
		end
	end
	local ok, err = handler(player, payload)
	if ok and def and def.cooldown > 0 then
		startCooldown(player, def.id, def.cooldown)
	end
	-- whistle: no quest or XP hangs on it, so it needn't publish or push state.
	-- (petEnd isn't a PetAction; it has its own PetEnd request kind.)
	local quiet = { attend = true, dismiss = true, feed = true, petStart = true, petStroke = true, whistle = true }
	if ok and not quiet[action] then -- feed and petting publish their own events
		EventBus.publish("pet.interacted", player, { action = action, trick = payload.trick })
		S.Data.pushState(player)
	end
	return ok, err
end

function Interaction.init(services)
	S = services
end

function Interaction.start()
	S.Net.on(Remotes.RequestKinds.PetAction, handle, 0.15)
	-- Ending has its own request kind (not PetAction) so it's never dropped by
	-- PetAction's rate limit right after a petStroke. Its own small limit only
	-- stops spam; with no session it does nothing.
	S.Net.on(Remotes.RequestKinds.PetEnd, function(player)
		endPetting(player)
		return true, nil
	end, 0.05)
	Players.PlayerRemoving:Connect(function(player)
		readyAt[player] = nil
		petting[player] = nil
	end)
end

return Interaction
