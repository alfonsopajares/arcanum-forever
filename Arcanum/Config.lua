local _, addon = ...

addon.defaults = {
    visible = true,
    locked = false,
    point = "CENTER",
    relativePoint = "CENTER",
    x = 0,
    y = 0,
    scale = 100,
    radius = 94,
    rotation = 0,
    hover = true,
    closeDelay = 0.35,
    iconsPerRow = 6,
    flyoutDirection = "auto",
    centerAction = "gem",
    showCounts = true,
    showCooldowns = true,
    showTooltips = true,
    showBadges = true,
    centerCooldown = true,
    showIgnite = true,
    showBuffTimers = true,
    showCooldownNumbers = true,
    colorTheme = "arcane",
    recipientBuffRanks = true,
    minimap = {enabled=true, angle=225},
    categoryOrder = {},
    lastSelections = {},
    messages = {
        enabled = true, channel = "group", delay = 30,
        events = {
            portal = {enabled=true, style="funny", timing="success", custom=""},
            polymorph = {enabled=true, style="useful", timing="success", custom=""},
            evocation = {enabled=false, style="funny", timing="start", custom=""},
            trade = {enabled=false, style="funny", timing="success", custom=""},
        },
    },
    restock = {enabled=false, maxGold=5, keepGold=1, targets={[17020]=20, [17031]=10, [17032]=10, [17056]=10}},
    debugLogging = false,
    preparation = {
        profile = "auto", showPrepare = true, trackTrades = true, historyMinutes = 30,
        profiles = {solo={food=20,water=40}, party={food=40,water=120}, raid={food=100,water=240}},
    },
    reminders = {
        enabled=true, hideInCombat=true, groupOnly=false,
        food=true, water=true, gems=true, armor=true, intellect=true, reagents=true,
        lowFood=20, lowWater=20, lowReagents=5,
    },
    categoryEnabled = {},
    vending = {
        enabled = true,
        collapseEnchanting = true,
        position = {},
        bestRank = true,
        reserveFood = 0,
        reserveWater = 0,
        presets = {
            WARRIOR = {food = 20, water = 0}, ROGUE = {food = 20, water = 0},
            HUNTER = {food = 20, water = 20}, PRIEST = {food = 20, water = 40},
            MAGE = {food = 20, water = 40}, WARLOCK = {food = 20, water = 40},
            PALADIN = {food = 20, water = 40}, SHAMAN = {food = 20, water = 40},
            DRUID = {food = 20, water = 40}, UNKNOWN = {food = 20, water = 20},
        },
    },
}

function addon:MergeDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then target[key] = {} end
            self:MergeDefaults(target[key], value)
        elseif type(target[key]) ~= type(value) then
            target[key] = value
        end
    end
end

function addon:Clone(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, child in pairs(value) do copy[key] = self:Clone(child) end
    return copy
end

function addon:EpochTime()
    return GetServerTime and GetServerTime() or time and time() or GetTime and GetTime() or 0
end

function addon:InitializeSettings()
    local guid = UnitGUID and self:Readable(UnitGUID("player"))
    local name = UnitName and self:Readable(UnitName("player")) or "Mage"
    local realm = GetRealmName and GetRealmName() or "Unknown Realm"
    self.characterKey = guid or (name .. "-" .. realm)
    local legacy
    if type(ArcanumDB) ~= "table" or ArcanumDB.schemaVersion ~= 2 then
        legacy = type(ArcanumDB) == "table" and self:Clone(ArcanumDB) or {}
        ArcanumDB = {schemaVersion=2, characters={}}
    end
    if type(ArcanumDB.characters) ~= "table" then ArcanumDB.characters = {} end
    local entry = ArcanumDB.characters[self.characterKey]
    if type(entry) ~= "table" then
        entry = {settings=legacy or {}, distribution={}, log={}}
        ArcanumDB.characters[self.characterKey] = entry
    end
    entry.name = name .. " - " .. realm
    if type(entry.settings) ~= "table" then entry.settings = {} end
    if type(entry.distribution) ~= "table" then entry.distribution = {} end
    if type(entry.log) ~= "table" then entry.log = {} end
    self.character, self.db, self.distribution = entry, entry.settings, entry.distribution
    self:MergeDefaults(self.db, self.defaults)
    self:NormalizeSettings()
    self:PruneDistribution()
end

function addon:NormalizeSettings()
    if self.db.hearthstoneShortcut == false and self.db.categoryEnabled.hearthstone == nil then self.db.categoryEnabled.hearthstone = false end
    self.db.hearthstoneShortcut = nil
    if self.db.centerAction == "drink" or self.db.centerAction == "water" then self.db.centerAction = "eatdrink" end
    self.db.preparation.showEatDrink = nil
end

function addon:CharacterOptions()
    local options = {}
    for key, entry in pairs(ArcanumDB.characters) do
        if key ~= self.characterKey then options[#options + 1] = {key, entry.name or key} end
    end
    table.sort(options, function(a,b) return a[2] < b[2] end)
    if #options == 0 then options[1] = {"", "No other mage yet"} end
    return options
end

function addon:CopyCharacterSettings(key)
    local source = ArcanumDB.characters[key]
    if key == self.characterKey or not source or type(source.settings) ~= "table" then return false end
    self.character.settings = self:Clone(source.settings)
    self.db = self.character.settings
    self:MergeDefaults(self.db, self.defaults)
    self:NormalizeSettings()
    self.positionPending = true
    self:SettingsChanged()
    self:OpenSettings("Support")
    self.settings.status:SetText("Copied settings from " .. (source.name or key) .. ". Your trade history is unchanged.")
    return true
end

function addon:DebugLog(event, detail)
    if not self.db.debugLogging then return end
    local log = self.character.log
    log[#log + 1] = {time=self:EpochTime(), event=event, detail=detail or ""}
    while #log > 200 do table.remove(log, 1) end
    self:RefreshLogUI()
end

function addon:ClearDebugLog()
    self.character.log = {}
    self:RefreshLogUI()
end

function addon:RefreshLogUI()
    if not self.settings or not self.settings.logText then return end
    local lines = {}
    for _, entry in ipairs(self.character.log) do
        local stamp = date and date("%H:%M:%S", entry.time) or tostring(entry.time)
        lines[#lines + 1] = stamp .. " • " .. entry.event .. "\n" .. entry.detail
    end
    self.settings.logText:SetText(#lines > 0 and table.concat(lines, "\n\n") or "No log entries. Enable logging above, then reproduce the issue.")
    self.settings.logContent:SetSize(500, math.max(300, #lines * 52))
end

function addon:ApplySettings()
    self:NormalizeSettings()
    if InCombatLockdown() then self.settingsPending = true; return end
    self.settingsPending = false
    if self.positionPending then self:RestorePosition(); self.positionPending = false end
    self.frame:SetScale(self.db.scale / 100)
    self.frame:SetShown(self.db.visible)
    local color = self.themes[self.db.colorTheme] or self.themes.arcane
    self.manaBar:SetStatusBarColor(unpack(color))
    self.manaText:SetTextColor(unpack(color))
    self:UpdateMinimapButton()
    self:RefreshActions()
    self:UpdateMana()
    if self.trade and self.trade.open then self:UpdateTradeUI() end
end
