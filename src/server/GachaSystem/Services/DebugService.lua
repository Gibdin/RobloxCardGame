-- Studio-only test shortcut: grants a competent 5-card team (one Tank, two
-- DPS, two Support, biased toward Rare/Epic so fights are winnable but not
-- trivial) so a tester can jump straight into combat without grinding packs.
-- Every entry point checks RunService:IsStudio() so this is inert on a
-- published server even if a client somehow calls the remote.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CardDatabase = require(ReplicatedStorage:WaitForChild("GachaSystem"):WaitForChild("CardDatabase"))

local InventoryService = require(script.Parent.InventoryService)

local DebugService = {}

local PREFERRED_RARITIES = { Rare = true, Epic = true }

local function pickForRole(role, rng, excludeIds)
	local preferred, fallback = {}, {}
	for _, card in ipairs(CardDatabase:GetAll()) do
		if card.role == role and not excludeIds[card.id] then
			table.insert(fallback, card)
			if PREFERRED_RARITIES[card.rarity] then
				table.insert(preferred, card)
			end
		end
	end
	local pool = #preferred > 0 and preferred or fallback
	if #pool == 0 then return nil end
	return pool[rng:NextInteger(1, #pool)]
end

function DebugService:QuickSetup(userId)
	if not RunService:IsStudio() then
		return { success = false, error = "Debug tools are Studio-only." }
	end

	local rng = Random.new()
	local roles = { "Tank", "DPS", "DPS", "Support", "Support" }
	local ids = {}
	local excludeIds = {}
	for _, role in ipairs(roles) do
		local card = pickForRole(role, rng, excludeIds)
		if card then
			excludeIds[card.id] = true
			InventoryService:AddCard(userId, card.id)
			table.insert(ids, card.id)
		end
	end

	InventoryService:SetTeam(userId, ids)
	InventoryService:AddPack(userId, "StandardPack", 5)
	InventoryService:AddPack(userId, "RarePack", 2)
	InventoryService:AddGems(userId, 1000)  -- lets testers exercise Gem spends without real products configured

	local names = {}
	for _, id in ipairs(ids) do
		table.insert(names, CardDatabase:GetById(id).name)
	end
	return { success = true, team = ids, names = names, gems = InventoryService:GetGems(userId) }
end

return DebugService
