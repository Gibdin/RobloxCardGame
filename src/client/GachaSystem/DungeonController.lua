-- DungeonController — orchestrates the battle modes behind the BATTLE button:
-- mode select → Endless Tower | Dungeon Run. Initialized by
-- PackOpeningController like the other UI modules.

local DungeonController = {}

local deps           -- { remotes, CardDatabase, RarityConfig, CombatConfig, TowerConfig, DungeonConfig, onRewardsGranted }
local ModeSelectUI, TowerUI, EliteBuffUI, RunTeamPanel, BattleUI, BattleController, DungeonMapUI, ShopUI
local towerRun        -- latest tower run snapshot (nil = no active run)
local dungeonRun       -- latest dungeon run snapshot (nil = no active run)
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

local function playSound(name)
	if deps.SoundManager then deps.SoundManager:Play(name) end
end

local function describeRewards(rewards)
	local lines = {}
	if rewards and rewards.xp then
		local levelUps = {}
		for idStr, rep in pairs(rewards.xp) do
			if rep.leveledUp then
				local card = deps.CardDatabase:GetById(tonumber(idStr))
				table.insert(levelUps, (card and card.name or idStr) .. " -> Lv" .. rep.level)
			end
		end
		if #levelUps > 0 then
			table.insert(lines, "Level up: " .. table.concat(levelUps, ", "))
		end
	end
	if rewards and rewards.gold and rewards.gold > 0 then
		table.insert(lines, "Gold earned: " .. rewards.gold)
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

-- ── Tower flow ────────────────────────────────────────────────────────────────

local function refreshTowerPanel()
	TowerUI:Update(towerRun)
	RunTeamPanel:Update(towerRun)
end

local function handleTowerBuffChoices()
	local run = towerRun
	if not run or run.state ~= "PickingBuff" then return end
	local teamIds = {}
	for _, id in ipairs(run.team) do
		if id then table.insert(teamIds, id) end
	end
	EliteBuffUI:Show(run.pendingBuffChoices, teamIds, function(choiceIndex, targetCardId)
		local res = invoke(deps.remotes.towerPickBuff, choiceIndex, targetCardId)
		if res and res.success then
			towerRun = res.run
			playSound("buff_pick")
			refreshTowerPanel()
		end
	end)
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
						handleTowerBuffChoices()
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
	handleTowerBuffChoices()
end

local function abandonTower()
	invoke(deps.remotes.towerAbandon)
	towerRun = nil
	TowerUI:Hide()
	RunTeamPanel:Hide()
	ModeSelectUI:Show(DungeonController:_modeInfo())
end

-- ── Dungeon flow ──────────────────────────────────────────────────────────────

local function refreshDungeonPanel()
	DungeonMapUI:Render(dungeonRun)
	RunTeamPanel:Update(dungeonRun)
end

local function handleDungeonBuffChoices()
	local run = dungeonRun
	if not run or run.state ~= "PickingBuff" then return end
	local teamIds = {}
	for _, id in ipairs(run.team) do
		if id then table.insert(teamIds, id) end
	end
	EliteBuffUI:Show(run.pendingBuffChoices, teamIds, function(choiceIndex, targetCardId)
		local res = invoke(deps.remotes.dungeonPickBuff, choiceIndex, targetCardId)
		if res and res.success then
			dungeonRun = res.run
			playSound("buff_pick")
			refreshDungeonPanel()
		end
	end)
end

local function chooseNode(nodeId)
	if busy or not dungeonRun then return end
	busy = true
	playSound("node_select")

	task.spawn(function()
		local res = invoke(deps.remotes.dungeonChooseNode, nodeId)
		if not res or not res.success then
			if res then warn("[Dungeon]", res.error) end
			busy = false
			return
		end

		if res.nodeType == "Rest" then
			dungeonRun = res.run
			playSound("rest_heal")
			refreshDungeonPanel()
			busy = false
			return
		end

		if res.nodeType == "Shop" then
			dungeonRun = res.run
			DungeonMapUI:Hide()
			ShopUI:Show(res.shop, dungeonRun)
			busy = false
			return
		end

		-- Mob / Elite / Boss: play the battle.
		DungeonMapUI:Hide()
		local label = res.nodeType == "Boss" and "DUNGEON — BOSS"
			or (res.nodeType == "Elite" and "DUNGEON — ELITE" or "DUNGEON")
		BattleController:Play(res.battle, label)

		local lines = describeRewards(res.rewards)
		if res.victory then
			dungeonRun = res.run
			table.insert(lines, 1, res.nodeType .. " defeated!")
			if res.complete then
				BattleUI:ShowResult({
					victory = true,
					title = "DUNGEON CLEARED",
					lines = lines,
					buttons = {
						{ text = "CLOSE", color = Color3.fromRGB(70, 170, 90), cb = function()
							BattleUI:Hide()
							RunTeamPanel:Hide()
							dungeonRun = nil
							ModeSelectUI:Show(DungeonController:_modeInfo())
						end },
					},
				})
			else
				BattleUI:ShowResult({
					victory = true,
					title = "VICTORY",
					lines = lines,
					buttons = {
						{ text = "CONTINUE", color = Color3.fromRGB(70, 170, 90), cb = function()
							BattleUI:Hide()
							refreshDungeonPanel()
							DungeonMapUI:Show()
							handleDungeonBuffChoices()
						end },
					},
				})
			end
		else
			local deepest = res.deepestRow or (dungeonRun and dungeonRun.deepestRow) or 0
			dungeonRun = nil
			BattleUI:ShowResult({
				victory = false,
				title = "DEFEATED",
				lines = { "You fell at row " .. deepest },
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
	end)
end

local function shopBuyItem(offerIndex, targetCardId)
	local res = invoke(deps.remotes.dungeonBuyItem, offerIndex, targetCardId)
	if res and res.success then
		dungeonRun = res.run
		playSound("shop_buy")
		ShopUI:Show(res.shop, dungeonRun)
		RunTeamPanel:Update(dungeonRun)
	elseif res then
		warn("[Dungeon shop]", res.error)
	end
end

local function shopBuyService(serviceId, targetCardId)
	local res = invoke(deps.remotes.dungeonBuyService, serviceId, targetCardId)
	if res and res.success then
		dungeonRun = res.run
		playSound("shop_buy")
		ShopUI:UpdateGold(res.gold)
		RunTeamPanel:Update(dungeonRun)
	elseif res then
		warn("[Dungeon shop]", res.error)
	end
end

local function shopReroll()
	local res = invoke(deps.remotes.dungeonReroll)
	if res and res.success then
		dungeonRun = res.run
		ShopUI:Show(res.shop, dungeonRun)
	elseif res then
		warn("[Dungeon shop]", res.error)
	end
end

local function shopLeave()
	ShopUI:Hide()
	refreshDungeonPanel()
	DungeonMapUI:Show()
	handleDungeonBuffChoices()
end

local function openDungeon()
	ModeSelectUI:Hide()
	local state = invoke(deps.remotes.dungeonGetState)
	if state then
		dungeonRun = state
	else
		local res = invoke(deps.remotes.dungeonStart)
		if not res or not res.success then
			if res then warn("[Dungeon]", res.error) end
			ModeSelectUI:Show(DungeonController:_modeInfo())
			return
		end
		dungeonRun = res.run
	end
	refreshDungeonPanel()
	RunTeamPanel:Show()
	DungeonMapUI:Show()
	handleDungeonBuffChoices()
end

local function abandonDungeon()
	invoke(deps.remotes.dungeonAbandon)
	dungeonRun = nil
	DungeonMapUI:Hide()
	RunTeamPanel:Hide()
	ModeSelectUI:Show(DungeonController:_modeInfo())
end

-- ── Debug (Studio-only) ───────────────────────────────────────────────────────

-- One-click test shortcut: seeds a competent team and drops straight into a
-- fresh dungeon run, abandoning any run already in progress.
function DungeonController:DebugQuickStart()
	local setup = invoke(deps.remotes.debugQuickSetup)
	if not setup or not setup.success then
		warn("[Debug] QuickSetup failed:", setup and setup.error)
		return
	end
	if invoke(deps.remotes.towerGetState) then invoke(deps.remotes.towerAbandon) end
	if invoke(deps.remotes.dungeonGetState) then invoke(deps.remotes.dungeonAbandon) end
	openDungeon()
end

-- ── Public API ────────────────────────────────────────────────────────────────

function DungeonController:_modeInfo()
	local full = invoke(deps.remotes.getInventory)
	local best = full and full.tower and full.tower.bestFloor or 0
	return {
		towerBest = best,
		towerActive = invoke(deps.remotes.towerGetState) ~= nil,
		dungeonActive = invoke(deps.remotes.dungeonGetState) ~= nil,
		dungeonReady = true,
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
	DungeonMapUI = uiModules.DungeonMapUI
	ShopUI = uiModules.ShopUI

	BattleUI:Init(screenGui, deps.CardDatabase, deps.RarityConfig, deps.SoundManager)
	BattleController:Init(BattleUI, deps.CombatConfig)
	RunTeamPanel:Init(screenGui, deps.CardDatabase)
	EliteBuffUI:Init(screenGui, deps.DungeonConfig, deps.CardDatabase)
	TowerUI:Init(screenGui, deps.TowerConfig, {
		onFight = fightFloor,
		onAbandon = abandonTower,
	})
	DungeonMapUI:Init(screenGui, {
		onNodeClick = chooseNode,
		onAbandon = abandonDungeon,
	})
	ShopUI:Init(screenGui, deps.DungeonConfig, deps.CardDatabase, {
		onBuyItem = shopBuyItem,
		onBuyService = shopBuyService,
		onReroll = shopReroll,
		onLeave = shopLeave,
	})
	ModeSelectUI:Init(screenGui, {
		onDungeon = openDungeon,
		onTower = openTower,
	})
end

function DungeonController:Toggle()
	if BattleController:IsPlaying() then return end
	if ModeSelectUI:GetPanel().Visible or TowerUI:GetPanel().Visible or DungeonMapUI:GetPanel().Visible then
		self:Hide()
		return
	end
	-- Resume straight into whichever run is live.
	local tState = invoke(deps.remotes.towerGetState)
	if tState then
		towerRun = tState
		refreshTowerPanel()
		RunTeamPanel:Show()
		TowerUI:Show()
		handleTowerBuffChoices()
		return
	end
	local dState = invoke(deps.remotes.dungeonGetState)
	if dState then
		dungeonRun = dState
		refreshDungeonPanel()
		RunTeamPanel:Show()
		DungeonMapUI:Show()
		handleDungeonBuffChoices()
		return
	end
	ModeSelectUI:Show(self:_modeInfo())
end

function DungeonController:Hide()
	if BattleController:IsPlaying() then return end
	ModeSelectUI:Hide()
	TowerUI:Hide()
	DungeonMapUI:Hide()
	ShopUI:Hide()
	BattleUI:Hide()
end

return DungeonController
