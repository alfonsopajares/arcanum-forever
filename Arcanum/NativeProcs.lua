local _, addon = ...

-- The engine owns the aura button and its visibility/text after initialization.
-- Retain only its ordinary parent; never inspect native child visibility to
-- infer protected buff state or compact the row around active auras.
function addon:CreateNativeProc(def)
    -- Spell-ID filtering of restricted harmful auras on an assistable unit is
    -- not permitted. Self-debuffs use the generic native group below instead.
    if def.harmful then return end
    if not CustomAuraContainerSharedMixin and C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer")
    end
    local holder = CreateFrame("Frame", nil, self.procDisplay)
    holder:SetSize(176,68)
    local ok, container = pcall(CreateFrame,"AuraContainer",nil,holder,"CustomAuraContainerTemplate")
    if not ok then holder:Hide(); return end
    local success = pcall(function()
        container:SetAllPoints(holder); container:EnableMouse(false)
        container:AddAuraSlot("ARCANUM_PROC", def.target and "HARMFUL|PLAYER" or "HELPFUL", {
            sortMethod=0, sortDirection=0,
            candidateFilters={includeSpellIDs={[def.id]=true}},
            initializeFrame=function(display)
                -- Bind all restricted presentation through the supported native
                -- setters. None of these regions are retained in addon tables.
                assert(display.SetIcon and display.SetDurationText and display.SetApplicationCount)
                display:SetSize(176,68); display:SetPoint("TOPLEFT",holder,"TOPLEFT")
                display:EnableMouse(false)
                local icon=display:CreateTexture(nil,"ARTWORK")
                icon:SetSize(46,46); icon:SetPoint("TOPLEFT",4,-5); icon:SetTexCoord(0.08,0.92,0.08,0.92)
                local mask=display:CreateMaskTexture(); mask:SetAllPoints(icon)
                mask:SetTexture("Interface\\AddOns\\Arcanum\\Media\\CircleMask","CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
                icon:AddMaskTexture(mask)
                display:SetIcon(icon)
                local ring=display:CreateTexture(nil,"OVERLAY")
                ring:SetSize(52,52); ring:SetPoint("CENTER",icon,"CENTER")
                ring:SetTexture("Interface\\AddOns\\Arcanum\\Media\\Ring")
                local name=display:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
                name:SetPoint("TOPLEFT",58,-5); name:SetWidth(116); name:SetJustifyH("LEFT"); name:SetText(def.label)
                name:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",12,"OUTLINE")
                local callout=display:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
                callout:SetPoint("TOPLEFT",58,-22); callout:SetWidth(116); callout:SetJustifyH("LEFT")
                callout:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",11,"OUTLINE")
                callout:SetText(def.threshold and (def.key=="heating" and "PYROBLAST STACKS" or "DAMAGE BOOST STACKS") or def.callout)
                local timer=display:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
                timer:SetPoint("TOPLEFT",58,-49); timer:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",12,"OUTLINE")
                display:SetDurationText(timer)
                if def.max then
                    local count=display:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
                    count:SetPoint("BOTTOMRIGHT",icon,"BOTTOMRIGHT",3,-3)
                    count:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",18,"OUTLINE")
                    display:SetApplicationCount(count)
                    local bar=CreateFrame("StatusBar",nil,display)
                    bar:SetPoint("TOPLEFT",58,-40); bar:SetSize(110,4)
                    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar"); bar:SetStatusBarColor(1,0.82,0.2)
                    display:SetApplicationBar(bar,{minApplications=0,maxApplications=def.max})
                end
            end,
        })
        container:SetUnit(def.target and "target" or "player"); container:SetEnabled(true); container:Show()
    end)
    if not success then holder:Hide(); return end
    return holder
end

-- Generic self-effects cannot safely be identified by spell ID while secret.
-- The engine supplies identity as well as stacks/timers; never relabel every
-- self-debuff as Arcane Blast or inspect native children to discover its state.
function addon:StyleSelfProc(display, native)
    display:SetSize(80,94); display:EnableMouse(false)
    local icon=display:CreateTexture(nil,"ARTWORK")
    icon:SetSize(46,46); icon:SetPoint("TOP",0,-4); icon:SetTexCoord(0.08,0.92,0.08,0.92)
    local mask=display:CreateMaskTexture(); mask:SetAllPoints(icon)
    mask:SetTexture("Interface\\AddOns\\Arcanum\\Media\\CircleMask","CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE"); icon:AddMaskTexture(mask)
    local ring=display:CreateTexture(nil,"OVERLAY"); ring:SetSize(52,52); ring:SetPoint("CENTER",icon,"CENTER")
    ring:SetTexture("Interface\\AddOns\\Arcanum\\Media\\Ring")
    local name=display:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    name:SetPoint("TOP",0,-56); name:SetWidth(76); name:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",10,"OUTLINE")
    local count=display:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    count:SetPoint("BOTTOMRIGHT",icon,"BOTTOMRIGHT",3,-3); count:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",18,"OUTLINE")
    local timer=display:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    timer:SetPoint("BOTTOM",0,0); timer:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",11,"OUTLINE")
    if native then
        assert(display.SetSpellName and display.SetIcon and display.SetApplicationCount and display.SetDurationText)
        display:SetIcon(icon); display:SetSpellName(name); display:SetApplicationCount(count); display:SetDurationText(timer)
    else
        return {icon=icon,name=name,count=count,timer=timer}
    end
end

function addon:CreateNativeSelfProcs()
    local holder=CreateFrame("Frame",nil,self.procDisplay); holder:SetSize(480,94); holder:Hide()
    local ok,container=pcall(CreateFrame,"AuraContainer",nil,holder,"CustomAuraContainerTemplate")
    if not ok then return end
    local success=pcall(function()
        container:SetPoint("TOPLEFT",holder,"TOPLEFT"); container:EnableMouse(false)
        container:AddAuraGroup("ARCANUM_SELF_EFFECTS","HARMFUL",{
            sortMethod=0,sortDirection=0,maxFrameCount=6,
            candidateFilters={isFromPlayerOrPlayerPet=true,maxDuration=60},
            layout={elementWidth=80,elementHeight=94,elementSpacing=0},
            initializeFrame=function(display) self:StyleSelfProc(display,true) end,
        })
        container:SetUnit("player"); container:SetEnabled(true); container:Show()
    end)
    if not success then holder:Hide(); return end
    return holder
end

function addon:PrintProcBackendStatus()
    local slots,sounds=0,0
    for _ in pairs(self.procDisplay and self.procDisplay.native or {}) do slots=slots+1 end
    for _ in pairs(self.procNativeSounds or {}) do sounds=sounds+1 end
    print(string.format("|cff66bbffArcanum:|r Native proc slots: %d/6. Self-effects row: %s. Native gain sounds: %d. Threshold and target sounds still require readable aura data.",slots,self.procDisplay and self.procDisplay.selfEffects and "ready" or "unavailable",sounds))
end

-- Native gain sounds do not depend on Lua observing a protected aura. Keep
-- threshold sounds on the readable path: the native API has no threshold trigger.
function addon:ConfigureNativeProcSounds()
    if InCombatLockdown() then return end
    local api=C_UnitAuras
    local cfg=self.db.procs
    self.procNativeSounds=self.procNativeSounds or {}
    for _, def in ipairs(self.procTypes) do
        local opt=self:ProcOption(def.key)
        local path
        if self.procDisplay.native[def.key] and not def.target and not def.threshold and not self.procTest
            and cfg.enabled and cfg.sound and opt.enabled and opt.sound then
            for _, tone in ipairs(self.procSounds) do if tone[1]==opt.tone then path=tone[3] end end
        end
        local old=self.procNativeSounds[def.key]
        if old and old.path~=path then
            local removed=api and api.RemoveAuraSound and pcall(api.RemoveAuraSound,old.id)
            if removed then self.procNativeSounds[def.key]=nil; old=nil end
        end
        if path and not old and api and api.AddAuraSound and api.RemoveAuraSound then
            local trigger=Enum and Enum.UnitAuraSoundTrigger and Enum.UnitAuraSoundTrigger.Added or 0
            local ok,id=pcall(api.AddAuraSound,trigger,{unitToken="player",spellID=def.id,
                soundFileName=path,outputChannel="Master",throttleSeconds=1.5})
            if ok and type(id)=="number" and not (issecretvalue and issecretvalue(id)) then
                self.procNativeSounds[def.key]={id=id,path=path}
            end
        end
    end
end
