-- Thin sound layer. Call Init() once with VFXConfig, then Play(name) anywhere.
-- Swap SoundIds in VFXConfig.Sounds — nothing else changes.

local SoundManager = {}

local slots = {}   -- { [name] = Sound instance }

function SoundManager:Init(vfxConfig)
	local folder = Instance.new("Folder")
	folder.Name   = "GachaSounds"
	folder.Parent = workspace

	for name, cfg in pairs(vfxConfig.Sounds) do
		local s = Instance.new("Sound")
		s.Name          = name
		s.SoundId       = cfg.id or "rbxassetid://0"
		s.Volume        = cfg.volume or 0.5
		s.PlaybackSpeed = cfg.pitch  or 1.0
		s.RollOffMaxDistance = 10000
		s.Parent        = folder
		slots[name]     = s
	end
end

-- Plays the sound only if a real SoundId has been set (skips placeholder 0).
function SoundManager:Play(name)
	local s = slots[name]
	if not s then return end
	if s.SoundId == "rbxassetid://0" or s.SoundId == "" then return end
	s:Play()
end

function SoundManager:Stop(name)
	local s = slots[name]
	if s then s:Stop() end
end

return SoundManager
