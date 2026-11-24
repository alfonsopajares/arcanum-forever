local _, addon = ...

local function amount(value)
    value=tonumber(value)
    return value and math.max(0,math.min(200,math.floor(value))) or nil
end

function addon:GetGroupSupplyRequest(member)
    if not self.character then return nil end
    self.character.supplyRequests=self.character.supplyRequests or {}
    local requests=self.character.supplyRequests
    if not requests[member.key] then
        local preset=self.db.vending.presets[member.class] or self.db.vending.presets.UNKNOWN
        requests[member.key]={food=preset.food,water=preset.water}
    end
    return requests[member.key]
end

function addon:SyncGroupSupplies()
    self:PruneDistribution()
    local members=self:GroupMembers(true)
    if #members==0 and IsLoggedIn and not IsLoggedIn() then return members end
    local present={}
    for _,member in ipairs(members) do present[member.key]=true; self:GetGroupSupplyRequest(member) end
    for key in pairs(self.character.supplyRequests or {}) do
        if not present[key] then self.character.supplyRequests[key]=nil end
    end
    if #members==0 then
        self.groupSuppliesOpened=nil; self.groupWhisperTimes={}; self.groupTradeNotice=nil
        self.character.supplyScope=nil
        self.supplyRoute,self.supplyPeers,self.supplyHelloAt,self.supplyOutbox=nil,nil,nil,nil
    end
    return members
end

function addon:FindGroupSupplyMember(name,key)
    local match
    for _,member in ipairs(self:GroupMembers()) do
        if key==member.key then return member end
        if name==member.fullName or name==member.name then
            if match then return nil end
            match=member
        end
    end
    return match
end

function addon:SetGroupSupplyAmount(member,kind,value)
    if InCombatLockdown() or (kind~="food" and kind~="water") then return end
    local current=self:FindGroupSupplyMember(member.name,member.key)
    if not current or current.key~=member.key then return end
    value=amount(value)
    if value==nil then return end
    local request=self:GetGroupSupplyRequest(member)
    if request[kind]==value then return end
    request[kind]=value
    self:RecordSupplyOrder(member,"C")
    self.groupSupplyTradePending=true
    self:UpdateGroupSupplies()
end

function addon:RestoreGroupSupply(member)
    if InCombatLockdown() then return end
    member=self:FindGroupSupplyMember(nil,member.key)
    if not member then return end
    local preset=self.db.vending.presets[member.class] or self.db.vending.presets.UNKNOWN
    local request=self:GetGroupSupplyRequest(member)
    if request.food+request.water==0 then request.food,request.water=preset.food,preset.water end
    self:RecordSupplyOrder(member,"C")
    self.groupSupplyTradePending=true
    if self.groupSuppliesWindow then self.groupSuppliesWindow.addList:Hide() end
    self:UpdateGroupSupplies()
end

function addon:GroupSupplyDelivered(trade)
    local member=self:FindGroupSupplyMember(trade.name,trade.key)
    if not member then return end
    local request=self:GetGroupSupplyRequest(member)
    if trade.food+trade.water==0 then return end
    -- Publish the serving mage's actual target when class presets differ.
    if not request.order then self:RecordSupplyOrder(member,"A") end
    request.food,request.water=math.max(0,request.food-trade.food),math.max(0,request.water-trade.water)
    request.sentFood=(request.sentFood or 0)+trade.food
    request.sentWater=(request.sentWater or 0)+trade.water
    request.creditedFood=(request.creditedFood or 0)+trade.food
    request.creditedWater=(request.creditedWater or 0)+trade.water
    self:MarkSupplyState(member)
    self:BroadcastSupplyDelivery(member)
    self.groupSupplyTradePending=true
    self:UpdateGroupSupplies()
end

function addon:GroupSupplyTradeTargets(name,key)
    local member=self:FindGroupSupplyMember(name,key)
    if not member then return nil end
    if self:SupplyAssignment(member) then return {food=0,water=0},member.key end
    local request=self:GetGroupSupplyRequest(member)
    return {food=request.food,water=request.water},member.key
end

function addon:TradeWithSupplyMember(member)
    if InCombatLockdown() then return end
    local current=member and self:FindGroupSupplyMember(member.name,member.key)
    if current and current.key~=member.key then current=nil end
    local notice
    if not current or not current.unit then notice="Player unavailable"
    elseif self.trade and self.trade.open then notice="Finish the current trade first"
    elseif UnitIsDeadOrGhost and self:Readable(UnitIsDeadOrGhost(current.unit))==true then notice="Player unavailable"
    elseif not CheckInteractDistance or not BeginTrade then notice="Trade is unavailable"
    else
        local ok,near=pcall(CheckInteractDistance,current.unit,2)
        if not ok or self:Readable(near)~=true then notice="Out of range"
        else
            local started,result=pcall(BeginTrade,current.unit)
            notice=started and result~=false and ("Opening trade with "..current.name) or "Unable to open trade"
        end
    end
    self.groupTradeNotice={text=notice,untilTime=GetTime()+4}
    self:UpdateGroupSupplies()
end

function addon:GroupSupplyWhisper(message,sender)
    if not self.db.groupSupplies.whispers then return end
    message,sender=self:Readable(message),self:Readable(sender)
    if type(message)~="string" or type(sender)~="string" then return end
    local kind,count=message:lower():match("^%s*!(%a+)%s*(%d*)%s*$")
    if kind~="food" and kind~="water" and kind~="both" then return end
    if count~="" and (not tonumber(count) or tonumber(count)<1 or tonumber(count)>200) then return end
    local member=self:FindGroupSupplyMember(sender)
    if not member then return end
    self.groupWhisperTimes=self.groupWhisperTimes or {}
    local now=GetTime()
    if self.groupWhisperTimes[member.key] and now-self.groupWhisperTimes[member.key]<10 then return end
    self.groupWhisperTimes[member.key]=now
    local preset=self.db.vending.presets[member.class] or self.db.vending.presets.UNKNOWN
    local request=self:GetGroupSupplyRequest(member)
    for _,supply in ipairs({"food","water"}) do
        if kind==supply or kind=="both" then request[supply]=count~="" and tonumber(count) or preset[supply] end
    end
    self:RecordSupplyOrder(member,"C")
    self.groupSupplyTradePending=true
    self:UpdateGroupSupplies()
end

function addon:SetSupplyDisposition(member,disposition)
    if InCombatLockdown() or not member then return end
    member=self:FindGroupSupplyMember(nil,member.key)
    if not member then return end
    self:RecordSupplyOrder(member,disposition=="declined" and "D" or "E")
    self.groupSupplyTradePending=true
    self:UpdateGroupSupplies()
end

function addon:OpenGroupSupplies()
    if InCombatLockdown() then return end
    self.groupSuppliesOpened=true
    self:UpdateGroupSupplies()
end

local function label(parent,text,x,y,width,font)
    local region=parent:CreateFontString(nil,"OVERLAY",font or "GameFontHighlightSmall")
    region:SetPoint("TOPLEFT",x,y); region:SetWidth(width); region:SetJustifyH("LEFT"); region:SetText(text)
    return region
end

local function servingMenu(self,anchor,choices)
    local window=self.groupSuppliesWindow
    local menu=window.servingMenu
    window.addList:Hide()
    menu:ClearAllPoints(); menu:SetPoint("TOPRIGHT",anchor,"BOTTOMRIGHT",0,0)
    menu:SetSize(190,#choices*22+10)
    for index,choice in ipairs(choices) do
        local button=menu.rows[index]
        if not button then
            button=CreateFrame("Button",nil,menu,"UIPanelButtonTemplate")
            button:SetPoint("TOPLEFT",5,-5-(index-1)*22); button:SetSize(180,22)
            button:SetScript("OnClick",function(b)
                if InCombatLockdown() then return end
                menu:Hide(); b.select()
            end)
            menu.rows[index]=button
        end
        button:SetText(choice[1]); button.select=choice[2]; button:Show()
    end
    for index=#choices+1,#menu.rows do menu.rows[index]:Hide() end
    menu:Show()
end

local function coverageMenu(self,anchor)
    local function selectScope(scope)
        self.character.supplyScope=scope
        self.supplyHelloAt=0
        self.groupSupplyTradePending=true
        self:UpdateGroupSupplies()
    end
    local scope=self.character.supplyScope or "all"
    local choices={}
    local function option(title,value)
        choices[#choices+1]={(scope==value and "✓ " or "")..title,function() selectScope(value) end}
    end
    option("Whole group","all")
    if IsInRaid and self:Readable(IsInRaid()) then
        option("My subgroup","mine")
        for group=1,8 do
            local digit=tostring(group)
            local mask=scope:match("^[1-8]+$") or ""
            local selected=mask:find(digit,1,true)
            choices[#choices+1]={(selected and "✓ " or "").."Raid group "..digit,function()
                local result=selected and mask:gsub(digit,"") or mask..digit
                selectScope(result~="" and result or "custom")
                coverageMenu(self,anchor)
            end}
        end
    end
    option("Handpick from Review","custom")
    choices[#choices+1]={"Done",function() end}
    servingMenu(self,anchor,choices)
end

function addon:PinGroupSuppliesTop()
    local frame=self.groupSuppliesWindow
    if not frame or InCombatLockdown() or not frame.GetLeft or not frame.GetTop then return end
    local left,top=frame:GetLeft(),frame:GetTop()
    if type(left)~="number" or type(top)~="number" then return end
    local cfg=self.db.groupSupplies
    cfg.point,cfg.relativePoint,cfg.x,cfg.y="TOPLEFT","BOTTOMLEFT",left,top
    frame:ClearAllPoints(); frame:SetPoint(cfg.point,UIParent,cfg.relativePoint,left,top)
end

function addon:CreateGroupSupplies()
    local frame=CreateFrame("Frame","ArcanumGroupSupplies",UIParent,"BackdropTemplate")
    self.groupSuppliesWindow=frame
    frame.rows={}; frame.addRows={}; frame:SetSize(340,180); frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true); frame:SetMovable(true); frame:EnableMouse(true)
    frame:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=16,insets={left=4,right=4,top=4,bottom=4}})
    frame:SetBackdropBorderColor(0.65,0.5,0.25,1)
    local header=CreateFrame("Frame",nil,frame)
    frame.header=header
    header:SetSize(252,22); header:SetPoint("TOPLEFT",4,-4); header:EnableMouse(true); header:RegisterForDrag("LeftButton")
    local titleBg=frame:CreateTexture(nil,"BACKGROUND"); titleBg:SetPoint("TOPLEFT",4,-4); titleBg:SetPoint("TOPRIGHT",-4,-4); titleBg:SetSize(1,22); titleBg:SetColorTexture(0.18,0.1,0.03,0.95)
    frame.title=label(header,"Group Supplies",8,-5,230,"GameFontNormal")
    frame.title:SetWordWrap(false)
    header:SetScript("OnDragStart",function() if not InCombatLockdown() then self.groupSuppliesDragging=true; frame:StartMoving() end end)
    header:SetScript("OnDragStop",function()
        if InCombatLockdown() then return end
        frame:StopMovingOrSizing()
        self.groupSuppliesDragging=nil
        local point,_,relativePoint,x,y=frame:GetPoint()
        local cfg=self.db.groupSupplies
        cfg.point,cfg.relativePoint,cfg.x,cfg.y=point,relativePoint,x,y
    end)
    local close=CreateFrame("Button",nil,frame,"UIPanelCloseButton")
    frame.close=close
    close:SetSize(24,24); close:SetPoint("TOPRIGHT",-2,-2); close:SetFrameLevel(header:GetFrameLevel()+5)
    close:SetScript("OnClick",function()
        if InCombatLockdown() then return end
        self.groupSuppliesOpened=nil
        self:UpdateGroupSupplies()
    end)
    local collapse=CreateFrame("Button",nil,frame,"UIPanelButtonTemplate")
    frame.collapse=collapse
    collapse:SetSize(20,18); collapse:SetPoint("TOPRIGHT",-30,-6); collapse:SetText("–")
    collapse:SetFrameLevel(header:GetFrameLevel()+5); collapse:RegisterForClicks("LeftButtonUp")
    collapse:SetScript("OnClick",function()
        if InCombatLockdown() then return end
        self.db.groupSupplies.collapsed=not self.db.groupSupplies.collapsed
        self:UpdateGroupSupplies()
    end)
    local help=CreateFrame("Button",nil,frame,"UIPanelButtonTemplate")
    help:SetSize(18,18); help:SetPoint("TOPRIGHT",-56,-6); help:SetText("?"); help:SetFrameLevel(header:GetFrameLevel()+5)
    help:SetScript("OnEnter",function()
        local stock=self:SupplyStatus()
        local personal=self.db.preparation.profiles.solo
        local tip=self:BeginTooltip(help,"Group Supplies")
        tip:AddLine(string.format("Bags: %d food, %d water",stock.food,stock.water),1,1,1)
        tip:AddLine(string.format("Keep for you: %d food, %d water",math.max(personal.food,self.db.vending.reserveFood),math.max(personal.water,self.db.vending.reserveWater)),0.7,0.8,1)
        tip:AddLine(" ")
        tip:AddLine("Click a name to trade. Edit amounts; 0 skips a supply.",1,1,1,true)
        tip:AddLine("Coverage chooses whom you serve. Nearby, ready players appear first.",1,1,1,true)
        tip:AddLine("Use … for players who decline or are handled elsewhere. Review lets you take a request back.",1,1,1,true)
        local peers=0
        for _ in pairs(self.supplyPeers or {}) do peers=peers+1 end
        tip:AddLine(string.format("Other coordinating mages: %d",peers),0.7,0.8,1,true)
        local plan=self:GroupPreparationProfile()
        tip:AddLine(string.format("Still to conjure: %d food, %d water",plan.missing.food,plan.missing.water),1,1,1,true)
        tip:AddLine("Group whispers: !food, !water, !both, or !water 40",0.7,0.8,1,true)
        tip:AddLine("One conjure per click, outside combat. Drag the title to move.",0.7,0.8,1,true)
        self:FinishTooltip()
    end)
    help:SetScript("OnLeave",function() self:HideTooltip() end)
    frame.body=CreateFrame("Frame",nil,frame); frame.body:SetPoint("TOPLEFT",0,-32); frame.body:SetSize(340,150)
    local coverage=CreateFrame("Button",nil,frame.body,"UIPanelButtonTemplate")
    frame.coverage=coverage
    coverage:SetSize(135,20); coverage:SetPoint("TOPLEFT",12,2)
    coverage:SetScript("OnClick",function()
        if InCombatLockdown() then return end
        if frame.servingMenu:IsShown() then frame.servingMenu:Hide() else coverageMenu(self,coverage) end
    end)
    coverage:SetScript("OnEnter",function()
        local tip=self:BeginTooltip(coverage,"Serving coverage")
        tip:AddLine("Choose the players or raid groups you want to serve.",1,1,1,true)
        self:FinishTooltip()
    end)
    coverage:SetScript("OnLeave",function() self:HideTooltip() end)
    for index,kind in ipairs({"food","water"}) do
        local headerIcon=CreateFrame("Button",nil,frame.body)
        headerIcon:SetSize(18,18); headerIcon:SetPoint("TOPLEFT",169+(index-1)*58,2)
        local icon=headerIcon:CreateTexture(nil,"ARTWORK"); icon:SetAllPoints(); icon:SetTexCoord(0.08,0.92,0.08,0.92)
        icon:SetTexture(kind=="food" and "Interface\\Icons\\INV_Misc_Food_10" or "Interface\\Icons\\INV_Drink_18")
        headerIcon:SetScript("OnEnter",function()
            local tip=self:BeginTooltip(headerIcon,kind=="food" and "Food requested" or "Water requested")
            tip:AddLine("Edit the amount below. Use 0 to skip this supply.",1,1,1,true); self:FinishTooltip()
        end)
        headerIcon:SetScript("OnLeave",function() self:HideTooltip() end)
    end
    frame.scroll=CreateFrame("ScrollFrame",nil,frame.body,"UIPanelScrollFrameTemplate")
    frame.scroll:SetPoint("TOPLEFT",12,-20); frame.scroll:SetSize(298,100)
    frame.content=CreateFrame("Frame",nil,frame.scroll); frame.content:SetSize(298,100); frame.scroll:SetScrollChild(frame.content)
    frame.empty=label(frame.content,"No requests waiting for you.",6,-9,286)
    frame.footer=CreateFrame("Frame",nil,frame.body); frame.footer:SetSize(316,50)
    frame.need=label(frame.footer,"",0,0,316,"GameFontNormalSmall")
    local conjure=CreateFrame("Button",nil,frame.footer,"SecureActionButtonTemplate,UIPanelButtonTemplate")
    frame.conjure=conjure; conjure:SetSize(164,23); conjure:SetPoint("TOPLEFT",0,-19)
    conjure:RegisterForClicks("AnyDown","AnyUp"); conjure:SetAttribute("useOnKeyDown",false)
    SecureHandlerWrapScript(conjure,"OnClick",conjure,[[if SecureCmdOptionParse("[combat] combat") then self:SetAttribute("type1","") end]])
    local add=CreateFrame("Button",nil,frame.footer,"UIPanelButtonTemplate")
    frame.add=add; add:SetSize(108,23); add:SetPoint("TOPRIGHT",0,-19); add:SetText("Review…")
    frame.addList=CreateFrame("Frame",nil,frame,"BackdropTemplate")
    frame.addList:SetClampedToScreen(true)
    frame.addList:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12})
    frame.addList:SetPoint("TOPRIGHT",add,"BOTTOMRIGHT",0,-2); frame.addList:SetSize(230,172); frame.addList:SetFrameLevel(frame:GetFrameLevel()+20)
    local addScroll=CreateFrame("ScrollFrame",nil,frame.addList,"UIPanelScrollFrameTemplate")
    addScroll:SetPoint("TOPLEFT",6,-6); addScroll:SetSize(202,160)
    frame.addContent=CreateFrame("Frame",nil,addScroll); frame.addContent:SetSize(202,160); addScroll:SetScrollChild(frame.addContent)
    frame.addList:Hide()
    frame.servingMenu=CreateFrame("Frame",nil,frame,"BackdropTemplate")
    frame.servingMenu:SetClampedToScreen(true)
    frame.servingMenu:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12})
    frame.servingMenu:SetFrameLevel(frame:GetFrameLevel()+25); frame.servingMenu:EnableMouse(true)
    frame.servingMenu.rows={}; frame.servingMenu:Hide()
    add:SetScript("OnClick",function()
        if not InCombatLockdown() then frame.servingMenu:Hide(); frame.addList:SetShown(not frame.addList:IsShown()) end
    end)
    frame:Hide()
    self:UpdateGroupSupplies()
end

function addon:UpdateGroupSupplies()
    local frame=self.groupSuppliesWindow
    if not frame then return end
    if InCombatLockdown() then self.groupSuppliesPending=true; return end
    self.groupSuppliesPending=nil
    local members=self:SyncGroupSupplies()
    local grouped=#members>0
    self:LayoutPreparationButtons(grouped)
    if self.groupSupplyTradePending and self.trade and self.trade.open then
        local targets=self:GroupSupplyTradeTargets(self.trade.name,self.trade.key)
        local old=self.trade.groupBaseline
        if targets and (not old or old.food~=targets.food or old.water~=targets.water) then
            self.trade.groupBaseline={food=targets.food,water=targets.water}
            self.trade.targets=targets
            self.trade.job=nil
            self.trade.groupRequest=true
            if self.tradeUI then for kind,input in pairs(self.tradeUI.inputs) do input:SetText(tostring(targets[kind])) end end
            self:UpdateTradeUI()
        end
    end
    self.groupSupplyTradePending=nil
    frame:SetShown(grouped and self.groupSuppliesOpened==true)
    if not frame:IsShown() then
        frame.servingMenu:Hide()
        frame.addList:Hide()
        return
    end
    local pending,reasons={},{}
    for _,member in ipairs(members) do
        local request=self:GetGroupSupplyRequest(member)
        reasons[member.key]=self:SupplyAssignment(member)
        if member.online~=false and not reasons[member.key] and request.food+request.water>0 then
            member.order=#pending+1
            pending[#pending+1]=member
        end
    end
    local cfg=self.db.groupSupplies
    if not self.groupSuppliesDragging then frame:ClearAllPoints(); frame:SetPoint(cfg.point,UIParent,cfg.relativePoint,cfg.x,cfg.y) end
    if not self.groupSuppliesDragging then self:PinGroupSuppliesTop() end
    local collapsed=cfg.collapsed
    frame.body:SetShown(not collapsed)
    frame.collapse:SetText(collapsed and "+" or "–")
    frame.title:SetText((collapsed and "Supplies" or "Group Supplies") .. " (" .. #pending .. ")")
    frame.title:SetWidth(collapsed and 128 or 230)
    frame.header:SetSize(collapsed and 132 or 252,22)
    if collapsed then frame:SetSize(220,30); frame.addList:Hide(); frame.servingMenu:Hide(); return end
    local scope=self.character.supplyScope or "all"
    local caption=({all="Whole group",mine="My subgroup",custom="Handpicked"})[scope] or ("Groups "..scope)
    frame.coverage:SetText(caption.." ▼")
    local plan=self:GroupPreparationProfile()
    table.sort(pending,function(a,b)
        local first=plan.ready[a.key] and plan.near[a.key] or false
        local second=plan.ready[b.key] and plan.near[b.key] or false
        if first~=second then return first end
        return a.order<b.order
    end)
    for index,member in ipairs(pending) do
        local row=frame.rows[index]
        if not row then
            row=CreateFrame("Frame",nil,frame.content); frame.rows[index]=row
            row:SetSize(298,32); row:SetPoint("TOPLEFT",0,-(index-1)*35)
            local bg=row:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.01,0.12,0.2,0.9)
            local line=row:CreateTexture(nil,"ARTWORK"); line:SetPoint("BOTTOMLEFT",0,0); line:SetSize(298,1); line:SetColorTexture(0.65,0.5,0.25,0.6)
            row.trade=CreateFrame("Button",nil,row)
            row.trade:SetSize(138,32); row.trade:SetPoint("TOPLEFT",0,0)
            local hover=row.trade:CreateTexture(nil,"HIGHLIGHT"); hover:SetAllPoints(); hover:SetColorTexture(1,0.82,0.35,0.14)
            row.readyDot=row.trade:CreateTexture(nil,"ARTWORK")
            row.readyDot:SetSize(6,6); row.readyDot:SetPoint("LEFT",4,0)
            row.readyDot:SetTexture("Interface\\COMMON\\Indicator-Green")
            row.name=label(row.trade,"",14,-10,123,"GameFontNormalSmall")
            row.name:SetWordWrap(false)
            row.trade:SetScript("OnClick",function() self:TradeWithSupplyMember(row.member) end)
            row.trade:SetScript("OnEnter",function()
                if not row.member then return end
                local tip=self:BeginTooltip(row.trade,row.member.name)
                tip:AddLine(row.ready and "Supplies ready." or "Still preparing supplies.",1,1,1,true)
                tip:AddLine("Click to trade when nearby.",1,1,1,true); self:FinishTooltip()
            end)
            row.trade:SetScript("OnLeave",function() self:HideTooltip() end)
            for k,kind in ipairs({"food","water"}) do
                local input=CreateFrame("EditBox",nil,row,"InputBoxTemplate")
                row[kind]=input; input:SetSize(44,22); input:SetPoint("TOPLEFT",144+(k-1)*58,-5); input:SetAutoFocus(false); input:SetMaxLetters(3)
                local function commit()
                    local target=input.editMember or row.member
                    if target then self:SetGroupSupplyAmount(target,kind,input:GetText()) end
                end
                input:SetScript("OnEditFocusGained",function() input.editMember=row.member end)
                input:SetScript("OnEnterPressed",function() commit(); input:ClearFocus() end)
                input:SetScript("OnEditFocusLost",function()
                    if input.editMember then commit() end
                    input.editMember=nil
                end)
                input:SetScript("OnEscapePressed",function()
                    local target=input.editMember or row.member
                    if target then input:SetText(tostring(self:GetGroupSupplyRequest(target)[kind])) end
                    input:ClearFocus(); self:UpdateGroupSupplies()
                end)
            end
            local skip=CreateFrame("Button",nil,row,"UIPanelButtonTemplate")
            skip:SetSize(28,22); skip:SetPoint("RIGHT",-5,0); skip:SetText("…")
            skip:SetScript("OnClick",function()
                if InCombatLockdown() or not row.member then return end
                local target=row.member
                servingMenu(self,skip,{
                    {"Doesn’t want supplies",function() self:SetSupplyDisposition(target,"declined") end},
                    {"Handled elsewhere",function() self:SetSupplyDisposition(target,"elsewhere") end},
                    {"Cancel",function() end},
                })
            end)
        end
        for _,kind in ipairs({"food","water"}) do
            local input=row[kind]
            if input.editMember and input.editMember.key~=member.key then
                input.editMember=nil; input:ClearFocus()
            end
        end
        row.member,row.ready=member,plan.ready[member.key]
        row.readyDot:SetShown(row.ready==true)
        local request=self:GetGroupSupplyRequest(member)
        row.name:SetText(member.name)
        local color=RAID_CLASS_COLORS and RAID_CLASS_COLORS[member.class]
        row.name:SetTextColor(color and color.r or 1,color and color.g or 0.82,color and color.b or 0)
        for _,kind in ipairs({"food","water"}) do
            if not row[kind].HasFocus or not row[kind]:HasFocus() then row[kind]:SetText(tostring(request[kind])) end
        end
        row:Show()
    end
    for index=#pending+1,#frame.rows do frame.rows[index].member=nil; frame.rows[index]:Hide() end
    frame.empty:SetShown(#pending==0)
    local height=math.max(1,math.min(6,#pending))*35
    frame.scroll:SetSize(298,height); frame.content:SetSize(298,math.max(1,#pending)*35)
    frame.footer:ClearAllPoints(); frame.footer:SetPoint("TOPLEFT",12,-26-height)
    frame.body:SetSize(340,80+height); frame:SetSize(340,112+height)
    frame.need:SetText(string.format("Can serve %d of %d waiting",plan.readyCount,#pending))
    local notice=self.groupTradeNotice
    if notice and GetTime()<notice.untilTime then frame.need:SetText(notice.text) else self.groupTradeNotice=nil end
    local kind=plan.missing.water>0 and plan.nextSupply.water and "water" or "food"
    local step=plan.missing[kind]>0 and plan.nextSupply[kind] or nil
    if not step and plan.bagLimited and not self.groupTradeNotice then
        frame.need:SetText(plan.readyCount>0 and ("Bags full • serve a player ("..plan.readyCount.." ready)") or "Bags full • trade a partial order or free a slot")
    end
    frame.conjure:SetText(step and ("Conjure next: " .. kind) or plan.missing.food+plan.missing.water==0 and "Supplies ready" or plan.bagLimited and "Bags full" or "Spell unavailable")
    frame.conjure:SetEnabled(step~=nil)
    frame.conjure:SetAttribute("type1",step and "spell" or ""); frame.conjure:SetAttribute("spell1",step and step.id or nil)
    local count=0
    for _,member in ipairs(members) do
        local request=self:GetGroupSupplyRequest(member)
        if member.online~=false and (request.food+request.water==0 or reasons[member.key]) then
            count=count+1
            local button=frame.addRows[count]
            if not button then
                button=CreateFrame("Button",nil,frame.addContent,"UIPanelButtonTemplate"); frame.addRows[count]=button
                button:SetSize(198,22); button:SetPoint("TOPLEFT",0,-(count-1)*24)
                button:SetScript("OnClick",function(b) if b.member then self:RestoreGroupSupply(b.member) end end)
                button:SetScript("OnEnter",function(b)
                    if not b.member then return end
                    local tip=self:BeginTooltip(b,b.member.name)
                    tip:AddLine("Click to serve this player. A completed order starts again at the class preset.",1,1,1,true)
                    self:FinishTooltip()
                end)
                button:SetScript("OnLeave",function() self:HideTooltip() end)
            end
            local reason=reasons[member.key] or "Supplied"
            if request.food+request.water==0 and (request.creditedFood or 0)+(request.creditedWater or 0)>0 then reason="Supplied" end
            button.member=member; button:SetText(member.name.." • "..reason); button:Show()
        end
    end
    for index=count+1,#frame.addRows do frame.addRows[index].member=nil; frame.addRows[index]:Hide() end
    frame.addContent:SetSize(202,math.max(1,count)*24); frame.add:SetEnabled(count>0)
    if count==0 then frame.addList:Hide() end
end
