--[[
	PanelCoordinator: one full panel open at a time (shop, journal,
	adoption, Help, dialogue).

	Controllers register their panel once with track(name, frame, close).
	Opening one closes the others. Panels the server can't see (everything
	except dialogue, which the server runs) are reported with PanelState so
	the server never invites a story scene while one is open. That signal
	can only hold invitations back; it never grants anything.

	While a reported panel stays open it is renewed every RENEW_SECONDS
	(the server forgets a panel after 75 s without renewal), and the current
	state is re-sent after respawn.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local State = require(script.Parent.State)

local RENEW_SECONDS = 30

type Panel = { frame: GuiObject, close: () -> (), reported: boolean }

local Panels = {}
local panels: { [string]: Panel } = {}
local openName: string? = nil

local function report(name: string, open: boolean)
	task.spawn(State.request, Remotes.RequestKinds.PanelState, { panel = name, open = open })
end

local function onVisible(name: string)
	local p = panels[name]
	if p.frame.Visible then
		if openName and openName ~= name then
			local other = panels[openName]
			openName = name
			if other and other.frame.Visible then
				other.close()
			end
		end
		openName = name
		if p.reported then
			report(name, true)
		end
	else
		if openName == name then
			openName = nil
		end
		if p.reported then
			report(name, false)
		end
	end
end

-- reported = false for panels the server already tracks (dialogue).
function Panels.track(name: string, frame: GuiObject, close: () -> (), reported: boolean?)
	panels[name] = { frame = frame, close = close, reported = reported ~= false }
	frame:GetPropertyChangedSignal("Visible"):Connect(function()
		onVisible(name)
	end)
end

function Panels.current(): string?
	return openName
end

task.spawn(function()
	while true do
		task.wait(RENEW_SECONDS)
		local p = openName and panels[openName]
		if p and p.reported and p.frame.Visible then
			report(openName :: string, true)
		end
	end
end)

Players.LocalPlayer.CharacterAdded:Connect(function()
	local p = openName and panels[openName]
	if p and p.reported and p.frame.Visible then
		report(openName :: string, true)
	end
end)

return Panels
