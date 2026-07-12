-- Central VFX config — premium, smooth, no harsh flashes.
-- All timing in seconds. Edit here; nothing else changes.

local VFXConfig = {}

-- Per-rarity card reveal tuning. Scale effects with rarity tier.
VFXConfig.RarityReveal = {
	Common = {
		auraAlpha      = 0.12,   -- aura frame opacity (0 = none)
		auraScale      = 0.85,   -- multiplier on base aura 500x680
		particleCount  = 8,      -- burst particles on reveal
		ringCount      = 0,      -- 0 = no rotating ring
		orbitCount     = 0,      -- orbital floating particles
		dramaticPause  = 0,      -- black-hold before reveal (seconds)
		shakeIntensity = 0,
		sound          = "reveal_common",
		specialFX      = nil,
	},
	Uncommon = {
		auraAlpha      = 0.20,
		auraScale      = 1.0,
		particleCount  = 16,
		ringCount      = 1,
		orbitCount     = 3,
		dramaticPause  = 0,
		shakeIntensity = 2,
		sound          = "reveal_common",
		specialFX      = nil,
	},
	Rare = {
		auraAlpha      = 0.28,
		auraScale      = 1.15,
		particleCount  = 28,
		ringCount      = 1,
		orbitCount     = 5,
		dramaticPause  = 0,
		shakeIntensity = 5,
		sound          = "reveal_rare",
		specialFX      = nil,
	},
	Epic = {
		auraAlpha      = 0.36,
		auraScale      = 1.32,
		particleCount  = 40,
		ringCount      = 2,
		orbitCount     = 7,
		dramaticPause  = 0.25,
		shakeIntensity = 8,
		sound          = "reveal_rare",
		specialFX      = "pulse",
	},
	Legendary = {
		auraAlpha      = 0.44,
		auraScale      = 1.52,
		particleCount  = 58,
		ringCount      = 2,
		orbitCount     = 9,
		dramaticPause  = 0.55,
		shakeIntensity = 13,
		sound          = "reveal_legendary",
		specialFX      = "explosion",
	},
	Mythic = {
		auraAlpha      = 0.52,
		auraScale      = 1.75,
		particleCount  = 78,
		ringCount      = 3,
		orbitCount     = 12,
		dramaticPause  = 0.75,
		shakeIntensity = 20,
		sound          = "reveal_mythic",
		specialFX      = "burst",
	},
	God = {
		auraAlpha      = 0.60,
		auraScale      = 2.0,
		particleCount  = 105,
		ringCount      = 3,
		orbitCount     = 16,
		dramaticPause  = 1.1,
		shakeIntensity = 28,
		sound          = "reveal_god",
		specialFX      = "rainbow",
	},
	Secret = {
		auraAlpha      = 0.70,
		auraScale      = 2.4,
		particleCount  = 135,
		ringCount      = 4,
		orbitCount     = 20,
		dramaticPause  = 1.9,
		shakeIntensity = 38,
		sound          = "reveal_secret",
		specialFX      = "secret",
	},
}

-- Per-click rip stage config
VFXConfig.RipStages = {
	[1] = { shakeIntensity = 5,  shakeDuration = 0.22, sparkCount = 10, tearCount = 1, streakCount = 2 },
	[2] = { shakeIntensity = 11, shakeDuration = 0.27, sparkCount = 17, tearCount = 2, streakCount = 3 },
	[3] = { shakeIntensity = 20, shakeDuration = 0.38, sparkCount = 28, tearCount = 3, streakCount = 5 },
}

-- Pack entrance + blur
VFXConfig.Entrance = {
	duration       = 0.40,
	blurSize       = 22,
	blurFadeTime   = 0.42,
	glowPulseSpeed = 1.5,
}

-- Idle float/tilt for the pack rip frame
VFXConfig.IdleFloat = {
	yAmplitude   = 6,    -- pixels up/down
	yFrequency   = 1.2,  -- Hz
	rotAmplitude = 2.0,  -- degrees left/right
	rotFrequency = 0.8,  -- Hz
}

-- Ambient background particles during opening
VFXConfig.Ambient = {
	interval = 0.09,   -- seconds between spawns
	minSize  = 4,
	maxSize  = 11,
	minLife  = 1.6,
	maxLife  = 3.2,
}

-- Radial color bloom (used instead of screen flash)
VFXConfig.Bloom = {
	duration   = 0.50,
	startAlpha = 0.30,
	maxRadius  = 900,
}

-- Rotating dot ring around the card
VFXConfig.Ring = {
	speed    = 0.85,   -- degrees per Heartbeat frame
	dotCount = 10,
	dotSize  = 8,
}

-- Results-screen animation timing (victory/defeat overlays).
VFXConfig.Results = {
	bannerTime   = 0.35,   -- banner scale-in duration
	staggerDelay = 0.28,   -- gap between reward rows appearing
	countUpTime  = 0.8,    -- gold/XP number roll duration
	tickEvery    = 0.05,   -- seconds between count-up tick sounds
	bonusHold    = 0.45,   -- beat of silence before BONUS LOOT! slams in
	bonusShake   = 10,     -- panel shake on the bonus banner
}

-- Sound slots — replace "rbxassetid://0" with real IDs.
-- pitchVariance: random +/- applied per play so rapid repeats don't fatigue.
-- pooled: true = round-robin clones so overlapping plays don't cut each other off.
VFXConfig.Sounds = {
	pack_select      = { id = "rbxassetid://0", volume = 0.8,  pitch = 1.00 },
	rip_click_1      = { id = "rbxassetid://0", volume = 0.70, pitch = 1.05 },
	rip_click_2      = { id = "rbxassetid://0", volume = 0.80, pitch = 0.95 },
	rip_click_3      = { id = "rbxassetid://0", volume = 1.00, pitch = 0.85 },
	pack_burst       = { id = "rbxassetid://0", volume = 1.00, pitch = 1.00 },
	roll_tick        = { id = "rbxassetid://0", volume = 0.25, pitch = 1.20 },
	reveal_common    = { id = "rbxassetid://0", volume = 0.50, pitch = 1.20 },
	reveal_rare      = { id = "rbxassetid://0", volume = 0.70, pitch = 1.05 },
	reveal_legendary = { id = "rbxassetid://0", volume = 0.90, pitch = 1.00 },
	reveal_mythic    = { id = "rbxassetid://0", volume = 1.00, pitch = 0.95 },
	reveal_god       = { id = "rbxassetid://0", volume = 1.00, pitch = 0.88 },
	reveal_secret    = { id = "rbxassetid://0", volume = 1.00, pitch = 0.70 },

	-- battle (free Creator Store picks — audition in Studio and swap ids freely)
	battle_start     = { id = "rbxassetid://1840076509", volume = 0.55, pitch = 1.00 },
	attack_hit       = { id = "rbxassetid://101309544882556", volume = 0.55, pitch = 1.00, pitchVariance = 0.08, pooled = true },
	attack_crit      = { id = "rbxassetid://7171761940", volume = 0.85, pitch = 0.95, pitchVariance = 0.05, pooled = true },
	cast             = { id = "rbxassetid://88350532436520", volume = 0.65, pitch = 1.00, pitchVariance = 0.06 },
	heal             = { id = "rbxassetid://86488607363887", volume = 0.45, pitch = 1.05, pitchVariance = 0.06, pooled = true },
	shield_gain      = { id = "rbxassetid://120055142560965", volume = 0.55, pitch = 1.00 },
	unit_death       = { id = "rbxassetid://7130144078", volume = 0.80, pitch = 0.85 },  -- player-side, heavier
	enemy_death      = { id = "rbxassetid://83416379007273", volume = 0.65, pitch = 1.00, pitchVariance = 0.06, pooled = true },
	synergy_proc     = { id = "rbxassetid://84811684053512", volume = 0.60, pitch = 1.00 },
	low_hp_warn      = { id = "rbxassetid://0", volume = 0.60, pitch = 1.00 },

	-- results
	victory_sting    = { id = "rbxassetid://1836860398", volume = 0.90, pitch = 1.00 },
	defeat_sting     = { id = "rbxassetid://9040193225", volume = 0.75, pitch = 0.90 },
	gold_tick        = { id = "rbxassetid://8646410774", volume = 0.35, pitch = 1.10, pooled = true },
	xp_tick          = { id = "rbxassetid://7381723941", volume = 0.30, pitch = 1.15, pooled = true },
	level_up         = { id = "rbxassetid://99980076888596", volume = 0.85, pitch = 1.00 },
	count_finish     = { id = "rbxassetid://1293433423", volume = 0.60, pitch = 1.00 },
	new_record       = { id = "rbxassetid://84872960927850", volume = 0.90, pitch = 1.00 },
	bonus_loot       = { id = "rbxassetid://1169806635", volume = 1.00, pitch = 1.00 },
	mvp_reveal       = { id = "rbxassetid://100288208393628", volume = 0.70, pitch = 1.00 },

	-- map / meta
	node_select      = { id = "rbxassetid://116115230622905", volume = 0.50, pitch = 1.00, pitchVariance = 0.05 },
	node_commit      = { id = "rbxassetid://70413169991999", volume = 0.70, pitch = 1.00 },
	rest_heal        = { id = "rbxassetid://1347153667", volume = 0.60, pitch = 1.00 },
	shop_buy         = { id = "rbxassetid://135483737426662", volume = 0.65, pitch = 1.00, pitchVariance = 0.05 },
	buff_pick        = { id = "rbxassetid://84872960927850", volume = 0.75, pitch = 1.10 },
}

return VFXConfig
