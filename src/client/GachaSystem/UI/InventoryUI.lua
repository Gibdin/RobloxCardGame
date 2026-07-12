local TweenService = game:GetService("TweenService")
local UIS          = game:GetService("UserInputService")
local Players      = game:GetService("Players")
local InventoryUI  = {}

local PW,PH=860,600; local TOPBAR_H=48; local BODY_Y=TOPBAR_H+1; local BODY_H=PH-BODY_Y-1
local GRID_W=430; local DET_X=GRID_W+1; local DET_W=PW-DET_X
local TW,TH=78,102; local TGAP=6; local MAX_CAP=500; local DRAG_THRESH=6

local RBORDER={Common=Color3.fromRGB(130,130,130),Uncommon=Color3.fromRGB(80,200,80),Rare=Color3.fromRGB(80,130,255),Epic=Color3.fromRGB(160,60,220),Legendary=Color3.fromRGB(255,165,0),Mythic=Color3.fromRGB(255,50,50),God=Color3.fromRGB(255,215,0),Secret=Color3.fromRGB(160,0,35)}
local RARTBG={Common=Color3.fromRGB(30,30,32),Uncommon=Color3.fromRGB(12,30,12),Rare=Color3.fromRGB(8,14,38),Epic=Color3.fromRGB(20,6,36),Legendary=Color3.fromRGB(32,20,4),Mythic=Color3.fromRGB(34,6,6),God=Color3.fromRGB(26,22,2),Secret=Color3.fromRGB(6,0,12)}
local RTEXT={Common=Color3.fromRGB(190,190,190),Uncommon=Color3.fromRGB(90,220,90),Rare=Color3.fromRGB(100,150,255),Epic=Color3.fromRGB(190,90,250),Legendary=Color3.fromRGB(255,185,20),Mythic=Color3.fromRGB(255,80,80),God=Color3.fromRGB(255,225,20),Secret=Color3.fromRGB(210,30,65)}
local ROLE_COLOR={Tank=Color3.fromRGB(60,130,220),DPS=Color3.fromRGB(220,60,60),Support=Color3.fromRGB(60,200,120)}
local ROLE_SHORT={Tank="TANK",DPS="DPS",Support="SUP"}
local PASSIVE_COLOR={Drain=Color3.fromRGB(60,130,220),Rage=Color3.fromRGB(220,60,60),Executioner=Color3.fromRGB(220,130,40),Medic=Color3.fromRGB(60,200,120),Battery=Color3.fromRGB(60,180,200)}
local PASSIVE_DESC_COLOR={Drain=Color3.fromRGB(120,170,255),Rage=Color3.fromRGB(255,130,130),Executioner=Color3.fromRGB(255,190,110),Medic=Color3.fromRGB(120,240,160),Battery=Color3.fromRGB(100,230,245)}
local ACTIVE_DESC_COLOR=Color3.fromRGB(195,160,255)
local RARITY_CYCLE={"All","Common","Uncommon","Rare","Epic","Legendary","Mythic","God","Secret"}
local SORT_CYCLE={"Rarity","Name","Awakening"}
local ROLE_CYCLE={"All","Tank","DPS","Support"}

local cardDb,rarityConf,roleConf,rfGetInventory,globalTeamBar
local allCards,filteredCards={},{}
local filterRarity,filterIdx="All",1
local filterRole,roleIdx="All",1
local sortMode,sortIdx="Rarity",1
local searchText=""
local selectedCard=nil
local highlightedSyn=nil
local synRefScroll=nil
local synNameToCard={}
local isDragging=false
local dragCard,dragGhost,dragStartPos=nil,nil,nil
local mouse

local panel,gridScroll,detailArea
local capLbl,filterBtn,sortBtn,roleFilterBtn,searchBox
local detailEmpty,detailContent,detailScroll
local dArtBg,dName,dRarity,dRoleBadge
local dATK,dHP
local dMPPips={}
local dPassiveChip,dCardPassiveName,dCardPassiveDesc
local dActiveName,dActiveDesc
local dSynContainer
local equBtn
local synergyTooltip,synergyTooltipInner
local selStroke,selOrigCol
local unitsBody,synergiesBody,tabUnitsBtn,tabSynBtn

local function F(p,sz,pos,col,z) local f=Instance.new("Frame");f.Size=sz;f.Position=pos;f.BackgroundColor3=col or Color3.fromRGB(18,18,28);f.BorderSizePixel=0;f.ZIndex=z or 21;f.Parent=p;return f end
local function L(p,text,sz,pos,col,font,xa,z) local l=Instance.new("TextLabel");l.Size=sz;l.Position=pos;l.BackgroundTransparency=1;l.Text=text;l.TextColor3=col or Color3.fromRGB(210,210,240);l.TextScaled=true;l.Font=font or Enum.Font.GothamBold;l.TextXAlignment=xa or Enum.TextXAlignment.Left;l.ZIndex=z or 22;l.Parent=p;return l end
local function B(p,text,sz,pos,bg,z) local b=Instance.new("TextButton");b.Size=sz;b.Position=pos;b.BackgroundColor3=bg or Color3.fromRGB(36,36,54);b.BorderSizePixel=0;b.Text=text;b.TextColor3=Color3.new(1,1,1);b.TextScaled=true;b.Font=Enum.Font.GothamBold;b.AutoButtonColor=false;b.ZIndex=z or 22;b.Parent=p;Instance.new("UICorner").CornerRadius=UDim.new(0,6);local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,6);c.Parent=b;return b end
local function C(p,r) local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,r or 8);c.Parent=p;return c end
local function S(p,col,t) local s=Instance.new("UIStroke");s.Color=col or Color3.fromRGB(40,40,62);s.Thickness=t or 1;s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;s.Parent=p;return s end
local function hoverBtn(b,norm,hot) b.MouseEnter:Connect(function() TweenService:Create(b,TweenInfo.new(0.08),{BackgroundColor3=hot}):Play() end);b.MouseLeave:Connect(function() TweenService:Create(b,TweenInfo.new(0.08),{BackgroundColor3=norm}):Play() end) end

local rebuildGrid
local function updateGridEquippedIndicators()
	if not gridScroll then return end
	for _,ch in ipairs(gridScroll:GetChildren()) do
		if ch:IsA("TextButton") then
			local idStr=ch.Name:match("^T(%d+)$"); if idStr then
				local ind=ch:FindFirstChild("TmInd"); if ind then
					local sn=globalTeamBar:IsInTeam(tonumber(idStr))
					ind.Visible=sn~=nil; local lbl=ind:FindFirstChild("Lbl"); if lbl and sn then lbl.Text="S"..sn end
				end
			end
		end
	end
end

local function createGhost(card)
	if dragGhost then dragGhost:Destroy();dragGhost=nil end
	local g=Instance.new("Frame");g.Name="DragGhost";g.Size=UDim2.new(0,TW,0,TH);g.BackgroundColor3=RARTBG[card.rarity] or Color3.fromRGB(20,20,28);g.BorderSizePixel=0;g.ZIndex=100;g.BackgroundTransparency=0.15;g.Parent=panel;C(g,8);S(g,RBORDER[card.rarity] or Color3.fromRGB(130,130,130),2)
	local nl=Instance.new("TextLabel");nl.Size=UDim2.new(1,-4,1,-4);nl.Position=UDim2.new(0,2,0,2);nl.BackgroundTransparency=1;nl.Text=card.name;nl.TextColor3=Color3.new(1,1,1);nl.TextScaled=true;nl.TextWrapped=true;nl.Font=Enum.Font.GothamBold;nl.ZIndex=101;nl.Parent=g;dragGhost=g
end
local function endDrag(targetSlot)
	isDragging=false
	if dragGhost then dragGhost:Destroy();dragGhost=nil end
	local sf=globalTeamBar:GetSlotFrames()
	for _,f in ipairs(sf) do TweenService:Create(f,TweenInfo.new(0.1),{BackgroundColor3=Color3.fromRGB(16,16,26)}):Play() end
	if targetSlot and dragCard then globalTeamBar:EquipToSlot(targetSlot,dragCard); if selectedCard and selectedCard.id==dragCard.id then showCard(selectedCard) end end
	dragCard=nil;dragStartPos=nil
end
local function connectDragHandlers()
	UIS.InputChanged:Connect(function(input)
		if input.UserInputType~=Enum.UserInputType.MouseMovement then return end
		if not panel or not panel.Visible then return end
		if dragStartPos and dragCard and not isDragging then
			local dx=mouse.X-dragStartPos.X;local dy=mouse.Y-dragStartPos.Y
			if math.sqrt(dx*dx+dy*dy)>DRAG_THRESH then isDragging=true;createGhost(dragCard) end
		end
		if isDragging then
			if dragGhost then dragGhost.Position=UDim2.new(0,mouse.X-TW/2,0,mouse.Y-TH/2) end
			local sf=globalTeamBar:GetSlotFrames()
			for _,f in ipairs(sf) do local ap=f.AbsolutePosition;local asz=f.AbsoluteSize;local over=mouse.X>=ap.X and mouse.X<=ap.X+asz.X and mouse.Y>=ap.Y and mouse.Y<=ap.Y+asz.Y;TweenService:Create(f,TweenInfo.new(0.06),{BackgroundColor3=over and Color3.fromRGB(25,48,25) or Color3.fromRGB(16,16,26)}):Play() end
		end
	end)
	UIS.InputEnded:Connect(function(input)
		if input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
		if not panel or not panel.Visible then return end
		if isDragging then
			local target=nil;local sf=globalTeamBar:GetSlotFrames()
			for i,f in ipairs(sf) do local ap=f.AbsolutePosition;local asz=f.AbsoluteSize;if mouse.X>=ap.X and mouse.X<=ap.X+asz.X and mouse.Y>=ap.Y and mouse.Y<=ap.Y+asz.Y then target=i;break end end
			endDrag(target)
		else dragCard=nil;dragStartPos=nil end
	end)
end

local function applyFilter()
	filteredCards={}
	local ls=searchText:lower()
	for _,c in ipairs(allCards) do
		local nameOk=ls=="" or c.name:lower():find(ls,1,true)
		local rarOk=filterRarity=="All" or c.rarity==filterRarity
		local roleOk=filterRole=="All" or c.role==filterRole
		if nameOk and rarOk and roleOk then table.insert(filteredCards,c) end
	end
	if sortMode=="Name" then table.sort(filteredCards,function(a,b) return a.name<b.name end)
	elseif sortMode=="Awakening" then table.sort(filteredCards,function(a,b) if a.awakening~=b.awakening then return a.awakening>b.awakening end;return a.name<b.name end)
	else table.sort(filteredCards,function(a,b) local ao=rarityConf:GetOrder(a.rarity);local bo=rarityConf:GetOrder(b.rarity);if ao~=bo then return ao>bo end;return a.name<b.name end) end
	rebuildGrid()
end
local function cycleFilter() filterIdx=(filterIdx%#RARITY_CYCLE)+1;filterRarity=RARITY_CYCLE[filterIdx];filterBtn.Text="Rarity: "..filterRarity;if filterRarity=="All" then filterBtn.BackgroundColor3=Color3.fromRGB(18,14,36) else local bc=RBORDER[filterRarity];filterBtn.BackgroundColor3=Color3.new(bc.R*0.20,bc.G*0.20,bc.B*0.20) end;applyFilter() end
local function cycleRole() roleIdx=(roleIdx%#ROLE_CYCLE)+1;filterRole=ROLE_CYCLE[roleIdx];roleFilterBtn.Text="Role: "..filterRole;if filterRole=="All" then roleFilterBtn.BackgroundColor3=Color3.fromRGB(18,14,36) else local rc=ROLE_COLOR[filterRole];roleFilterBtn.BackgroundColor3=Color3.new(rc.R*0.20,rc.G*0.20,rc.B*0.20) end;applyFilter() end
local function cycleSort() sortIdx=(sortIdx%#SORT_CYCLE)+1;sortMode=SORT_CYCLE[sortIdx];sortBtn.Text="Sort: "..sortMode;applyFilter() end

-- ── synergy tooltip ───────────────────────────────────────────────────────────
local function applyHighlight(synName)
	if not gridScroll then return end
	highlightedSyn=synName
	local memberIds={}
	if cardDb and synName then
		for _,mc in ipairs(cardDb:GetBySeries(synName)) do memberIds[mc.id]=true end
	end
	for _,ch in ipairs(gridScroll:GetChildren()) do
		if ch:IsA("TextButton") then
			local idStr=ch.Name:match("^T(%d+)$"); local id=idStr and tonumber(idStr)
			local ov=ch:FindFirstChild("SynHL")
			if id and not memberIds[id] then
				if not ov then
					ov=Instance.new("Frame"); ov.Name="SynHL"
					ov.Size=UDim2.new(1,0,1,0); ov.BackgroundColor3=Color3.new(0,0,0)
					ov.BackgroundTransparency=1; ov.BorderSizePixel=0; ov.ZIndex=ch.ZIndex+5; ov.Parent=ch
					local oc=Instance.new("UICorner"); oc.CornerRadius=UDim.new(0,8); oc.Parent=ov
				end
				TweenService:Create(ov, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{BackgroundTransparency=0.45}):Play()
			else
				if ov then
					TweenService:Create(ov, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{BackgroundTransparency=1}):Play()
					task.delay(0.2, function() if ov.Parent then ov:Destroy() end end)
				end
			end
		end
	end
end
local function clearHighlight()
	highlightedSyn=nil
	if not gridScroll then return end
	for _,ch in ipairs(gridScroll:GetChildren()) do
		if ch:IsA("TextButton") then
			local ov=ch:FindFirstChild("SynHL")
			if ov then
				TweenService:Create(ov, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{BackgroundTransparency=1}):Play()
				task.delay(0.2, function() if ov.Parent then ov:Destroy() end end)
			end
		end
	end
end
local function hideSynergyTooltip()
	if synergyTooltip then synergyTooltip.Visible=false end
	if synergyTooltipInner then
		for _,ch in ipairs(synergyTooltipInner:GetChildren()) do
			if not ch:IsA("UIListLayout") and not ch:IsA("UIPadding") then ch:Destroy() end
		end
	end
end

local function showSynergyTooltipFor(synName,row)
	local synDef=roleConf and roleConf.Synergies[synName]; if not synDef then return end
	hideSynergyTooltip()
	local sc=synDef.color or Color3.fromRGB(100,100,180)
	local lo=0

	local hdr=Instance.new("TextLabel");hdr.Size=UDim2.new(1,0,0,16);hdr.BackgroundTransparency=1
	hdr.Text=synName;hdr.TextColor3=sc;hdr.TextScaled=false;hdr.TextSize=11;hdr.Font=Enum.Font.GothamBold
	hdr.TextXAlignment=Enum.TextXAlignment.Left;hdr.LayoutOrder=lo;lo=lo+1;hdr.ZIndex=52;hdr.Parent=synergyTooltipInner

	-- Member card tiles
	local members=cardDb and cardDb:GetBySeries(synName) or {}
	if #members>0 then
		local cols=4; local cellW=54; local cellH=68; local cellGap=4
		local rows=math.ceil(#members/cols)
		local tilesH=rows*(cellH+cellGap)-cellGap
		local tilesF=Instance.new("Frame");tilesF.Size=UDim2.new(1,0,0,tilesH);tilesF.BackgroundTransparency=1;tilesF.BorderSizePixel=0;tilesF.LayoutOrder=lo;lo=lo+1;tilesF.ZIndex=51;tilesF.Parent=synergyTooltipInner
		local gl=Instance.new("UIGridLayout");gl.CellSize=UDim2.new(0,cellW,0,cellH);gl.CellPadding=UDim2.new(0,cellGap,0,cellGap);gl.SortOrder=Enum.SortOrder.LayoutOrder;gl.Parent=tilesF
		for mi,mc in ipairs(members) do
			local tile=Instance.new("Frame");tile.BackgroundColor3=RARTBG[mc.rarity] or Color3.fromRGB(20,20,28);tile.BorderSizePixel=0;tile.LayoutOrder=mi;tile.ZIndex=52;tile.Parent=tilesF;C(tile,5);S(tile,RBORDER[mc.rarity] or Color3.fromRGB(100,100,140),1)
			local rc2=ROLE_COLOR[mc.role] or Color3.fromRGB(80,80,100)
			local rb=Instance.new("Frame");rb.Size=UDim2.new(0,24,0,11);rb.Position=UDim2.new(0,3,0,3);rb.BackgroundColor3=rc2;rb.BackgroundTransparency=0.1;rb.BorderSizePixel=0;rb.ZIndex=54;rb.Parent=tile;C(rb,2)
			local rbl=Instance.new("TextLabel");rbl.Size=UDim2.new(1,0,1,0);rbl.BackgroundTransparency=1;rbl.Text=ROLE_SHORT[mc.role] or "?";rbl.TextColor3=Color3.new(1,1,1);rbl.TextScaled=false;rbl.TextSize=6;rbl.Font=Enum.Font.GothamBold;rbl.ZIndex=55;rbl.Parent=rb
			-- role strip bottom
			local rs2=Instance.new("Frame");rs2.Size=UDim2.new(1,0,0,3);rs2.Position=UDim2.new(0,0,1,-3);rs2.BackgroundColor3=rc2;rs2.BorderSizePixel=0;rs2.ZIndex=54;rs2.Parent=tile
			local nh=Instance.new("Frame");nh.Size=UDim2.new(1,0,0,16);nh.Position=UDim2.new(0,0,1,-19);nh.BackgroundColor3=Color3.fromRGB(0,0,0);nh.BackgroundTransparency=0.3;nh.BorderSizePixel=0;nh.ZIndex=53;nh.Parent=tile;C(nh,5)
			local nl=Instance.new("TextLabel");nl.Size=UDim2.new(1,-2,1,0);nl.Position=UDim2.new(0,1,0,0);nl.BackgroundTransparency=1;nl.Text=mc.name;nl.TextColor3=Color3.fromRGB(220,220,240);nl.TextScaled=false;nl.TextSize=7;nl.TextTruncate=Enum.TextTruncate.AtEnd;nl.Font=Enum.Font.GothamBold;nl.TextXAlignment=Enum.TextXAlignment.Center;nl.ZIndex=54;nl.Parent=nh
		end
	end

	-- Position tooltip beside cursor, to the left of the mouse
	local panelAP=panel.AbsolutePosition
	local mx=mouse.X-panelAP.X
	local my=mouse.Y-panelAP.Y
	local tipW=280
	local tipX=mx-tipW-12
	tipX=math.max(4,math.min(PW-tipW-4,tipX))
	local tipY=my-30
	tipY=math.max(TOPBAR_H+4,math.min(PH-320,tipY))
	synergyTooltip.Position=UDim2.new(0,tipX,0,tipY)
	synergyTooltip.Visible=true
end

-- ── detail show ───────────────────────────────────────────────────────────────
local function showEmpty()
	selectedCard=nil;detailEmpty.Visible=true;detailContent.Visible=false
	hideSynergyTooltip()
	if selStroke then selStroke.Thickness=2;selStroke.Color=selOrigCol;selStroke=nil;selOrigCol=nil end
end

showCard=function(c)
	local full=cardDb:GetById(c.id) or c; selectedCard=c
	local bc=RBORDER[c.rarity] or Color3.fromRGB(130,130,130)
	local ab=RARTBG[c.rarity] or Color3.fromRGB(28,28,28)
	local tc=RTEXT[c.rarity] or Color3.fromRGB(210,210,240)
	local rc=ROLE_COLOR[full.role] or Color3.fromRGB(100,100,140)

	dArtBg.BackgroundColor3=ab
	for _,ch in ipairs(dArtBg:GetChildren()) do if ch:IsA("UIStroke") then ch:Destroy() end end
	S(dArtBg,bc,3)

	if dRoleBadge then dRoleBadge.BackgroundColor3=rc; local lbl=dRoleBadge:FindFirstChild("Lbl"); if lbl then lbl.Text=ROLE_SHORT[full.role] or "?" end end

	dName.Text=c.name; dName.TextColor3=Color3.fromRGB(215,215,240)
	dRarity.Text=c.rarity; dRarity.TextColor3=tc; dRarity.BackgroundColor3=Color3.new(bc.R*0.2,bc.G*0.2,bc.B*0.2)

	dATK.Text=tostring(c.attack); dHP.Text=tostring(c.hp)

	-- MP pips
	local mpCost=math.max(1,math.min(5,c.mp or 2))
	for i=1,5 do
		if dMPPips[i] then
			dMPPips[i].BackgroundColor3=i<=mpCost and Color3.fromRGB(150,80,240) or Color3.fromRGB(30,24,50)
			dMPPips[i].BackgroundTransparency=i<=mpCost and 0 or 0
			for _,ch in ipairs(dMPPips[i]:GetChildren()) do if ch:IsA("UIStroke") then ch.Color=i<=mpCost and Color3.fromRGB(180,110,255) or Color3.fromRGB(45,38,70) end end
		end
	end

	local ptColor=PASSIVE_COLOR[full.passive] or Color3.fromRGB(100,100,180)
	local pdColor=PASSIVE_DESC_COLOR[full.passive] or Color3.fromRGB(180,180,210)
	if dPassiveChip then dPassiveChip.BackgroundColor3=ptColor; local lbl=dPassiveChip:FindFirstChild("Lbl"); if lbl then lbl.Text=(full.passive or "—"):upper() end end
	if dCardPassiveName then dCardPassiveName.Text=full.passive_name or "—" end
	if dCardPassiveDesc then dCardPassiveDesc.Text=full.passive_desc or ""; dCardPassiveDesc.TextColor3=pdColor end

	local act=full.active or {}
	if dActiveName then dActiveName.Text=act.name or "—" end
	if dActiveDesc then dActiveDesc.Text=act.desc or ""; dActiveDesc.TextColor3=ACTIVE_DESC_COLOR end

	local sn=globalTeamBar:IsInTeam(c.id)
	equBtn.Text=sn and ("Remove (S"..sn..")") or "Equip"
	equBtn.BackgroundColor3=sn and Color3.fromRGB(72,18,18) or Color3.fromRGB(28,68,36)
	for _,ch in ipairs(equBtn:GetChildren()) do if ch:IsA("UIStroke") then ch:Destroy() end end
	S(equBtn,sn and Color3.fromRGB(120,30,30) or Color3.fromRGB(40,100,52),1)

	if dSynContainer then
		for _,ch in ipairs(dSynContainer:GetChildren()) do if ch:IsA("Frame") or ch:IsA("TextLabel") then ch:Destroy() end end
		local synSeries=full.series or {}
		if #synSeries==0 then
			local none=Instance.new("TextLabel");none.Size=UDim2.new(1,0,0,16);none.BackgroundTransparency=1
			none.Text="No synergy affiliation";none.TextColor3=Color3.fromRGB(50,50,70);none.TextScaled=false;none.TextSize=10;none.Font=Enum.Font.Gotham;none.TextXAlignment=Enum.TextXAlignment.Left;none.ZIndex=24;none.Parent=dSynContainer
		else
			for si,synName in ipairs(synSeries) do
				local synDef=roleConf and roleConf.Synergies[synName]; if not synDef then continue end
				local synColor=synDef.color or Color3.fromRGB(100,100,180)
				local row=Instance.new("Frame");row.Size=UDim2.new(1,0,0,34);row.BackgroundColor3=Color3.fromRGB(16,16,26);row.BorderSizePixel=0;row.LayoutOrder=si;row.ZIndex=23;row.Parent=dSynContainer;C(row,6)
				S(row,Color3.new(synColor.R*0.3,synColor.G*0.3,synColor.B*0.3),1)
				local strip=Instance.new("Frame");strip.Size=UDim2.new(0,4,1,0);strip.BackgroundColor3=synColor;strip.BorderSizePixel=0;strip.ZIndex=24;strip.Parent=row;C(strip,2)
				local nameLbl=Instance.new("TextLabel");nameLbl.Size=UDim2.new(1,-80,0,14);nameLbl.Position=UDim2.new(0,10,0,4)
				nameLbl.BackgroundTransparency=1;nameLbl.Text=synName;nameLbl.TextColor3=synColor;nameLbl.TextScaled=false;nameLbl.TextSize=11;nameLbl.Font=Enum.Font.GothamBold;nameLbl.TextXAlignment=Enum.TextXAlignment.Left;nameLbl.ZIndex=25;nameLbl.Parent=row
				-- hover hint
				local hint=Instance.new("TextLabel");hint.Size=UDim2.new(0,60,0,12);hint.Position=UDim2.new(1,-66,0,5)
				hint.BackgroundTransparency=1;hint.Text="click for synergy";hint.TextColor3=Color3.fromRGB(60,60,90);hint.TextScaled=false;hint.TextSize=10;hint.Font=Enum.Font.Gotham;hint.TextXAlignment=Enum.TextXAlignment.Right;hint.ZIndex=25;hint.Parent=row
				local pipX=10; local pipY=21
				for _,thresh in ipairs(synDef.thresholds) do
					local pip=Instance.new("Frame");pip.Size=UDim2.new(0,24,0,10);pip.Position=UDim2.new(0,pipX,0,pipY);pip.BackgroundColor3=Color3.fromRGB(24,24,38);pip.BorderSizePixel=0;pip.ZIndex=24;pip.Parent=row;C(pip,3);S(pip,Color3.fromRGB(40,40,60),1)
					local pipLbl=Instance.new("TextLabel");pipLbl.Size=UDim2.new(1,0,1,0);pipLbl.BackgroundTransparency=1;pipLbl.Text=tostring(thresh.count);pipLbl.TextColor3=Color3.fromRGB(100,100,140);pipLbl.TextScaled=false;pipLbl.TextSize=8;pipLbl.Font=Enum.Font.GothamBold;pipLbl.ZIndex=25;pipLbl.Parent=pip
					pip.Name="Pip_"..thresh.count; pipX=pipX+28
				end
				local maxLbl=Instance.new("TextLabel");maxLbl.Size=UDim2.new(0,40,0,10);maxLbl.Position=UDim2.new(1,-46,0,pipY);maxLbl.BackgroundTransparency=1;maxLbl.Text="max "..synDef.maxCount;maxLbl.TextColor3=Color3.fromRGB(40,40,55);maxLbl.TextScaled=false;maxLbl.TextSize=8;maxLbl.Font=Enum.Font.Gotham;maxLbl.TextXAlignment=Enum.TextXAlignment.Right;maxLbl.ZIndex=25;maxLbl.Parent=row
				-- hover
				local capturedSyn=synName; local capturedRow=row
				row.MouseEnter:Connect(function()
					TweenService:Create(row, TweenInfo.new(0.10), {BackgroundColor3=Color3.fromRGB(28,22,48)}):Play()
					showSynergyTooltipFor(capturedSyn,capturedRow); applyHighlight(capturedSyn)
				end)
				row.MouseLeave:Connect(function()
					TweenService:Create(row, TweenInfo.new(0.10), {BackgroundColor3=Color3.fromRGB(16,16,26)}):Play()
					hideSynergyTooltip(); clearHighlight()
				end)
				row.InputBegan:Connect(function(input)
					if input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
					InventoryUI:NavigateToSynergy(capturedSyn)
				end)
			end
		end
	end
	detailEmpty.Visible=false;detailContent.Visible=true
end

local function refreshSynergyPips()
	if not selectedCard or not dSynContainer then return end
	if not detailContent.Visible then return end
	local full=cardDb:GetById(selectedCard.id); if not full then return end
	local teamCounts={}
	local t=globalTeamBar:GetTeam()
	for i=1,5 do local cid=t[i]; if cid and cid~=false then local card=cardDb:GetById(cid); if card then for _,syn in ipairs(card.series or {}) do teamCounts[syn]=(teamCounts[syn] or 0)+1 end end end end
	for _,row in ipairs(dSynContainer:GetChildren()) do
		if not row:IsA("Frame") then continue end
		local synName=nil
		for _,ch in ipairs(row:GetChildren()) do if ch:IsA("TextLabel") and ch.TextXAlignment==Enum.TextXAlignment.Left and ch.TextSize==11 then synName=ch.Text;break end end
		if not synName then continue end
		local synDef=roleConf and roleConf.Synergies[synName]; if not synDef then continue end
		local count=teamCounts[synName] or 0
		for _,thresh in ipairs(synDef.thresholds) do
			local pip=row:FindFirstChild("Pip_"..thresh.count); if pip then
				local active=count>=thresh.count
				pip.BackgroundColor3=active and synDef.color or Color3.fromRGB(24,24,38)
				local lbl=pip:FindFirstChildOfClass("TextLabel"); if lbl then lbl.TextColor3=active and Color3.new(1,1,1) or Color3.fromRGB(100,100,140) end
			end
		end
	end
end

-- ── tile builder ──────────────────────────────────────────────────────────────
local function buildTile(card,order)
	local bc=RBORDER[card.rarity] or Color3.fromRGB(130,130,130); local ab=RARTBG[card.rarity] or Color3.fromRGB(28,28,28); local rc=ROLE_COLOR[card.role] or Color3.fromRGB(80,80,100)
	local t=Instance.new("TextButton");t.Name="T"..card.id;t.Size=UDim2.new(0,TW,0,TH);t.BackgroundColor3=ab;t.BorderSizePixel=0;t.Text="";t.AutoButtonColor=false;t.LayoutOrder=order;t.ZIndex=22;t.Parent=gridScroll
	C(t,8);local ts=S(t,bc,2)
	local rBadge=Instance.new("Frame");rBadge.Size=UDim2.new(0,28,0,13);rBadge.Position=UDim2.new(0,4,0,4);rBadge.BackgroundColor3=rc;rBadge.BackgroundTransparency=0.1;rBadge.BorderSizePixel=0;rBadge.ZIndex=25;rBadge.Parent=t;C(rBadge,3)
	local rbLbl=Instance.new("TextLabel");rbLbl.Size=UDim2.new(1,0,1,0);rbLbl.BackgroundTransparency=1;rbLbl.Text=ROLE_SHORT[card.role] or "?";rbLbl.TextColor3=Color3.new(1,1,1);rbLbl.TextScaled=false;rbLbl.TextSize=7;rbLbl.Font=Enum.Font.GothamBold;rbLbl.ZIndex=26;rbLbl.Parent=rBadge
	local rdot=Instance.new("Frame");rdot.Size=UDim2.new(0,7,0,7);rdot.Position=UDim2.new(1,-10,0,5);rdot.BackgroundColor3=bc;rdot.BorderSizePixel=0;rdot.ZIndex=24;rdot.Parent=t;local rdc=Instance.new("UICorner");rdc.CornerRadius=UDim.new(1,0);rdc.Parent=rdot
	local roleStrip=Instance.new("Frame");roleStrip.Size=UDim2.new(1,0,0,4);roleStrip.Position=UDim2.new(0,0,1,-4);roleStrip.BackgroundColor3=rc;roleStrip.BorderSizePixel=0;roleStrip.ZIndex=25;roleStrip.Parent=t
	local nameBar=Instance.new("Frame");nameBar.Size=UDim2.new(1,0,0,22);nameBar.Position=UDim2.new(0,0,1,-26);nameBar.BackgroundColor3=Color3.fromRGB(0,0,0);nameBar.BackgroundTransparency=0.35;nameBar.BorderSizePixel=0;nameBar.ZIndex=23;nameBar.Parent=t;C(nameBar,8)
	local nl=Instance.new("TextLabel");nl.Size=UDim2.new(1,-4,1,0);nl.Position=UDim2.new(0,2,0,0);nl.BackgroundTransparency=1;nl.Text=card.name;nl.TextColor3=Color3.fromRGB(225,225,242);nl.TextScaled=false;nl.TextSize=9;nl.TextTruncate=Enum.TextTruncate.AtEnd;nl.Font=Enum.Font.GothamBold;nl.TextXAlignment=Enum.TextXAlignment.Center;nl.ZIndex=24;nl.Parent=nameBar
	local ind=Instance.new("Frame");ind.Name="TmInd";ind.Size=UDim2.new(1,0,1,0);ind.BackgroundColor3=Color3.fromRGB(14,46,14);ind.BackgroundTransparency=0.5;ind.BorderSizePixel=0;ind.ZIndex=24;ind.Visible=false;ind.Parent=t;C(ind,8)
	local indLbl=Instance.new("TextLabel");indLbl.Name="Lbl";indLbl.Size=UDim2.new(1,0,1,-22);indLbl.BackgroundTransparency=1;indLbl.Text="S1";indLbl.TextColor3=Color3.fromRGB(90,255,140);indLbl.TextScaled=false;indLbl.TextSize=13;indLbl.Font=Enum.Font.GothamBold;indLbl.TextXAlignment=Enum.TextXAlignment.Center;indLbl.ZIndex=25;indLbl.Parent=ind
	local chk=Instance.new("TextLabel");chk.Size=UDim2.new(0,16,0,16);chk.Position=UDim2.new(0,4,0,4);chk.BackgroundTransparency=1;chk.Text="\226\156\147";chk.TextColor3=Color3.fromRGB(90,255,140);chk.TextScaled=true;chk.Font=Enum.Font.GothamBold;chk.ZIndex=25;chk.Parent=ind
	local sn=globalTeamBar:IsInTeam(card.id);ind.Visible=sn~=nil; if sn then indLbl.Text="S"..sn end
	t.MouseButton1Click:Connect(function() if isDragging then return end; if selStroke then selStroke.Thickness=2;selStroke.Color=selOrigCol end; selStroke=ts;selOrigCol=bc;ts.Thickness=3;ts.Color=Color3.new(1,1,1);showCard(card) end)
	t.InputBegan:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 then dragCard=card;dragStartPos=Vector2.new(mouse.X,mouse.Y) end end)
	t.MouseEnter:Connect(function() TweenService:Create(t,TweenInfo.new(0.1),{BackgroundColor3=Color3.new(math.min(ab.R+0.05,1),math.min(ab.G+0.05,1),math.min(ab.B+0.05,1))}):Play() end)
	t.MouseLeave:Connect(function() TweenService:Create(t,TweenInfo.new(0.1),{BackgroundColor3=ab}):Play() end)
end

rebuildGrid=function()
	for _,ch in ipairs(gridScroll:GetChildren()) do if ch:IsA("TextButton") or ch.Name=="EmptyMsg" then ch:Destroy() end end
	selStroke=nil
	if #filteredCards==0 then
		local msg=Instance.new("TextLabel");msg.Name="EmptyMsg";msg.Size=UDim2.new(1,-16,0,40);msg.BackgroundTransparency=1;msg.Text=#allCards==0 and "Open packs to start your collection!" or "No cards match your filter.";msg.TextColor3=Color3.fromRGB(65,65,95);msg.TextScaled=true;msg.Font=Enum.Font.Gotham;msg.ZIndex=22;msg.Parent=gridScroll;showEmpty();return
	end
	for i,card in ipairs(filteredCards) do buildTile(card,i) end
end

-- ── top bar ───────────────────────────────────────────────────────────────────
local function buildTopBar()
	local tb=F(panel,UDim2.new(1,0,0,TOPBAR_H),UDim2.new(0,0,0,0),Color3.fromRGB(18,12,36),21)
	local grad=Instance.new("UIGradient");grad.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(28,16,52)),ColorSequenceKeypoint.new(0.5,Color3.fromRGB(16,10,32)),ColorSequenceKeypoint.new(1,Color3.fromRGB(10,10,22))});grad.Parent=tb
	local TAB_W=82
	tabUnitsBtn=B(tb,"UNITS",UDim2.new(0,TAB_W,0,28),UDim2.new(0,10,0,10),Color3.fromRGB(36,26,68),22);tabUnitsBtn.TextSize=11;tabUnitsBtn.TextScaled=false
	tabSynBtn=B(tb,"SYNERGIES",UDim2.new(0,TAB_W+12,0,28),UDim2.new(0,TAB_W+16,0,10),Color3.fromRGB(22,16,44),22);tabSynBtn.TextSize=11;tabSynBtn.TextScaled=false
	searchBox=Instance.new("TextBox");searchBox.Size=UDim2.new(0,130,0,26);searchBox.Position=UDim2.new(0,TAB_W*2+24,0,11);searchBox.BackgroundColor3=Color3.fromRGB(16,12,30);searchBox.BorderSizePixel=0;searchBox.Text="";searchBox.PlaceholderText="Search...";searchBox.PlaceholderColor3=Color3.fromRGB(55,50,80);searchBox.TextColor3=Color3.fromRGB(200,200,230);searchBox.TextScaled=false;searchBox.TextSize=12;searchBox.Font=Enum.Font.Gotham;searchBox.ClearTextOnFocus=false;searchBox.ZIndex=22;searchBox.Parent=tb;C(searchBox,5);S(searchBox,Color3.fromRGB(36,28,58),1)
	local sp=Instance.new("UIPadding");sp.PaddingLeft=UDim.new(0,7);sp.PaddingRight=UDim.new(0,7);sp.Parent=searchBox
	searchBox:GetPropertyChangedSignal("Text"):Connect(function() searchText=searchBox.Text;applyFilter() end)
	local FBASE=TAB_W*2+162
	filterBtn=B(tb,"Rarity: All",UDim2.new(0,72,0,26),UDim2.new(0,FBASE,0,11),Color3.fromRGB(18,14,36));S(filterBtn,Color3.fromRGB(36,28,58),1);filterBtn.Font=Enum.Font.Gotham;filterBtn.TextSize=10;filterBtn.TextScaled=false;filterBtn.MouseButton1Click:Connect(cycleFilter)
	hoverBtn(filterBtn, Color3.fromRGB(18,14,36), Color3.fromRGB(30,24,52))
	roleFilterBtn=B(tb,"Role: All",UDim2.new(0,68,0,26),UDim2.new(0,FBASE+76,0,11),Color3.fromRGB(18,14,36));S(roleFilterBtn,Color3.fromRGB(36,28,58),1);roleFilterBtn.Font=Enum.Font.Gotham;roleFilterBtn.TextSize=10;roleFilterBtn.TextScaled=false;roleFilterBtn.MouseButton1Click:Connect(cycleRole)
	hoverBtn(roleFilterBtn, Color3.fromRGB(18,14,36), Color3.fromRGB(30,24,52))
	sortBtn=B(tb,"Sort: Rarity",UDim2.new(0,72,0,26),UDim2.new(0,FBASE+148,0,11),Color3.fromRGB(18,14,36));S(sortBtn,Color3.fromRGB(36,28,58),1);sortBtn.Font=Enum.Font.Gotham;sortBtn.TextSize=10;sortBtn.TextScaled=false;sortBtn.MouseButton1Click:Connect(cycleSort)
	hoverBtn(sortBtn, Color3.fromRGB(18,14,36), Color3.fromRGB(30,24,52))
	capLbl=L(tb,"0/"..MAX_CAP,UDim2.new(0,56,0,26),UDim2.new(0,FBASE+224,0,11),Color3.fromRGB(70,65,105),Enum.Font.Gotham,Enum.TextXAlignment.Left,22);capLbl.TextScaled=false;capLbl.TextSize=11
	local close=B(tb,"\195\151",UDim2.new(0,28,0,28),UDim2.new(1,-38,0,10),Color3.fromRGB(55,18,18),23);close.TextSize=13;close.TextScaled=false;hoverBtn(close,Color3.fromRGB(55,18,18),Color3.fromRGB(88,26,26));close.MouseButton1Click:Connect(function() InventoryUI:Hide() end)
	F(panel,UDim2.new(1,0,0,1),UDim2.new(0,0,0,TOPBAR_H),Color3.fromRGB(28,18,52),21)
end

-- ── grid pane ─────────────────────────────────────────────────────────────────
local function buildGridPane(parent)
	gridScroll=Instance.new("ScrollingFrame");gridScroll.Name="CardGrid";gridScroll.Size=UDim2.new(0,GRID_W,1,0);gridScroll.Position=UDim2.new(0,0,0,0);gridScroll.BackgroundTransparency=1;gridScroll.BorderSizePixel=0;gridScroll.ScrollBarThickness=4;gridScroll.ScrollBarImageColor3=Color3.fromRGB(50,50,80);gridScroll.CanvasSize=UDim2.new(0,0,0,0);gridScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y;gridScroll.ZIndex=21;gridScroll.Parent=parent
	local pad=Instance.new("UIPadding");pad.PaddingTop=UDim.new(0,8);pad.PaddingBottom=UDim.new(0,8);pad.PaddingLeft=UDim.new(0,8);pad.PaddingRight=UDim.new(0,8);pad.Parent=gridScroll
	local grid=Instance.new("UIGridLayout");grid.CellSize=UDim2.new(0,TW,0,TH);grid.CellPadding=UDim2.new(0,TGAP,0,TGAP);grid.SortOrder=Enum.SortOrder.LayoutOrder;grid.FillDirection=Enum.FillDirection.Horizontal;grid.HorizontalAlignment=Enum.HorizontalAlignment.Center;grid.Parent=gridScroll
	local div=Instance.new("Frame");div.Size=UDim2.new(0,1,1,0);div.Position=UDim2.new(0,GRID_W,0,0);div.BackgroundColor3=Color3.fromRGB(36,36,54);div.BorderSizePixel=0;div.ZIndex=21;div.Parent=parent
end

-- ── detail pane ───────────────────────────────────────────────────────────────
local function buildDetailPane(parent)
	detailArea=Instance.new("Frame");detailArea.Name="DetailArea";detailArea.Size=UDim2.new(0,DET_W,1,0);detailArea.Position=UDim2.new(0,DET_X,0,0);detailArea.BackgroundColor3=Color3.fromRGB(10,10,20);detailArea.BorderSizePixel=0;detailArea.ZIndex=21;detailArea.Parent=parent
	detailEmpty=Instance.new("Frame");detailEmpty.Size=UDim2.new(1,0,1,0);detailEmpty.BackgroundTransparency=1;detailEmpty.ZIndex=22;detailEmpty.Parent=detailArea
	local el=Instance.new("TextLabel");el.Size=UDim2.new(0.8,0,0,22);el.Position=UDim2.new(0.1,0,0.44,-11);el.BackgroundTransparency=1;el.Text="Select a unit";el.TextColor3=Color3.fromRGB(38,38,62);el.TextScaled=false;el.TextSize=12;el.Font=Enum.Font.Gotham;el.TextXAlignment=Enum.TextXAlignment.Center;el.ZIndex=22;el.Parent=detailEmpty
	detailContent=Instance.new("Frame");detailContent.Name="DetailContent";detailContent.Size=UDim2.new(1,0,1,0);detailContent.BackgroundTransparency=1;detailContent.Visible=false;detailContent.ZIndex=22;detailContent.Parent=detailArea
	detailScroll=Instance.new("ScrollingFrame");detailScroll.Name="DetailScroll";detailScroll.Size=UDim2.new(1,0,1,0);detailScroll.BackgroundTransparency=1;detailScroll.BorderSizePixel=0;detailScroll.CanvasSize=UDim2.new(0,0,0,0);detailScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y;detailScroll.ScrollBarThickness=3;detailScroll.ScrollBarImageColor3=Color3.fromRGB(50,50,80);detailScroll.ZIndex=22;detailScroll.Parent=detailContent

	local P=12; local IW=DET_W-P*2; local y=P

	-- Art (180px tall)
	dArtBg=Instance.new("Frame");dArtBg.Name="Art";dArtBg.Size=UDim2.new(0,IW,0,180);dArtBg.Position=UDim2.new(0,P,0,y);dArtBg.BackgroundColor3=Color3.fromRGB(20,18,30);dArtBg.BorderSizePixel=0;dArtBg.ZIndex=23;dArtBg.Parent=detailScroll;C(dArtBg,10);S(dArtBg,Color3.fromRGB(40,36,64),2)
	y=y+188

	-- Role badge + Name + Rarity
	dRoleBadge=Instance.new("Frame");dRoleBadge.Size=UDim2.new(0,46,0,20);dRoleBadge.Position=UDim2.new(0,P,0,y);dRoleBadge.BackgroundColor3=Color3.fromRGB(60,130,220);dRoleBadge.BorderSizePixel=0;dRoleBadge.ZIndex=23;dRoleBadge.Parent=detailScroll;C(dRoleBadge,4)
	local rbL=Instance.new("TextLabel");rbL.Name="Lbl";rbL.Size=UDim2.new(1,0,1,0);rbL.BackgroundTransparency=1;rbL.Text="TANK";rbL.TextColor3=Color3.new(1,1,1);rbL.TextScaled=false;rbL.TextSize=9;rbL.Font=Enum.Font.GothamBold;rbL.ZIndex=24;rbL.Parent=dRoleBadge
	dName=Instance.new("TextLabel");dName.Size=UDim2.new(0,IW-46-58-8,0,20);dName.Position=UDim2.new(0,P+50,0,y);dName.BackgroundTransparency=1;dName.Text="";dName.TextColor3=Color3.fromRGB(215,215,240);dName.TextScaled=false;dName.TextSize=13;dName.TextTruncate=Enum.TextTruncate.AtEnd;dName.Font=Enum.Font.GothamBold;dName.TextXAlignment=Enum.TextXAlignment.Left;dName.ZIndex=23;dName.Parent=detailScroll
	dRarity=Instance.new("TextLabel");dRarity.Size=UDim2.new(0,54,0,18);dRarity.Position=UDim2.new(1,-P-54,0,y+1);dRarity.BackgroundColor3=Color3.fromRGB(18,10,28);dRarity.BorderSizePixel=0;dRarity.Text="—";dRarity.TextColor3=Color3.fromRGB(180,180,200);dRarity.TextScaled=false;dRarity.TextSize=9;dRarity.Font=Enum.Font.GothamBold;dRarity.TextXAlignment=Enum.TextXAlignment.Center;dRarity.ZIndex=23;dRarity.Parent=detailScroll;C(dRarity,4)
	y=y+28

	local div0=Instance.new("Frame");div0.Size=UDim2.new(0,IW,0,1);div0.Position=UDim2.new(0,P,0,y);div0.BackgroundColor3=Color3.fromRGB(26,22,46);div0.BorderSizePixel=0;div0.ZIndex=22;div0.Parent=detailScroll; y=y+9

	-- Stats (ATK, HP colored large; MP pips)
	local SW=math.floor(IW/3)
	local statDefs={{label="ATK",bg=Color3.fromRGB(32,12,10),valCol=Color3.fromRGB(255,130,80)},{label="HP",bg=Color3.fromRGB(10,28,14),valCol=Color3.fromRGB(90,230,120)},{label="MP",bg=Color3.fromRGB(18,10,32),valCol=nil}}
	for i,sd in ipairs(statDefs) do
		local cx=P+(i-1)*SW
		local box=Instance.new("Frame");box.Size=UDim2.new(0,SW-4,0,46);box.Position=UDim2.new(0,cx,0,y);box.BackgroundColor3=sd.bg;box.BorderSizePixel=0;box.ZIndex=23;box.Parent=detailScroll;C(box,6)
		S(box,Color3.fromRGB(40,36,54),1)
		local slbl=Instance.new("TextLabel");slbl.Size=UDim2.new(1,0,0,13);slbl.BackgroundTransparency=1;slbl.Text=sd.label;slbl.TextColor3=sd.valCol and Color3.new(sd.valCol.R*0.6,sd.valCol.G*0.6,sd.valCol.B*0.6) or Color3.fromRGB(100,80,140);slbl.TextScaled=false;slbl.TextSize=9;slbl.Font=Enum.Font.GothamBold;slbl.TextXAlignment=Enum.TextXAlignment.Center;slbl.ZIndex=24;slbl.Parent=box
		if i==1 then
			dATK=Instance.new("TextLabel");dATK.Size=UDim2.new(1,0,0,28);dATK.Position=UDim2.new(0,0,0,14);dATK.BackgroundTransparency=1;dATK.Text="—";dATK.TextColor3=sd.valCol;dATK.TextScaled=false;dATK.TextSize=22;dATK.Font=Enum.Font.GothamBold;dATK.TextXAlignment=Enum.TextXAlignment.Center;dATK.ZIndex=24;dATK.Parent=box
		elseif i==2 then
			dHP=Instance.new("TextLabel");dHP.Size=UDim2.new(1,0,0,28);dHP.Position=UDim2.new(0,0,0,14);dHP.BackgroundTransparency=1;dHP.Text="—";dHP.TextColor3=sd.valCol;dHP.TextScaled=false;dHP.TextSize=22;dHP.Font=Enum.Font.GothamBold;dHP.TextXAlignment=Enum.TextXAlignment.Center;dHP.ZIndex=24;dHP.Parent=box
		else
			-- MP pips
			local pipTotalW=5*10+4*5; local pipStartX=math.floor((SW-4-pipTotalW)/2)
			for pi=1,5 do
				local pip=Instance.new("Frame");pip.Size=UDim2.new(0,10,0,10);pip.Position=UDim2.new(0,pipStartX+(pi-1)*15,0,18);pip.BackgroundColor3=Color3.fromRGB(30,24,50);pip.BorderSizePixel=0;pip.ZIndex=25;pip.Parent=box;C(pip,5)
				S(pip,Color3.fromRGB(45,38,70),1);dMPPips[pi]=pip
			end
		end
	end
	y=y+54

	-- Equip
	equBtn=B(detailScroll,"Equip",UDim2.new(0,IW,0,28),UDim2.new(0,P,0,y),Color3.fromRGB(28,68,36),23);equBtn.TextScaled=false;equBtn.TextSize=12;equBtn.Font=Enum.Font.GothamBold;S(equBtn,Color3.fromRGB(40,100,52),1);hoverBtn(equBtn,Color3.fromRGB(28,68,36),Color3.fromRGB(38,88,48))
	equBtn.MouseButton1Click:Connect(function()
		if not selectedCard then return end
		local sn=globalTeamBar:IsInTeam(selectedCard.id)
		if sn then globalTeamBar:RemoveFromSlot(sn) else local target=1;local t=globalTeamBar:GetTeam();for i=1,5 do if not t[i] or t[i]==false then target=i;break end end;globalTeamBar:EquipToSlot(target,selectedCard) end
		showCard(selectedCard)
	end)
	y=y+36

	-- PASSIVE
	local sd1=Instance.new("Frame");sd1.Size=UDim2.new(0,IW,0,1);sd1.Position=UDim2.new(0,P,0,y);sd1.BackgroundColor3=Color3.fromRGB(30,26,50);sd1.BorderSizePixel=0;sd1.ZIndex=22;sd1.Parent=detailScroll; y=y+9
	local pasHdr=Instance.new("TextLabel");pasHdr.Size=UDim2.new(0,50,0,11);pasHdr.Position=UDim2.new(0,P,0,y);pasHdr.BackgroundTransparency=1;pasHdr.Text="PASSIVE";pasHdr.TextColor3=Color3.fromRGB(80,80,110);pasHdr.TextScaled=false;pasHdr.TextSize=9;pasHdr.Font=Enum.Font.GothamBold;pasHdr.ZIndex=23;pasHdr.Parent=detailScroll
	dPassiveChip=Instance.new("Frame");dPassiveChip.Size=UDim2.new(0,64,0,14);dPassiveChip.Position=UDim2.new(0,P+54,0,y-1);dPassiveChip.BackgroundColor3=Color3.fromRGB(100,100,180);dPassiveChip.BorderSizePixel=0;dPassiveChip.ZIndex=23;dPassiveChip.Parent=detailScroll;C(dPassiveChip,3)
	local chipLbl=Instance.new("TextLabel");chipLbl.Name="Lbl";chipLbl.Size=UDim2.new(1,0,1,0);chipLbl.BackgroundTransparency=1;chipLbl.Text="—";chipLbl.TextColor3=Color3.new(1,1,1);chipLbl.TextScaled=false;chipLbl.TextSize=8;chipLbl.Font=Enum.Font.GothamBold;chipLbl.ZIndex=24;chipLbl.Parent=dPassiveChip
	dCardPassiveName=Instance.new("TextLabel");dCardPassiveName.Size=UDim2.new(0,IW-54-68,0,14);dCardPassiveName.Position=UDim2.new(0,P+122,0,y);dCardPassiveName.BackgroundTransparency=1;dCardPassiveName.Text="";dCardPassiveName.TextColor3=Color3.fromRGB(220,200,100);dCardPassiveName.TextScaled=false;dCardPassiveName.TextSize=10;dCardPassiveName.Font=Enum.Font.GothamBold;dCardPassiveName.TextXAlignment=Enum.TextXAlignment.Left;dCardPassiveName.ZIndex=23;dCardPassiveName.Parent=detailScroll
	y=y+18
	dCardPassiveDesc=Instance.new("TextLabel");dCardPassiveDesc.Size=UDim2.new(0,IW,0,34);dCardPassiveDesc.Position=UDim2.new(0,P,0,y);dCardPassiveDesc.BackgroundTransparency=1;dCardPassiveDesc.Text="";dCardPassiveDesc.TextColor3=Color3.fromRGB(155,160,185);dCardPassiveDesc.TextScaled=false;dCardPassiveDesc.TextSize=12;dCardPassiveDesc.Font=Enum.Font.Gotham;dCardPassiveDesc.TextXAlignment=Enum.TextXAlignment.Left;dCardPassiveDesc.TextYAlignment=Enum.TextYAlignment.Top;dCardPassiveDesc.TextWrapped=true;dCardPassiveDesc.ZIndex=23;dCardPassiveDesc.Parent=detailScroll
	y=y+40

	-- ACTIVE
	local sd2=Instance.new("Frame");sd2.Size=UDim2.new(0,IW,0,1);sd2.Position=UDim2.new(0,P,0,y);sd2.BackgroundColor3=Color3.fromRGB(30,26,50);sd2.BorderSizePixel=0;sd2.ZIndex=22;sd2.Parent=detailScroll; y=y+9
	local actHdr=Instance.new("TextLabel");actHdr.Size=UDim2.new(0,40,0,11);actHdr.Position=UDim2.new(0,P,0,y);actHdr.BackgroundTransparency=1;actHdr.Text="ACTIVE";actHdr.TextColor3=Color3.fromRGB(80,80,110);actHdr.TextScaled=false;actHdr.TextSize=9;actHdr.Font=Enum.Font.GothamBold;actHdr.ZIndex=23;actHdr.Parent=detailScroll
	local actBadge=Instance.new("Frame");actBadge.Size=UDim2.new(0,36,0,14);actBadge.Position=UDim2.new(0,P+44,0,y-1);actBadge.BackgroundColor3=Color3.fromRGB(60,40,100);actBadge.BorderSizePixel=0;actBadge.ZIndex=23;actBadge.Parent=detailScroll;C(actBadge,3)
	local actBadgeLbl=Instance.new("TextLabel");actBadgeLbl.Size=UDim2.new(1,0,1,0);actBadgeLbl.BackgroundTransparency=1;actBadgeLbl.Text="SKILL";actBadgeLbl.TextColor3=Color3.fromRGB(180,140,255);actBadgeLbl.TextScaled=false;actBadgeLbl.TextSize=8;actBadgeLbl.Font=Enum.Font.GothamBold;actBadgeLbl.ZIndex=24;actBadgeLbl.Parent=actBadge
	dActiveName=Instance.new("TextLabel");dActiveName.Size=UDim2.new(0,IW-44-40,0,14);dActiveName.Position=UDim2.new(0,P+84,0,y);dActiveName.BackgroundTransparency=1;dActiveName.Text="";dActiveName.TextColor3=Color3.fromRGB(190,150,255);dActiveName.TextScaled=false;dActiveName.TextSize=10;dActiveName.Font=Enum.Font.GothamBold;dActiveName.TextXAlignment=Enum.TextXAlignment.Left;dActiveName.ZIndex=23;dActiveName.Parent=detailScroll
	y=y+18
	dActiveDesc=Instance.new("TextLabel");dActiveDesc.Size=UDim2.new(0,IW,0,34);dActiveDesc.Position=UDim2.new(0,P,0,y);dActiveDesc.BackgroundTransparency=1;dActiveDesc.Text="";dActiveDesc.TextColor3=ACTIVE_DESC_COLOR;dActiveDesc.TextScaled=false;dActiveDesc.TextSize=12;dActiveDesc.Font=Enum.Font.Gotham;dActiveDesc.TextXAlignment=Enum.TextXAlignment.Left;dActiveDesc.TextYAlignment=Enum.TextYAlignment.Top;dActiveDesc.TextWrapped=true;dActiveDesc.ZIndex=23;dActiveDesc.Parent=detailScroll
	y=y+40

	-- SYNERGIES
	local sd3=Instance.new("Frame");sd3.Size=UDim2.new(0,IW,0,1);sd3.Position=UDim2.new(0,P,0,y);sd3.BackgroundColor3=Color3.fromRGB(30,26,50);sd3.BorderSizePixel=0;sd3.ZIndex=22;sd3.Parent=detailScroll; y=y+9
	local synHdr=Instance.new("TextLabel");synHdr.Size=UDim2.new(0,IW,0,11);synHdr.Position=UDim2.new(0,P,0,y);synHdr.BackgroundTransparency=1;synHdr.Text="SYNERGIES";synHdr.TextColor3=Color3.fromRGB(80,80,110);synHdr.TextScaled=false;synHdr.TextSize=9;synHdr.Font=Enum.Font.GothamBold;synHdr.TextXAlignment=Enum.TextXAlignment.Left;synHdr.ZIndex=23;synHdr.Parent=detailScroll; y=y+15
	dSynContainer=Instance.new("Frame");dSynContainer.Name="SynContainer";dSynContainer.Size=UDim2.new(0,IW,0,0);dSynContainer.Position=UDim2.new(0,P,0,y);dSynContainer.BackgroundTransparency=1;dSynContainer.AutomaticSize=Enum.AutomaticSize.Y;dSynContainer.BorderSizePixel=0;dSynContainer.ZIndex=23;dSynContainer.Parent=detailScroll
	local synList=Instance.new("UIListLayout");synList.Parent=dSynContainer;synList.Padding=UDim.new(0,5);synList.SortOrder=Enum.SortOrder.LayoutOrder

	-- Synergy tooltip (parented to panel, floats over grid area)
	synergyTooltip=Instance.new("Frame");synergyTooltip.Name="SynTooltip";synergyTooltip.Size=UDim2.new(0,280,0,0);synergyTooltip.AutomaticSize=Enum.AutomaticSize.Y;synergyTooltip.BackgroundColor3=Color3.fromRGB(11,9,20);synergyTooltip.BackgroundTransparency=0.05;synergyTooltip.BorderSizePixel=0;synergyTooltip.ZIndex=48;synergyTooltip.Visible=false;synergyTooltip.Parent=panel;C(synergyTooltip,8);S(synergyTooltip,Color3.fromRGB(60,45,90),1)
	local tip_pad=Instance.new("UIPadding");tip_pad.PaddingTop=UDim.new(0,8);tip_pad.PaddingBottom=UDim.new(0,8);tip_pad.PaddingLeft=UDim.new(0,10);tip_pad.PaddingRight=UDim.new(0,10);tip_pad.Parent=synergyTooltip
	synergyTooltipInner=Instance.new("Frame");synergyTooltipInner.Size=UDim2.new(1,0,0,0);synergyTooltipInner.AutomaticSize=Enum.AutomaticSize.Y;synergyTooltipInner.BackgroundTransparency=1;synergyTooltipInner.BorderSizePixel=0;synergyTooltipInner.ZIndex=49;synergyTooltipInner.Parent=synergyTooltip
	local innerList=Instance.new("UIListLayout");innerList.Padding=UDim.new(0,6);innerList.SortOrder=Enum.SortOrder.LayoutOrder;innerList.Parent=synergyTooltipInner
end

-- ── synergies reference tab ───────────────────────────────────────────────────
local function buildSynergiesTab(parent)
	local scroll=Instance.new("ScrollingFrame");scroll.Name="SynRefScroll";scroll.Size=UDim2.new(1,0,1,0);scroll.BackgroundTransparency=1;scroll.BorderSizePixel=0;scroll.CanvasSize=UDim2.new(0,0,0,0);scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y;scroll.ScrollBarThickness=5;scroll.ScrollBarImageColor3=Color3.fromRGB(60,60,90);scroll.ZIndex=21;scroll.Parent=parent
	synRefScroll=scroll; synNameToCard={}
	local list=Instance.new("UIListLayout");list.Parent=scroll;list.Padding=UDim.new(0,8);list.SortOrder=Enum.SortOrder.LayoutOrder
	local outerPad=Instance.new("UIPadding");outerPad.Parent=scroll;outerPad.PaddingTop=UDim.new(0,10);outerPad.PaddingBottom=UDim.new(0,10);outerPad.PaddingLeft=UDim.new(0,12);outerPad.PaddingRight=UDim.new(0,12)
	for order,synName in ipairs(roleConf.SynergyOrder) do
		local synDef=roleConf.Synergies[synName]; if not synDef then continue end
		local sc=synDef.color or Color3.fromRGB(100,100,180)
		local card=Instance.new("Frame");card.Name="Syn_"..order;card.Size=UDim2.new(1,0,0,0);card.AutomaticSize=Enum.AutomaticSize.Y;card.BackgroundColor3=Color3.fromRGB(14,14,22);card.BorderSizePixel=0;card.LayoutOrder=order;card.ZIndex=22;card.Parent=scroll;C(card,8)
		local dimColor=Color3.new(sc.R*0.5,sc.G*0.5,sc.B*0.5)
		local cardStroke=S(card,dimColor,1)
		local accent=Instance.new("Frame");accent.Size=UDim2.new(0,5,1,0);accent.BackgroundColor3=sc;accent.BorderSizePixel=0;accent.ZIndex=23;accent.Parent=card;C(accent,3)
		synNameToCard[synName]={frame=card,stroke=cardStroke,dimColor=dimColor,color=sc,accent=accent}
		local inner=Instance.new("Frame");inner.Name="Inner";inner.Size=UDim2.new(1,-16,0,0);inner.Position=UDim2.new(0,12,0,0);inner.AutomaticSize=Enum.AutomaticSize.Y;inner.BackgroundTransparency=1;inner.BorderSizePixel=0;inner.ZIndex=23;inner.Parent=card
		local iList=Instance.new("UIListLayout");iList.Parent=inner;iList.Padding=UDim.new(0,4);iList.SortOrder=Enum.SortOrder.LayoutOrder
		local ipad=Instance.new("UIPadding");ipad.Parent=inner;ipad.PaddingTop=UDim.new(0,8);ipad.PaddingBottom=UDim.new(0,8)
		local hdr=Instance.new("Frame");hdr.Size=UDim2.new(1,0,0,18);hdr.BackgroundTransparency=1;hdr.BorderSizePixel=0;hdr.LayoutOrder=1;hdr.ZIndex=23;hdr.Parent=inner
		local nameLbl=Instance.new("TextLabel");nameLbl.Size=UDim2.new(0.65,0,1,0);nameLbl.BackgroundTransparency=1;nameLbl.Text=synName;nameLbl.TextColor3=sc;nameLbl.TextScaled=false;nameLbl.TextSize=13;nameLbl.Font=Enum.Font.GothamBold;nameLbl.TextXAlignment=Enum.TextXAlignment.Left;nameLbl.ZIndex=24;nameLbl.Parent=hdr
		local maxLbl=Instance.new("TextLabel");maxLbl.Size=UDim2.new(0.35,0,1,0);maxLbl.Position=UDim2.new(0.65,0,0,0);maxLbl.BackgroundTransparency=1;maxLbl.Text="max "..synDef.maxCount;maxLbl.TextColor3=Color3.fromRGB(70,70,90);maxLbl.TextScaled=false;maxLbl.TextSize=10;maxLbl.Font=Enum.Font.Gotham;maxLbl.TextXAlignment=Enum.TextXAlignment.Right;maxLbl.ZIndex=24;maxLbl.Parent=hdr
		for tierIdx,thresh in ipairs(synDef.thresholds) do
			local tierRow=Instance.new("Frame");tierRow.Size=UDim2.new(1,0,0,26);tierRow.AutomaticSize=Enum.AutomaticSize.Y;tierRow.BackgroundColor3=Color3.new(sc.R*0.06,sc.G*0.06,sc.B*0.06);tierRow.BorderSizePixel=0;tierRow.LayoutOrder=1+tierIdx;tierRow.ZIndex=23;tierRow.Parent=inner;C(tierRow,4)
			local cb=Instance.new("Frame");cb.Size=UDim2.new(0,22,0,18);cb.Position=UDim2.new(0,5,0,4);cb.BackgroundColor3=sc;cb.BorderSizePixel=0;cb.ZIndex=24;cb.Parent=tierRow;C(cb,4)
			local cl=Instance.new("TextLabel");cl.Size=UDim2.new(1,0,1,0);cl.BackgroundTransparency=1;cl.Text=tostring(thresh.count);cl.TextColor3=Color3.new(1,1,1);cl.TextScaled=false;cl.TextSize=11;cl.Font=Enum.Font.GothamBold;cl.ZIndex=25;cl.Parent=cb
			local bl=Instance.new("TextLabel");bl.Size=UDim2.new(1,-34,0,26);bl.Position=UDim2.new(0,30,0,0);bl.AutomaticSize=Enum.AutomaticSize.Y;bl.BackgroundTransparency=1;bl.Text=thresh.bonus;bl.TextColor3=Color3.fromRGB(190,215,190);bl.TextScaled=false;bl.TextSize=10;bl.Font=Enum.Font.Gotham;bl.TextXAlignment=Enum.TextXAlignment.Left;bl.TextWrapped=true;bl.TextYAlignment=Enum.TextYAlignment.Center;bl.ZIndex=24;bl.Parent=tierRow
		end
		local unitNames={}; if cardDb then for _,c2 in ipairs(cardDb:GetBySeries(synName)) do table.insert(unitNames,c2.name) end end
		if #unitNames>0 then
			local mRow=Instance.new("Frame");mRow.Size=UDim2.new(1,0,0,14);mRow.AutomaticSize=Enum.AutomaticSize.Y;mRow.BackgroundTransparency=1;mRow.BorderSizePixel=0;mRow.LayoutOrder=20;mRow.ZIndex=23;mRow.Parent=inner
			local mLbl=Instance.new("TextLabel");mLbl.Size=UDim2.new(1,0,0,14);mLbl.AutomaticSize=Enum.AutomaticSize.Y;mLbl.BackgroundTransparency=1;mLbl.Text=table.concat(unitNames," · ");mLbl.TextColor3=Color3.fromRGB(60,60,80);mLbl.TextScaled=false;mLbl.TextSize=9;mLbl.Font=Enum.Font.Gotham;mLbl.TextXAlignment=Enum.TextXAlignment.Left;mLbl.TextWrapped=true;mLbl.TextYAlignment=Enum.TextYAlignment.Top;mLbl.ZIndex=24;mLbl.Parent=mRow
		end
	end
end

-- ── synergy card highlight (SYNERGIES tab) ────────────────────────────────────
local function highlightSynergyCard(synName)
	for name, data in pairs(synNameToCard) do
		if name ~= synName then
			TweenService:Create(data.stroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{Color=data.dimColor, Thickness=1}):Play()
			TweenService:Create(data.frame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{BackgroundColor3=Color3.fromRGB(14,14,22)}):Play()
			if data.accent then
				TweenService:Create(data.accent, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{Size=UDim2.new(0,5,1,0)}):Play()
			end
		end
	end
	local data = synNameToCard[synName]
	if not data or not synRefScroll then return end
	-- Flash stroke white+thick then settle to synergy color
	data.stroke.Color = Color3.new(1,1,1)
	data.stroke.Thickness = 4
	TweenService:Create(data.stroke, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Color=data.color, Thickness=2.5}):Play()
	-- Tint background
	TweenService:Create(data.frame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{BackgroundColor3=Color3.new(data.color.R*0.12, data.color.G*0.12, data.color.B*0.12)}):Play()
	-- Pop accent strip wider then settle slightly wider than default
	if data.accent then
		data.accent.Size = UDim2.new(0, 8, 1, 0)
		TweenService:Create(data.accent, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Size=UDim2.new(0,6,1,0)}):Play()
	end
	task.spawn(function()
		task.wait() task.wait()
		if not synRefScroll or not data.frame.Parent then return end
		local canvasY = data.frame.AbsolutePosition.Y - synRefScroll.AbsolutePosition.Y + synRefScroll.CanvasPosition.Y
		TweenService:Create(synRefScroll, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{CanvasPosition=Vector2.new(0, math.max(0, canvasY - 20))}):Play()
	end)
end

-- ── tab switching ─────────────────────────────────────────────────────────────
local function switchTab(tab)
	local isUnits=(tab=="units")
	local outgoing = isUnits and synergiesBody or unitsBody
	local incoming = isUnits and unitsBody or synergiesBody
	-- Quick fade-out then swap
	TweenService:Create(outgoing, TweenInfo.new(0.08), {BackgroundTransparency=1}):Play()
	task.delay(0.08, function()
		outgoing.Visible=false; outgoing.BackgroundTransparency=1
		incoming.BackgroundTransparency=1; incoming.Visible=true
		TweenService:Create(incoming, TweenInfo.new(0.10), {BackgroundTransparency=1}):Play()
	end)
	TweenService:Create(tabUnitsBtn, TweenInfo.new(0.10), {BackgroundColor3=isUnits and Color3.fromRGB(50,36,90) or Color3.fromRGB(22,16,44)}):Play()
	TweenService:Create(tabSynBtn,   TweenInfo.new(0.10), {BackgroundColor3=isUnits and Color3.fromRGB(22,16,44) or Color3.fromRGB(50,36,90)}):Play()
	searchBox.Visible=isUnits;filterBtn.Visible=isUnits;roleFilterBtn.Visible=isUnits;sortBtn.Visible=isUnits;capLbl.Visible=isUnits
	if not isUnits then hideSynergyTooltip() end
end

-- ── panel builder ─────────────────────────────────────────────────────────────
local function buildPanel(gui)
	panel=Instance.new("Frame");panel.Name="INVENTORYPanel";panel.Size=UDim2.new(0,PW,0,PH);panel.Position=UDim2.new(0.5,-PW/2,0,4);panel.BackgroundColor3=Color3.fromRGB(10,10,20);panel.BackgroundTransparency=0.10;panel.BorderSizePixel=0;panel.ZIndex=20;panel.Visible=false;panel.Parent=gui;C(panel,12);S(panel,Color3.fromRGB(38,38,58),1)
	buildTopBar()
	unitsBody=Instance.new("Frame");unitsBody.Name="UnitsBody";unitsBody.Size=UDim2.new(1,0,0,BODY_H);unitsBody.Position=UDim2.new(0,0,0,BODY_Y);unitsBody.BackgroundTransparency=1;unitsBody.BorderSizePixel=0;unitsBody.ZIndex=21;unitsBody.Parent=panel
	buildGridPane(unitsBody);buildDetailPane(unitsBody)
	synergiesBody=Instance.new("Frame");synergiesBody.Name="SynergiesBody";synergiesBody.Size=UDim2.new(1,0,0,BODY_H);synergiesBody.Position=UDim2.new(0,0,0,BODY_Y);synergiesBody.BackgroundTransparency=1;synergiesBody.BorderSizePixel=0;synergiesBody.ZIndex=21;synergiesBody.Visible=false;synergiesBody.Parent=panel
	buildSynergiesTab(synergiesBody)
	tabUnitsBtn.MouseButton1Click:Connect(function() switchTab("units") end)
	tabSynBtn.MouseButton1Click:Connect(function() switchTab("synergies") end)
	switchTab("units")
	mouse=Players.LocalPlayer:GetMouse()
	connectDragHandlers()
end

-- ── data loader ───────────────────────────────────────────────────────────────
local function loadData()
	local ok,data=pcall(function() return rfGetInventory:InvokeServer() end)
	if not ok or not data then return end
	allCards={}
	for _,id in ipairs(data.cardIds or {}) do
		local card=cardDb:GetById(id); if card then
			local awk=(data.awakening or {})[tostring(id)] or 0
			table.insert(allCards,{id=card.id,name=card.name,rarity=card.rarity,attack=card.attack,hp=card.hp,mp=card.mp,passive=card.passive,passive_name=card.passive_name,passive_desc=card.passive_desc,active=card.active,role=card.role,series=card.series or {},awakening=awk})
		end
	end
	capLbl.Text=#allCards.." / "..MAX_CAP
	globalTeamBar:LoadTeam(data.team)
	applyFilter()
end

-- ── public API ────────────────────────────────────────────────────────────────
function InventoryUI:Init(gui,db,rc,roleC,rfInv,gtb)
	cardDb=db;rarityConf=rc;roleConf=roleC;rfGetInventory=rfInv;globalTeamBar=gtb
	gtb:SetOnChanged(function() updateGridEquippedIndicators(); if selectedCard then showCard(selectedCard) end; refreshSynergyPips() end)
	gtb:SetOnSlotClicked(function(slotIdx)
		if not panel.Visible then InventoryUI:Show() end
		switchTab("units")
		local cid=globalTeamBar:GetTeam()[slotIdx]
		if cid and cid~=false then
			task.spawn(function()
				for _=1,30 do
					local tile=gridScroll:FindFirstChild("T"..cid)
					if tile then
						if selStroke then selStroke.Thickness=2;selStroke.Color=selOrigCol;selStroke=nil;selOrigCol=nil end
						local ts=tile:FindFirstChildOfClass("UIStroke"); local card=cardDb:GetById(cid)
						if card then local bc=RBORDER[card.rarity] or Color3.fromRGB(130,130,130); if ts then selStroke=ts;selOrigCol=bc;ts.Thickness=3;ts.Color=Color3.new(1,1,1) end; showCard(card) end
						task.wait(0.05)
						local canvasY=tile.AbsolutePosition.Y-gridScroll.AbsolutePosition.Y+gridScroll.CanvasPosition.Y
						gridScroll.CanvasPosition=Vector2.new(0,math.max(0,canvasY-20)); return
					end
					task.wait(0.1)
				end
			end)
		end
	end)
	buildPanel(gui)
end
function InventoryUI:Show() panel.Visible=true;showEmpty();task.spawn(loadData) end
function InventoryUI:Hide() panel.Visible=false;hideSynergyTooltip() end
function InventoryUI:GetPanel() return panel end
function InventoryUI:NavigateToSynergy(synName)
	if not panel then return end
	if not panel.Visible then
		panel.Visible = true
		if #allCards == 0 then task.spawn(loadData) end
	end
	switchTab("synergies")
	task.spawn(function() task.wait(); highlightSynergyCard(synName) end)
end
function InventoryUI:HighlightSynergy(synName)
	if panel and panel.Visible then applyHighlight(synName) end
end
function InventoryUI:ClearHighlight()
	clearHighlight()
end
return InventoryUI