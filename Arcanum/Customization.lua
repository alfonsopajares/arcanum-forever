local _, addon = ...

addon.themes = {arcane={0.2,0.65,1}, violet={0.65,0.35,1}, frost={0.4,0.9,1}, gold={1,0.7,0.2}}

function addon:OrderedCategories()
    local result, seen, lookup = {}, {}, {}
    for _, category in ipairs(self.categories) do lookup[category.id] = category end
    for _, id in ipairs(self.db.categoryOrder) do
        if lookup[id] and not seen[id] then result[#result+1] = lookup[id]; seen[id] = true end
    end
    for _, category in ipairs(self.categories) do
        if not seen[category.id] then result[#result+1] = category end
    end
    return result
end

function addon:MoveCategory(id, direction)
    local ordered = self:OrderedCategories()
    for index, category in ipairs(ordered) do
        if category.id == id then
            local other = index + direction
            if other >= 1 and other <= #ordered then ordered[index], ordered[other] = ordered[other], ordered[index] end
            break
        end
    end
    self.db.categoryOrder = {}
    for _, category in ipairs(ordered) do self.db.categoryOrder[#self.db.categoryOrder+1] = category.id end
    self:SettingsChanged()
    self:RefreshCategoryOrderUI()
end

function addon:RefreshCategoryOrderUI()
    if not self.settings or not self.settings.orderLabels then return end
    for index, category in ipairs(self:OrderedCategories()) do self.settings.orderLabels[index]:SetText(index .. ". " .. category.label) end
end

function addon:RememberSelection(category, action)
    if not category or not action or action.kind ~= "spell" then return end
    self.db.lastSelections[category] = action.id
    if InCombatLockdown() then self.refreshPending = true; return end
    self:BindLastSelection(category, action)
end

function addon:SelectionMatches(category, action)
    local selected = self.db.lastSelections[category]
    if action.id == selected then return true end
    for _, definition in ipairs(self.spells) do
        if definition.category == category and definition.ranks[1] == action.baseSpell then
            for _, id in ipairs(definition.ranks) do if id == selected then return true end end
        end
    end
    return false
end

function addon:BindLastSelection(category, action)
    local toggle = self.toggles[category]
    if not toggle then return end
    toggle.lastAction = action
    toggle:SetAttribute("shift-type1", action and "spell" or "")
    toggle:SetAttribute("shift-spell1", action and action.id or nil)
    toggle:SetAttribute("shift-unit1", action and action.self and "player" or nil)
    self:ConfigureRecipientBuff(toggle, action, "shift-")
end

function addon:BuffTime(category)
    local ids = {}
    for _, spell in ipairs(self.spells) do
        if spell.category == category and (category == "armor" or spell.ranks[1] == 1459 or spell.ranks[1] == 23028) then
            for _, id in ipairs(spell.ranks) do ids[id] = true end
        end
    end
    local query = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
    local function expiration(info)
        info = self:Readable(info)
        local value = info and self:Readable(info.expirationTime)
        if type(value) == "number" and value > 0 then return value end
    end
    if query then
        for id in pairs(ids) do
            local ok, info = pcall(query, id)
            if ok then local value = expiration(info); if value then return value end end
        end
    else
        for index = 1, 80 do
            local info
            if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
                local ok, value = pcall(C_UnitAuras.GetAuraDataByIndex, "player", index, "HELPFUL")
                if not ok then return end
                info = self:Readable(value)
            elseif UnitBuff then
                local values = {pcall(UnitBuff, "player", index)}
                if not values[1] or self:Readable(values[2]) == nil then return end
                info = {spellId=values[11], expirationTime=values[8]}
            else return end
            if not info then return end
            local id = self:Readable(info.spellId)
            if id and ids[id] then return expiration(info) end
        end
    end
end

function addon:UpdateBuffTimers()
    for _, category in ipairs({"buffs", "armor"}) do
        local toggle = self.toggles and self.toggles[category]
        if toggle and toggle.timer then
            local expiry = self.db.showBuffTimers and self:BuffTime(category)
            local remaining = expiry and math.max(0, expiry - GetTime())
            toggle.timer:SetText(remaining and remaining > 0 and
                (remaining >= 60 and (math.ceil(remaining / 60) .. "m") or (math.ceil(remaining) .. "s")) or "")
        end
    end
end
