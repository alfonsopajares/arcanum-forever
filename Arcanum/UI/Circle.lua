local _, addon = ...

local function makeText(parent, template, point, x, y)
    local text = parent:CreateFontString(nil, "OVERLAY", template)
    text:SetPoint(point, parent, point, x or 0, y or 0)
    return text
end

local function roundedIcon(parent, icon, size)
    local texture = parent:CreateTexture(nil, "ARTWORK")
    texture:SetSize(size, size)
    texture:SetPoint("CENTER")
    texture:SetTexture(icon)
    texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local mask = parent:CreateMaskTexture()
    mask:SetAllPoints(texture)
    mask:SetTexture("Interface\\AddOns\\Arcanum\\Media\\CircleMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    texture:AddMaskTexture(mask)
    local ring = parent:CreateTexture(nil, "OVERLAY")
    ring:SetAllPoints(texture)
    ring:SetTexture("Interface\\AddOns\\Arcanum\\Media\\Ring")
    return texture
end

-- Prefer an exact native query: unrelated protected auras cannot be inspected
-- to identify Ignite. Fall back only when the direct query is unavailable.
function addon:TargetIgnite()
    local api = C_UnitAuras
    if api and api.GetUnitAuraBySpellID then
        local ok, aura = pcall(api.GetUnitAuraBySpellID, "target", 12654)
        if ok and not (issecretvalue and issecretvalue(aura)) then return aura, "known" end
    end
    local name = self:SpellInfo(12654)
    if name and api and api.GetAuraDataBySpellName then
        local ok, aura = pcall(api.GetAuraDataBySpellName, "target", name, "HARMFUL")
        if ok and not (issecretvalue and issecretvalue(aura)) then return aura, "known" end
    end
    local unknown = false
    for index = 1, 80 do
        local ok, aura
        if api and api.GetAuraDataByIndex then
            ok, aura = pcall(api.GetAuraDataByIndex, "target", index, "HARMFUL")
        elseif UnitDebuff then
            local values = {pcall(UnitDebuff, "target", index)}
            ok = values[1]
            if ok and not (issecretvalue and issecretvalue(values[2])) and values[2] == nil then
                return nil, unknown and "unknown" or "known"
            end
            aura = ok and {name=values[2], applications=values[4], spellId=values[11]} or nil
        else return nil, "unknown" end
        if not ok then return nil, "unknown" end
        if issecretvalue and issecretvalue(aura) then unknown = true
        elseif aura == nil then return nil, unknown and "unknown" or "known"
        else
            local id, auraName = self:Readable(aura.spellId), self:Readable(aura.name)
            if id == 12654 or (name and auraName == name) then return aura, "known" end
            if id == nil and auraName == nil then unknown = true end
        end
    end
    return nil, "unknown"
end

function addon:CreateIgniteDisplay()
    local frame = CreateFrame("Frame", "ArcanumIgniteDisplay", UIParent, "BackdropTemplate")
    frame:SetSize(210, 94)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, -110)
    frame:SetFrameStrata("HIGH")
    frame:EnableMouse(false)
    frame:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=16,edgeSize=16,insets={left=4,right=4,top=4,bottom=4}})
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetSize(54, 54); frame.icon:SetPoint("LEFT", 16, 0)
    local _, icon = self:SpellInfo(12654)
    frame.icon:SetTexture(icon or "Interface\\Icons\\Spell_Fire_Incinerate")
    frame.label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.label:SetPoint("TOPLEFT", 84, -14)
    frame.label:SetText("IGNITE"); frame.label:SetTextColor(1, 0.65, 0.1)
    frame.count = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    frame.count:SetPoint("CENTER", frame, "CENTER", 34, -8)
    frame.count:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 42, "OUTLINE")
    frame.count:SetTextColor(1, 0.85, 0.1)
    local elapsed = 0
    frame:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed >= 0.2 then elapsed = 0; self:UpdateIgniteDisplay() end
    end)
    self.igniteDisplay = frame
    self:UpdateIgniteDisplay()
end

function addon:UpdateIgniteDisplay()
    local frame = self.igniteDisplay
    if not frame then return end
    frame:Hide()
    if not self.db.showIgnite or not UnitExists or self:Readable(UnitExists("target")) ~= true
        or not UnitCanAttack or self:Readable(UnitCanAttack("player", "target")) ~= true
        or (UnitIsDeadOrGhost and self:Readable(UnitIsDeadOrGhost("target")) == true) then return end
    local aura, state = self:TargetIgnite()
    if not aura then
        -- A failed lookup is never rendered as a fabricated stack count.
        if state == "unknown" and not self.igniteUnavailable then self:DebugLog("Ignite unavailable", "The client restricted target aura information.") end
        self.igniteUnavailable = state == "unknown"
        return
    end
    self.igniteUnavailable = false
    local count = aura.applications
    local readable = self:Readable(count)
    if readable == 0 then count = 1 end
    if readable == nil and not (issecretvalue and issecretvalue(count)) then
        frame.count:SetText("?")
    else
        -- Secret stack counts go directly to Blizzard's native text formatter.
        frame.count:SetFormattedText("%d", count)
    end
    frame:Show()
end

function addon:RestorePosition()
    self.frame:ClearAllPoints()
    self.frame:SetPoint(self.db.point, UIParent, self.db.relativePoint, self.db.x, self.db.y)
end

function addon:UpdateMana()
    -- Secret values are passed only to native display widgets.
    self.manaBar:SetMinMaxValues(0, UnitPowerMax("player", 0))
    self.manaBar:SetValue(UnitPower("player", 0))
    self:UpdateCenterDisplay()
end

function addon:UpdateCenterDisplay()
    local selected = self.sphere.displayMode or self.db.centerAction
    if selected == "evocation" then
        self.centerLabel:SetText("Evocation")
        -- Do not inspect or calculate with protected mana values.
        self.manaText:SetFormattedText("%d", UnitPower("player", 0))
        return
    end
    if selected == "eatdrink" then
        self.centerLabel:SetText("Eat + Drink")
        local stock = self:SupplyStatus()
        self.manaText:SetFormattedText("Food %d\nWater %d", stock.food, stock.water)
        return
    end
    self.centerLabel:SetText("Mana Gem")
    local count = 0
    for _, definition in ipairs(self.spells) do
        if definition.category == "mana" and definition.item then
            count = count + self:ItemCount(definition.item)
        end
    end
    self.manaText:SetFormattedText("%d", count)
end

function addon:CreateActionButton(menu, index)
    local button = CreateFrame("Button", nil, menu, "SecureActionButtonTemplate")
    button:SetSize(40, 40)
    local columns = self.db.iconsPerRow
    local column, row = (index - 1) % columns, math.floor((index - 1) / columns)
    button:SetPoint("TOPLEFT", menu, "TOPLEFT", 6 + column * 44, -6 - row * 44)
    button:RegisterForClicks("AnyDown", "AnyUp")
    button:SetAttribute("useOnKeyDown", false)
    button.icon = roundedIcon(button, "Interface\\Icons\\INV_Misc_QuestionMark", 40)
    button.count = makeText(button, "GameFontHighlightSmall", "BOTTOMRIGHT", -2, 1)
    button.badge = makeText(button, "GameFontHighlightSmall", "TOPLEFT", 1, -1)
    button.badge:SetTextColor(0.5, 0.9, 1)
    button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    button.cooldown:SetAllPoints(button.icon)
    button.cooldown:EnableMouse(false)
    if button.cooldown.SetHideCountdownNumbers then button.cooldown:SetHideCountdownNumbers(true) end
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetTexture("Interface\\AddOns\\Arcanum\\Media\\Ring")
    highlight:SetBlendMode("ADD")
    button:SetScript("OnEnter", function()
        if not self.db.showTooltips then return end
        local action = button.action
        if not action then return end
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        if action.kind == "spell" then GameTooltip:SetSpellByID(self:RecipientBuffSpell(action, InCombatLockdown()) or action.id)
        else GameTooltip:SetItemByID(action.id) end
        if action.friendly then GameTooltip:AddLine("Right-click: cast on yourself", 0.5, 0.8, 1) end
        if action.countItem then GameTooltip:AddLine("Count: carried items or required reagent", 0.5, 0.8, 1, true) end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:HookScript("PostClick", function(_, _, down)
        if not down then self:RememberSelection(button.categoryID, button.action) end
    end)
    return button
end

function addon:BindAction(button, action)
    button.action = action
    button:SetAttribute("type", action.kind)
    button:SetAttribute("spell", action.kind == "spell" and action.id or nil)
    button:SetAttribute("item", action.kind == "item" and ("item:" .. action.id) or nil)
    button:SetAttribute("unit", action.self and "player" or nil)
    button:SetAttribute("unit2", action.friendly and "player" or nil)
    self:ConfigureRecipientBuff(button, action)
    button.icon:SetTexture(action.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    button.badge:SetText(self.db.showBadges and (action.kind == "item" and "Use" or (action.conjure and "+" or "")) or "")
    button:Show()
end

function addon:RefreshCenterAction(actions)
    local gem, evocation
    for _, action in ipairs(actions.mana) do
        if action.kind == "item" then gem = action end
        if action.kind == "spell" and action.id == 12051 then evocation = action end
    end
    local selected = self.db.centerAction
    local action
    if selected == "evocation" then action = evocation
    elseif selected == "eatdrink" then action = self:EatDrinkAction(actions)
    else action = gem end
    self.sphere.displayMode = selected
    self.sphere.action, self.sphere.shiftAction = action, evocation
    self.sphere:SetAttribute("*type3", "")
    self.sphere:SetAttribute("*item3", nil)
    -- Explicit no-op prevents a missing Shift action from falling back to drink
    -- or a gem. Only Blizzard's secure template performs spell/item actions.
    for prefix, binding in pairs({[""]={action}, ["shift-"]={evocation}}) do
        local bound = binding[1]
        self.sphere:SetAttribute(prefix .. "type1", bound and bound.kind or "")
        self.sphere:SetAttribute(prefix .. "spell1", bound and bound.kind == "spell" and bound.id or nil)
        self.sphere:SetAttribute(prefix .. "item1", bound and bound.kind == "item" and ("item:" .. bound.id) or nil)
        self.sphere:SetAttribute(prefix .. "macrotext1", bound and bound.kind == "macro" and bound.macro or nil)
        self.sphere:SetAttribute(prefix .. "unit1", "player")
    end
    self.sphere.unavailable = selected == "evocation" and "Evocation is not learned yet."
        or selected == "eatdrink" and "No usable conjured food or water carried."
        or "No mana gem carried. Conjure one using the mana menu."
end

function addon:CreateCircle()
    local frame = CreateFrame("Frame", "ArcanumFrame", UIParent)
    frame:SetSize(236, 236)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    self.frame = frame
    self:RestorePosition()
    self.menus, self.toggles = {}, {}

    local sphere = CreateFrame("Button", nil, frame, "SecureActionButtonTemplate")
    self.sphere = sphere
    sphere:SetSize(96, 96)
    sphere:SetPoint("CENTER")
    sphere:RegisterForDrag("LeftButton")
    sphere:RegisterForClicks("AnyDown", "AnyUp")
    sphere:SetAttribute("useOnKeyDown", false)
    sphere:SetAttribute("*type2", "")
    sphere:HookScript("OnClick", function(_, button, down)
        if button == "RightButton" and not down then self:OpenSettings() end
    end)
    sphere:SetScript("OnDragStart", function()
        if not self.db.locked and not InCombatLockdown() then frame:StartMoving() end
    end)
    sphere:SetScript("OnDragStop", function()
        if InCombatLockdown() then return end
        frame:StopMovingOrSizing()
        local point, _, relativePoint, x, y = frame:GetPoint()
        self.db.point, self.db.relativePoint = point, relativePoint
        self.db.x, self.db.y = x, y
    end)
    sphere:SetScript("OnEnter", function()
        if not self.db.showTooltips then return end
        GameTooltip:SetOwner(sphere, "ANCHOR_RIGHT")
        GameTooltip:SetText("Arcanum")
        local action = sphere.action
        GameTooltip:AddLine("Left-click: " .. (action and action.name or sphere.unavailable), 1, 1, 1, true)
        local shift = sphere.shiftAction
        GameTooltip:AddLine("Shift + left-click: " .. (shift and shift.name or "Evocation (not learned yet)"), 0.5, 0.8, 1, true)
        GameTooltip:AddLine("Right-click: options. Drag to move when unlocked.", 1, 1, 1, true)
        for _, message in ipairs(self.reminderMessages or {}) do GameTooltip:AddLine(message, 1, 0.65, 0.2, true) end
        GameTooltip:Show()
    end)
    sphere:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local orb = sphere:CreateTexture(nil, "BACKGROUND")
    orb:SetAllPoints()
    orb:SetTexture("Interface\\AddOns\\Arcanum\\Media\\Orb")
    local centerCooldown = CreateFrame("Cooldown", nil, sphere, "CooldownFrameTemplate")
    centerCooldown:SetAllPoints(orb)
    centerCooldown:EnableMouse(false)
    if centerCooldown.SetSwipeTexture then centerCooldown:SetSwipeTexture("Interface\\AddOns\\Arcanum\\Media\\Ring") end
    if centerCooldown.SetDrawEdge then centerCooldown:SetDrawEdge(false) end
    if centerCooldown.SetHideCountdownNumbers then centerCooldown:SetHideCountdownNumbers(true) end
    self.centerCooldown = centerCooldown
    self.reminderGlow = sphere:CreateTexture(nil, "OVERLAY")
    self.reminderGlow:SetAllPoints(orb)
    self.reminderGlow:SetTexture("Interface\\AddOns\\Arcanum\\Media\\Ring")
    self.reminderGlow:SetVertexColor(1, 0.65, 0.2)
    self.reminderGlow:SetBlendMode("ADD")
    self.reminderGlow:Hide()
    self.reminderGlows = {}
    local alert = CreateFrame("Frame", "ArcanumBuffReminder", UIParent, "BackdropTemplate")
    alert:SetSize(280, 86)
    alert:SetFrameStrata("DIALOG")
    alert:SetClampedToScreen(true)
    alert:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", tile=true,tileSize=16,edgeSize=16,insets={left=4,right=4,top=4,bottom=4}})
    local title = alert:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -10)
    title:SetText("Missing Buffs")
    title:SetTextColor(1, 0.4, 0.2)
    self.buffReminderFrame = alert
    self.buffReminderText = alert:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.buffReminderText:SetPoint("TOP", 0, -30)
    self.buffReminderText:SetWidth(254)
    self.buffReminderText:SetJustifyH("CENTER")
    self.buffReminderText:SetTextColor(1, 0.82, 0)
    alert:Hide()
    self.manaText = makeText(sphere, "GameFontNormalLarge", "CENTER")
    self.manaText:SetTextColor(0.75, 0.93, 1)
    self.centerLabel = makeText(sphere, "GameFontHighlightSmall", "TOP", 0, -18)
    local bar = CreateFrame("StatusBar", nil, sphere)
    bar:SetSize(52, 4)
    bar:SetPoint("BOTTOM", 0, 20)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0.2, 0.65, 1)
    bar:SetMinMaxValues(0, 1)
    self.manaBar = bar
    local color = self.themes[self.db.colorTheme] or self.themes.arcane
    bar:SetStatusBarColor(unpack(color))
    self.manaText:SetTextColor(unpack(color))

    for _, category in ipairs(self.categories) do
        local menu = CreateFrame("Frame", nil, frame, "SecureHandlerBaseTemplate")
        menu:SetSize(240, 100)
        menu:SetFrameStrata("DIALOG")
        menu:EnableMouse(true)
        menu:SetClampedToScreen(true)
        menu.rows = {}
        -- Keep the hover region invisible; only round action icons are drawn.
        menu:Hide()
        self.menus[category.id] = menu

        local toggle = CreateFrame("Button", nil, frame, "SecureActionButtonTemplate,SecureHandlerEnterLeaveTemplate")
        toggle.categoryID = category.id
        toggle:SetSize(40, 40)
        toggle.icon = roundedIcon(toggle, category.icon, 40)
        if category.direct then
            toggle.directCooldown = CreateFrame("Cooldown", nil, toggle, "CooldownFrameTemplate")
            toggle.directCooldown:SetAllPoints(toggle.icon); toggle.directCooldown:EnableMouse(false)
        end
        local glow = toggle:CreateTexture(nil, "HIGHLIGHT")
        glow:SetAllPoints()
        glow:SetTexture("Interface\\AddOns\\Arcanum\\Media\\Ring")
        glow:SetBlendMode("ADD")
        toggle:RegisterForClicks("AnyDown", "AnyUp")
        toggle:SetAttribute("useOnKeyDown", false)
        toggle:SetAttribute("type", "")
        toggle:SetAttribute("direct", category.direct)
        toggle:SetAttribute("menu-count", #self.categories)
        toggle.timer = makeText(toggle, "GameFontHighlightSmall", "BOTTOM", 0, -12)
        toggle:SetFrameRef("menu", menu)
        -- Preserve the template's secure hover scripts. Category icons open
        -- actual action buttons; only the individual actions show tooltips.
        toggle:HookScript("OnEnter", function()
            GameTooltip:Hide()
            if category.direct and self.db.showTooltips and toggle.directAction then
                GameTooltip:SetOwner(toggle, "ANCHOR_RIGHT")
                GameTooltip:SetItemByID(toggle.directAction.id)
                GameTooltip:AddLine("Left-click: use Hearthstone", 0.5, 0.8, 1, true)
                local home = GetBindLocation and self:Readable(GetBindLocation())
                if type(home) == "string" then GameTooltip:AddLine("Home: " .. home, 1, 1, 1, true) end
                GameTooltip:Show()
            end
        end)
        if category.direct then toggle:HookScript("OnLeave", function() GameTooltip:Hide() end) end
        self.toggles[category.id] = toggle
        local reminder = toggle:CreateTexture(nil, "OVERLAY")
        reminder:SetAllPoints()
        reminder:SetTexture("Interface\\AddOns\\Arcanum\\Media\\Ring")
        reminder:SetVertexColor(1, 0.65, 0.2); reminder:SetBlendMode("ADD"); reminder:Hide()
        self.reminderGlows[category.id] = reminder
    end
    for _, toggle in pairs(self.toggles) do
        for index, category in ipairs(self.categories) do
            toggle:SetFrameRef("menu" .. index, self.menus[category.id])
        end
        toggle:SetAttribute("_onclick", [[
            local button, down = ...
            if self:GetAttribute("direct") then return end
            if down or IsShiftKeyDown() then return end
            local menu = self:GetFrameRef("menu")
            if menu:GetAttribute("pinned") then
                menu:SetAttribute("pinned", nil)
                menu:Hide()
            else
                for index = 1, self:GetAttribute("menu-count") do
                    local other = self:GetFrameRef("menu" .. index)
                    other:SetAttribute("pinned", nil)
                    other:Hide()
                end
                menu:Show()
                menu:SetAttribute("pinned", true)
                menu:UnregisterAutoHide()
            end
        ]])
        SecureHandlerWrapScript(toggle, "OnClick", toggle, [[self:RunAttribute("_onclick", button, down)]])
        toggle:SetAttribute("_onenter", [[
            if self:GetAttribute("direct") then return end
            if not self:GetAttribute("hover-enabled") then return end
            local menu = self:GetFrameRef("menu")
            for index = 1, self:GetAttribute("menu-count") do
                local other = self:GetFrameRef("menu" .. index)
                if other ~= menu then
                    other:SetAttribute("pinned", nil)
                    other:Hide()
                end
            end
            menu:Show()
            if not menu:GetAttribute("pinned") then
                menu:RegisterAutoHide(self:GetAttribute("close-delay") or 0.35)
                menu:AddToAutoHide(self)
            end
        ]])
    end
    frame:SetShown(self.db.visible)
    self:CreatePreparationButtons()
    self:UpdateMana()
    self:RefreshActions()
    frame:SetScale(self.db.scale / 100)
end
