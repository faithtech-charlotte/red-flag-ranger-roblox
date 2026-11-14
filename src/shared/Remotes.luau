--[[
	Remotes: the only two network channels.

	  Request (RemoteFunction, client -> server):
	    Request:InvokeServer(kind, payload) -> { ok: boolean, error: string?, data: any? }
	    Every kind is validated by the server; the client never decides outcomes.

	  Push (RemoteEvent, server -> client):
	    Push:FireClient(player, kind, payload)

	The server creates the folder; the client waits for it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local Remotes = {}

-- Client -> server request kinds.
Remotes.RequestKinds = {
	GetState = "getState",
	Adopt = "adopt",
	Purchase = "purchase",
	Equip = "equip",
	Unequip = "unequip",
	UseItem = "useItem",
	PetAction = "petAction",
	PetEnd = "petEnd",
	FetchThrow = "fetchThrow",
	FetchReady = "fetchReady",
	GroomStep = "groomStep",
	ActivityCancel = "activityCancel",
	TrainPress = "trainPress",
	TrailHold = "trailHold", -- { runId, challengeId, phase = "start" | "end" }
	DialogueChoose = "dialogueChoose",
	DialogueClose = "dialogueClose",
	DialogueSafety = "dialogueSafety",
	RequestHelp = "requestHelp",
	Unblock = "unblock",
	PanelState = "panelState", -- client-only panel opened/closed (suppresses story invitations only)
}

-- Server -> client push kinds.
Remotes.PushKinds = {
	State = "state",
	Toast = "toast",
	Dialogue = "dialogue",
	DialogueClose = "dialogueClose",
	OpenShop = "openShop",
	OpenAdoption = "openAdoption",
	Fetch = "fetch",
	Agility = "agility",
	Waypoint = "waypoint",
	Celebrate = "celebrate",
	Bond = "bond",
	Petted = "petted",
	FetchAim = "fetchAim",
	Grooming = "grooming",
	Training = "training",
	TrailWalk = "trailWalk",
	OpenMissions = "openMissions",
}

function Remotes.create(): (RemoteFunction, RemoteEvent)
	assert(RunService:IsServer(), "Remotes.create is server-only")
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME) or Instance.new("Folder")
	folder.Name = FOLDER_NAME
	local request = folder:FindFirstChild("Request") or Instance.new("RemoteFunction")
	request.Name = "Request"
	request.Parent = folder
	local push = folder:FindFirstChild("Push") or Instance.new("RemoteEvent")
	push.Name = "Push"
	push.Parent = folder
	folder.Parent = ReplicatedStorage
	return request :: RemoteFunction, push :: RemoteEvent
end

function Remotes.get(): (RemoteFunction, RemoteEvent)
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	return folder:WaitForChild("Request") :: RemoteFunction, folder:WaitForChild("Push") :: RemoteEvent
end

return Remotes
