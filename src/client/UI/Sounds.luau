--[[
	Sounds: small local sound effects. Uses only sounds that ship with Roblox
	(rbxasset://sounds/...), so nothing needs uploading. Custom sounds
	(barks, squeaks, chimes) would be a big upgrade: put their asset ids in
	CUSTOM and they'll be used instead.
]]

local SoundService = game:GetService("SoundService")

local Sounds = {}

local BUILTIN = {
	click = { id = "rbxasset://sounds/volume_slider.ogg", speed = 1.2, volume = 0.4 },
	chime = { id = "rbxasset://sounds/volume_slider.ogg", speed = 1.8, volume = 0.6 },
	levelup = { id = "rbxasset://sounds/volume_slider.ogg", speed = 2.4, volume = 0.7 },
	throw = { id = "rbxasset://sounds/action_jump.mp3", speed = 1.3, volume = 0.5 },
	catch = { id = "rbxasset://sounds/action_jump_land.mp3", speed = 1.2, volume = 0.6 },
	splash = { id = "rbxasset://sounds/impact_water.mp3", speed = 1.4, volume = 0.4 },
	pop = { id = "rbxasset://sounds/action_get_up.mp3", speed = 2.0, volume = 0.4 },
	pat = { id = "rbxasset://sounds/volume_slider.ogg", speed = 1.0, volume = 0.25 },
	bounce = { id = "rbxasset://sounds/action_jump_land.mp3", speed = 1.8, volume = 0.35 },
	whoosh = { id = "rbxasset://sounds/action_jump.mp3", speed = 0.9, volume = 0.4 },
}

-- Asset ids for custom sounds. Empty for now. Most wanted: bark, happy whine,
-- panting, squeaky ball, ball bounce, crunch, pat/rustle, sparkle chime.
local CUSTOM: { [string]: string } = {}

-- pitch multiplies the base playback speed (e.g. rising pops while petting).
function Sounds.play(name: string, pitch: number?)
	local spec = BUILTIN[name]
	if not spec and not CUSTOM[name] then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = CUSTOM[name] or spec.id
	s.PlaybackSpeed = (spec and spec.speed or 1) * (pitch or 1)
	s.Volume = spec and spec.volume or 0.5
	SoundService:PlayLocalSound(s)
	task.delay(3, function()
		s:Destroy()
	end)
end

return Sounds
