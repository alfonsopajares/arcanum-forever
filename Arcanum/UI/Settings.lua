local _, addon = ...

local function text(parent, value, x, y, width, font)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", x, y)
    label:SetWidth(width or 500)
    label:SetJustifyH("LEFT")
    label:SetText(value)
    return label
end

function addon:SettingsChanged()
    self:ApplySettings()
    self:UpdateReminders()
    self:UpdateActionDisplays()
    self:UpdateIgniteDisplay()
    if self.trade.open then self:UpdateTradeUI() end
    if self.settings then
        self.settings.status:SetText(InCombatLockdown() and "Saved. Layout and secure button changes apply after combat." or "Settings saved automatically.")
    end
end

function addon:CreateSettings()
    local window = CreateFrame("Frame", "ArcanumSettingsFrame", UIParent, "BackdropTemplate")
    window:SetSize(760, 650)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetClampedToScreen(true)
    window:EnableMouse(true)
    window:SetMovable(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", function() window:StartMoving() end)
    window:SetScript("OnDragStop", function() window:StopMovingOrSizing() end)
    window:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", tile=true, tileSize=32, edgeSize=32, insets={left=11,right=12,top=12,bottom=11}})
    local portrait = window:CreateTexture(nil, "ARTWORK")
    portrait:SetSize(56, 56); portrait:SetPoint("TOPLEFT", 18, -14)
    portrait:SetTexture("Interface\\AddOns\\Arcanum\\Media\\Orb")
    text(window, "Arcanum Forever", 86, -20, 450, "GameFontNormalLarge")
    text(window, "Mage spellbook & options", 86, -44, 450)
    window.pageTitle = text(window, "", 24, -78, 550, "GameFontNormalLarge")
    window.pageTitle:SetTextColor(0.45, 0.8, 1)
    local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function() window:Hide() end)
    window.pages, window.refreshers, window.choices, window.tabs = {}, {}, {}, {}
    window.status = text(window, "Settings saved automatically.", 24, -620, 710)
    self.settings = window
    if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = "ArcanumSettingsFrame" end

    local function page(name, index, label)
        local panel = CreateFrame("Frame", nil, window)
        panel:SetSize(550, 500)
        panel:SetPoint("TOPLEFT", 24, -110)
        panel:Hide()
        window.pages[name] = panel
        local tab = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
        tab:SetSize(148, 32)
        tab:SetPoint("TOPRIGHT", -18, -96 - (index - 1) * 38)
        tab:SetText(label or name)
        local icons = {Circle="Spell_Arcane_Arcane04", Flyouts="INV_Misc_Book_09", Display="INV_Misc_Gem_Sapphire_02",
            Vending="INV_Drink_18", Preparation="INV_Misc_Food_10", Reminders="Spell_Holy_MagicalSentry",
            Distribution="INV_Misc_Coin_01", Support="INV_Misc_QuestionMark", Messages="INV_Misc_Note_01", Restocking="INV_Misc_Rune_01", Buffs="Spell_Holy_MagicalSentry", Procs="Spell_Shadow_ManaBurn", Curses="Spell_Nature_RemoveCurse"}
        local icon = tab:CreateTexture(nil, "ARTWORK")
        icon:SetSize(20, 20); icon:SetPoint("LEFT", 4, 0); icon:SetTexture("Interface\\Icons\\" .. icons[name])
        window.tabs[name] = tab
        tab:SetScript("OnClick", function() self:OpenSettings(name) end)
        return panel
    end
    local function check(panel, label, x, y, getter, setter)
        local control = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
        control:SetSize(24, 24)
        control:SetPoint("TOPLEFT", x, y)
        text(panel, label, x + 30, y - 5, 440)
        control:SetScript("OnClick", function() setter(control:GetChecked() == true); self:SettingsChanged() end)
        window.refreshers[#window.refreshers + 1] = function() control:SetChecked(getter()) end
        return control
    end
    local function number(panel, label, x, y, minimum, maximum, decimals, getter, setter)
        if label then text(panel, label, x, y - 6, 280) end
        local input = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
        input:SetSize(60, 24)
        input:SetPoint("TOPLEFT", x + (label and 290 or 0), y)
        input:SetAutoFocus(false)
        input:SetMaxLetters(6)
        local function commit()
            local value = tonumber(input:GetText())
            if value then
                value = math.max(minimum, math.min(maximum, value))
                if not decimals then value = math.floor(value) end
                if getter() ~= value then setter(value); self:SettingsChanged() end
            end
            input:SetText(tostring(getter()))
        end
        input:SetScript("OnEnterPressed", function() commit(); input:ClearFocus() end)
        input:SetScript("OnEditFocusLost", commit)
        input:SetScript("OnEscapePressed", function() input:SetText(tostring(getter())); input:ClearFocus() end)
        window.refreshers[#window.refreshers + 1] = function() input:SetText(tostring(getter())) end
        return input
    end
    local function choice(panel, label, y, options, getter, setter)
        text(panel, label, 0, y - 6, 280)
        local native = UIDropDownMenu_Initialize and UIDropDownMenu_CreateInfo and UIDropDownMenu_AddButton
            and UIDropDownMenu_SetWidth and UIDropDownMenu_SetText
        local id = #window.refreshers + 1
        local button = CreateFrame(native and "Frame" or "Button", "ArcanumChoice" .. id, panel,
            native and "UIDropDownMenuTemplate" or "UIPanelButtonTemplate")
        button:SetSize(180, 24); button:SetPoint("TOPLEFT", native and 274 or 290, native and y + 2 or y)
        local function list() return type(options) == "function" and options() or options end
        local function refresh()
            local caption = "Choose…"
            for _, option in ipairs(list()) do if getter() == option[1] then caption = option[2]; break end end
            if native then UIDropDownMenu_SetText(button, caption) else button:SetText(caption .. "  ▼") end
        end
        local function select(value) setter(value); refresh(); self:SettingsChanged() end
        button.choose = select
        if native then
            UIDropDownMenu_SetWidth(button, 180)
            UIDropDownMenu_Initialize(button, function(_, level)
                for _, option in ipairs(list()) do
                    local value = option[1]
                    local info = UIDropDownMenu_CreateInfo()
                    info.text, info.value, info.checked = option[2], value, getter() == value
                    info.func = function() select(value); if CloseDropDownMenus then CloseDropDownMenus() end end
                    UIDropDownMenu_AddButton(info, level)
                end
            end)
        else
            -- A real selection list also works on clients without legacy dropdown APIs.
            local menu = CreateFrame("Frame", "ArcanumChoiceMenu" .. id, UIParent, "BackdropTemplate")
            menu:SetFrameStrata("FULLSCREEN_DIALOG"); menu:SetFrameLevel(200); menu:SetClampedToScreen(true)
            menu:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=16,edgeSize=16})
            local scroll = CreateFrame("ScrollFrame", nil, menu, "UIPanelScrollFrameTemplate")
            scroll:SetPoint("TOPLEFT", 10, -10)
            local content = CreateFrame("Frame", nil, scroll); scroll:SetScrollChild(content)
            menu.rows = {}; menu:Hide(); button.menu = menu
            if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = "ArcanumChoiceMenu" .. id end
            window:HookScript("OnHide", function() menu:Hide() end)
            button:SetScript("OnClick", function()
                if menu:IsShown() then menu:Hide(); return end
                local entries = list()
                for _, row in ipairs(menu.rows) do row:Hide() end
                for index, option in ipairs(entries) do
                    local value = option[1]
                    local row = menu.rows[index] or CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
                    menu.rows[index] = row; row:SetSize(180, 24); row:SetPoint("TOPLEFT", 0, -(index-1)*26)
                    row:SetText((getter() == value and "✓ " or "") .. option[2])
                    row:SetScript("OnClick", function() menu:Hide(); select(value) end); row:Show()
                end
                content:SetSize(180, #entries*26)
                scroll:SetSize(180, math.min(312, #entries*26))
                menu:SetSize(220, math.min(312, #entries*26)+20)
                menu:ClearAllPoints(); menu:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", 0, -2); menu:Show()
            end)
        end
        window.choices[label] = button
        window.refreshers[#window.refreshers + 1] = refresh
    end
    local function getter(key) return function() return self.db[key] end end
    local function setter(key) return function(value) self.db[key] = value end end
    local circle = page("Circle", 1)
    check(circle, "Show Arcanum", 0, 0, getter("visible"), setter("visible"))
    check(circle, "Lock circle position", 0, -34, getter("locked"), setter("locked"))
    number(circle, "Circle size (50–200%)", 0, -80, 50, 200, false, getter("scale"), setter("scale"))
    number(circle, "Button distance (64–180)", 0, -116, 64, 180, false, getter("radius"), setter("radius"))
    number(circle, "Rotation (0–360 degrees)", 0, -152, 0, 360, false, getter("rotation"), setter("rotation"))
    text(circle, "Circle buttons — learned spells and carried items", 0, -204, 500, "GameFontNormal")
    for index, category in ipairs(self.categories) do
        check(circle, category.label, ((index - 1) % 2) * 265, -232 - math.floor((index - 1) / 2) * 34,
            function() return self.db.categoryEnabled[category.id] ~= false end,
            function(value) self.db.categoryEnabled[category.id] = value end)
    end
    local reset = CreateFrame("Button", nil, circle, "UIPanelButtonTemplate")
    reset:SetSize(180, 24); reset:SetPoint("TOPLEFT", 0, -398); reset:SetText("Reset circle layout")
    reset:SetScript("OnClick", function() self:HandleCommand("reset"); self:OpenSettings("Circle") end)
    check(circle, "Show minimap options button", 0, -438,
        function() return self.db.minimap.enabled end, function(value) self.db.minimap.enabled = value end)

    local menus = page("Flyouts", 2)
    check(menus, "Open flyouts on hover", 0, 0, getter("hover"), setter("hover"))
    number(menus, "Close delay (0.1–3 seconds)", 0, -46, 0.1, 3, true, getter("closeDelay"), setter("closeDelay"))
    number(menus, "Icons per row (1–8)", 0, -84, 1, 8, false, getter("iconsPerRow"), setter("iconsPerRow"))
    choice(menus, "Flyout direction", -128, {{"auto","Automatic"},{"left","Left"},{"right","Right"},{"up","Up"},{"down","Down"}}, getter("flyoutDirection"), setter("flyoutDirection"))
    text(menus, "Click a circle button to pin its flyout. Click again to close.\nShift + left-click repeats the last selected spell in that category.\nA selection made during combat becomes the shortcut after combat.\nFlyouts stay open while you move onto their spell icons.", 0, -190, 520)
    text(menus, "Clockwise button order (hidden categories keep their place)", 0, -274, 530, "GameFontNormal")
    window.orderLabels = {}
    for index = 1, #self.categories do
        window.orderLabels[index] = text(menus, "", 0, -302 - (index-1)*22, 270)
        for column, direction in ipairs({-1,1}) do
            local move = CreateFrame("Button", nil, menus)
            move:SetSize(22, 22); move:SetPoint("TOPLEFT", 292 + (column-1)*28, -296 - (index-1)*22)
            local texture = "Interface\\Buttons\\UI-ScrollBar-Scroll" .. (direction == -1 and "Up" or "Down") .. "Button-"
            move:SetNormalTexture(texture .. "Up")
            move:SetPushedTexture(texture .. "Down")
            move:SetHighlightTexture(texture .. "Highlight")
            move:SetScript("OnClick", function() self:MoveCategory(self:OrderedCategories()[index].id, direction) end)
        end
    end

    local display = page("Display", 3)
    choice(display, "Orb action and center display", 0, {{"gem","Mana Gem"},{"evocation","Evocation"},{"eatdrink","Eat + Drink"}}, getter("centerAction"), setter("centerAction"))
    check(display, "Show item and reagent counts", 0, -48, getter("showCounts"), setter("showCounts"))
    check(display, "Show cooldown swipes", 0, -82, getter("showCooldowns"), setter("showCooldowns"))
    check(display, "Show spell and item tooltips", 0, -116, getter("showTooltips"), setter("showTooltips"))
    check(display, "Show conjure (+) and Use badges", 0, -150, getter("showBadges"), setter("showBadges"))
    check(display, "Show orb cooldown ring", 0, -184, getter("centerCooldown"), setter("centerCooldown"))
    text(display, "Mana Gem shows total gems in your bags; Eat + Drink shows food and water counts.\nEvocation shows your current mana. Left-click uses the selected action.\nShift + left-click casts learned Evocation. Right-click opens options.", 0, -230, 530)
    check(display, "Show your Ignite in the proc alert row", 0, -300, getter("showIgnite"), setter("showIgnite"))
    text(display, "Only your confirmed Ignite is shown. Configure alerts and sounds under Procs.\nProtected aura data is never guessed; unavailable alerts stay hidden.", 0, -344, 530)
    check(display, "Show Intellect and Armor time below their buttons", 0, -390, getter("showBuffTimers"), setter("showBuffTimers"))
    check(display, "Show cooldown numbers on spell icons", 0, -424, getter("showCooldownNumbers"), setter("showCooldownNumbers"))
    choice(display, "Mana display color", -466, {{"arcane","Arcane blue"},{"violet","Violet"},{"frost","Frost"},{"gold","Gold"}}, getter("colorTheme"), setter("colorTheme"))
    local buffs = page("Buffs", 8, "Buffs / Travel")
    check(buffs, "Choose buff rank for the recipient's level", 0, 0, getter("recipientBuffRanks"), setter("recipientBuffRanks"))
    text(buffs, "Applies to Arcane Intellect, Dampen Magic, and Amplify Magic.\nOutside combat, left-click uses the highest learned rank your target can receive.\nDuring combat, left-click uses the lowest learned rank.\nRight-click still casts your highest learned rank on yourself.\nUnknown target levels use the lowest learned rank.\nGroup buffs keep their normal spell binding.", 0, -48, 530)
    text(buffs, "Hearthstone has its own outer circle button. Left-click it to return home.\nIt has no flyout and shows only while your Hearthstone is carried.\nHide it under Circle; reorder it under Flyouts.", 0, -186, 530)
    check(buffs,"Enable Drive-by Intellect",0,-250,
        function() return self.db.driveBy.enabled end,function(v) self.db.driveBy.enabled=v end)
    check(buffs,"Use friendly target when no eligible player is under mouse",0,-280,
        function() return self.db.driveBy.targetFallback end,function(v) self.db.driveBy.targetFallback=v end)
    check(buffs,"Only buff players currently using mana",0,-310,
        function() return self.db.driveBy.manaOnly end,function(v) self.db.driveBy.manaOnly=v end)
    check(buffs,"Skip targets with a stronger Intellect buff",0,-340,
        function() return self.db.driveBy.skipBuffed end,function(v) self.db.driveBy.skipBuffed=v end)
    check(buffs,"Show a brief confirmation after a successful buff",0,-370,
        function() return self.db.driveBy.confirm end,function(v) self.db.driveBy.confirm=v end)
    check(buffs,"Play confirmation sound",0,-400,
        function() return self.db.driveBy.sound end,function(v) self.db.driveBy.sound=v end)
    text(buffs,"Bind Drive-by Intellect in WoW Key Bindings → Arcanum.\nHover a player or unit frame, then press the key. Your target is preserved.\nOutside combat only; always chooses a learned rank for the recipient's level.\nUnknown levels use the lowest rank. Unreadable buffs do not block casting.",0,-446,530)

    local vending = page("Vending", 4)
    check(vending, "Enable vending trade controls", 0, 0,
        function() return self.db.vending.enabled end, function(value) self.db.vending.enabled = value end)
    check(vending, "Give only ranks the recipient can use", 0, -26,
        function() return self.db.vending.bestRank end, function(value) self.db.vending.bestRank = value end)
    check(vending, "Collapse while enchanting", 0, -52,
        function() return self.db.vending.collapseEnchanting end, function(value) self.db.vending.collapseEnchanting = value end)
    check(vending,"Accept supply requests from group whispers",0,-78,
        function() return self.db.groupSupplies.whispers end,function(v) self.db.groupSupplies.whispers=v end)
    local resetVending = CreateFrame("Button", nil, vending, "UIPanelButtonTemplate")
    resetVending:SetSize(200, 24); resetVending:SetPoint("TOPLEFT", 0, -136)
    resetVending:SetText("Reset vending position")
    resetVending:SetScript("OnClick", function() self:ResetTradePosition() end)
    local supplies = CreateFrame("Button", nil, vending, "UIPanelButtonTemplate")
    supplies:SetSize(220,24); supplies:SetPoint("TOPLEFT",220,-136); supplies:SetText("Open Group Supplies")
    supplies:SetScript("OnClick",function() self:OpenGroupSupplies() end)
    number(vending, "Keep food for yourself (0–120)", 0, -172, 0, 120, false,
        function() return self.db.vending.reserveFood end, function(value) self.db.vending.reserveFood = value end)
    number(vending, "Keep water for yourself (0–120)", 0, -206, 0, 120, false,
        function() return self.db.vending.reserveWater end, function(value) self.db.vending.reserveWater = value end)
    text(vending, "Default requests (items, 0–120)", 0, -240, 300, "GameFontNormal")
    text(vending, "Food", 300, -240, 60, "GameFontNormal")
    text(vending, "Water", 400, -240, 60, "GameFontNormal")
    local classes = {"WARRIOR","ROGUE","HUNTER","PRIEST","MAGE","WARLOCK","PALADIN","SHAMAN","DRUID","UNKNOWN"}
    for index, class in ipairs(classes) do
        local y = -262 - (index - 1) * 20
        text(vending, class == "UNKNOWN" and "Unknown class" or (class:sub(1,1) .. class:sub(2):lower()), 0, y - 5, 260)
        for column, kind in ipairs({"food","water"}) do
            local input=number(vending, nil, 300 + (column - 1) * 100, y, 0, 120, false,
                function() return self.db.vending.presets[class][kind] end,
                function(value) self.db.vending.presets[class][kind] = value end)
            input:SetSize(60,18)
        end
    end
    check(vending,"Coordinate assignments and deliveries with other Arcanum mages",0,-464,
        function() return self.db.groupSupplies.coordinate end,function(v)
            self.db.groupSupplies.coordinate=v
            self:TickSupplyProtocol()
            self.groupSupplyTradePending=true
            self:UpdateGroupSupplies()
        end)
    local prep = page("Preparation", 5, "Prep")
    window.preparationInputs = {}
    text(prep,"Prepared covers only your own food, water, and mana gems.",0,0,530)
    window.preparationInputs.food = number(prep, "Personal food target", 0, -34, 0, 5000, false,
        function() return self:EditablePreparationProfile().food end,
        function(value) self:EditablePreparationProfile().food = value end)
    window.preparationInputs.water = number(prep, "Personal water target", 0, -70, 0, 5000, false,
        function() return self:EditablePreparationProfile().water end,
        function(value) self:EditablePreparationProfile().water = value end)
    check(prep, "Show Prepare button", 0, -118,
        function() return self.db.preparation.showPrepare end, function(value) self.db.preparation.showPrepare = value end)
    window.preparationSummary = text(prep, "", 0, -164, 530)
    text(prep,"Prepare replenishes your own supplies one cast per click.\nGroup requests and trading options are under Vending.\nKey Bindings → Arcanum includes Prepare and Toggle circle.",0,-234,530)

    check(prep, "Show Comprehend popup for eligible bag scrolls", 0, -470,
        function() return self.db.scrolls.enabled end, function(v) self.db.scrolls.enabled = v end)
    local reminders = page("Reminders", 6)
    local function reminder(key) return function() return self.db.reminders[key] end, function(value) self.db.reminders[key] = value end end
    local function reminderCheck(label, y, key, parent)
        local read, write = reminder(key); check(parent or reminders, label, 0, y, read, write)
    end
    reminderCheck("Enable reminders (master switch)", 0, "enabled")
    reminderCheck("Hide reminders during combat", -32, "hideInCombat")
    reminderCheck("Show reminders only in a group", -64, "groupOnly")
    reminderCheck("Low food stock", -102, "food")
    reminderCheck("Low water stock", -134, "water")
    reminderCheck("Missing learned mana gems", -166, "gems")
    reminderCheck("Missing mage armor", -198, "armor")
    reminderCheck("Missing Arcane Intellect", -230, "intellect")
    reminderCheck("Low reagents for learned spells", -262, "reagents")
    for index, entry in ipairs({{"lowFood","Food warning below"},{"lowWater","Water warning below"},{"lowReagents","Reagent warning below"}}) do
        local read, write = reminder(entry[1]); number(reminders, entry[2], 0, -304 - (index - 1) * 36, 0, 120, false, read, write)
    end
    local barrierOptions = CreateFrame("Frame", nil, reminders)
    barrierOptions:SetPoint("TOPLEFT", 0, -416)
    barrierOptions:SetSize(530, 52)
    barrierOptions:Hide()
    window.iceBarrierOptions = barrierOptions
    reminderCheck("Refresh Ice Barrier when Frigid Power is missing", 0, "iceBarrier", barrierOptions)
    reminderCheck("Remind when the Ice Barrier shield is missing", -26, "iceBarrierShield", barrierOptions)
    text(reminders, "Missing buffs show an alert below the circle.\nWarnings require readable buff information.", 0, -476, 530)

    local distribution = page("Distribution", 7, "Trades")
    check(distribution, "Track completed food/water deliveries", 0, 0,
        function() return self.db.preparation.trackTrades end, function(value) self.db.preparation.trackTrades = value end)
    number(distribution, "Forget deliveries after (minutes)", 0, -38, 1, 180, false,
        function() return self.db.preparation.historyMinutes end, function(value) self.db.preparation.historyMinutes = value end)
    local clear = CreateFrame("Button", nil, distribution, "UIPanelButtonTemplate")
    clear:SetSize(200, 24); clear:SetPoint("TOPLEFT", 0, -80); clear:SetText("Reset supply history")
    clear:SetScript("OnClick", function() self:ResetDistribution() end)
    local scroll = CreateFrame("ScrollFrame", nil, distribution, "UIPanelScrollFrameTemplate")
    scroll:SetSize(510, 330); scroll:SetPoint("TOPLEFT", 0, -124)
    local content = CreateFrame("Frame", nil, scroll); content:SetSize(500, 330); scroll:SetScrollChild(content)
    window.distributionContent = content
    window.distributionText = text(content, "", 0, 0, 500)
    text(distribution, "History survives reloads until it expires. Cancelled trades are never counted.", 0, -474, 530)
    local support = page("Support", 13)
    check(support, "Enable troubleshooting log (last 200 entries)", 0, 0, getter("debugLogging"), setter("debugLogging"))
    choice(support, "Copy settings from another mage", -40, function() return self:CharacterOptions() end,
        function() return self.copySource or "" end, function(value) self.copySource = value end)
    local copy = CreateFrame("Button", nil, support, "UIPanelButtonTemplate")
    copy:SetSize(200, 24); copy:SetPoint("TOPLEFT", 0, -80); copy:SetText("Copy selected settings")
    copy:SetScript("OnClick", function() self:CopyCharacterSettings(self.copySource or "") end)
    local clearLog = CreateFrame("Button", nil, support, "UIPanelButtonTemplate")
    clearLog:SetSize(140, 24); clearLog:SetPoint("TOPLEFT", 0, -114); clearLog:SetText("Clear log")
    clearLog:SetScript("OnClick", function() self:ClearDebugLog() end)
    local logScroll = CreateFrame("ScrollFrame", nil, support, "UIPanelScrollFrameTemplate")
    logScroll:SetSize(510, 230); logScroll:SetPoint("TOPLEFT", 0, -150)
    local logContent = CreateFrame("Frame", nil, logScroll); logContent:SetSize(500, 230); logScroll:SetScrollChild(logContent)
    window.logContent, window.logText = logContent, text(logContent, "", 0, 0, 500)
    text(support, "Made by Hollow Bell Studios", 0, -390, 530, "GameFontNormal")
    text(support, "Enjoying Arcanum? Supporting future updates is always optional.", 0, -412, 530)
    local supportURL = "https://buymeacoffee.com/hollowbellstudios"
    local supportLink = CreateFrame("EditBox", nil, support, "InputBoxTemplate")
    supportLink:SetSize(500,24); supportLink:SetPoint("TOPLEFT",8,-436); supportLink:SetAutoFocus(false)
    supportLink:SetText(supportURL)
    supportLink:SetScript("OnEditFocusGained",function(box) box:SetText(supportURL); box:HighlightText() end)
    supportLink:SetScript("OnEditFocusLost",function(box) box:SetText(supportURL) end)
    supportLink:SetScript("OnEscapePressed",function(box) box:ClearFocus() end)
    supportLink:SetScript("OnEnterPressed",function(box) box:ClearFocus() end)
    text(support, "Settings and history are separate for each mage. Copying keeps your history.", 0, -474, 530)

    local messages = page("Messages", 9)
    check(messages, "Enable spell and trade messages", 0, 0,
        function() return self.db.messages.enabled end, function(value) self.db.messages.enabled = value end)
    choice(messages, "Where to send", -38, {{"group","Party / raid (local when solo)"},{"local","Only me"}},
        function() return self.db.messages.channel end, function(value) self.db.messages.channel = value end)
    number(messages, "Repeat delay per event (seconds)", 0, -78, 5, 600, false,
        function() return self.db.messages.delay end, function(value) self.db.messages.delay = value end)
    for index, event in ipairs(self.messageEvents) do
        local key = event[1]
        check(messages, event[2], ((index-1)%2)*265, -116-math.floor((index-1)/2)*30,
            function() return self.db.messages.events[key].enabled end, function(value) self.db.messages.events[key].enabled = value end)
    end
    local function selected() return self.db.messages.events[window.messageEvent or "portal"] end
    choice(messages, "Edit messages for", -188, self.messageEvents,
        function() return window.messageEvent or "portal" end,
        function(value) window.messageEvent = value; self:OpenSettings("Messages") end)
    choice(messages, "Message style", -228, {{"useful","Short & useful"},{"funny","Funny / roleplay"},{"custom","My own text"}},
        function() return selected().style end, function(value) selected().style = value end)
    choice(messages, "When to announce", -268, function()
        return window.messageEvent == "trade" and {{"success","After completion"}}
            or {{"start","When casting starts"},{"success","After successful cast"},{"both","Start and completion"}}
        end, function() return selected().timing end, function(value) selected().timing = value end)
    text(messages, "Custom text (up to 3 lines; 255 bytes per line)", 0, -312, 530, "GameFontNormal")
    local custom = CreateFrame("EditBox", nil, messages, "InputBoxTemplate")
    custom:SetSize(500, 70); custom:SetPoint("TOPLEFT", 8, -336); custom:SetAutoFocus(false)
    custom:SetMultiLine(true); custom:SetMaxLetters(700)
    local function saveSpeech()
        local value, count = custom:GetText() or "", 0
        for line in value:gmatch("[^\r\n]+") do
            count = count + 1
            if count > 3 or #line > 255 then
                window.status:SetText("Custom messages need at most 3 lines, each at most 255 bytes.")
                return false
            end
        end
        selected().custom = value
        return true
    end
    custom:SetScript("OnEditFocusLost", function() if saveSpeech() then self:SettingsChanged() end end)
    custom:SetScript("OnEscapePressed", function() custom:ClearFocus() end)
    window.refreshers[#window.refreshers+1] = function() custom:SetText(selected().custom) end
    window.messageInput = custom
    text(messages, "Tokens: {player}, {target}, {destination}, {food}, {water}, {phase}.\nFunny / roleplay cycles through 5 messages per event and timing.\nReminders have their own switches.", 0, -418, 530)
    local preview = CreateFrame("Button", nil, messages, "UIPanelButtonTemplate")
    preview:SetSize(200, 24); preview:SetPoint("TOPLEFT", 0, -470); preview:SetText("Preview (only you see it)")
    preview:SetScript("OnClick", function()
        if not saveSpeech() then return end
        local value = self:MessageText(window.messageEvent or "portal", selected().timing == "start" and "start" or "success",
            {target="Nix", destination="Stormwind", food=20, water=40}, true)
        if value then print("|cff66bbffArcanum preview:|r " .. value) end
    end)

    local restock = page("Restocking", 10, "Reagents")
    check(restock, "Automatically restock at reagent vendors", 0, 0,
        function() return self.db.restock.enabled end, function(value) self.db.restock.enabled = value end)
    text(restock, "Buy only reagents for spells you have learned.\nTargets count items in your bags. Your bags are never rearranged.", 0, -46, 530)
    for index, reagent in ipairs(self.reagents) do
        local id = reagent.id
        number(restock, reagent.label .. " target", 0, -106-(index-1)*40, 0, 200, false,
            function() return self.db.restock.targets[id] end, function(value) self.db.restock.targets[id] = value end)
    end
    number(restock, "Maximum gold per vendor visit", 0, -286, 0, 100, true,
        function() return self.db.restock.maxGold end, function(value) self.db.restock.maxGold = value end)
    number(restock, "Gold to keep", 0, -328, 0, 10000, true,
        function() return self.db.restock.keepGold end, function(value) self.db.restock.keepGold = value end)
    text(restock, "Restocking starts when you open a vendor. Purchases stop at your targets,\nspending limit, gold reserve, available stock, or bag capacity.\nOnly normal gold purchases are used; special currency offers are skipped.\nDisabled by default. Enable above when you want automatic purchases.", 0, -396, 530)
    local procs = page("Procs", 11)
    check(procs, "Enable proc alerts (independent of the circle)", 0, 0,
        function() return self.db.procs.enabled end, function(v) self.db.procs.enabled=v end)
    check(procs, "Enable proc sounds", 0, -30,
        function() return self.db.procs.sound end, function(v) self.db.procs.sound=v end)
    check(procs, "Lock alert position", 0, -60,
        function() return self.db.procs.locked end, function(v) self.db.procs.locked=v end)
    number(procs, "Alert size (60–150%)", 0, -98, 60, 150, false,
        function() return self.db.procs.scale end, function(v) self.db.procs.scale=v end)
    local function procOptions()
        local list={}; for _, def in ipairs(self.procTypes) do list[#list+1]={def.key,def.label} end; return list
    end
    window.procSelection = "clearcasting"
    local function procOption() return self:ProcOption(window.procSelection) end
    choice(procs, "Effect", -146, procOptions,
        function() return window.procSelection end,
        function(v) window.procSelection=v; for _, refresh in ipairs(window.refreshers) do refresh() end end)
    check(procs, "Show this effect", 0, -184,
        function() return procOption().enabled end, function(v) procOption().enabled=v end)
    check(procs, "Play sound for this effect", 0, -214,
        function() return procOption().sound end, function(v) procOption().sound=v end)
    choice(procs, "Sound", -252, self.procSounds,
        function() return procOption().tone end, function(v) procOption().tone=v end)
    local function procButton(caption, x, y, action)
        local b=CreateFrame("Button",nil,procs,"UIPanelButtonTemplate")
        b:SetSize(164,26); b:SetPoint("TOPLEFT",x,y); b:SetText(caption); b:SetScript("OnClick",action)
        return b
    end
    window.procTests = {}
    window.procTests.gain=procButton("Gain / add stack",0,-300,function() self:TestProc(window.procSelection,"gain") end)
    window.procTests.consume=procButton("Consume / use charge",178,-300,function() self:TestProc(window.procSelection,"consume") end)
    window.procTests.expire=procButton("Expire selected",356,-300,function() self:TestProc(window.procSelection,"expire") end)
    window.procTests.all=procButton("Test all alerts",0,-336,function() self:TestProc("all") end)
    window.procTests.stop=procButton("Stop test",178,-336,function() self:StopProcTest() end)
    window.procTests.sound=procButton("Preview sound",356,-336,function() self:PlayProcSound(window.procSelection,true) end)
    text(procs,"Test mode needs no learned talents; it ends after 30 seconds or entering combat.\nArcane Blast uses a native row of up to six short player-applied self-debuffs.\nEffects lasting over 60 seconds are excluded; other short self-effects may appear.\nIgnite and Winter's Chill use native player-owned target filters in combat.\nThreshold and target sounds still need readable data. Tests check the UI only.\nTry /arc procs test arcane to preview the new self-effect icon without casting.",0,-386,530)
    procButton("Reset alert position",0,-478,function()
        for _, key in ipairs({"point","relativePoint","x","y","scale"}) do self.db.procs[key]=self.defaults.procs[key] end
        self:ApplyProcSettings(); self:OpenSettings("Procs")
    end)
    local curses=page("Curses",12,"Curse helper")
    check(curses,"Enable mage curse helper",0,0,
        function() return self.db.curseHelper.enabled end,function(v) self.db.curseHelper.enabled=v end)
    check(curses,"Hide while solo",0,-36,
        function() return self.db.curseHelper.hideWhenSolo end,function(v) self.db.curseHelper.hideWhenSolo=v end)
    check(curses,"Lock helper position",0,-72,
        function() return self.db.curseHelper.locked end,function(v) self.db.curseHelper.locked=v end)
    check(curses,"Sound when a readable curse appears",0,-108,
        function() return self.db.curseHelper.sound end,function(v) self.db.curseHelper.sound=v end)
    number(curses,"Helper size (60–150%)",0,-154,60,150,false,
        function() return self.db.curseHelper.scale end,function(v) self.db.curseHelper.scale=v end)
    text(curses,"Left-click a player's square to cast Remove Lesser Curse on that player.\nYour current target is kept. Learn Remove Lesser Curse to show the live grid.\nParty and raid slots stay securely bound during combat.\nPurple CURSE indicators use Blizzard's native display when available.\n? means addon aura data is restricted; native CURSE indicators still apply.\nFar, Dead, and Offline are shown only when their state is readable.\nSounds require a readable curse and are throttled; restricted auras stay silent.\nChanging visibility or layout during combat applies after combat.",0,-214,530)
    local previewCurse=CreateFrame("Button",nil,curses,"UIPanelButtonTemplate")
    previewCurse:SetSize(220,26); previewCurse:SetPoint("TOPLEFT",0,-372); previewCurse:SetText("Preview squares (15 seconds)")
    previewCurse:SetScript("OnClick",function() self:PreviewCurseHelper() end)
    local resetCurse=CreateFrame("Button",nil,curses,"UIPanelButtonTemplate")
    resetCurse:SetSize(220,26); resetCurse:SetPoint("TOPLEFT",0,-412); resetCurse:SetText("Reset helper position")
    resetCurse:SetScript("OnClick",function()
        for _,key in ipairs({"point","relativePoint","x","y","scale"}) do self.db.curseHelper[key]=self.defaults.curseHelper[key] end
        self:ApplyCurseSettings(); self:OpenSettings("Curses")
    end)
    text(curses,"Preview squares cannot cast. /arc curses opens these options.\n/arc curses test previews; /arc curses stop closes the preview.",0,-460,530)
    window:Hide()
end

function addon:OpenSettings(page)
    if not self.settings then self:CreateSettings() end
    for _, refresh in ipairs(self.settings.refreshers) do refresh() end
    local selected = page or self.settings.selected or "Circle"
    if not self.settings.pages[selected] then selected = "Circle" end
    self.settings.selected = selected
    self.settings.pageTitle:SetText(selected == "Restocking" and "Reagent restocking" or selected)
    for name, panel in pairs(self.settings.pages) do panel:SetShown(name == selected) end
    for name, tab in pairs(self.settings.tabs) do tab:SetEnabled(name ~= selected) end
    self.settings:Show()
    self:RefreshPreparationUI()
    self:RefreshLogUI()
    self:RefreshCategoryOrderUI()
end
