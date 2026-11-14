--[[
	ActivityService: the shared activity framework.

	  * Definitions (rewards, rules) come from Content/Activities.
	  * Mechanics (Server/Activities/*) do the playing: Fetch, Agility,
	    Grooming, TrickTraining, and world Props that start them.
	  * One session per player at a time. Starting a new one interrupts the
	    old one, which cleans up after itself through its onInterrupt.
	  * complete() is the only place rewards are paid: coins (with a
	    first-time bonus and a cooldown against loops), medal bonuses, Bond
	    XP, and the "activity.completed" event that quests and Jordan's story
	    listen to.

	Mechanics are decoupled from world objects: e.g. Fetch.throw() is the same
	whether it starts from the pet menu, the park's ball bucket, or a quest.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionService = require(script.Parent.Parent.Core.ActionService)
local EventBus = require(script.Parent.Parent.Core.EventBus)
local Conditions = require(script.Parent.Parent.Logic.Conditions)
local Definitions = require(script.Parent.Parent.Content.Activities)
local Ratings = require(script.Parent.Parent.Logic.Ratings)
local Places = require(ReplicatedStorage.Shared.Places)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local MechanicsFolder = script.Parent.Parent.Activities
local MECHANICS = { "Fetch", "Agility", "Grooming", "TrickTraining", "TrailWalk", "Props" }

export type Session = {
	id: string,
	startedAt: number,
	data: { [string]: any },
	onInterrupt: ((reason: string) -> ())?,
}

local Activity = {}
local S
local sessions: { [Player]: Session } = {}
local lastPaid: { [Player]: { [string]: number } } = {}
local mechanics = {}

Activity.Definitions = Definitions

function Activity.def(id: string)
	return Definitions[id]
end

-- The player's root part, or nil when there is no living character (a dead
-- character can't make progress in any activity).
function Activity.hrp(player: Player): BasePart?
	local c = player.Character
	local humanoid = c and c:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health <= 0 then
		return nil
	end
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function Activity.isAt(player: Player, placeId: string, margin: number?): boolean
	local hrp = Activity.hrp(player)
	return hrp ~= nil and Places.isInside(placeId, hrp.Position, margin)
end

-- Eligibility for a defined activity. Returns (ok, reason?).
function Activity.canStart(player: Player, id: string): (boolean, string?)
	local def = Definitions[id]
	local profile = S.Data.get(player)
	if not def or not profile then
		return false, "Not available."
	end
	if not Conditions.evaluate(def.requires, { profile = profile }) then
		if not profile.activePetId then
			return false, "Adopt a dog first!"
		end
		return false, "Not unlocked yet."
	end
	return true, nil
end

function Activity.current(player: Player): Session?
	return sessions[player]
end

-- Mirrors "is this player in an activity" onto the player (ActivityName
-- attribute), so the client can ask "stop this?" before a whistle or a
-- command cancels it. Display only: the server still decides everything.
local function mirror(player: Player)
	if typeof(player) ~= "Instance" then
		return -- unit tests use plain tables as players
	end
	local session = sessions[player]
	local name = nil
	if session then
		local def = Definitions[session.id] or Definitions[(string.gsub(session.id, "_play$", ""))]
		name = def and def.name or "this activity"
	end
	if player:GetAttribute("ActivityName") ~= name then
		player:SetAttribute("ActivityName", name)
	end
end

-- Starts a session, interrupting any other one first.
function Activity.begin(player: Player, id: string, onInterrupt: ((string) -> ())?): Session
	Activity.interrupt(player, "replaced")
	if S.Encounter and S.Encounter.dismissCard then
		-- A story card never sits over play: starting an activity puts it off.
		S.Encounter.dismissCard(player)
	end
	local session = { id = id, startedAt = os.clock(), data = {}, onInterrupt = onInterrupt }
	sessions[player] = session
	mirror(player)
	return session
end

-- Ends a session normally (no interrupt callback).
function Activity.finish(player: Player, session: Session?)
	if session == nil or sessions[player] == session then
		sessions[player] = nil
		mirror(player)
	end
end

-- Async mechanics pass their session so stale tasks cannot cancel a replacement.
function Activity.interrupt(player: Player, reason: string, expectedSession: Session?)
	local session = sessions[player]
	if not session or (expectedSession ~= nil and session ~= expectedSession) then
		return
	end
	sessions[player] = nil
	mirror(player)
	if session.onInterrupt then
		local ok, err = pcall(session.onInterrupt, reason)
		if not ok then
			warn(`[Activity] interrupt of {session.id} failed: {err}`)
		end
	end
end

-- Pays rewards for a completed activity. Only server mechanics call this.
-- data (optional): timeSeconds (medals, best time) and rating (an integer
-- 1-3, e.g. trail stars or spa shine; kept as bestRating). An invalid
-- rating is ignored rather than stored.
function Activity.complete(player: Player, id: string, data: { [string]: any }?)
	local def = Definitions[id]
	local profile = S.Data.get(player)
	if not def or not profile then
		return
	end
	local record = profile.activities[id] or { count = 0 }
	record.count += 1
	local seconds = data and data.timeSeconds
	if seconds and (record.best == nil or seconds < record.best) then
		record.best = seconds
	end
	local rating = data and data.rating
	if not Ratings.isValid(rating) then
		rating = nil
	end
	record.bestRating = Ratings.best(record.bestRating, rating)
	profile.activities[id] = record

	local coins = 0
	local now = os.clock()
	lastPaid[player] = lastPaid[player] or {}
	local paidAt = lastPaid[player][id]
	if paidAt == nil or now - paidAt >= (def.rewardCooldown or 0) then
		lastPaid[player][id] = now
		coins += def.rewards.coins or 0
	end
	local firstClaim = "first:" .. id
	if not profile.claims[firstClaim] then
		profile.claims[firstClaim] = true
		coins += def.rewards.firstBonus or 0
	end
	local medal = nil
	if seconds and def.medals then
		for _, m in def.medals do
			if seconds < m.under then
				medal = m
				local claim = `medal:{id}:{m.id}`
				if not profile.claims[claim] then
					profile.claims[claim] = true
					coins += m.bonus
				end
				break
			end
		end
	end

	if coins > 0 then
		S.Economy.grant(player, coins, id)
	end
	if def.rewards.bond then
		S.Bond.addXp(player, def.rewards.bond)
	end
	S.Pet.react(player, "happy")
	S.Net.push(player, Remotes.PushKinds.Celebrate, {
		title = `{def.name} complete!`,
		subtitle = medal and `{medal.label} time!` or (rating and Ratings.label(rating)) or nil,
		coins = coins > 0 and coins or nil,
	})
	EventBus.publish("activity.completed", player, {
		activityId = id,
		count = record.count,
		timeSeconds = seconds,
		medal = medal and medal.id or nil,
		rating = rating,
	})
	S.Data.pushState(player)
end

function Activity.init(services)
	S = services
	for _, name in MECHANICS do
		local module = require(MechanicsFolder:FindFirstChild(name) :: ModuleScript)
		mechanics[name] = module
		module.init(services, Activity)
	end
	Activity.Fetch = mechanics.Fetch

	ActionService.register("unlock_activity", function(player, spec)
		local profile = S.Data.get(player)
		local def = Definitions[spec.activityId]
		if not profile or not def then
			return false, "unknown activity"
		end
		if not profile.unlocks[spec.activityId] then
			profile.unlocks[spec.activityId] = true
			S.Net.toast(player, `New activity unlocked: {def.name}!`, "success")
			S.Data.pushState(player)
		end
		return true
	end)
end

function Activity.start()
	for _, name in MECHANICS do
		mechanics[name].start()
	end
	S.Net.on(Remotes.RequestKinds.ActivityCancel, function(player)
		Activity.interrupt(player, "cancelled")
		return true
	end, 0.3)
	-- Dying (or respawning) ends whatever the player was doing; each
	-- mechanic cleans up through its onInterrupt.
	local function watch(player: Player)
		local function onCharacter(character: Model)
			local humanoid = character:WaitForChild("Humanoid", 10)
			if humanoid and humanoid:IsA("Humanoid") then
				humanoid.Died:Connect(function()
					Activity.interrupt(player, "died")
				end)
			end
		end
		player.CharacterAdded:Connect(onCharacter)
		player.CharacterRemoving:Connect(function()
			Activity.interrupt(player, "died")
		end)
		if player.Character then
			task.spawn(onCharacter, player.Character)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		Activity.interrupt(player, "left")
		lastPaid[player] = nil
	end)
end

return Activity
