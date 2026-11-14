--[[
	ProgressionService: connects play to the practice-story campaign.

	It feeds validated server events into two pure modules and saves the
	result:
	  * Logic/EncounterScheduler: which story beat may come next, and when
	    (profile.campaign).
	  * Logic/LearningProgress: the private 30-point evidence ledger
	    (profile.learningV2), with weights in Content/ScoreRules.

	Inputs (all server-side; the client never reports progress):
	  activity.completed            a finished round -> scheduler
	  encounter.facts_presented     facts a node showed -> ledger
	  encounter.exited              how a scene ended -> scheduler + ledger
	  encounter.safety_tool         practice block/report -> scheduler
	  action "learning"             semantic evidence from story choices
	  active-time ticks             the 90 s pacing gap

	Every handler runs to completion without yielding, so updates for one
	player never interleave even though EventBus spawns listeners. Every
	ledger/scheduler update is idempotent, so a replayed event can't give
	extra credit. After each change the profile is checkpointed.

	Story invitations are ON (Phase 2): each tick, consider() asks the
	scheduler for at most one invitation (never while the player is busy,
	only for beats that have a scene) and StoryService shows the card.
	Nothing here is sent to the client except through
	PlayerDataService.snapshot's allowlist.
]]

local Players = game:GetService("Players")

local ActionService = require(script.Parent.Parent.Core.ActionService)
local EventBus = require(script.Parent.Parent.Core.EventBus)
local Content = require(script.Parent.Parent.Content)
local ScoreRules = require(script.Parent.Parent.Content.ScoreRules)
local EncounterScheduler = require(script.Parent.Parent.Logic.EncounterScheduler)
local LearningProgress = require(script.Parent.Parent.Logic.LearningProgress)
local Rules = require(script.Parent.Parent.Logic.ProgressionRules)

local INVITATIONS_ENABLED = true
local TICK_SECONDS = 5
local IDLE_SECONDS = 30 -- active play = moved or busy within this window
local MOVE_EPSILON = 1

local Progression = {}
local S
local lastPos: { [Player]: Vector3 } = {}
local lastActive: { [Player]: number } = {}

local function same(a: any, b: any): boolean
	if typeof(a) ~= "table" or typeof(b) ~= "table" then
		return a == b
	end
	for k, v in a do
		if not same(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

local function beatOf(encounterId: string?): (string?, boolean)
	local enc = encounterId and Content.encounters[encounterId]
	if not enc then
		return nil, false
	end
	if enc.roleplayFor then
		return enc.roleplayFor, true
	end
	return enc.beat, false
end

local function isConcerning(factId: string): boolean
	local facts = Content.facts
	local def = facts and facts[factId]
	return typeof(def) == "table" and def.concerning == true
end

-- Applies one scheduler event to the saved campaign state.
function Progression.schedule(player: Player, event): boolean
	local profile = S.Data.get(player)
	if not profile then
		return false
	end
	local before = profile.campaign
	local after = EncounterScheduler.apply(before, event)
	if same(after, before) then
		return false -- apply() always copies; only save real changes
	end
	profile.campaign = after
	S.Data.checkpoint(player, "campaign")
	if not same(before.beats, after.beats) then
		S.Data.pushState(player) -- story presence (who's in the park) may change
	end
	return true
end

-- Records one ledger event. Returns whether anything changed.
function Progression.record(player: Player, event): boolean
	local profile = S.Data.get(player)
	if not profile then
		return false
	end
	local changed = LearningProgress.record(profile.learningV2, ScoreRules, event)
	if changed then
		S.Data.checkpoint(player, "learning")
	end
	return changed
end

function Progression.campaign(player: Player)
	local profile = S.Data.get(player)
	return profile and profile.campaign
end

local function onFacts(player: Player, info)
	local beat, viaRoleplay = beatOf(info.encounterId)
	if not beat then
		return
	end
	for _, event in Rules.factEvents(beat, viaRoleplay, info.facts) do
		Progression.record(player, event)
	end
end

local function onExit(player: Player, info)
	local beat, viaRoleplay = beatOf(info.encounterId)
	if not beat then
		return
	end
	local ledgerEvents, schedulerEvents = Rules.exitEvents(info, beat, viaRoleplay, isConcerning)
	for _, event in ledgerEvents do
		Progression.record(player, event)
	end
	for _, event in schedulerEvents do
		Progression.schedule(player, event)
	end
end

local function tick()
	for _, player in Players:GetPlayers() do
		local profile = S.Data.get(player)
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if profile and hrp and humanoid and humanoid.Health > 0 then
			local now = os.clock()
			local pos = hrp.Position
			local moved = lastPos[player] == nil or (pos - lastPos[player]).Magnitude > MOVE_EPSILON
			lastPos[player] = pos
			-- Real play only: moving, or a request the player actually made.
			-- An open panel alone (auto-renewed) does not count.
			local acted = S.Net.lastActedAt(player)
			-- Keep the real timestamp of the last action, so one request
			-- counts for at most IDLE_SECONDS of play.
			if moved then
				lastActive[player] = now
			elseif acted and acted > (lastActive[player] or 0) then
				lastActive[player] = acted
			end
			if lastActive[player] and now - lastActive[player] <= IDLE_SECONDS then
				local campaign = profile.campaign
				if campaign.remainingGap and campaign.remainingGap > 0 then
					Progression.schedule(player, Rules.activeSeconds(TICK_SECONDS))
				end
			end
			if INVITATIONS_ENABLED then
				Progression.consider(player)
			end
		end
	end
end

-- Asks the scheduler whether to invite now, and shows the card if so.
-- Help, replay and recovery are player-started elsewhere; only campaign
-- beats (that have a scene) and ambient scenes are invited here.
function Progression.consider(player: Player)
	local profile = S.Data.get(player)
	if not profile or not profile.campaign.onboarded then
		return nil
	end
	local busy = S.InteractionState.busy(player) or S.Story.busy(player)
	local decision = EncounterScheduler.decide(profile.campaign, {
		busy = busy,
		help = false,
		available = S.Story.available,
		ambient = S.Story.ambient(player),
	})
	if decision and (decision.kind == "campaign" or decision.kind == "ambient") then
		S.Story.invite(player, decision)
	end
	return decision
end

function Progression.init(services)
	S = services
	ActionService.register("learning", function(player, spec, ctx)
		local event = table.clone(spec)
		event.action = nil
		if event.beat == nil then
			event.beat = beatOf(ctx and ctx.encounterId)
		end
		Progression.record(player, event)
		return true -- evidence is best-effort; never blocks the conversation
	end)
	ActionService.register("campaign", function(player, spec)
		local event = table.clone(spec)
		event.action = nil
		Progression.schedule(player, event)
		return true
	end)
end

function Progression.start()
	S.Data.onLoaded(function(player, profile)
		profile.campaign = EncounterScheduler.sanitize(profile.campaign)
	end)
	EventBus.subscribe("activity.completed", function(player)
		Progression.schedule(player, Rules.ACTIVITY_COMPLETED)
	end)
	EventBus.subscribe("encounter.facts_presented", onFacts)
	EventBus.subscribe("encounter.exited", onExit)
	EventBus.subscribe("encounter.safety_tool", function(player, info)
		if info.tool == "block" then
			Progression.schedule(player, Rules.blocked(info.npcId))
		end
	end)
	EventBus.subscribe("encounter.unblocked", function(player, info)
		-- No reset, no restart: blocked beats stay skipped_by_block.
		Progression.schedule(player, { kind = "unblocked", npc = info.npcId })
	end)
	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			tick()
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastPos[player] = nil
		lastActive[player] = nil
	end)
end

return Progression
