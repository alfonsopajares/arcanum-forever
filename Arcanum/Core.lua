local addonName, addon = ...

local function printMessage(message)
    print("|cff66bbffArcanum:|r " .. message)
end

function addon:HandleCommand(command)
    command = (command or ""):match("^%s*(.-)%s*$"):lower()
    if command == "help" then
        printMessage("/arc opens options. /arc toggle hides or shows the circle. /arc [lock | reset | refresh].")
        return
    end
    if command == "" or command == "settings" then self:OpenSettings(); return end
    if InCombatLockdown() then
        printMessage("Layout changes are available after combat. Spell menus still work.")
        return
    end
    if command == "toggle" then
        self.db.visible = not self.db.visible
        self.frame:SetShown(self.db.visible)
        self:UpdateReminders()
    elseif command == "lock" then
        self.db.locked = not self.db.locked
        printMessage(self.db.locked and "Position locked." or "Position unlocked. Drag the center to move.")
    elseif command == "reset" then
        for _, key in ipairs({"visible","locked","point","relativePoint","x","y","scale","radius","rotation"}) do
            self.db[key] = self.defaults[key]
        end
        self:RestorePosition()
        self.frame:Show()
        for _, menu in pairs(self.menus) do
            menu:SetAttribute("pinned", nil)
            menu:Hide()
        end
        printMessage("Layout reset.")
        self.db.categoryOrder = {}
        self:ApplySettings()
    elseif command == "refresh" then
        self:RefreshActions()
        printMessage("Learned spells and carried items refreshed.")
    else
        printMessage("/arc opens options. /arc toggle hides or shows the circle. /arc [lock | reset | refresh].")
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, event, unit, powerType, third, fourth)
    if event == "ADDON_LOADED" then
        if unit ~= addonName then return end
        events:UnregisterEvent("ADDON_LOADED")
        local _, class = UnitClass("player")
        if class ~= "MAGE" then return end
        addon:InitializeSettings()
        addon:CreateCircle()
        addon:CreateIgniteDisplay()
        addon:CreateMinimapButton()
        SLASH_ARCANUM1 = "/arc"
        SlashCmdList.ARCANUM = function(command) addon:HandleCommand(command) end
        local getMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
        local version = getMetadata and getMetadata(addonName, "Version") or "unknown"
        printMessage("v" .. version .. " loaded. Use /arc for options or /arc toggle to hide or show the circle.")
        events:RegisterEvent("UNIT_POWER_UPDATE")
        events:RegisterEvent("UNIT_MAXPOWER")
        events:RegisterEvent("PLAYER_ENTERING_WORLD")
        events:RegisterEvent("SPELLS_CHANGED")
        events:RegisterEvent("BAG_UPDATE_DELAYED")
        events:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        events:RegisterEvent("BAG_UPDATE_COOLDOWN")
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
        events:RegisterEvent("TRADE_SHOW")
        events:RegisterEvent("TRADE_CLOSED")
        events:RegisterEvent("TRADE_PLAYER_ITEM_CHANGED")
        events:RegisterEvent("TRADE_TARGET_ITEM_CHANGED")
        events:RegisterEvent("TRADE_ACCEPT_UPDATE")
        events:RegisterEvent("UI_INFO_MESSAGE")
        events:RegisterEvent("GROUP_ROSTER_UPDATE")
        events:RegisterEvent("UNIT_AURA")
        events:RegisterEvent("PLAYER_REGEN_DISABLED")
        events:RegisterEvent("PLAYER_TARGET_CHANGED")
        events:RegisterEvent("UNIT_HEALTH")
        events:RegisterEvent("UNIT_FLAGS")
        events:RegisterEvent("UNIT_LEVEL")
        for _, name in ipairs({"UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START",
            "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED",
            "MERCHANT_SHOW", "MERCHANT_UPDATE", "MERCHANT_CLOSED"}) do events:RegisterEvent(name) end
        local elapsed = 0
        events:SetScript("OnUpdate", function(_, delta)
            elapsed = elapsed + delta
            if elapsed >= 1 then elapsed = 0; addon:UpdateBuffTimers() end
        end)
    elseif event:find("^UNIT_SPELLCAST_") then
        addon:SpeechEvent(event, unit, powerType, third, fourth)
    elseif event == "MERCHANT_SHOW" or event == "MERCHANT_UPDATE" or event == "MERCHANT_CLOSED" then
        addon:RestockEvent(event)
    elseif event == "PLAYER_TARGET_CHANGED" or ((event == "UNIT_AURA" or event == "UNIT_HEALTH" or event == "UNIT_FLAGS") and unit == "target") then
        addon:UpdateIgniteDisplay()
        if event == "PLAYER_TARGET_CHANGED" then addon:RefreshActions() end
    elseif event == "UNIT_LEVEL" and unit == "target" then
        addon:RefreshActions()
    elseif event == "TRADE_ACCEPT_UPDATE" or event == "UI_INFO_MESSAGE" then
        addon:DistributionEvent(event, unit, powerType)
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_REGEN_DISABLED" or (event == "UNIT_AURA" and unit == "player") then
        if event == "GROUP_ROSTER_UPDATE" then addon:RefreshActions() end
        addon:UpdateReminders()
        addon:UpdateBuffTimers()
        if event == "PLAYER_REGEN_DISABLED" then addon:UpdateIgniteDisplay() end
    elseif event == "TRADE_SHOW" or event == "TRADE_CLOSED" or
        event == "TRADE_PLAYER_ITEM_CHANGED" or event == "TRADE_TARGET_ITEM_CHANGED" then
        addon:DistributionEvent(event, unit, powerType)
        addon:VendingEvent(event)
    elseif event == "PLAYER_REGEN_ENABLED" or event == "SPELLS_CHANGED" or
        event == "BAG_UPDATE_DELAYED" or event == "GET_ITEM_INFO_RECEIVED" then
        if event == "GET_ITEM_INFO_RECEIVED" then
            local itemID = addon:Readable(unit)
            if not itemID or not addon.trackedItems or not addon.trackedItems[itemID] then return end
        end
        if event == "PLAYER_REGEN_ENABLED" then addon.frame:StopMovingOrSizing() end
        if addon.settingsPending and event == "PLAYER_REGEN_ENABLED" then addon:ApplySettings()
        else addon:RefreshActions() end
        if event == "PLAYER_REGEN_ENABLED" then addon:UpdateIgniteDisplay() end
        if addon.trade.open then addon:UpdateTradeUI() end
        if event == "BAG_UPDATE_DELAYED" or event == "GET_ITEM_INFO_RECEIVED" then addon:RestockEvent(event) end
    elseif event == "SPELL_UPDATE_COOLDOWN" or event == "BAG_UPDATE_COOLDOWN" then
        addon:UpdateActionDisplays()
    elseif event == "PLAYER_ENTERING_WORLD" then
        addon:UpdateMana()
        addon:RefreshActions()
        addon:UpdateIgniteDisplay()
    elseif unit == "player" and (powerType == nil or powerType == "MANA") then
        addon:UpdateMana()
    end
end)
