--[[
	ProgressionRules: pure translation from server game events to the
	events EncounterScheduler and LearningProgress understand. Kept apart
	from ProgressionService so the translation is unit-tested against the
	real scheduler and ledger (tests/ProgressionRules.spec).
]]

local ProgressionRules = {}

-- Safe choices by the player. After a concerning request these earn full
-- Respond credit; before one they earn nothing and cost nothing.
ProgressionRules.SAFE_EXITS = { walk_away = true, help = true, blocked = true, reported = true }
-- Exits that only interrupt a scene; the beat goes back to eligible.
ProgressionRules.INTERRUPTIONS = { replaced = true, respawn = true, disconnect = true }

-- Facts a node presented -> ledger events.
function ProgressionRules.factEvents(beat: string, viaRoleplay: boolean, facts: { string }): { any }
	local out = { { kind = "beat_encountered", beat = beat, viaRoleplay = viaRoleplay } }
	for _, fact in facts do
		table.insert(out, { kind = "fact_seen", beat = beat, fact = fact })
	end
	return out
end

-- A scene exit -> (ledgerEvents, schedulerEvents).
-- isConcerning(factId) says whether a fact is a concerning request.
-- Respawn, disconnect and a replaced scene still end the conversation
-- right after the request, so they credit like Leave (campaign-script
-- 1.3). The beat itself only goes back to eligible.
function ProgressionRules.exitEvents(info, beat: string, viaRoleplay: boolean, isConcerning: (string) -> boolean): ({ any }, { any })
	local ledger, scheduler = {}, {}
	-- Leaving from the recovery card after a simulated agreement is "Keep
	-- playing" (campaign-script 4.6): no Respond credit from the exit.
	if (ProgressionRules.SAFE_EXITS[info.kind] or ProgressionRules.INTERRUPTIONS[info.kind]) and info.atRecovery ~= true then
		for _, fact in info.facts or {} do
			if isConcerning(fact) then
				table.insert(ledger, { kind = "left_after_request", beat = beat })
				break
			end
		end
	end
	if not viaRoleplay then -- practice roleplays never move the live campaign
		if ProgressionRules.INTERRUPTIONS[info.kind] then
			table.insert(scheduler, { kind = "interrupted", beat = beat })
		else
			table.insert(scheduler, { kind = "resolved", beat = beat })
		end
	end
	return ledger, scheduler
end

ProgressionRules.ACTIVITY_COMPLETED = { kind = "activity_completed" }

function ProgressionRules.activeSeconds(seconds: number)
	return { kind = "active_seconds", seconds = seconds }
end

function ProgressionRules.blocked(npcId: string)
	return { kind = "blocked", npc = npcId }
end

return ProgressionRules
