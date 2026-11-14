--[[
	QuestService: completes Ranger Journal quests when matching events fire,
	then runs their reward actions once (profile.quests is the claim record).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionService = require(script.Parent.Parent.Core.ActionService)
local EventBus = require(script.Parent.Parent.Core.EventBus)
local QuestCatalog = require(ReplicatedStorage.Shared.Catalogs.QuestCatalog)

local Quest = {}
local S

local function matches(match: { [string]: any }?, payload: { [string]: any }): boolean
	if not match then
		return true
	end
	for key, expected in match do
		local actual = payload[key]
		if typeof(expected) == "table" then
			if not table.find(expected, actual) then
				return false
			end
		elseif actual ~= expected then
			return false
		end
	end
	return true
end
Quest.matches = matches

function Quest.complete(player: Player, questId: string): boolean
	local profile = S.Data.get(player)
	local quest = QuestCatalog.get(questId)
	if not profile or not quest or profile.quests[questId] then
		return false
	end
	profile.quests[questId] = true
	S.Net.toast(player, `Journal: {quest.title} ✔`, "success")
	ActionService.run(player, quest.rewards, { questId = questId })
	EventBus.publish("quest.completed", player, { questId = questId })
	S.Data.pushState(player)
	return true
end

function Quest.init(services)
	S = services
	ActionService.register("complete_quest", function(player, spec)
		Quest.complete(player, spec.questId)
		return true
	end)
end

function Quest.start()
	local byEvent: { [string]: { QuestCatalog.Quest } } = {}
	for _, quest in QuestCatalog.Ordered do
		local name = quest.completeOn.event
		byEvent[name] = byEvent[name] or {}
		table.insert(byEvent[name], quest)
	end
	for eventName, quests in byEvent do
		EventBus.subscribe(eventName, function(player, payload)
			local profile = S.Data.get(player)
			if not profile then
				return
			end
			for _, quest in quests do
				if not profile.quests[quest.id] and matches(quest.completeOn.match, payload) then
					Quest.complete(player, quest.id)
				end
			end
		end)
	end
end

return Quest
