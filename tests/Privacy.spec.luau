--[[
	The client must never see scores, rules, answer keys or the private
	evidence ledger (spec acceptance: snapshots, payloads, replicated
	modules). The visible title is the one allowed learning-derived field.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local ProfileSchema = require(Server.Data.ProfileSchema)
local Data = require(Server.Services.PlayerDataService)
local LearningProgress = require(Server.Logic.LearningProgress)
local ScoreRules = require(Server.Content.ScoreRules)

local FORBIDDEN = {
	"learningV2", "learning", "campaign", "evidence", "encountered", "seenFacts",
	"toldCara", "toldLee", "needsCoaching", "review", "firstAttempt", "rulesVersion",
	"thresholds", "slots", "titles", "arcs", "claims", "npcs",
}

local function findKey(value: any, key: string, depth: number?): boolean
	if typeof(value) ~= "table" or (depth or 0) > 8 then
		return false
	end
	for k, v in value do
		if k == key or findKey(v, key, (depth or 0) + 1) then
			return true
		end
	end
	return false
end

return function(t)
	local expect = t.expect

	t.test("snapshot view carries no private learning or campaign state", function()
		local p = ProfileSchema.default(0)
		p.activePetId = "p"
		p.pets.p = ProfileSchema.newPet("p", "golden", "Sun", 0)
		local ledger = p.learningV2
		LearningProgress.record(ledger, ScoreRules, { kind = "beat_encountered", beat = "e2" })
		LearningProgress.record(ledger, ScoreRules, { kind = "left_after_request", beat = "e2" })
		LearningProgress.record(ledger, ScoreRules, { kind = "told_lee", beat = "e2" })
		p.visibleTitle = "cadet"
		p.show.ribbon = true
		local view = Data.view(p, { blocked = {}, cooldowns = {}, persistent = false })
		for _, key in FORBIDDEN do
			if findKey(view, key) then
				error(`snapshot exposes "{key}"`)
			end
		end
		expect(view.visibleTitle).toBe("cadet")
		expect(view.showRibbon).toBe(true)
	end)

	t.test("no replicated module contains scoring rules or the ledger", function()
		for _, inst in ReplicatedStorage:GetDescendants() do
			if inst:IsA("LuaSourceContainer") then
				local src = (inst :: any).Source
				for _, word in { "ScoreRules", "learningV2", "LearningProgress", "EncounterScheduler", "thresholds" } do
					if src:find(word, 1, true) then
						error(`{inst:GetFullName()} mentions {word}`)
					end
				end
			end
		end
		expect(true).toBe(true)
	end)
end
