-- Generates the branching dungeon map: Slay-the-Spire-style rows of nodes with
-- a single boss node at the top. Fully seeded and deterministic.
--
-- Edge algorithm (interval-overlap, no crossings): node i of m in a row
-- connects to node j of n in the next row iff intervals [(i-1)/m, i/m] and
-- [(j-1)/n, j/n] overlap. Both rows' intervals tile [0,1] with no gaps, so
-- every node in either row is guaranteed at least one edge — full
-- reachability from row 1 to the boss falls out for free, no extra checks
-- needed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DungeonConfig = require(ReplicatedStorage:WaitForChild("GachaSystem"):WaitForChild("DungeonConfig"))

local MapGenerator = {}

local function weightedPick(rng, weights)
	local total = 0
	local keys = {}
	for k, w in pairs(weights) do
		total = total + w
		table.insert(keys, k)
	end
	table.sort(keys) -- deterministic iteration order regardless of hash order
	local roll = rng:NextNumber() * total
	local acc = 0
	for _, k in ipairs(keys) do
		acc = acc + weights[k]
		if roll <= acc then return k end
	end
	return keys[#keys]
end

local function pickNodeCount(rng, defs)
	local weights = {}
	for _, def in ipairs(defs) do weights[tostring(def.n)] = def.w end
	return tonumber(weightedPick(rng, weights))
end

local function connectRows(rowA, rowB)
	local m, n = #rowA, #rowB
	for i, nodeA in ipairs(rowA) do
		local loA, hiA = (i - 1) / m, i / m
		for j, nodeB in ipairs(rowB) do
			local loB, hiB = (j - 1) / n, j / n
			if loA < hiB and loB < hiA then
				table.insert(nodeA.edges, nodeB.id)
			end
		end
	end
end

local function ensureMinimum(rows, maxRow, nodeType, minCount, placedCount, rng)
	if placedCount >= minCount then return end
	local conf = DungeonConfig.Map
	local candidates = {}
	for r = 2, maxRow do
		if nodeType ~= "Elite" or r >= conf.EliteMinRow then
			for _, node in ipairs(rows[r]) do
				if node.type == "Mob" then table.insert(candidates, node) end
			end
		end
	end
	local need = minCount - placedCount
	for i = 1, math.min(need, #candidates) do
		local idx = rng:NextInteger(i, #candidates)
		candidates[i], candidates[idx] = candidates[idx], candidates[i]
		candidates[i].type = nodeType
	end
end

-- Returns { rows = { [r] = {node...} }, bossId, maxRow }.
-- node = { id, type, row, col, edges = {id...}, visited = false }.
function MapGenerator.Generate(seed)
	local rng = Random.new(seed)
	local conf = DungeonConfig.Map
	local rows = {}
	local placed = { Elite = 0, Shop = 0, Rest = 0 }

	for r = 1, conf.Rows do
		local count = pickNodeCount(rng, conf.NodesPerRow)
		local rowNodes = {}
		for col = 1, count do
			local nodeType
			if r == 1 then
				nodeType = "Mob"
			else
				local weights = {}
				for t, w in pairs(conf.TypeWeights) do
					if conf.EnabledTypes[t] and (t ~= "Elite" or r >= conf.EliteMinRow) then
						weights[t] = w
					end
				end
				if next(weights) == nil then weights = { Mob = 1 } end
				nodeType = weightedPick(rng, weights)
			end
			table.insert(rowNodes, {
				id = "r" .. r .. "n" .. col, type = nodeType, row = r, col = col,
				edges = {}, visited = false,
			})
			if placed[nodeType] then placed[nodeType] = placed[nodeType] + 1 end
		end
		rows[r] = rowNodes
	end

	ensureMinimum(rows, conf.Rows, "Shop", conf.EnabledTypes.Shop and conf.MinShops or 0, placed.Shop, rng)
	ensureMinimum(rows, conf.Rows, "Elite", conf.EnabledTypes.Elite and conf.MinElites or 0, placed.Elite, rng)
	ensureMinimum(rows, conf.Rows, "Rest", conf.EnabledTypes.Rest and conf.MinRests or 0, placed.Rest, rng)

	local bossRow = conf.Rows + 1
	local boss = { id = "boss", type = "Boss", row = bossRow, col = 1, edges = {}, visited = false }
	rows[bossRow] = { boss }

	for r = 1, conf.Rows - 1 do
		connectRows(rows[r], rows[r + 1])
	end
	for _, node in ipairs(rows[conf.Rows]) do
		table.insert(node.edges, boss.id)
	end

	return { rows = rows, bossId = boss.id, maxRow = bossRow }
end

-- Flat id -> node lookup for O(1) access during play.
function MapGenerator.Index(map)
	local byId = {}
	for _, row in pairs(map.rows) do
		for _, node in ipairs(row) do
			byId[node.id] = node
		end
	end
	return byId
end

return MapGenerator
