-- Main client controller for the gacha pack-opening experience.
-- Sequence per pack open:
--   1. Player clicks "Open" on a pack in the list panel.
--   2. Pack rip frame shown — player clicks 3 times (or presses Skip).
--   3. Roll request sent to server; flash sequence plays.
--   4. Final reveal shown with rarity effects.
--   5. Player dismisses; pack list refreshes.
--   6. If Auto Roll is ON, repeat with the next available pack.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for server remotes
local remotes   = ReplicatedStorage:WaitForChild("GachaRemotes", 30)
if not remotes then
	error("[GachaSystem] GachaRemotes folder not found — is Main.server.lua running?")
end

local rfOpenPack     = remotes:WaitForChild("OpenPack")
local rfGetPacks     = remotes:WaitForChild("GetPacks")
local rfGetPityInfo  = remotes:WaitForChild("GetPityInfo")
local rfGetInventory = remotes:WaitForChild("GetInventory")
local rfGetTeam      = remotes:WaitForChild("GetTeam")
local rfSetTeam      = remotes:WaitForChild("SetTeam")

-- Shared modules
local gachaShared  = ReplicatedStorage:WaitForChild("GachaSystem")
local RarityConfig = require(gachaShared:WaitForChild("RarityConfig"))
local RoleConfig   = require(gachaShared:WaitForChild("RoleConfig"))
local CardDatabase = require(gachaShared:WaitForChild("CardDatabase"))

-- VFX modules
local vfxFolder    = script.Parent.VFX
local VFXConfig    = require(vfxFolder.VFXConfig)
local SoundManager = require(vfxFolder.SoundManager)

-- UI modules
local uiFolder      = script.Parent.UI
local PackOpeningUI = require(uiFolder.PackOpeningUI)
local FlashSequence = require(uiFolder.FlashSequence)
local CardReveal    = require(uiFolder.CardReveal)
local SideMenuUI    = require(uiFolder.SideMenuUI)
local InventoryUI   = require(uiFolder.InventoryUI)
local GlobalTeamBar = require(uiFolder.GlobalTeamBar)
local TeamBuilderUI = require(uiFolder.TeamBuilderUI)

-- Root ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name            = "GachaSystemUI"
screenGui.ResetOnSpawn    = false
screenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset  = true
screenGui.Parent          = playerGui

-- Init VFX
SoundManager:Init(VFXConfig)

-- Init UI modules
PackOpeningUI:Init(screenGui, RarityConfig, VFXConfig, SoundManager)
FlashSequence:Init(screenGui, RarityConfig, CardDatabase, VFXConfig, SoundManager)
CardReveal:Init(screenGui, RarityConfig, VFXConfig, SoundManager)
GlobalTeamBar:Init(screenGui, CardDatabase, rfSetTeam, RoleConfig)
InventoryUI:Init(screenGui, CardDatabase, RarityConfig, RoleConfig, rfGetInventory, GlobalTeamBar)
TeamBuilderUI:Init(screenGui, CardDatabase, RarityConfig, RoleConfig, rfGetInventory, rfGetTeam, rfSetTeam)
GlobalTeamBar:SetOnSynergyHover(function(synName)
	if synName then InventoryUI:HighlightSynergy(synName)
	else InventoryUI:ClearHighlight() end
end)
GlobalTeamBar:SetOnSynergyClick(function(synName)
	InventoryUI:NavigateToSynergy(synName)
end)

-- State
local isOpening       = false
local autoRollEnabled = false

local function refreshPacks()
	local ok, packs = pcall(function() return rfGetPacks:InvokeServer() end)
	if ok and packs then
		PackOpeningUI:UpdatePackList(packs)
	end
end

local function openPack(packType)
	if isOpening then return end
	isOpening = true

	-- First pack: player manually rips. Auto Roll button appears after this.
	local skipped = PackOpeningUI:ShowPackRip(packType)
	PackOpeningUI:HidePackRip()
	PackOpeningUI:ShowAutoRollButton()

	local currentPackType = packType
	local currentSkipped  = skipped

	while true do
		-- Fire server roll request
		local response
		task.spawn(function()
			local ok, res = pcall(function()
				return rfOpenPack:InvokeServer(currentPackType)
			end)
			response = ok and res or { success = false, error = tostring(res) }
		end)

		local waited = 0
		while not response and waited < 10 do
			task.wait(0.05); waited = waited + 0.05
		end

		if not response or not response.success then
			warn("[GachaSystem] OpenPack failed:", response and response.error or "timeout")
			break
		end

		local result = response.result

		-- Flash: skip only if player pressed Skip on the manual rip; auto roll always plays flash
		if not currentSkipped then
			FlashSequence:Play(result.card, result.rarity)
		end

		CardReveal:Show(result)

		-- Watcher: auto-dismiss as soon as auto roll is on and card has shown >= 1.5s.
		-- Handles the case where the player enables auto roll mid-reveal.
		local revealTime = tick()
		local watchActive = true
		task.spawn(function()
			while watchActive do
				task.wait(0.1)
				if not watchActive then break end
				if autoRollEnabled then
					local remaining = math.max(0, 1.5 - (tick() - revealTime))
					if remaining > 0 then task.wait(remaining) end
					if watchActive and autoRollEnabled then
						CardReveal:TriggerDismiss()
					end
					break
				end
			end
		end)

		CardReveal:WaitForDismiss()
		watchActive = false

		if not autoRollEnabled then break end

		-- Find the next pack to open
		task.wait(0.5)
		local ok2, packs = pcall(function() return rfGetPacks:InvokeServer() end)
		local nextPack = nil
		if ok2 and packs then
			for pt, count in pairs(packs) do
				if count > 0 then nextPack = pt; break end
			end
		end

		if not nextPack then break end

		currentPackType = nextPack
		currentSkipped  = false  -- auto roll never skips the flash
	end

	isOpening = false
	autoRollEnabled = false
	PackOpeningUI:HideAutoRollButton()
	refreshPacks()
end

PackOpeningUI:SetOpenCallback(function(packType) openPack(packType) end)

PackOpeningUI:SetAutoRollCallback(function(enabled)
	autoRollEnabled = enabled
end)

-- Stub panels (placeholders until Inventory/Team/Settings are built)
local function makeStubPanel(title)
	local bg=Instance.new("Frame"); bg.Name=title.."Panel"
	bg.Size=UDim2.new(0,480,0,360); bg.Position=UDim2.new(0.5,-240,0.5,-180)
	bg.BackgroundColor3=Color3.fromRGB(14,14,24); bg.BackgroundTransparency=0.05
	bg.BorderSizePixel=0; bg.ZIndex=20; bg.Visible=false; bg.Parent=screenGui
	local bc=Instance.new("UICorner"); bc.CornerRadius=UDim.new(0,12); bc.Parent=bg
	local bs=Instance.new("UIStroke"); bs.Thickness=1; bs.Color=Color3.fromRGB(40,40,60); bs.Parent=bg
	local titleLbl=Instance.new("TextLabel")
	titleLbl.Size=UDim2.new(1,-60,0,44); titleLbl.Position=UDim2.new(0,16,0,10)
	titleLbl.BackgroundTransparency=1; titleLbl.Text=title; titleLbl.TextColor3=Color3.fromRGB(210,210,240)
	titleLbl.TextXAlignment=Enum.TextXAlignment.Left; titleLbl.TextScaled=true
	titleLbl.Font=Enum.Font.GothamBold; titleLbl.ZIndex=21; titleLbl.Parent=bg
	local closeBtn=Instance.new("TextButton")
	closeBtn.Size=UDim2.new(0,36,0,36); closeBtn.Position=UDim2.new(1,-46,0,12)
	closeBtn.BackgroundColor3=Color3.fromRGB(80,30,30); closeBtn.BorderSizePixel=0
	closeBtn.Text="X"; closeBtn.TextColor3=Color3.new(1,1,1); closeBtn.TextScaled=true
	closeBtn.Font=Enum.Font.GothamBold; closeBtn.ZIndex=21; closeBtn.Parent=bg
	local cc=Instance.new("UICorner"); cc.CornerRadius=UDim.new(0,6); cc.Parent=closeBtn
	local stub=Instance.new("TextLabel")
	stub.Size=UDim2.new(0.8,0,0,36); stub.Position=UDim2.new(0.1,0,0.5,-18)
	stub.BackgroundTransparency=1; stub.Text=title.." — Coming Soon"
	stub.TextColor3=Color3.fromRGB(70,70,90); stub.TextScaled=true
	stub.Font=Enum.Font.Gotham; stub.ZIndex=21; stub.Parent=bg
	closeBtn.MouseButton1Click:Connect(function() bg.Visible=false end)
	return bg
end
local settingsPanel = makeStubPanel("SETTINGS")

-- Side menu
local function closeAllExcept(except)
	if except~="packs"     then PackOpeningUI:ClosePacksDrawer() end
	if except~="inventory" then InventoryUI:Hide() end
	if except~="team"      then TeamBuilderUI:Hide() end
	if except~="settings"  then settingsPanel.Visible=false end
end
SideMenuUI:Init(screenGui,{
	packs=function() closeAllExcept("packs"); PackOpeningUI:TogglePacksDrawer() end,
	inventory=function()
		if InventoryUI:GetPanel().Visible then InventoryUI:Hide()
		else closeAllExcept("inventory"); InventoryUI:Show() end
	end,
	team=function()
		if TeamBuilderUI:GetPanel().Visible then TeamBuilderUI:Hide()
		else closeAllExcept("team"); TeamBuilderUI:Show() end
	end,
	settings=function() closeAllExcept("settings"); settingsPanel.Visible=not settingsPanel.Visible end,
})

refreshPacks()
