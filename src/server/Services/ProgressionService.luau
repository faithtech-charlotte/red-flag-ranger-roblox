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

	Story invitations stay OFF (INVITATIONS_ENABLED) until Phase 2 adds the
	campaign content and the invitation card. Nothing here is sent to the
	client except through PlayerDataService.snapshot's allowlist.
]]

local Players = game:GetService("Players")

local ActionService = require(script.Parent.Parent.Core.ActionService)
local EventBus = require(script.Parent.Parent.Core.EventBus)
local Content = require(script.Parent.Parent.Content)
local ScoreRules = require(script.Parent.Parent.Content.ScoreRules)
local EncounterScheduler = require(script.Parent.Parent.Logic.EncounterScheduler)
local LearningProgress = require(script.Parent.Parent.Logic.LearningProgress)
local Rules = require(script.Parent.Parent.Logic.ProgressionRules)

local INVITATIONS_ENABLED = false
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
			if moved or (acted and now - acted <= IDLE_SECONDS) then
				lastActive[player] = now
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

-- Asks the scheduler whether to invite now. Phase 2 sends the card.
function Progression.consider(player: Player)
	local profile = S.Data.get(player)
	if not profile then
		return nil
	end
	local busy = S.InteractionState.busy(player)
	return EncounterScheduler.decide(profile.campaign, { busy = busy, help = false })
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
