local _, addon = ...

function addon:Readable(value)
    if issecretvalue and issecretvalue(value) then return nil end
    return value
end

function addon:KnownSpell(id)
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, known = pcall(C_SpellBook.IsSpellKnown, id)
        if ok and self:Readable(known) ~= nil then return known == true end
    end
    if IsSpellKnown then
        local ok, known = pcall(IsSpellKnown, id)
        if ok and self:Readable(known) ~= nil then return known == true end
    end
    if IsPlayerSpell then
        local ok, known = pcall(IsPlayerSpell, id)
        if ok and self:Readable(known) ~= nil then return known == true end
    end
    return false
end

function addon:SpellInfo(id)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(id)
        if self:Readable(info) and self:Readable(info.name) then
            return info.name, self:Readable(info.iconID)
        end
    elseif GetSpellInfo then
        local name, _, icon = GetSpellInfo(id)
        return self:Readable(name), self:Readable(icon)
    end
end

function addon:ItemCount(id)
    local query = C_Item and C_Item.GetItemCount or GetItemCount
    if not query then return 0 end
    local count = self:Readable(query(id, false, false))
    return type(count) == "number" and count or 0
end

-- Discover additional learned ranks sharing a catalog spell's localized name.
-- This lets a new Forever rank participate without pretending every database
-- spell is learned. A later rank in the spellbook replaces an earlier one.
function addon:ScanSpellBook()
    local learned, variants = {}, {}
    for _, definition in ipairs(self.spells) do
        if definition.discoverRanks == false then
            for _, id in ipairs(definition.ranks) do variants[id] = true end
        end
    end
    if not (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and
        C_SpellBook.GetSpellBookSkillLineInfo and C_SpellBook.GetSpellBookItemInfo) then
        return learned
    end
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    local lines = self:Readable(C_SpellBook.GetNumSpellBookSkillLines())
    if type(lines) ~= "number" then return learned end
    for line = 1, lines do
        local info = self:Readable(C_SpellBook.GetSpellBookSkillLineInfo(line))
        if info then
            local offset, count = self:Readable(info.itemIndexOffset), self:Readable(info.numSpellBookItems)
            if type(offset) == "number" and type(count) == "number" then
                for slot = offset + 1, offset + count do
                    local entry = self:Readable(C_SpellBook.GetSpellBookItemInfo(slot, bank))
                    local id = entry and self:Readable(entry.spellID)
                    if type(id) == "number" and not variants[id] and self:KnownSpell(id) then
                        local name = self:SpellInfo(id)
                        if name then learned[name] = id end
                    end
                end
            end
        end
    end
    return learned
end

function addon:BuildActions()
    local byCategory, learned, included = {}, self:ScanSpellBook(), {}
    self.trackedItems = {}
    for _, category in ipairs(self.categories) do byCategory[category.id] = {} end
    for _, definition in ipairs(self.spells) do
        if definition.reagent then self.trackedItems[definition.reagent] = true end
        local id, rank
        for index, candidate in ipairs(definition.ranks) do
            if self:KnownSpell(candidate) then id, rank = candidate, index end
        end
        -- Conjuring ranks have item mappings, so only use their verified ranks.
        if not definition.items and definition.discoverRanks ~= false then
            local baseName = self:SpellInfo(definition.ranks[1])
            local discovered = baseName and learned[baseName]
            if discovered and self:KnownSpell(discovered) then id = discovered end
        end
        local key = id and (definition.category .. ":" .. id)
        if id and not included[key] then
            local name, icon = self:SpellInfo(id)
            if name then
                included[key] = true
                local item = definition.item or (definition.items and definition.items[rank])
                if item then self.trackedItems[item] = true end
                local actions = byCategory[definition.category]
                actions[#actions + 1] = {
                    kind = "spell", id = id, name = name, icon = icon, baseSpell = definition.ranks[1],
                    self = definition.self, friendly = definition.friendly,
                    conjure = item ~= nil,
                    countItem = item or definition.reagent,
                }
                if definition.items then
                    -- Use the best conjured rank that is actually in the bags.
                    item = nil
                    for index = #definition.items, 1, -1 do
                        local candidate = definition.items[index]
                        if self:KnownSpell(definition.ranks[index]) and self:ItemCount(candidate) > 0 then
                            item = candidate
                            break
                        end
                    end
                end
                if item and self:ItemCount(item) > 0 then
                    self.trackedItems[item] = true
                    local query = C_Item and C_Item.GetItemInfo or GetItemInfo
                    local itemName = query and self:Readable(query(item))
                    local iconQuery = C_Item and C_Item.GetItemIconByID or GetItemIcon
                    actions[#actions + 1] = {
                        kind = "item", id = item, name = "Use: " .. (itemName or name),
                        icon = iconQuery and self:Readable(iconQuery(item)) or icon,
                        countItem = item, self = true,
                    }
                end
            end
        end
    end
    self.trackedItems[6948] = true
    if self:ItemCount(6948) > 0 then
        byCategory.hearthstone = {{kind="item", id=6948, name="Hearthstone", icon="Interface\\Icons\\INV_Misc_Rune_01", self=true}}
    end
    return byCategory
end

function addon:RefreshActions()
    if InCombatLockdown() then self.refreshPending = true; return end
    self.refreshPending = false
    local actions = self:BuildActions()
    self:RefreshCenterAction(actions)
    self:RefreshPreparationActions(actions)
    local visible = {}
    for _, category in ipairs(self:OrderedCategories()) do
        local menu, toggle = self.menus[category.id], self.toggles[category.id]
        local list = {}
        for _, action in ipairs(actions[category.id]) do
            local supply = action.kind == "item" and self.supplyItems[action.id]
            -- Eating/drinking belong to the combined orb action and keybinding.
            if not supply then list[#list + 1] = action end
        end
        local wasShown = menu:IsShown()
        menu:Hide()
        for _, button in ipairs(menu.rows) do
            button:Hide()
            button:SetAttribute("type", nil)
            button:SetAttribute("spell", nil)
            button:SetAttribute("item", nil)
            button.action = nil
        end
        for index, action in ipairs(category.direct and {} or list) do
            local button = menu.rows[index]
            if not button then
                button = self:CreateActionButton(menu, index)
                menu.rows[index] = button
            end
            button.categoryID = category.id
            self:BindAction(button, action)
            local columns = self.db.iconsPerRow
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", menu, "TOPLEFT", 6 + ((index - 1) % columns) * 44,
                -6 - math.floor((index - 1) / columns) * 44)
        end
        menu:SetSize(math.max(1, math.min(self.db.iconsPerRow, #list)) * 44 + 8,
            math.max(1, math.ceil(#list / self.db.iconsPerRow)) * 44 + 8)
        local last
        for _, action in ipairs(list) do
            if action.kind == "spell" and self:SelectionMatches(category.id, action) then last = action end
        end
        self:BindLastSelection(category.id, last)
        toggle.directAction = category.direct and list[1] or nil
        if category.direct then
            toggle:SetAttribute("type1", toggle.directAction and "item" or "")
            toggle:SetAttribute("item1", toggle.directAction and "item:" .. toggle.directAction.id or nil)
            toggle:SetAttribute("unit1", "player")
        end
        local enabled = #list > 0 and self.db.categoryEnabled[category.id] ~= false
        toggle:SetShown(enabled)
        toggle:SetAttribute("hover-enabled", self.db.hover)
        toggle:SetAttribute("close-delay", self.db.closeDelay)
        if wasShown and enabled and not category.direct then
            menu:Show()
            if RegisterAutoHide and AddToAutoHide and not menu:GetAttribute("pinned") then
                RegisterAutoHide(menu, self.db.closeDelay)
                AddToAutoHide(menu, toggle)
            end
        elseif not enabled then
            menu:SetAttribute("pinned", nil)
        end
        if enabled then visible[#visible + 1] = toggle end
    end
    for index, toggle in ipairs(visible) do
        local angle = math.rad(90 - self.db.rotation - (index - 1) * 360 / #visible)
        toggle:ClearAllPoints()
        toggle:SetPoint("CENTER", self.frame, "CENTER", math.cos(angle) * self.db.radius, math.sin(angle) * self.db.radius)
        local menu = self.menus[toggle.categoryID]
        menu:ClearAllPoints()
        local direction = self.db.flyoutDirection
        if direction == "up" then
            menu:SetPoint("BOTTOM", toggle, "TOP", 0, 6)
        elseif direction == "down" then
            menu:SetPoint("TOP", toggle, "BOTTOM", 0, -6)
        elseif direction == "left" or (direction == "auto" and math.cos(angle) < -0.1) then
            menu:SetPoint("RIGHT", toggle, "LEFT", -6, 0)
        else
            menu:SetPoint("LEFT", toggle, "RIGHT", 6, 0)
        end
    end
    self:UpdateActionDisplays()
    self:UpdateReminders()
    self:UpdateBuffTimers()
end

function addon:DisplayCooldown(widget, action, enabled)
    if not enabled or not action then widget:Clear(); return end
    if action.kind == "spell" and C_Spell and C_Spell.GetSpellCooldownDuration and widget.SetCooldownFromDurationObject then
        local duration = C_Spell.GetSpellCooldownDuration(action.id)
        if duration then widget:SetCooldownFromDurationObject(duration) else widget:Clear() end
        return
    end
    local start, duration
    if action.kind == "item" then
        local query = C_Container and C_Container.GetItemCooldown or GetItemCooldown
        if query then start, duration = query(action.id) end
    elseif C_Spell and C_Spell.GetSpellCooldown then
        local info = self:Readable(C_Spell.GetSpellCooldown(action.id))
        if info then start, duration = info.startTime, info.duration end
    elseif GetSpellCooldown then start, duration = GetSpellCooldown(action.id) end
    start, duration = self:Readable(start), self:Readable(duration)
    if type(start) == "number" and type(duration) == "number" then widget:SetCooldown(start, duration)
    else widget:Clear() end
end

function addon:UpdateActionDisplays()
    self:UpdateCenterDisplay()
    local centerAction = self.sphere.displayMode ~= "eatdrink" and self.sphere.action or nil
    self:DisplayCooldown(self.centerCooldown, centerAction, self.db.centerCooldown)
    for _, toggle in pairs(self.toggles) do
        if toggle.directCooldown then
            toggle.directCooldown:SetHideCountdownNumbers(not self.db.showCooldownNumbers)
            self:DisplayCooldown(toggle.directCooldown, toggle.directAction, self.db.showCooldowns)
        end
    end
    for _, menu in pairs(self.menus) do
        for _, button in ipairs(menu.rows) do
            local action = button.action
            if action then
                if button.cooldown.SetHideCountdownNumbers then button.cooldown:SetHideCountdownNumbers(not self.db.showCooldownNumbers) end
                if action.countItem and self.db.showCounts then
                    -- Count labels go straight to the native formatter.
                    local query = C_Item and C_Item.GetItemCount or GetItemCount
                    if query then button.count:SetFormattedText("%d", query(action.countItem, false, false)) end
                else
                    button.count:SetText("")
                end
                if not self.db.showCooldowns then
                    button.cooldown:Clear()
                elseif action.kind == "spell" and C_Spell and C_Spell.GetSpellCooldownDuration and
                    button.cooldown.SetCooldownFromDurationObject then
                    local duration = C_Spell.GetSpellCooldownDuration(action.id)
                    if duration then button.cooldown:SetCooldownFromDurationObject(duration)
                    else button.cooldown:Clear() end
                else
                    local start, duration
                    if action.kind == "item" then
                        local query = C_Container and C_Container.GetItemCooldown or GetItemCooldown
                        if query then start, duration = query(action.id) end
                    elseif C_Spell and C_Spell.GetSpellCooldown then
                        local info = self:Readable(C_Spell.GetSpellCooldown(action.id))
                        if info then start, duration = info.startTime, info.duration end
                    elseif GetSpellCooldown then
                        start, duration = GetSpellCooldown(action.id)
                    end
                    start, duration = self:Readable(start), self:Readable(duration)
                    if type(start) == "number" and type(duration) == "number" then
                        button.cooldown:SetCooldown(start, duration)
                    else
                        button.cooldown:Clear()
                    end
                end
            end
        end
    end
end
