local _, addon = ...

local intellectRanks = {1459,1460,1461,10156,10157}
local recipientLevels = {1,4,17,32,46}
local castErrors = {
    "SPELL_FAILED_LINE_OF_SIGHT", "SPELL_FAILED_OUT_OF_RANGE", "ERR_SPELL_OUT_OF_RANGE",
    "SPELL_FAILED_NO_POWER", "ERR_OUT_OF_MANA", "SPELL_FAILED_NOT_READY", "ERR_SPELL_COOLDOWN",
    "SPELL_FAILED_SPELL_IN_PROGRESS", "ERR_SPELL_IN_PROGRESS", "SPELL_FAILED_AURA_BOUNCED",
    "SPELL_FAILED_BAD_TARGETS", "SPELL_FAILED_TARGET_TOO_LOW", "SPELL_FAILED_TARGETS_DEAD",
    "SPELL_FAILED_SILENCED", "SPELL_FAILED_STUNNED", "SPELL_FAILED_PACIFIED",
}
local function now() return GetTime and GetTime() or 0 end

local function reportFailure(reason)
    print("|cff66bbffArcanum:|r Drive-by Intellect — " .. reason)
end

local function reportAttemptFailure(addon, attempt, fallback)
    if addon.driveByPending ~= attempt then return end
    addon.driveByPending = nil
    reportFailure(attempt.error or fallback)
end

function addon:DriveByRank(unit)
    local level = UnitLevel and self:Readable(UnitLevel(unit))
    local selected, lowest
    for index, id in ipairs(intellectRanks) do
        if self:KnownSpell(id) then
            lowest = lowest or id
            if type(level)=="number" and level>0 and level>=recipientLevels[index] then selected=id end
        end
    end
    if type(level)~="number" or level<=0 then return lowest end
    return selected
end

function addon:DriveByEligible(unit)
    if not UnitIsPlayer or self:Readable(UnitIsPlayer(unit))~=true then return false end
    if UnitIsUnit and self:Readable(UnitIsUnit(unit,"player"))==true then return false, "Hover another player." end
    if not UnitCanAssist or self:Readable(UnitCanAssist("player",unit))~=true then
        return false, "You can only buff a friendly player."
    end
    local dead = UnitIsDeadOrGhost and self:Readable(UnitIsDeadOrGhost(unit))
    if dead then return false, "That player is dead." end
    if dead == nil then return false, "That player’s status is unavailable." end
    if self.db.driveBy.manaOnly then
        local power = UnitPowerType and self:Readable(UnitPowerType(unit))
        if power == nil then return false, "Couldn’t verify the player’s mana for the mana-only filter." end
        if power~=0 then return false, "The mana-only filter is on and that player doesn’t use mana." end
    end
    return true
end

-- Equal ranks can be refreshed. Only a confirmed stronger aura blocks the cast.
function addon:DriveByHasStrongerIntellect(unit, selected)
    local rankByID={}; for index,id in ipairs(intellectRanks) do rankByID[id]=index end
    rankByID[23028]=#intellectRanks -- Arcane Brilliance grants rank-five Intellect.
    local wanted=rankByID[selected]
    for index=1,80 do
        local ok,aura
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            ok,aura=pcall(C_UnitAuras.GetAuraDataByIndex,unit,index,"HELPFUL")
        elseif UnitBuff then
            local v={pcall(UnitBuff,unit,index)}
            ok=v[1]
            if ok and self:Readable(v[2])==nil then return false end
            aura={spellId=v[11]}
        else return false end
        if not ok or self:Readable(aura)==nil then return false end
        local id=self:Readable(aura.spellId)
        if type(id)=="number" and rankByID[id] and rankByID[id]>wanted then return true end
    end
    return false
end

function addon:ConfigureDriveBy(capture)
    if InCombatLockdown() then return end
    local button=self.keyButtons and self.keyButtons.DriveBy
    if not button then return end
    button:SetAttribute("type1","")
    button:SetAttribute("spell1",nil)
    button:SetAttribute("unit1","none")
    button:SetAttribute("checkselfcast",false)
    button:SetAttribute("checkfocuscast",false)
    if capture then self.driveByPending=nil end
    local function skip(reason)
        if capture then reportFailure(reason) end
    end
    if not self.db.driveBy.enabled then return skip("The keybind is disabled in Arcanum’s Buffs settings.") end
    local eligible, reason = self:DriveByEligible("mouseover")
    local unit = eligible and "mouseover" or nil
    if not unit and self.db.driveBy.targetFallback then
        local targetEligible, targetReason = self:DriveByEligible("target")
        if targetEligible then unit = "target" else reason = reason or targetReason end
    end
    if not unit then return skip(reason or "Hover a living, friendly player.") end
    local spell=self:DriveByRank(unit)
    if not spell then return skip("You haven’t learned an Arcane Intellect rank this player can receive.") end
    if self.db.driveBy.skipBuffed and self:DriveByHasStrongerIntellect(unit,spell) then
        return skip("That player already has a stronger Arcane Intellect buff.")
    end
    if capture and C_Spell then
        if C_Spell.IsSpellInRange then
            local ok, inRange = pcall(C_Spell.IsSpellInRange, spell, unit)
            if ok and self:Readable(inRange) == false then return skip("That player is out of range.") end
        end
        if C_Spell.IsSpellUsable then
            local ok, _, insufficientPower = pcall(C_Spell.IsSpellUsable, spell)
            if ok and self:Readable(insufficientPower) == true then return skip("Not enough mana.") end
        end
    end
    button:SetAttribute("unit1",unit)
    button:SetAttribute("spell1",spell)
    button:SetAttribute("type1","spell")
    if capture then
        local attempt = {spell=spell, name=UnitName and self:Readable(UnitName(unit)) or "Player", time=now()}
        self.driveByPending = attempt
        if C_Timer and C_Timer.After then
            C_Timer.After(3, function()
                reportAttemptFailure(self, attempt, "The game didn’t confirm the Arcane Intellect cast.")
            end)
        end
    end
end

function addon:SetupDriveBy()
    local button=self.keyButtons.DriveBy
    -- PreClick only sets up a normal secure spell action outside combat.
    -- The secure wrapper also suppresses an action armed before combat began.
    SecureHandlerWrapScript(button,"OnClick",button,[[
        if SecureCmdOptionParse("[combat] combat") then self:SetAttribute("type1","") end
    ]])
    button:HookScript("PreClick",function(_,_,down)
        if down then return end
        if InCombatLockdown() then
            reportFailure("Drive-by Intellect is available outside combat.")
        else
            self:ConfigureDriveBy(true)
        end
    end)
    self.driveByNotice=CreateFrame("Frame",nil,UIParent)
    self.driveByNotice:SetSize(270,28); self.driveByNotice:SetFrameStrata("HIGH")
    self.driveByNotice.text=self.driveByNotice:CreateFontString(nil,"OVERLAY","GameFontNormal")
    self.driveByNotice.text:SetAllPoints()
    self.driveByNotice.text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",13,"OUTLINE")
    self.driveByNotice:SetScript("OnUpdate",function()
        if now()>=(self.driveByNotice.untilTime or 0) then self.driveByNotice:Hide() end
    end)
    self.driveByNotice:Hide()
    self:ConfigureDriveBy()
end

function addon:DriveByErrorEvent(message)
    local attempt = self.driveByPending
    local text = self:Readable(message)
    if not attempt or type(text) ~= "string" then return end
    local age = now() - attempt.time
    if age > 3 or (not attempt.cast and age > 0.5) then return end
    for _, key in ipairs(castErrors) do
        if text == _G[key] then
            attempt.error = text
            if not attempt.cast and C_Timer and C_Timer.After then
                C_Timer.After(0.25, function()
                    if not attempt.cast then reportAttemptFailure(self, attempt, text) end
                end)
            end
            return
        end
    end
end

function addon:DriveBySpellEvent(event,unit,a,b,c)
    if self:Readable(unit)~="player" then return end
    local pending=self.driveByPending
    if not pending then return end
    if now()-pending.time>3 then return end
    if event=="UNIT_SPELLCAST_SENT" then
        if not pending.cast and self:Readable(c)==pending.spell then pending.cast=self:Readable(b) end
        return
    end
    if not pending.cast or self:Readable(a)~=pending.cast then return end
    if event=="UNIT_SPELLCAST_INTERRUPTED" then
        reportAttemptFailure(self, pending, "Arcane Intellect was interrupted.")
        return
    end
    if event=="UNIT_SPELLCAST_FAILED" then
        local reason = "The game rejected the Arcane Intellect cast."
        if pending.error or not (C_Timer and C_Timer.After) then
            reportAttemptFailure(self, pending, reason)
        else
            -- The client's error text can arrive just after the failed-cast event.
            C_Timer.After(0.25, function() reportAttemptFailure(self, pending, reason) end)
        end
        return
    end
    if event~="UNIT_SPELLCAST_SUCCEEDED" or self:Readable(b)~=pending.spell then return end
    self.driveByPending=nil
    if self.db.driveBy.confirm then
        local notice=self.driveByNotice
        notice:ClearAllPoints(); notice:SetPoint("BOTTOM",self.frame,"TOP",0,self.db.radius+32)
        notice.text:SetText("Intellect → "..(type(pending.name)=="string" and pending.name or "Player"))
        notice.untilTime=now()+2; notice:Show()
    end
    if self.db.driveBy.sound and PlaySoundFile then
        PlaySoundFile("Interface\\AddOns\\Arcanum\\Media\\ProcChime.wav","Master")
    end
end
