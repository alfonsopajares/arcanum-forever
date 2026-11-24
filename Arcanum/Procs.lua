local _, addon = ...

-- Aura spell IDs, not the talent IDs. Names also come from the client so
-- renamed/localized versions can be found without inferring procs from casts.
addon.procTypes = {
    {key="clearcasting", label="Clearcasting", id=12536, callout="FREE CAST", sound="chime", duration=15},
    {key="missiles", label="Missile Barrage", id=400589, callout="MISSILES READY", sound="pulse", duration=15},
    {key="fingers", label="Fingers of Frost", id=400670, callout="TARGET COUNTS AS FROZEN", sound="frost", duration=15, max=2},
    {key="heating", label="Heating Up", id=400625, callout="FASTER PYROBLAST", sound="fire", duration=20, max=3, threshold=3},
    {key="arcane", label="Arcane Blast", id=400573, nameID=400574, callout="SPELL DAMAGE BOOST", sound="pulse", duration=18, max=4, threshold=4, harmful=true, quiet=true},
    {key="winter", label="Winter's Chill", id=12579, callout="CONE OF COLD BONUS", sound="frost", duration=15, max=5, threshold=5, target=true, quiet=true},
    {key="ignite", label="Ignite", id=12654, icon="Interface\\Icons\\Spell_Fire_Incinerate", callout="YOUR TARGET IS BURNING", sound="fire", duration=4, target=true, quiet=true},
}

addon.procSounds = {
    {"chime", "Arcane chime", "Interface\\AddOns\\Arcanum\\Media\\ProcChime.wav"},
    {"pulse", "Arcane pulse", "Interface\\AddOns\\Arcanum\\Media\\ProcPulse.wav"},
    {"frost", "Frost chime", "Interface\\AddOns\\Arcanum\\Media\\ProcFrost.wav"},
    {"fire", "Fire pulse", "Interface\\AddOns\\Arcanum\\Media\\ProcFire.wav"},
}

local function clock() return GetTime and GetTime() or 0 end
local function secret(value) return issecretvalue and issecretvalue(value) end

function addon:ProcDefinition(key)
    for _, def in ipairs(self.procTypes) do if def.key == key then return def end end
end

function addon:ProcOption(key)
    return self.db.procs.effects[key]
end

-- Only confirmed ownership is accepted for personal effects on the enemy.
-- Unknown/protected ownership is not treated as the player's application.
function addon:OwnProcAura(aura)
    local source = self:Readable(aura.sourceUnit)
    if source == "player" then return true end
    if type(source) == "string" and UnitIsUnit then
        local ok, own = pcall(UnitIsUnit, source, "player")
        return ok and self:Readable(own) == true
    end
    return false
end

function addon:FindProcAura(def)
    local unit = def.target and "target" or "player"
    if def.target and (not UnitExists or self:Readable(UnitExists(unit)) ~= true
        or not UnitCanAttack or self:Readable(UnitCanAttack("player", unit)) ~= true
        or (UnitIsDeadOrGhost and self:Readable(UnitIsDeadOrGhost(unit)) == true)) then return nil, "absent" end
    local api, unknown = C_UnitAuras, false
    local filter = def.target and "HARMFUL|PLAYER" or def.harmful and "HARMFUL" or "HELPFUL"
    local name = self:SpellInfo(def.nameID or def.id)
    local function accept(aura)
        if secret(aura) then unknown = true; return end
        if type(aura) == "table" then
            if not def.target or self:OwnProcAura(aura) then return aura end
            if self:Readable(aura.sourceUnit) == nil then unknown = true end
        end
    end
    if api and api.GetUnitAuraBySpellID then
        local ok, aura = pcall(api.GetUnitAuraBySpellID, unit, def.id)
        if ok then local found = accept(aura); if found then return found, "active" end
        else unknown = true end
    end
    if api and api.GetAuraDataBySpellName and name then
        local ok, aura = pcall(api.GetAuraDataBySpellName, unit, name, filter)
        if ok then local found = accept(aura); if found then return found, "active" end
        else unknown = true end
    end
    -- A scan can find the player's copy when the first ID match belongs to
    -- another mage. Never inspect protected IDs, names, or ownership.
    for index = 1, 80 do
        local ok, aura
        if api and api.GetAuraDataByIndex then
            ok, aura = pcall(api.GetAuraDataByIndex, unit, index, filter)
        else
            local query = (def.target or def.harmful) and UnitDebuff or UnitBuff
            if not query then return nil, "unavailable" end
            local v = {pcall(query, unit, index, filter)}
            ok = v[1]
            if ok and not secret(v[2]) and v[2] == nil then break end
            aura = ok and {name=v[2], icon=v[3], applications=v[4], duration=v[6], expirationTime=v[7], sourceUnit=v[8], spellId=v[11]} or nil
        end
        if not ok then return nil, "unavailable" end
        if secret(aura) then unknown = true
        elseif aura == nil then break
        else
            local id, auraName = self:Readable(aura.spellId), self:Readable(aura.name)
            if id == def.id or (name and auraName == name) then
                local found = accept(aura); if found then return found, "active" end
            elseif id == nil and auraName == nil then unknown = true end
        end
    end
    return nil, unknown and "unavailable" or "absent"
end

function addon:PlayProcSound(key, preview)
    local def, opt = self:ProcDefinition(key), self:ProcOption(key)
    if not def or not opt or (not preview and (not self.db.procs.sound or not opt.sound)) then return end
    if not preview and self.procNativeSounds and self.procNativeSounds[key] then return end
    local now = clock()
    self.procLastSound = self.procLastSound or {}
    if not preview and (now - (self.procLastSound[key] or -100) < 1.5
        or now - (self.procAnySound or -100) < 0.25) then return end
    for _, entry in ipairs(self.procSounds) do
        if entry[1] == opt.tone and PlaySoundFile then
            PlaySoundFile(entry[3], "Master")
            self.procLastSound[key], self.procAnySound = now, now
            return
        end
    end
end

function addon:CreateProcDisplay()
    if self.procDisplay then return end
    local frame = CreateFrame("Frame", "ArcanumProcDisplay", UIParent)
    frame:SetSize(548, 148); frame:SetFrameStrata("HIGH"); frame:SetClampedToScreen(true)
    frame:SetMovable(true); frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() if not self.db.procs.locked then frame:StartMoving() end end)
    frame:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        local point, _, relativePoint, x, y = frame:GetPoint()
        self.db.procs.point, self.db.procs.relativePoint, self.db.procs.x, self.db.procs.y = point, relativePoint, x, y
    end)
    frame.handle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.handle:SetPoint("TOP", 0, 0)
    frame.handle:SetText("Arcanum alerts — drag here")
    frame.testLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.testLabel:SetPoint("BOTTOM", 0, -18)
    frame.testLabel:SetText("TEST ALERTS — /arc procs stop")
    frame.cards, frame.native = {}, {}
    for _, def in ipairs(self.procTypes) do
        local card = CreateFrame("Frame", nil, frame)
        card:SetSize(176, 68)
        card.icon = card:CreateTexture(nil, "ARTWORK")
        card.icon:SetSize(46, 46); card.icon:SetPoint("TOPLEFT", 4, -5)
        local _, icon = self:SpellInfo(def.id)
        card.icon:SetTexture(def.icon or icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        card.icon:SetTexCoord(0.08,0.92,0.08,0.92)
        local mask = card:CreateMaskTexture()
        mask:SetAllPoints(card.icon)
        mask:SetTexture("Interface\\AddOns\\Arcanum\\Media\\CircleMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        card.icon:AddMaskTexture(mask)
        card.glow = card:CreateTexture(nil, "OVERLAY")
        card.glow:SetSize(52,52); card.glow:SetPoint("CENTER", card.icon, "CENTER")
        card.glow:SetTexture("Interface\\AddOns\\Arcanum\\Media\\Ring")
        card.glow:SetVertexColor(1,0.8,0.35)
        -- The shared circle ring is blue: tinting it cannot make a bright gold
        -- highlight. Use a separate, broader gold halo for maximum stacks.
        card.readyGlow = card:CreateTexture(nil, "OVERLAY")
        card.readyGlow:SetSize(62,62); card.readyGlow:SetPoint("CENTER",card.icon,"CENTER")
        card.readyGlow:SetTexture("Interface\\AddOns\\Arcanum\\Media\\ProcReady")
        card.readyGlow:SetBlendMode("ADD"); card.readyGlow:Hide()
        card.name = card:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        card.name:SetPoint("TOPLEFT",58,-5); card.name:SetWidth(116); card.name:SetJustifyH("LEFT"); card.name:SetText(def.label)
        card.name:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",12,"OUTLINE")
        card.callout = card:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        card.callout:SetPoint("TOPLEFT",58,-22); card.callout:SetWidth(116); card.callout:SetJustifyH("LEFT")
        card.callout:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",11,"OUTLINE")
        card.timer = card:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        card.timer:SetPoint("TOPLEFT",58,-49)
        card.timer:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",12,"OUTLINE")
        card.count = card:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
        card.count:SetPoint("BOTTOMRIGHT",card.icon,"BOTTOMRIGHT",3,-3)
        card.count:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",18,"OUTLINE")
        card:Hide(); frame.cards[def.key] = card
    end
    frame.elapsed = 0
    frame:SetScript("OnUpdate", function(_, delta)
        frame.elapsed = frame.elapsed + delta
        if frame.elapsed >= 0.1 then frame.elapsed = 0; self:UpdateProcDisplay(true) end
    end)
    self.procDisplay, self.procPrevious, self.procStates = frame, {}, {}
    for _, def in ipairs(self.procTypes) do frame.native[def.key]=self:CreateNativeProc(def) end
    frame.selfEffects=self:CreateNativeSelfProcs()
    frame.selfPreview=CreateFrame("Frame",nil,frame)
    frame.selfPreview:SetSize(80,94); frame.selfPreview.regions=self:StyleSelfProc(frame.selfPreview,false); frame.selfPreview:Hide()
    self:ApplyProcSettings()
end

function addon:ApplyProcSettings()
    local frame, opt = self.procDisplay, self.db.procs
    if not frame then return end
    frame:ClearAllPoints(); frame:SetPoint(opt.point, UIParent, opt.relativePoint, opt.x, opt.y)
    frame:SetScale(opt.scale / 100); frame:EnableMouse(not opt.locked)
    frame.handle:SetShown(not opt.locked)
    self:ConfigureNativeProcSounds()
    self:UpdateProcDisplay(false)
end

function addon:UpdateProcDisplay(allowSound)
    local frame = self.procDisplay
    if not frame then return end
    local cfg, now, visible = self.db.procs, clock(), {}
    if self.procTest and now >= self.procTest.ends then self:StopProcTest(); return end
    for _, def in ipairs(self.procTypes) do
        local card, opt = frame.cards[def.key], self:ProcOption(def.key)
        local aura, state
        if self.procTest then
            aura = self.procTest.auras[def.key]; state = "test"
            if aura and now >= aura.expirationTime then self.procTest.auras[def.key] = nil; aura = nil end
        else aura, state = self:FindProcAura(def) end
        self.procStates[def.key] = state
        local enabled = cfg.enabled and opt.enabled and (def.key ~= "ignite" or self.db.showIgnite)
        if self.procTest then enabled = true end
        local previous = self.procPrevious[def.key]
        if aura then
            local stacks = self:Readable(aura.applications)
            local count = type(stacks) == "number" and stacks or nil
            local ready = not def.threshold or (count ~= nil and count >= def.threshold)
            -- A threshold alert can only fire with a readable stack count.
            if enabled and ready and allowSound and previous and not previous.ready and not self.procTest then self:PlayProcSound(def.key) end
            if enabled and ready and (not previous or not previous.ready) then card.pulseUntil = now + 0.65 end
            -- Losing access to stacks must not manufacture a below-threshold
            -- observation and then sound again when access returns.
            if not def.threshold or count ~= nil then self.procPrevious[def.key] = {ready=ready} end
            local selfDisplay=def.harmful and frame.selfEffects
            if enabled and not selfDisplay and not (frame.native[def.key] and InCombatLockdown() and not self.procTest) then
                visible[#visible+1] = card
                card.count:SetText("")
                if def.max then
                    if count then card.count:SetText(tostring(math.max(1,count)) .. "/" .. def.max)
                    elseif secret(aura.applications) then card.count:SetFormattedText("%d",aura.applications)
                    else card.count:SetText("?") end
                end
                local callout = def.callout
                if def.key == "heating" and not ready then callout = "BUILDING PYROBLAST" end
                local maximum = def.max ~= nil and count ~= nil and count >= def.max
                card.readyGlow:SetShown(maximum)
                if maximum then callout = "MAX STACKS" end
                card.count:SetTextColor(1, maximum and 0.85 or 1, maximum and 0.2 or 1)
                card.callout:SetText(callout)
                local expiry = self:Readable(aura.expirationTime)
                if type(expiry) == "number" and expiry > 0 then
                    card.timer:SetText(string.format("%.1fs", math.max(0,expiry-now)))
                else card.timer:SetText(secret(aura.expirationTime) and "Timer unavailable" or "Active") end
                local pulse = card.pulseUntil and now < card.pulseUntil
                card.glow:SetAlpha(pulse and 1 or ready and 0.75 or 0.3)
                card.readyGlow:SetAlpha(pulse and 1 or 0.9)
                card:SetAlpha(pulse and 1 or 0.95)
            end
        else
            -- A restricted read cannot re-arm a sound as if the buff ended.
            if state ~= "unavailable" then self.procPrevious[def.key] = {ready=false} end
        end
        card:Hide()
    end
    local nativeCount=0
    for _, def in ipairs(self.procTypes) do
        local holder=frame.native[def.key]
        if holder then
            local enabled=cfg.enabled and self:ProcOption(def.key).enabled and InCombatLockdown() and not self.procTest
                and (def.key~="ignite" or self.db.showIgnite)
            if enabled then
                holder:ClearAllPoints()
                holder:SetPoint("TOPLEFT",(nativeCount%3)*184,-20-math.floor(nativeCount/3)*72)
                nativeCount=nativeCount+1
            end
            holder:SetShown(enabled)
        end
    end
    local total=nativeCount+#visible
    local cols = math.min(3,math.max(1,total))
    for index, card in ipairs(visible) do
        card:ClearAllPoints()
        local slot=nativeCount+index-1
        card:SetPoint("TOPLEFT", (slot%3)*184, -20-math.floor(slot/3)*72)
        card:Show()
    end
    local rows=math.max(1,math.ceil(total/3))
    local showSelf=frame.selfEffects and cfg.enabled and self:ProcOption("arcane").enabled and not self.procTest
    if frame.selfEffects then
        frame.selfEffects:ClearAllPoints(); frame.selfEffects:SetPoint("TOPLEFT",0,-20-rows*72)
        frame.selfEffects:SetShown(showSelf and true or false)
    end
    local sample=self.procTest and self.procTest.auras.arcane
    local showSample=sample and frame.selfEffects
    frame.selfPreview:SetShown(showSample and true or false)
    if showSample then
        local r=frame.selfPreview.regions
        local def=self:ProcDefinition("arcane")
        local _,icon=self:SpellInfo(def.nameID or def.id)
        r.icon:SetTexture(icon or "Interface\\Icons\\Spell_Arcane_Blast")
        r.name:SetText("Arcane Blast"); r.count:SetText(tostring(sample.applications))
        r.timer:SetText(string.format("%.1fs",math.max(0,sample.expirationTime-now)))
        frame.selfPreview:ClearAllPoints(); frame.selfPreview:SetPoint("TOPLEFT",0,-20-rows*72)
    end
    frame:SetSize(math.max(cols*184,showSelf and 480 or 0),rows*72+20+((showSelf or showSample) and 98 or 0))
    frame.testLabel:SetShown(self.procTest ~= nil)
    -- The controller stays shown so its ticker can discover newly active auras.
end

function addon:TestProc(key, operation)
    if InCombatLockdown() then print("|cff66bbffArcanum:|r Test alerts are available outside combat."); return false end
    if operation == "stop" then self:StopProcTest(); return true end
    local now = clock()
    self.procTest = self.procTest or {auras={}, ends=now+30}
    self.procTest.ends = now+30
    self:ConfigureNativeProcSounds()
    local function fill(def, count)
        self.procTest.auras[def.key] = {applications=count or 1,expirationTime=now+def.duration,sourceUnit="player"}
    end
    if key == "all" then
        for _, def in ipairs(self.procTypes) do fill(def,def.max) end
    else
        local def = self:ProcDefinition(key)
        if not def then return false end
        local aura = self.procTest.auras[key]
        if operation == "expire" then self.procTest.auras[key] = nil
        elseif operation == "consume" then
            if def.key == "fingers" and aura and aura.applications > 1 then aura.applications = aura.applications-1
            else self.procTest.auras[key] = nil end
        else
            fill(def,def.max and math.min(def.max, (aura and aura.applications or 0)+1) or 1)
            if not def.threshold or self.procTest.auras[key].applications >= def.threshold then self:PlayProcSound(key,false) end
        end
    end
    self:ConfigureNativeProcSounds()
    self:UpdateProcDisplay(false)
    return true
end

function addon:StopProcTest()
    self.procTest, self.procPrevious = nil, {}
    if self.procDisplay then self:ConfigureNativeProcSounds(); self:UpdateProcDisplay(false) end
end

-- Existing callers and saved Ignite visibility keep working with the new row.
function addon:CreateIgniteDisplay() self:CreateProcDisplay() end
function addon:UpdateIgniteDisplay() self:UpdateProcDisplay(false) end
