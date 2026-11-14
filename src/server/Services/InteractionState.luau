--[[
	InteractionState: one answer to "is this player busy?", so story
	invitations never interrupt play.

	Server-owned states are read from their owners, so they can't drift out
	of sync: an activity session (ActivityService), a dialogue or Help
	scene (EncounterService), and petting (the dog's BeingPetted state).

	Client-only panels (shop, journal, adoption, the Help popup) report
	open/close with the PanelState request. A client report can only hold
	invitations back; it never authorizes a reward or progression. A panel
	the client stops renewing is forgotten after PANEL_TTL seconds.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local PANEL_TTL = 75
local CLIENT_PANELS = { shop = true, missions = true, adoption = true, help = true }

local InteractionState = {}
local S
local panels: { [Player]: { [string]: number } } = {}

-- Returns (busy, reason?). Reason is for logs and tests only.
function InteractionState.busy(player: Player): (boolean, string?)
	if S.Activity.current(player) then
		return true, "activity"
	end
	if S.Encounter.isActive(player) then
		return true, "dialogue"
	end
	if S.Pet.getState(player) == "BeingPetted" then
		return true, "petting"
	end
	local open = panels[player]
	if open then
		local now = os.clock()
		for name, at in open do
			if now - at <= PANEL_TTL then
				return true, name
			end
			open[name] = nil
		end
	end
	return false, nil
end

function InteractionState.init(services)
	S = services
end

function InteractionState.start()
	S.Net.on(Remotes.RequestKinds.PanelState, function(player, payload)
		if typeof(payload) ~= "table" or typeof(payload.panel) ~= "string" or not CLIENT_PANELS[payload.panel] then
			return false, nil
		end
		local open = panels[player]
		if not open then
			open = {}
			panels[player] = open
		end
		open[payload.panel] = if payload.open == true then os.clock() else nil
		return true
	end, 0) -- switching panels sends close + open back to back
	Players.PlayerRemoving:Connect(function(player)
		panels[player] = nil
	end)
end

return InteractionState
