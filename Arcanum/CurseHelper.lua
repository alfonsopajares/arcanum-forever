local _, addon = ...
local outOfRangeAlpha = 0.55
local function stamp() return GetTime and GetTime() or 0 end

local function stylePanel(frame)
    frame:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true,tileSize=16,edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
    frame:SetBackdropBorderColor(0.65,0.49,0.26,1)
end

local function styleTile(frame)
    frame:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize=10,insets={left=2,right=2,top=2,bottom=2}})
    frame:SetBackdropColor(0.01,0.12,0.2,0.95)
    frame:SetBackdropBorderColor(0.55,0.43,0.25,0.9)
end

-- Native AuraContainer slots own the restricted visual. No native aura button
-- is retained, inspected, or changed by addon code after initialization.
function addon:AttachNativeCurseIndicator(button, unit)
    local ok, container = pcall(CreateFrame,"AuraContainer",nil,button,"CustomAuraContainerTemplate")
    if not ok or not container.AddAuraSlot or not container.SetUnit then return false end
    local success = pcall(function()
        container:SetAllPoints(button)
        container:EnableMouse(false)
        container:AddAuraSlot("ARCANUM_CURSE","HARMFUL",{
            sortMethod=0, sortDirection=0,
            candidateFilters={includeDispelTypes={Curse=true}},
            initializeFrame=function(display)
                display:EnableMouse(false)
                display:SetAllPoints(button)
                display:SetFrameLevel(button:GetFrameLevel()+2)
                for _, edge in ipairs({{"TOPLEFT","TOPRIGHT",72,3},{"BOTTOMLEFT","BOTTOMRIGHT",72,3},
                    {"TOPLEFT","BOTTOMLEFT",3,40},{"TOPRIGHT","BOTTOMRIGHT",3,40}}) do
                    local line=display:CreateTexture(nil,"OVERLAY")
                    line:SetPoint(edge[1]); line:SetPoint(edge[2]); line:SetSize(edge[3],edge[4]); line:SetColorTexture(0.85,0.25,1,1)
                end
                local bar=display:CreateTexture(nil,"BACKGROUND")
                bar:SetPoint("BOTTOMLEFT",3,3); bar:SetPoint("BOTTOMRIGHT",-3,3); bar:SetSize(66,15)
                bar:SetColorTexture(0.55,0.08,0.7,1)
                local label=display:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
                label:SetPoint("BOTTOM",0,4); label:SetText("CURSE")
            end,
        })
        container:SetUnit(unit); container:SetEnabled(true); container:Show()
    end)
    if not success then container:Hide(); return false end
    return true
end

function addon:CurseState(unit)
    local unknown=false
    for index=1,80 do
        local ok,aura
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            ok,aura=pcall(C_UnitAuras.GetAuraDataByIndex,unit,index,"HARMFUL")
        elseif UnitDebuff then
            local v={pcall(UnitDebuff,unit,index)}; ok=v[1]
            if ok and not (issecretvalue and issecretvalue(v[2])) and v[2]==nil then break end
            aura={dispelName=v[5]}
        else return "unknown" end
        if not ok then return "unknown" end
        if issecretvalue and issecretvalue(aura) then unknown=true
        elseif aura==nil then break
        else
            local kind=self:Readable(aura.dispelName)
            if kind=="Curse" then return "curse" end
            if issecretvalue and issecretvalue(aura.dispelName) then unknown=true end
        end
    end
    return unknown and "unknown" or "clear"
end

function addon:CreateCurseHelper()
    if self.curseHelper then return end
    local root=CreateFrame("Frame","ArcanumCurseHelper",UIParent,"BackdropTemplate")
    root:SetSize(380,400); root:SetFrameStrata("HIGH"); root:SetClampedToScreen(true)
    root:SetMovable(true); root:EnableMouse(false)
    stylePanel(root)
    root.handle=CreateFrame("Button",nil,root,"BackdropTemplate")
    root.handle:SetSize(148,20); root.handle:SetPoint("TOPLEFT",6,-4)
    root.handle:SetBackdrop({bgFile="Interface\\FrameGeneral\\UI-Background-Marble",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize=10,insets={left=2,right=2,top=2,bottom=2}})
    root.handle:SetBackdropColor(0.38,0.24,0.1,1); root.handle:SetBackdropBorderColor(0.65,0.49,0.26,1)
    root.handle.title=root.handle:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    root.handle.title:SetPoint("CENTER"); root.handle.title:SetText("Curse helper")
    root.handle:SetScript("OnEnter",function()
        if not self.db.showTooltips then return end
        self:BeginTooltip(root.handle,"Curse helper")
        self:TooltipControl("Drag","Move the helper")
        self:TooltipControl("/arc curses","Options and position lock")
        self:FinishTooltip()
    end)
    root.handle:SetScript("OnLeave",function() self:HideTooltip() end)
    root.handle:RegisterForDrag("LeftButton")
    root.handle:SetScript("OnDragStart",function() if not InCombatLockdown() and not self.db.curseHelper.locked then root:StartMoving() end end)
    root.handle:SetScript("OnDragStop",function()
        if InCombatLockdown() then return end
        root:StopMovingOrSizing()
        local point,_,relative,x,y=root:GetPoint()
        local cfg=self.db.curseHelper; cfg.point,cfg.relativePoint,cfg.x,cfg.y=point,relative,x,y
    end)
    root.party=CreateFrame("Frame",nil,root); root.party:SetAllPoints(root)
    root.raid=CreateFrame("Frame",nil,root); root.raid:SetAllPoints(root)
    root.buttons={}
    local function add(unit,index,parent)
        local b=CreateFrame("Button",nil,parent,"SecureActionButtonTemplate,BackdropTemplate")
        b.unit=unit; b:SetSize(72,40); b:SetPoint("TOPLEFT",((index-1)%5)*76,-28-math.floor((index-1)/5)*44)
        styleTile(b)
        b.fill=b:CreateTexture(nil,"ARTWORK"); b.fill:SetPoint("TOPLEFT",2,-2); b.fill:SetPoint("BOTTOMRIGHT",-2,2); b.fill:SetColorTexture(0.01,0.12,0.2,0.95)
        local highlight=b:CreateTexture(nil,"HIGHLIGHT"); highlight:SetAllPoints(b); highlight:SetColorTexture(1,0.82,0.35,0.16)
        b:RegisterForClicks("AnyDown","AnyUp"); b:SetAttribute("useOnKeyDown",false)
        b:SetAttribute("unit",unit); b:SetAttribute("checkselfcast",false); b:SetAttribute("checkfocuscast",false)
        b.name=b:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        b.name:SetPoint("TOPLEFT",4,-5); b.name:SetWidth(64); b.name:SetWordWrap(false)
        b.name:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",11,"OUTLINE")
        b.name:SetTextColor(0.5,0.82,1)
        b.status=b:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        b.status:SetPoint("BOTTOM",0,4)
        b.native=self:AttachNativeCurseIndicator(b,unit)
        b:SetScript("OnEnter",function()
            if not self.db.showTooltips then return end
            self:BeginTooltip(b,"Curse helper")
            self:TooltipControl("Left-click","Remove Lesser Curse")
            if b.outOfRange then GameTooltip:AddLine("Out of range for Remove Lesser Curse.",1,0.72,0.3,true) end
            GameTooltip:AddLine("Purple CURSE: curse detected. ? means aura data is restricted.\nDimmed squares are out of range.\nChoose the player to cleanse. Your current target is kept.",1,1,1,true)
            self:FinishTooltip()
        end)
        b:SetScript("OnLeave",function() self:HideTooltip() end)
        if RegisterUnitWatch then RegisterUnitWatch(b) end
        root.buttons[#root.buttons+1]=b
    end
    add("player",1,root.party)
    for i=1,4 do add("party"..i,i+1,root.party) end
    for i=1,40 do add("raid"..i,i,root.raid) end
    self.curseHelper=root
    local events=CreateFrame("Frame")
    for _,event in ipairs({"UNIT_AURA","UNIT_HEALTH","UNIT_FLAGS","UNIT_CONNECTION","GROUP_ROSTER_UPDATE",
        "PLAYER_ENTERING_WORLD","PLAYER_REGEN_ENABLED","PLAYER_REGEN_DISABLED","SPELLS_CHANGED"}) do events:RegisterEvent(event) end
    events:SetScript("OnEvent",function(_,event,unit)
        if event=="PLAYER_REGEN_DISABLED" then self:StopCursePreview() end
        if event=="GROUP_ROSTER_UPDATE" or event=="PLAYER_ENTERING_WORLD" or event=="PLAYER_REGEN_ENABLED" or event=="SPELLS_CHANGED" then
            if InCombatLockdown() then self.curseSettingsPending=true else self:ApplyCurseSettings() end
        end
        self:UpdateCurseHelper(event=="UNIT_AURA" or event=="PLAYER_REGEN_ENABLED")
    end)
    local elapsed=0
    events:SetScript("OnUpdate",function(_,delta)
        elapsed=elapsed+delta
        if elapsed>=0.3 then elapsed=0; self:UpdateCurseHelper(true) end
        if self.cursePreview and self.cursePreview:IsShown() and stamp()>=(self.cursePreview.ends or 0) then self:StopCursePreview() end
    end)
    self:ApplyCurseSettings()
end

function addon:ApplyCurseSettings()
    local root,cfg=self.curseHelper,self.db.curseHelper
    if not root then return end
    if InCombatLockdown() then self.curseSettingsPending=true; return end
    self.curseSettingsPending=false
    root:ClearAllPoints(); root:SetPoint(cfg.point,UIParent,cfg.relativePoint,cfg.x,cfg.y); root:SetScale(cfg.scale/100)
    root.handle:SetShown(not cfg.locked)
    -- Size to the current roster outside combat. Keep all secure unit buttons
    -- precreated so native unit watches still handle combat roster changes.
    local raid=IsInRaid and self:Readable(IsInRaid())==true
    local last=1
    for index=1,(raid and 40 or 5) do
        local unit=raid and ("raid"..index) or (index==1 and "player" or "party"..(index-1))
        if UnitExists and self:Readable(UnitExists(unit))==true then last=index end
    end
    local top=cfg.locked and 6 or 28
    local width=math.max(96,math.min(5,last)*76+8)
    root:SetSize(width,top+math.ceil(last/5)*44+2)
    root.handle:SetSize(width-12,20)
    for index,b in ipairs(root.buttons) do
        local slot=index<=5 and index or index-5
        b:ClearAllPoints(); b:SetPoint("TOPLEFT",6+((slot-1)%5)*76,-top-math.floor((slot-1)/5)*44)
    end
    if RegisterStateDriver then
        RegisterStateDriver(root.party,"visibility","[group:raid] hide; show")
        RegisterStateDriver(root.raid,"visibility","[group:raid] show; hide")
    else
        root.raid:SetShown(raid)
        root.party:SetShown(not raid)
    end
    local learned=self:KnownSpell(475)
    for _,b in ipairs(root.buttons) do
        b:SetAttribute("type1",cfg.enabled and learned and "spell" or "")
        b:SetAttribute("spell1",learned and 475 or nil)
    end
    self:UpdateCurseHelper(false)
end

local function updateVisibility(root,enabled,hideWhenSolo,grouped,showSolo)
    if InCombatLockdown() then return end
    if not RegisterStateDriver then
        root:SetShown(enabled and (grouped or (not hideWhenSolo and showSolo)))
        return
    end

    local rule="hide"
    if enabled then
        rule="[group:raid] show; [group:party] show; "
        if hideWhenSolo then
            rule=rule.."hide"
        else
            -- Blizzard owns visibility in combat so the self-cast stays clickable.
            rule=rule.."[combat] show; "..(showSolo and "show" or "hide")
        end
    end
    if root.visibilityRule~=rule then
        RegisterStateDriver(root,"visibility",rule)
        root.visibilityRule=rule
    end
end

function addon:UpdateCurseHelper(allowSound)
    local root,cfg=self.curseHelper,self.db.curseHelper
    if not root then return end
    local enabled=cfg.enabled and self:KnownSpell(475)
    local raid=IsInRaid and self:Readable(IsInRaid())==true
    local grouped=raid or (IsInGroup and self:Readable(IsInGroup())==true)
    local active=enabled and (grouped or not cfg.hideWhenSolo)
    local selfCurse=active and not grouped and self:CurseState("player") or nil
    local editing=not cfg.locked and self.settings and self.settings.selected=="Curses" and self.settings:IsShown()
    updateVisibility(root,enabled,cfg.hideWhenSolo,grouped,selfCurse=="curse" or editing)
    if not enabled then return end
    local newCurse=false
    for _,b in ipairs(root.buttons) do
        local relevant=(b.unit:sub(1,4)=="raid")==raid
        if relevant and (grouped or b.unit=="player") and UnitExists and self:Readable(UnitExists(b.unit))==true then
            local rawName=UnitName and UnitName(b.unit)
            if issecretvalue and issecretvalue(rawName) then b.name:SetText(rawName)
            else b.name:SetText(type(rawName)=="string" and rawName or b.unit) end
            local guid=UnitGUID and self:Readable(UnitGUID(b.unit))
            if guid and guid~=b.member then b.member=guid; b.previous=nil end
            local state=(b.unit=="player" and selfCurse) or self:CurseState(b.unit)
            b.curseState=state
            local dead=UnitIsDeadOrGhost and self:Readable(UnitIsDeadOrGhost(b.unit))==true
            local offline=UnitIsConnected and self:Readable(UnitIsConnected(b.unit))==false
            local range
            if C_Spell and C_Spell.IsSpellInRange then
                local ok,value=pcall(C_Spell.IsSpellInRange,475,b.unit)
                if ok then range=self:Readable(value) end
            end
            local outOfRange=range==false
            if b.outOfRange~=outOfRange then
                b.outOfRange=outOfRange
                b:SetAlpha(outOfRange and outOfRangeAlpha or 1)
            end
            b.status:SetText(offline and "Offline" or dead and "Dead" or outOfRange and "Far" or state=="curse" and "CURSE" or state=="unknown" and "?" or "")
            b.status:SetTextColor(state=="curse" and 0.9 or 0.8,state=="curse" and 0.35 or 0.8,1)
            b.fill:SetColorTexture(state=="curse" and 0.45 or 0.01,state=="curse" and 0.1 or 0.12,state=="curse" and 0.6 or 0.2,0.95)
            if active and not dead and not offline and state=="curse" and b.previous~="curse" then newCurse=true end
            if state~="unknown" then b.previous=state end
        elseif relevant then b.member=nil; b.previous=nil; b.curseState=nil end
    end
    if allowSound and newCurse and cfg.sound and stamp()-(self.curseLastSound or -100)>=3 and PlaySoundFile then
        self.curseLastSound=stamp(); PlaySoundFile("Interface\\AddOns\\Arcanum\\Media\\ProcChime.wav","Master")
    end
end

function addon:StopCursePreview() if self.cursePreview then self.cursePreview:Hide() end end

function addon:PreviewCurseHelper()
    if InCombatLockdown() then return end
    if not self.cursePreview then
        local panel=CreateFrame("Frame",nil,UIParent,"BackdropTemplate")
        panel:SetSize(388,74); panel:SetFrameStrata("DIALOG"); panel:EnableMouse(true); stylePanel(panel)
        local title=panel:CreateFontString(nil,"OVERLAY","GameFontNormal")
        title:SetPoint("TOP",0,-7); title:SetText("Curse helper · Preview (15s)")
        for i,entry in ipairs({{"You",""},{"Cursed mage","CURSE"},{"Far player","Far"},{"Fallen ally","Dead"},{"Restricted","?"}}) do
            local cell=CreateFrame("Frame",nil,panel,"BackdropTemplate")
            cell:SetSize(72,40); cell:SetPoint("TOPLEFT",6+(i-1)*76,-28)
            styleTile(cell); cell:SetBackdropColor(i==2 and 0.55 or 0.01,i==2 and 0.1 or 0.12,i==2 and 0.7 or 0.2,1)
            if entry[2]=="Far" then cell:SetAlpha(outOfRangeAlpha) end
            local name=cell:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); name:SetPoint("TOP",0,-5); name:SetWidth(66); name:SetText(entry[1]); name:SetTextColor(0.5,0.82,1)
            local status=cell:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); status:SetPoint("BOTTOM",0,4); status:SetText(entry[2])
        end
        self.cursePreview=panel
    end
    local cfg=self.db.curseHelper
    self.cursePreview:ClearAllPoints(); self.cursePreview:SetPoint(cfg.point,UIParent,cfg.relativePoint,cfg.x,cfg.y)
    self.cursePreview:SetScale(cfg.scale/100); self.cursePreview.ends=stamp()+15; self.cursePreview:Show()
end
