-- Thin sound layer. Call Init() once with VFXConfig, then Play(name) anywhere.
-- Swap SoundIds in VFXConfig.Sounds — nothing else changes.
--
-- Slot options (all optional, set in VFXConfig.Sounds):
--   pitchVariance — random +/- fraction applied per play, so rapid repeats
--                   (attack hits, ticks) don't fatigue the ear.
--   pooled        — round-robin pool of clones so overlapping plays don't cut
--                   each other off (use for sounds that can fire every frame).
-- Play(name, opts): opts.pitchScale multiplies the final pitch — lets count-up
-- ticks rise in pitch as they accelerate.

local SoundManager = {}

local POOL_SIZE = 3

local slots = {}   -- { [name] = { sounds = {Sound...}, nextIdx = 1, cfg = cfg } }
local masterVolume = 1

function SoundManager:Init(vfxConfig)
	local folder = Instance.new("Folder")
	folder.Name   = "GachaSounds"
	folder.Parent = workspace

	for name, cfg in pairs(vfxConfig.Sounds) do
		local count = cfg.pooled and POOL_SIZE or 1
		local sounds = {}
		for i = 1, count do
			local s = Instance.new("Sound")
			s.Name          = count > 1 and (name .. "_" .. i) or name
			-- Leave SoundId blank for unfilled placeholder slots so Roblox doesn't
			-- log a spurious "asset not found" warning for every one at Init.
			if cfg.id and cfg.id ~= "rbxassetid://0" then
				s.SoundId = cfg.id
			end
			s.Volume        = cfg.volume or 0.5
			s.PlaybackSpeed = cfg.pitch  or 1.0
			s.RollOffMaxDistance = 10000
			s.Parent        = folder
			table.insert(sounds, s)
		end
		slots[name] = { sounds = sounds, nextIdx = 1, cfg = cfg }
	end
end

-- Plays the sound only if a real SoundId has been set (skips placeholder 0).
function SoundManager:Play(name, opts)
	local slot = slots[name]
	if not slot then return end
	local s = slot.sounds[slot.nextIdx]
	slot.nextIdx = slot.nextIdx % #slot.sounds + 1
	if s.SoundId == "rbxassetid://0" or s.SoundId == "" then return end

	local pitch = slot.cfg.pitch or 1.0
	local variance = slot.cfg.pitchVariance
	if variance then
		pitch = pitch * (1 + (math.random() * 2 - 1) * variance)
	end
	if opts and opts.pitchScale then
		pitch = pitch * opts.pitchScale
	end
	s.Volume = (slot.cfg.volume or 0.5) * masterVolume
	s.PlaybackSpeed = pitch
	s:Play()
end

function SoundManager:Stop(name)
	local slot = slots[name]
	if not slot then return end
	for _, s in ipairs(slot.sounds) do
		s:Stop()
	end
end

-- v: 0-1 multiplier applied to every sound's configured base volume.
function SoundManager:SetMasterVolume(v)
	masterVolume = math.clamp(v, 0, 1)
	for _, slot in pairs(slots) do
		for _, s in ipairs(slot.sounds) do
			s.Volume = (slot.cfg.volume or 0.5) * masterVolume
		end
	end
end

function SoundManager:GetMasterVolume()
	return masterVolume
end

return SoundManager
