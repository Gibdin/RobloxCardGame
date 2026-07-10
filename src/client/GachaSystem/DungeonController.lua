-- DungeonController — orchestrates the battle modes behind the BATTLE button:
-- mode select → Endless Tower (dungeon runs arrive in a later phase).
-- Initialized by PackOpeningController like the other UI modules.

local DungeonController = {}

local deps           -- { remotes, CardDatabase, RarityConfig, CombatConfig, TowerConfig, DungeonConfig, onRewardsGranted }
local ModeSelectUI, TowerUI, EliteBuffUI, RunTeamPanel, BattleUI, BattleController
local towerRun       -- latest tower run snapshot (nil = no active run)
local busy = false

local function invoke(rf, ...)
	local args = { ... }
	local ok, res = pcall(function()
		return rf:InvokeServer(unpack(args))
	end)
	if not ok then
		warn("[DungeonController] remote failed:", res)
		return nil
	end
	return res
end

-- ── Tower flow ────────────────────────────────────────────────────────────────

local function refreshTowerPanel()
	TowerUI:Update(towerRun)
	RunTeamPanel:Update(towerRun)
end

local function handleBuffChoices(run)
	if not run or run.state ~= "PickingBuff" then return end
	local teamIds = {}
	for _, id in ipairs(run.team) do
		if id then table.insert(teamIds, id) end
	end
	EliteBuffUI:Show(run.pendingBuffChoices, teamIds, function(choiceIndex, targetCardId)
		local res = invoke(deps.remotes.towerPickBuff, choiceIndex, targetCardId)
		if res and res.success then
			towerRun = res.run
			refreshTowerPanel()
		end
	end)
end

local function describeRewards(rewards)
	local lines = {}
	if rewards and rewards.xp then
		local levelUps = {}
		for idStr, rep in pairs(rewards.xp) do
			if rep.leveledUp then
				local card = deps.CardDatabase:GetById(tonumber(idStr))
				table.insert(levelUps, (card and card.name or idStr) .. " → Lv" .. rep.level)
			end
		end
		if #levelUps > 0 then
			table.insert(lines, "Level up: " .. table.concat(levelUps, ", "))
		end
	end
	if rewards and rewards.packs then
		local parts = {}
		for packType, n in pairs(rewards.packs) do
			table.insert(parts, n .. "x " .. packType:gsub("Pack", " Pack"))
		end
		table.insert(lines, "Packs earned: " .. table.concat(parts, ", "))
		if deps.onRewardsGranted then deps.onRewardsGranted() end
	end
	return lines
end

local function fightFloor()
	if busy or not towerRun then return end
	busy = true
	TowerUI:SetBusy(true)

	task.spawn(function()
		local res = invoke(deps.remotes.towerNextFloor)
		if not res or not res.success then
			if res then warn("[Tower]", res.error) end
			busy = false
			TowerUI:SetBusy(false)
			return
		end

		TowerUI:Hide()
		local label = res.boss and ("TOWER — FLOOR " .. res.floor .. " (BOSS)") or ("TOWER — FLOOR " .. res.floor)
		BattleController:Play(res.battle, label)

		local lines = describeRewards(res.rewards)
		if res.victory then
			towerRun = res.run
			table.insert(lines, 1, "Floor " .. res.floor .. " cleared!")
			BattleUI:ShowResult({
				victory = true,
				title = "VICTORY",
				lines = lines,
				buttons = {
					{ text = "CONTINUE", color = Color3.fromRGB(70, 170, 90), cb = function()
						BattleUI:Hide()
						refreshTowerPanel()
						TowerUI:Show()
						handleBuffChoices(towerRun)
					end },
				},
			})
		else
			towerRun = nil
			BattleUI:ShowResult({
				victory = false,
				title = "DEFEATED",
				lines = {
					"You fell on floor " .. res.floor,
					"Floors cleared: " .. (res.floorsCleared or 0),
					"Best: Floor " .. (res.bestFloor or 0),
				},
				buttons = {
					{ text = "CLOSE", color = Color3.fromRGB(60, 60, 90), cb = function()
						BattleUI:Hide()
						RunTeamPanel:Hide()
						ModeSelectUI:Show(DungeonController:_modeInfo())
					end },
				},
			})
		end
		busy = false
		TowerUI:SetBusy(false)
	end)
end

local function openTower()
	ModeSelectUI:Hide()
	local state = invoke(deps.remotes.towerGetState)
	if state then
		towerRun = state
	else
		local res = invoke(deps.remotes.towerStart)
		if not res or not res.success then
			if res then warn("[Tower]", res.error) end
			ModeSelectUI:Show(DungeonController:_modeInfo())
			return
		end
		towerRun = res.run
	end
	refreshTowerPanel()
	RunTeamPanel:Show()
	TowerUI:Show()
	handleBuffChoices(towerRun)
end

local function abandonTower()
	invoke(deps.remotes.towerAbandon)
	towerRun = nil
	TowerUI:Hide()
	RunTeamPanel:Hide()
	ModeSelectUI:Show(DungeonController:_modeInfo())
end

-- ── Public API ────────────────────────────────────────────────────────────────

function DungeonController:_modeInfo()
	local full = invoke(deps.remotes.getInventory)
	local best = full and full.tower and full.tower.bestFloor or 0
	return {
		towerBest = best,
		towerActive = invoke(deps.remotes.towerGetState) ~= nil,
		dungeonReady = false,  -- flips on when dungeon runs ship
	}
end

function DungeonController:Init(screenGui, dependencies, uiModules)
	deps = dependencies
	ModeSelectUI = uiModules.ModeSelectUI
	TowerUI = uiModules.TowerUI
	EliteBuffUI = uiModules.EliteBuffUI
	RunTeamPanel = uiModules.RunTeamPanel
	BattleUI = uiModules.BattleUI
	BattleController = uiModules.BattleController

	BattleUI:Init(screenGui, deps.CardDatabase, deps.RarityConfig)
	BattleController:Init(BattleUI, deps.CombatConfig)
	RunTeamPanel:Init(screenGui, deps.CardDatabase)
	EliteBuffUI:Init(screenGui, deps.DungeonConfig, deps.CardDatabase)
	TowerUI:Init(screenGui, deps.TowerConfig, {
		onFight = fightFloor,
		onAbandon = abandonTower,
	})
	ModeSelectUI:Init(screenGui, {
		onDungeon = function() end,  -- phase 3
		onTower = openTower,
	})
end

function DungeonController:Toggle()
	if BattleController:IsPlaying() then return end
	if ModeSelectUI:GetPanel().Visible or TowerUI:GetPanel().Visible then
		self:Hide()
		return
	end
	-- Resume straight into the tower panel if a run is live.
	local state = invoke(deps.remotes.towerGetState)
	if state then
		towerRun = state
		refreshTowerPanel()
		RunTeamPanel:Show()
		TowerUI:Show()
		handleBuffChoices(towerRun)
	else
		ModeSelectUI:Show(self:_modeInfo())
	end
end

function DungeonController:Hide()
	if BattleController:IsPlaying() then return end
	ModeSelectUI:Hide()
	TowerUI:Hide()
	BattleUI:Hide()
end

return DungeonController
