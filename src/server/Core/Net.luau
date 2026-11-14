--[[
	Net: routes client requests to handlers and sends pushes to clients.

	Every request is rate-limited per player and per kind, wrapped in pcall,
	and refused until the player's profile has loaded. Handlers return
	(ok, error?, data?). Clients only ever receive { ok, error, data }.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

type Handler = (player: Player, payload: any) -> (boolean, string?, any?)

local Net = {}
local S
local handlers: { [string]: { fn: Handler, interval: number, needsProfile: boolean } } = {}
local lastCall: { [Player]: { [string]: number } } = {}
local push: RemoteEvent

function Net.init(services)
	S = services
	local request
	request, push = Remotes.create()
	request.OnServerInvoke = function(player: Player, kind: any, payload: any)
		if typeof(kind) ~= "string" then
			return { ok = false, error = "bad request" }
		end
		local entry = handlers[kind]
		if not entry then
			return { ok = false, error = "unknown request" }
		end
		local now = os.clock()
		local calls = lastCall[player]
		if not calls then
			calls = {}
			lastCall[player] = calls
		end
		if calls[kind] and now - calls[kind] < entry.interval then
			return { ok = false, error = "slow down", throttled = true }
		end
		calls[kind] = now
		if entry.needsProfile and not S.Data.get(player) then
			return { ok = false, error = "Still loading, one sec!" }
		end
		local ok, result, err, data = pcall(entry.fn, player, payload)
		if not ok then
			warn(`[Net] {kind} failed for {player.Name}: {result}`)
			return { ok = false, error = "Something went wrong. Try again!" }
		end
		return { ok = result == true, error = err, data = data }
	end
	Players.PlayerRemoving:Connect(function(player)
		lastCall[player] = nil
	end)
end

-- interval: minimum seconds between calls of this kind from one player.
function Net.on(kind: string, fn: Handler, interval: number?, needsProfile: boolean?)
	assert(handlers[kind] == nil, `Net handler {kind} registered twice`)
	handlers[kind] = { fn = fn, interval = interval or 0.2, needsProfile = needsProfile ~= false }
end

function Net.push(player: Player, kind: string, payload: any?)
	if player.Parent then
		push:FireClient(player, kind, payload)
	end
end

function Net.toast(player: Player, text: string, style: string?)
	Net.push(player, Remotes.PushKinds.Toast, { text = text, style = style or "info" })
end

return Net
