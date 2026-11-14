--[[
	State: the client's read-only copy of its profile snapshot, plus a
	request() helper. The server pushes a fresh snapshot after every change.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local State = {}
State.data = nil :: any
local changed = Instance.new("BindableEvent")
State.changed = changed.Event

local requestRemote: RemoteFunction, pushRemote: RemoteEvent = Remotes.get()
State.push = pushRemote.OnClientEvent

-- Sends a request; returns (ok, error?, data?). Never throws.
function State.request(kind: string, payload: any?): (boolean, string?, any?)
	local ok, result = pcall(function()
		return requestRemote:InvokeServer(kind, payload)
	end)
	if not ok or typeof(result) ~= "table" then
		return false, "Connection hiccup. Try again!", nil
	end
	return result.ok == true, result.error, result.data
end

function State.set(data)
	State.data = data
	changed:Fire(data)
end

pushRemote.OnClientEvent:Connect(function(kind, payload)
	if kind == Remotes.PushKinds.State then
		State.set(payload)
	end
end)

task.spawn(function()
	while not State.data do
		local ok, _, data = State.request(Remotes.RequestKinds.GetState)
		if ok and data then
			State.set(data)
			break
		end
		task.wait(1)
	end
end)

return State
