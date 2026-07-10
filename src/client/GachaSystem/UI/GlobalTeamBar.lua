local TweenService = game:GetService("TweenService")
local UIS          = game:GetService("UserInputService")
local Players      = game:GetService("Players")
local GlobalTeamBar = {}

local BAR_H    = 96
local SLOT_W   = 130
local SLOT_H   = 72
local GAP      = 6
local TOTAL_W  = 5 * SLOT_W + 4 * GAP
local BAR_W    = TOTAL_W + 28
local BOTTOM_GAP = 10
local DRAG_THRESH = 6
local SLOT_ORDER  = {5, 4, 3, 2, 1}

local RBORDER = {
	Common=Color3.fromRGB(130,130,130), Uncommon=Color3.fromRGB(80,200,80),
	Rare=Color3.fromRGB(80,130,255),    Epic=Color3.fromRGB(160,60,220),
	Legendary=Color3.fromRGB(255,165,0),Mythic=Color3.fromRGB(255,50,50),
	God=Color3.fromRGB(255,215,0),      Secret=Color3.fromRGB(160,0,35),
}
local RARTBG = {
	Common=Color3.fromRGB(30,30,32),   Uncommon=Color3.fromRGB(12,30,12),
	Rare=Color3.fromRGB(8,14,38),      Epic=Color3.fromRGB(20,6,36),
	Legendary=Color3.fromRGB(32,20,4), Mythic=Color3.fromRGB(34,6,6),
	God=Color3.fromRGB(26,22,2),       Secret=Color3.fromRGB(6,0,12),
}
local ROLE_COLOR = {
	Tank=Color3.fromRGB(60,130,220), DPS=Color3.fromRGB(220,60,60), Support=Color3.fromRGB(60,200,120),
}

local cardDb, rfSetTeam, roleConf
local team = {false,false,false,false,false}
local teamSlotFrames = {}
local saveDebounce = nil
local onChangedCb = nil
local onSlotClickedCb = nil
local onSynergyHoverCb = nil
local onSynergyClickCb = nil
local isDragging = false
local dragCard = nil
local dragGhost = nil
local dragFromSlot = nil
local dragStartPos = nil
local mouse
local bar
local synergyBar
local trackerTooltip

-- ── tracker tooltip ───────────────────────────────────────────────────────────
local function buildTrackerTooltip(gui)
	trackerTooltip = Instance.new("Frame")
	trackerTooltip.Name = "TrackerSynergyTooltip"
	trackerTooltip.AnchorPoint = Vector2.new(1, 1)
	trackerTooltip.Size = UDim2.new(0, 0, 0, 0)
	trackerTooltip.AutomaticSize = Enum.AutomaticSize.XY
	trackerTooltip.BackgroundColor3 = Color3.fromRGB(8, 8, 16)
	trackerTooltip.BackgroundTransparency = 0.06
	trackerTooltip.BorderSizePixel = 0
	trackerTooltip.ZIndex = 50
	trackerTooltip.Visible = false
	trackerTooltip.Parent = gui
	local uc = Instance.new("UICorner"); uc.CornerRadius = UDim.new(0,10); uc.Parent = trackerTooltip
	local us = Instance.new("UIStroke"); us.Color = Color3.fromRGB(50,50,80); us.Thickness = 1
	us.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; us.Parent = trackerTooltip
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0,8); pad.PaddingBottom = UDim.new(0,8)
	pad.PaddingLeft = UDim.new(0,8); pad.PaddingRight = UDim.new(0,8)
	pad.Parent = trackerTooltip
	local inner = Instance.new("Frame"); inner.Name = "Inner"
	inner.Size = UDim2.new(0, 0, 0, 0); inner.AutomaticSize = Enum.AutomaticSize.XY
	inner.BackgroundTransparency = 1; inner.ZIndex = 51; inner.Parent = trackerTooltip
	local il = Instance.new("UIListLayout")
	il.Padding = UDim.new(0,6); il.SortOrder = Enum.SortOrder.LayoutOrder
	il.FillDirection = Enum.FillDirection.Vertical; il.Parent = inner
end

local function hideTrackerTooltip()
	if trackerTooltip then trackerTooltip.Visible = false end
end

local function showTrackerTooltip(synName, pill)
	if not trackerTooltip or not roleConf then return end
	local def = roleConf.Synergies[synName]; if not def then return end
	local inner = trackerTooltip:FindFirstChild("Inner"); if not inner then return end
	for _, ch in ipairs(inner:GetChildren()) do
		if not ch:IsA("UIListLayout") then ch:Destroy() end
	end
	local sc = def.color or Color3.fromRGB(100,100,180)
	local hdr = Instance.new("TextLabel")
	hdr.Size = UDim2.new(0,0,0,16); hdr.AutomaticSize = Enum.AutomaticSize.X
	hdr.BackgroundTransparency = 1; hdr.Text = synName
	hdr.TextColor3 = sc; hdr.TextScaled = false; hdr.TextSize = 11
	hdr.Font = Enum.Font.GothamBold; hdr.TextXAlignment = Enum.TextXAlignment.Left
	hdr.LayoutOrder = 0; hdr.ZIndex = 52; hdr.Parent = inner
	local tilesFrame = Instance.new("Frame"); tilesFrame.Name = "Tiles"
	tilesFrame.Size = UDim2.new(0,0,0,68); tilesFrame.AutomaticSize = Enum.AutomaticSize.X
	tilesFrame.BackgroundTransparency = 1; tilesFrame.LayoutOrder = 1; tilesFrame.ZIndex = 52
	tilesFrame.Parent = inner
	local tl = Instance.new("UIListLayout")
	tl.FillDirection = Enum.FillDirection.Horizontal; tl.Padding = UDim.new(0,4)
	tl.SortOrder = Enum.SortOrder.LayoutOrder; tl.Parent = tilesFrame
	local members = cardDb and cardDb:GetBySeries(synName) or {}
	for idx, mc in ipairs(members) do
		local tile = Instance.new("Frame")
		tile.Size = UDim2.new(0,54,0,68)
		tile.BackgroundColor3 = RARTBG[mc.rarity] or Color3.fromRGB(20,20,28)
		tile.BorderSizePixel = 0; tile.ZIndex = 53; tile.LayoutOrder = idx; tile.Parent = tilesFrame
		local tc = Instance.new("UICorner"); tc.CornerRadius = UDim.new(0,6); tc.Parent = tile
		local ts = Instance.new("UIStroke")
		ts.Color = RBORDER[mc.rarity] or Color3.fromRGB(60,60,80)
		ts.Thickness = 1.5; ts.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; ts.Parent = tile
		local rb = Instance.new("Frame"); rb.Size = UDim2.new(0,28,0,12)
		rb.Position = UDim2.new(1,-30,0,3)
		rb.BackgroundColor3 = ROLE_COLOR[mc.role] or Color3.fromRGB(80,80,80)
		rb.BorderSizePixel = 0; rb.ZIndex = 55; rb.Parent = tile
		local rbc = Instance.new("UICorner"); rbc.CornerRadius = UDim.new(0,3); rbc.Parent = rb
		local rbl = Instance.new("TextLabel"); rbl.Size = UDim2.new(1,0,1,0)
		rbl.BackgroundTransparency = 1; rbl.Text = (mc.role or "?"):sub(1,3):upper()
		rbl.TextColor3 = Color3.new(1,1,1); rbl.TextScaled = false; rbl.TextSize = 7
		rbl.Font = Enum.Font.GothamBold; rbl.TextXAlignment = Enum.TextXAlignment.Center
		rbl.ZIndex = 56; rbl.Parent = rb
		local nb = Instance.new("Frame"); nb.Size = UDim2.new(1,0,0,18)
		nb.Position = UDim2.new(0,0,1,-18)
		nb.BackgroundColor3 = Color3.fromRGB(0,0,0); nb.BackgroundTransparency = 0.2
		nb.BorderSizePixel = 0; nb.ZIndex = 54; nb.Parent = tile
		local nl = Instance.new("TextLabel"); nl.Size = UDim2.new(1,-4,1,0)
		nl.Position = UDim2.new(0,2,0,0); nl.BackgroundTransparency = 1
		nl.Text = mc.name; nl.TextColor3 = Color3.fromRGB(230,230,250)
		nl.TextScaled = false; nl.TextSize = 8
		nl.TextTruncate = Enum.TextTruncate.AtEnd
		nl.Font = Enum.Font.Gotham; nl.TextXAlignment = Enum.TextXAlignment.Center
		nl.ZIndex = 55; nl.Parent = nb
		for i=1,5 do
			if team[i]==mc.id then
				local ov = Instance.new("Frame"); ov.Size = UDim2.new(1,0,1,0)
				ov.BackgroundColor3 = sc; ov.BackgroundTransparency = 0.55
				ov.BorderSizePixel = 0; ov.ZIndex = 57; ov.Parent = tile
				local ovc = Instance.new("UICorner"); ovc.CornerRadius = UDim.new(0,6); ovc.Parent = ov
				break
			end
		end
	end
	local ap = pill.AbsolutePosition; local asz = pill.AbsoluteSize
	trackerTooltip.AnchorPoint = Vector2.new(0, 1)
	trackerTooltip.Position = UDim2.new(0, ap.X - 8, 0, ap.Y + asz.Y)
	trackerTooltip.Visible = true
end

-- ── synergy tracker ───────────────────────────────────────────────────────────
local function buildSynergyBar(gui)
	synergyBar = Instance.new("Frame")
	synergyBar.Name = "SynergyTracker"
	synergyBar.AnchorPoint = Vector2.new(0, 1)
	synergyBar.Size = UDim2.new(0, 34, 0, 0)
	synergyBar.AutomaticSize = Enum.AutomaticSize.Y
	synergyBar.Position = UDim2.new(0.5, math.floor(BAR_W/2) + 8, 1, -(BOTTOM_GAP + 4))
	synergyBar.BackgroundTransparency = 1
	synergyBar.BorderSizePixel = 0
	synergyBar.ZIndex = 24
	synergyBar.Parent = gui
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 3)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.FillDirection = Enum.FillDirection.Vertical
	list.Parent = synergyBar
	buildTrackerTooltip(gui)
end

local function updateSynergies()
	if not synergyBar or not roleConf then return end
	for _, ch in ipairs(synergyBar:GetChildren()) do
		if ch:IsA("Frame") then ch:Destroy() end
	end
	local counts = {}
	for i = 1, 5 do
		local cid = team[i]
		if cid and cid ~= false then
			local card = cardDb:GetById(cid)
			if card then
				for _, syn in ipairs(card.series or {}) do
					counts[syn] = (counts[syn] or 0) + 1
				end
			end
		end
	end
	local entries = {}
	for synName, count in pairs(counts) do
		local def = roleConf.Synergies[synName]
		if def then
			local activeTier = 0
			local nextThreshCount = nil
			for _, thresh in ipairs(def.thresholds) do
				if count >= thresh.count then
					activeTier = thresh.count
				else
					if not nextThreshCount then nextThreshCount = thresh.count end
				end
			end
			table.insert(entries, {
				name=synName, count=count, def=def,
				activeTier=activeTier, nextThresh=nextThreshCount,
				isActive=activeTier > 0,
			})
		end
	end
	if #entries == 0 then return end
	table.sort(entries, function(a, b)
		if a.isActive ~= b.isActive then return a.isActive end
		if a.count ~= b.count then return a.count > b.count end
		return a.name < b.name
	end)
	for idx, e in ipairs(entries) do
		local sc = e.def.color or Color3.fromRGB(100,100,180)
		-- compact circle icon pill
		local pill = Instance.new("Frame")
		pill.Name = "Pill_"..e.name
		pill.Size = UDim2.new(1, 0, 0, 34)
		pill.BackgroundColor3 = e.isActive
			and Color3.new(sc.R*0.25, sc.G*0.25, sc.B*0.25)
			or  Color3.fromRGB(12, 12, 20)
		pill.BackgroundTransparency = 0.08
		pill.BorderSizePixel = 0
		pill.LayoutOrder = idx
		pill.ZIndex = 25
		pill.Parent = synergyBar
		local pc = Instance.new("UICorner"); pc.CornerRadius = UDim.new(1, 0); pc.Parent = pill
		local ps = Instance.new("UIStroke")
		ps.Color = e.isActive and sc or Color3.fromRGB(36,36,56)
		ps.Thickness = e.isActive and 2 or 1
		ps.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; ps.Parent = pill
		local bnum = Instance.new("TextLabel")
		bnum.Size = UDim2.new(1,0,1,0); bnum.BackgroundTransparency = 1
		bnum.Text = tostring(e.count)
		bnum.TextColor3 = e.isActive and Color3.new(1,1,1)
			or Color3.new(sc.R*0.6+0.1, sc.G*0.6+0.1, sc.B*0.6+0.1)
		bnum.TextScaled = false; bnum.TextSize = 13
		bnum.Font = Enum.Font.GothamBold; bnum.TextXAlignment = Enum.TextXAlignment.Center
		bnum.ZIndex = 28; bnum.Parent = pill
		local capturedName = e.name
		local capturedPill = pill
		pill.MouseEnter:Connect(function()
			showTrackerTooltip(capturedName, capturedPill)
			if onSynergyHoverCb then onSynergyHoverCb(capturedName) end
		end)
		pill.MouseLeave:Connect(function()
			hideTrackerTooltip()
			if onSynergyHoverCb then onSynergyHoverCb(nil) end
		end)
		pill.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
			hideTrackerTooltip()
			if onSynergyHoverCb then onSynergyHoverCb(nil) end
			if onSynergyClickCb then onSynergyClickCb(capturedName) end
		end)
	end
end

-- ── team bar internals ────────────────────────────────────────────────────────
local function isInTeamLocal(cardId)
	for i=1,5 do if team[i]==cardId then return i end end; return nil
end

local function scheduleSave()
	if saveDebounce then task.cancel(saveDebounce) end
	saveDebounce=task.delay(1.5,function() pcall(function() rfSetTeam:InvokeServer(team) end) end)
end

local function notifyChanged()
	updateSynergies()
	if onChangedCb then onChangedCb() end
end

local function updateBar()
	for i=1,5 do
		local sf=teamSlotFrames[i]; if not sf then continue end
		local eg=sf:FindFirstChild("EmptyGrp"); local og=sf:FindFirstChild("OccGrp")
		local ss=sf:FindFirstChildOfClass("UIStroke")
		local cardId=team[i]
		local card=(cardId and cardId~=false) and cardDb:GetById(cardId) or nil
		if card then
			if eg then eg.Visible=false end; if og then og.Visible=true end
			local rc=RBORDER[card.rarity] or Color3.fromRGB(60,60,80)
			if ss then ss.Color=rc end
			if og then
				local art=og:FindFirstChild("Art")
				if art then
					art.BackgroundColor3=RARTBG[card.rarity] or Color3.fromRGB(20,20,28)
					local rb=art:FindFirstChild("RoleBadge")
					if rb then rb.BackgroundColor3=ROLE_COLOR[card.role] or Color3.fromRGB(80,80,80)
						local rbl=rb:FindFirstChild("L")
						if rbl then rbl.Text=(card.role or "?"):sub(1,3):upper() end
					end
				end
				local cnl=og:FindFirstChild("CardName",true); if cnl then cnl.Text=card.name end
			end
		else
			if eg then eg.Visible=true end; if og then og.Visible=false end
			if ss then ss.Color=(i==1) and Color3.fromRGB(80,60,10) or Color3.fromRGB(38,38,58) end
		end
	end
end

local function createGhost(card)
	if dragGhost then dragGhost:Destroy(); dragGhost=nil end
	local g=Instance.new("Frame"); g.Name="DragGhost"
	g.Size=UDim2.new(0,SLOT_W,0,SLOT_H); g.BackgroundColor3=RARTBG[card.rarity] or Color3.fromRGB(20,20,28)
	g.BorderSizePixel=0; g.ZIndex=100; g.BackgroundTransparency=0.15; g.Parent=bar
	local cr=Instance.new("UICorner"); cr.CornerRadius=UDim.new(0,8); cr.Parent=g
	local st=Instance.new("UIStroke"); st.Color=RBORDER[card.rarity] or Color3.fromRGB(130,130,130)
	st.Thickness=2; st.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; st.Parent=g
	local nl=Instance.new("TextLabel"); nl.Size=UDim2.new(1,-4,1,-4); nl.Position=UDim2.new(0,2,0,2)
	nl.BackgroundTransparency=1; nl.Text=card.name; nl.TextColor3=Color3.new(1,1,1)
	nl.TextScaled=true; nl.TextWrapped=true; nl.Font=Enum.Font.GothamBold; nl.ZIndex=101; nl.Parent=g
	dragGhost=g
end

local function endInternalDrag(targetSlot)
	isDragging=false
	if dragGhost then dragGhost:Destroy(); dragGhost=nil end
	for _,sf in ipairs(teamSlotFrames) do
		TweenService:Create(sf,TweenInfo.new(0.1),{BackgroundColor3=Color3.fromRGB(16,16,26)}):Play()
	end
	if targetSlot and dragCard and dragFromSlot then
		local tmp=team[dragFromSlot]; team[dragFromSlot]=team[targetSlot]; team[targetSlot]=tmp
		updateBar(); scheduleSave(); notifyChanged()
	end
	dragCard=nil; dragFromSlot=nil; dragStartPos=nil
end

local function connectInternalDrag()
	UIS.InputChanged:Connect(function(input)
		if input.UserInputType~=Enum.UserInputType.MouseMovement then return end
		if dragStartPos and dragCard and not isDragging then
			local dx=mouse.X-dragStartPos.X; local dy=mouse.Y-dragStartPos.Y
			if math.sqrt(dx*dx+dy*dy)>DRAG_THRESH then isDragging=true; createGhost(dragCard) end
		end
		if isDragging then
			if dragGhost then dragGhost.Position=UDim2.new(0,mouse.X-SLOT_W/2,0,mouse.Y-SLOT_H/2) end
			for _,sf in ipairs(teamSlotFrames) do
				local ap=sf.AbsolutePosition; local asz=sf.AbsoluteSize
				local over=mouse.X>=ap.X and mouse.X<=ap.X+asz.X and mouse.Y>=ap.Y and mouse.Y<=ap.Y+asz.Y
				TweenService:Create(sf,TweenInfo.new(0.06),{BackgroundColor3=over and Color3.fromRGB(20,44,20) or Color3.fromRGB(16,16,26)}):Play()
			end
		end
	end)
	UIS.InputEnded:Connect(function(input)
		if input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
		if isDragging and dragFromSlot then
			local target=nil
			for i,sf in ipairs(teamSlotFrames) do
				local ap=sf.AbsolutePosition; local asz=sf.AbsoluteSize
				if mouse.X>=ap.X and mouse.X<=ap.X+asz.X and mouse.Y>=ap.Y and mouse.Y<=ap.Y+asz.Y then target=i; break end
			end
			endInternalDrag(target)
		elseif not isDragging then
			dragCard=nil; dragStartPos=nil; dragFromSlot=nil
		end
	end)
end

local function buildSlot(parent, slotIdx, xOff)
	local front=slotIdx==1
	local sf=Instance.new("TextButton"); sf.Name="TS"..slotIdx; sf.Text=""; sf.AutoButtonColor=false
	sf.Size=UDim2.new(0,SLOT_W,0,SLOT_H); sf.Position=UDim2.new(0.5,xOff,0,math.floor((BAR_H-SLOT_H)/2))
	sf.BackgroundColor3=Color3.fromRGB(16,16,26); sf.BorderSizePixel=0; sf.ZIndex=26; sf.Parent=parent
	local uc=Instance.new("UICorner"); uc.CornerRadius=UDim.new(0,8); uc.Parent=sf
	local ss=Instance.new("UIStroke")
	ss.Color=front and Color3.fromRGB(80,60,10) or Color3.fromRGB(38,38,58)
	ss.Thickness=front and 2 or 1; ss.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; ss.Parent=sf
	local nb=Instance.new("Frame"); nb.Size=UDim2.new(0,18,0,18); nb.Position=UDim2.new(0,4,0,4)
	nb.BackgroundColor3=front and Color3.fromRGB(50,36,0) or Color3.fromRGB(18,18,36)
	nb.BorderSizePixel=0; nb.ZIndex=29; nb.Parent=sf
	local nbc=Instance.new("UICorner"); nbc.CornerRadius=UDim.new(0,4); nbc.Parent=nb
	local nbl=Instance.new("TextLabel"); nbl.Size=UDim2.new(1,0,1,0); nbl.BackgroundTransparency=1
	nbl.Text=front and "\226\152\133" or tostring(slotIdx)
	nbl.TextColor3=front and Color3.fromRGB(255,200,30) or Color3.fromRGB(80,110,200)
	nbl.TextScaled=true; nbl.Font=Enum.Font.GothamBold
	nbl.TextXAlignment=Enum.TextXAlignment.Center; nbl.ZIndex=30; nbl.Parent=nb
	local eg=Instance.new("Frame"); eg.Name="EmptyGrp"
	eg.Size=UDim2.new(1,0,1,0); eg.BackgroundTransparency=1
	eg.BorderSizePixel=0; eg.ZIndex=27; eg.Parent=sf
	local epl=Instance.new("TextLabel"); epl.Size=UDim2.new(1,0,1,0)
	epl.BackgroundTransparency=1; epl.Text="+"
	epl.TextColor3=Color3.fromRGB(85,95,155); epl.TextScaled=true
	epl.Font=Enum.Font.GothamBold; epl.ZIndex=28; epl.Parent=eg
	local og=Instance.new("Frame"); og.Name="OccGrp"
	og.Size=UDim2.new(1,0,1,0); og.BackgroundTransparency=1
	og.BorderSizePixel=0; og.ZIndex=27; og.Visible=false; og.Parent=sf
	local art=Instance.new("Frame"); art.Name="Art"
	art.Size=UDim2.new(1,-2,1,-2); art.Position=UDim2.new(0,1,0,1)
	art.BackgroundColor3=Color3.fromRGB(20,20,28); art.BorderSizePixel=0; art.ZIndex=28; art.Parent=og
	local ac=Instance.new("UICorner"); ac.CornerRadius=UDim.new(0,7); ac.Parent=art
	local rb=Instance.new("Frame"); rb.Name="RoleBadge"
	rb.Size=UDim2.new(0,28,0,13); rb.Position=UDim2.new(1,-30,0,4)
	rb.BackgroundColor3=Color3.fromRGB(60,130,220); rb.BorderSizePixel=0; rb.ZIndex=30; rb.Parent=art
	local rbc=Instance.new("UICorner"); rbc.CornerRadius=UDim.new(0,3); rbc.Parent=rb
	local rbl=Instance.new("TextLabel"); rbl.Name="L"; rbl.Size=UDim2.new(1,0,1,0); rbl.BackgroundTransparency=1
	rbl.Text=""; rbl.TextColor3=Color3.new(1,1,1); rbl.TextScaled=false; rbl.TextSize=7
	rbl.Font=Enum.Font.GothamBold; rbl.TextXAlignment=Enum.TextXAlignment.Center; rbl.ZIndex=31; rbl.Parent=rb
	local nameOv=Instance.new("Frame")
	nameOv.Size=UDim2.new(1,0,0,24); nameOv.Position=UDim2.new(0,0,1,-24)
	nameOv.BackgroundColor3=Color3.fromRGB(0,0,0); nameOv.BackgroundTransparency=0.15
	nameOv.BorderSizePixel=0; nameOv.ZIndex=29; nameOv.Parent=og
	local cnl=Instance.new("TextLabel"); cnl.Name="CardName"
	cnl.Size=UDim2.new(1,-6,1,0); cnl.Position=UDim2.new(0,3,0,0)
	cnl.BackgroundTransparency=1; cnl.Text=""
	cnl.TextColor3=Color3.fromRGB(235,235,250); cnl.TextScaled=false; cnl.TextSize=12
	cnl.TextTruncate=Enum.TextTruncate.AtEnd; cnl.Font=Enum.Font.GothamBold
	cnl.TextXAlignment=Enum.TextXAlignment.Center; cnl.ZIndex=30; cnl.Parent=nameOv
	sf.MouseButton1Click:Connect(function()
		if isDragging then return end
		if onSlotClickedCb then onSlotClickedCb(slotIdx) end
	end)
	sf.MouseEnter:Connect(function()
		if not isDragging then
			TweenService:Create(sf, TweenInfo.new(0.10), {BackgroundColor3=Color3.fromRGB(30,30,48)}):Play()
		end
	end)
	sf.MouseLeave:Connect(function()
		if not isDragging then
			TweenService:Create(sf, TweenInfo.new(0.10), {BackgroundColor3=Color3.fromRGB(16,16,26)}):Play()
		end
	end)
	sf.InputBegan:Connect(function(input)
		if input.UserInputType==Enum.UserInputType.MouseButton1 then
			local cid=team[slotIdx]
			if cid and cid~=false then
				local c=cardDb:GetById(cid)
				if c then dragCard=c; dragFromSlot=slotIdx; dragStartPos=Vector2.new(mouse.X,mouse.Y) end
			end
		end
	end)
	teamSlotFrames[slotIdx]=sf
end

local function buildBarFrame(gui)
	bar=Instance.new("Frame"); bar.Name="GlobalTeamBar"
	bar.Size=UDim2.new(0,BAR_W,0,BAR_H)
	bar.Position=UDim2.new(0.5,-math.floor(BAR_W/2),1,-BAR_H-BOTTOM_GAP)
	bar.BackgroundColor3=Color3.fromRGB(8,8,16); bar.BackgroundTransparency=0.08
	bar.BorderSizePixel=0; bar.ZIndex=25; bar.Parent=gui
	local bc=Instance.new("UICorner"); bc.CornerRadius=UDim.new(0,14); bc.Parent=bar
	local bs=Instance.new("UIStroke"); bs.Color=Color3.fromRGB(44,44,70); bs.Thickness=1
	bs.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; bs.Parent=bar
	for col,slotIdx in ipairs(SLOT_ORDER) do
		local xOff=-math.floor(TOTAL_W/2)+(col-1)*(SLOT_W+GAP)
		buildSlot(bar,slotIdx,xOff)
	end
	mouse=Players.LocalPlayer:GetMouse()
	connectInternalDrag()
end

-- ── public API ────────────────────────────────────────────────────────────────
function GlobalTeamBar:Init(gui, db, rfST, rc)
	cardDb=db; rfSetTeam=rfST; roleConf=rc
	buildBarFrame(gui)
	buildSynergyBar(gui)
end
function GlobalTeamBar:LoadTeam(teamData)
	if teamData then
		for i=1,5 do local v=teamData[i]; team[i]=(type(v)=="number" and v>0) and v or false end
	end
	updateBar()
	updateSynergies()
end
function GlobalTeamBar:GetTeam() return team end
function GlobalTeamBar:IsInTeam(cardId) return isInTeamLocal(cardId) end
function GlobalTeamBar:EquipToSlot(slotIdx, card)
	if not card then return end
	for i=1,5 do if team[i]==card.id then team[i]=false end end
	team[slotIdx]=card.id; updateBar(); scheduleSave(); notifyChanged()
end
function GlobalTeamBar:GetSlotFrames() return teamSlotFrames end
function GlobalTeamBar:RemoveFromSlot(slotIdx)
	team[slotIdx]=false; updateBar(); scheduleSave(); notifyChanged()
end
function GlobalTeamBar:SetOnChanged(cb) onChangedCb=cb end
function GlobalTeamBar:SetOnSlotClicked(cb) onSlotClickedCb=cb end
function GlobalTeamBar:SetOnSynergyHover(cb) onSynergyHoverCb=cb end
function GlobalTeamBar:SetOnSynergyClick(cb) onSynergyClickCb=cb end

return GlobalTeamBar
