local _, addon = ...

addon.distribution = {}
local function now() return GetTime and GetTime() or 0 end

function addon:GroupMembers()
    local members, player = {}, UnitGUID and self:Readable(UnitGUID("player"))
    local raid = IsInRaid and self:Readable(IsInRaid()) == true
    local count = raid and (GetNumGroupMembers and self:Readable(GetNumGroupMembers()) or 0)
        or (GetNumSubgroupMembers and self:Readable(GetNumSubgroupMembers()) or 0)
    for index = 1, math.min(40, count) do
        local unit = (raid and "raid" or "party") .. index
        local name = self:Readable(UnitName(unit))
        local guid = UnitGUID and self:Readable(UnitGUID(unit))
        if name and (not player or guid ~= player) then
            local _, class = UnitClass(unit)
            members[#members + 1] = {name=name, key=guid or name, class=self:Readable(class) or "UNKNOWN"}
        end
    end
    return members
end

function addon:ActiveProfile()
    local name = self.db.preparation.profile
    if name == "auto" then
        if IsInRaid and self:Readable(IsInRaid()) == true then name = "raid"
        elseif #self:GroupMembers() > 0 then name = "party" else name = "solo" end
    end
    if not self.db.preparation.profiles[name] then name = "solo" end
    return name, self.db.preparation.profiles[name]
end

function addon:PruneDistribution()
    local cutoff = self:EpochTime() - self.db.preparation.historyMinutes * 60
    for key, entry in pairs(self.distribution) do
        if type(entry) ~= "table" or type(entry.time) ~= "number" or entry.time <= cutoff
            or type(entry.food) ~= "number" or type(entry.water) ~= "number" then self.distribution[key] = nil end
    end
end

function addon:EstimateSupplies()
    self:PruneDistribution()
    local estimate = {food=self.db.vending.reserveFood, water=self.db.vending.reserveWater}
    local members = self:GroupMembers()
    for _, member in ipairs(members) do
        local preset = self.db.vending.presets[member.class] or self.db.vending.presets.UNKNOWN
        local given = self.db.preparation.trackTrades and self.distribution[member.key]
        estimate.food = estimate.food + math.max(0, preset.food - (given and given.food or 0))
        estimate.water = estimate.water + math.max(0, preset.water - (given and given.water or 0))
    end
    return estimate, members
end

function addon:SetTargetsFromGroup()
    local estimate, members = self:EstimateSupplies()
    if #members == 0 then return end
    local _, profile = self:ActiveProfile()
    profile.food, profile.water = estimate.food, estimate.water
    self:SettingsChanged()
    self:OpenSettings("Preparation")
end

function addon:SupplyStatus()
    local status = {food=0, water=0, gems=0, missingGems=0, learnedGems=0}
    for _, definition in ipairs(self.spells) do
        if definition.kind then
            for _, item in ipairs(definition.items) do status[definition.kind] = status[definition.kind] + self:ItemCount(item) end
        elseif definition.category == "mana" and definition.item then
            local count = self:ItemCount(definition.item)
            status.gems = status.gems + count
            if self:KnownSpell(definition.ranks[1]) then
                status.learnedGems = status.learnedGems + 1
                if count == 0 then status.missingGems = status.missingGems + 1 end
            end
        end
    end
    return status
end

-- Trade acceptance is not completion. Record only the client's success message,
-- allowing it to arrive just after TRADE_CLOSED. Each snapshot is consumed once.
function addon:DistributionEvent(event, first, message)
    if event == "TRADE_SHOW" then self.acceptedTrade = nil; return end
    if event == "TRADE_PLAYER_ITEM_CHANGED" or event == "TRADE_TARGET_ITEM_CHANGED" then
        self.acceptedTrade = nil; return
    end
    if event == "TRADE_ACCEPT_UPDATE" then
        self.acceptedTrade = nil
        if self:Readable(first) ~= 1 or not self.trade.open then return end
        local totals = self:TradeOffer()
        if totals then
            self.acceptedTrade = {key=self.trade.key or self.trade.name, name=self.trade.name,
                class=self.trade.class, food=totals.food, water=totals.water, time=now()}
        end
    elseif event == "TRADE_CLOSED" then
        if self.acceptedTrade then self.acceptedTrade.closed = now() end
    elseif event == "UI_INFO_MESSAGE" then
        message = self:Readable(message)
        local snapshot = self.acceptedTrade
        if not snapshot or not ERR_TRADE_COMPLETE or message ~= ERR_TRADE_COMPLETE then return end
        self.acceptedTrade = nil
        if not self.db.preparation.trackTrades or (snapshot.closed and now() - snapshot.closed > 5) then return end
        if snapshot.food + snapshot.water == 0 then return end
        self:PruneDistribution()
        local deliveredFood, deliveredWater = snapshot.food, snapshot.water
        local previous = self.distribution[snapshot.key]
        snapshot.food = snapshot.food + (previous and previous.food or 0)
        snapshot.water = snapshot.water + (previous and previous.water or 0)
        snapshot.time, snapshot.closed = self:EpochTime(), nil
        self.distribution[snapshot.key] = snapshot
        self:DebugLog("trade completed", string.format("%s: delivered food=%d water=%d", snapshot.name, deliveredFood, deliveredWater))
        self:RefreshPreparationUI()
    end
end

function addon:ResetDistribution()
    self.distribution, self.acceptedTrade = {}, nil
    self.character.distribution = self.distribution
    self:RefreshPreparationUI()
end

function addon:PlayerBuffs()
    local result = {}
    for index = 1, 80 do
        local id
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local ok, info = pcall(C_UnitAuras.GetAuraDataByIndex, "player", index, "HELPFUL")
            if not ok or (info and not self:Readable(info)) then return nil end
            if not info then return result end
            id = self:Readable(info.spellId)
        elseif UnitBuff then
            local values = {pcall(UnitBuff, "player", index)}
            if not values[1] then return nil end
            if values[2] == nil then return result end
            id = self:Readable(values[11])
        else return nil end
        if type(id) ~= "number" then return nil end
        result[id] = true
    end
    return nil -- Suppress missing-buff warnings if the scan was incomplete.
end

function addon:UpdateReminders()
    if not self.reminderGlow then return end
    local options, messages, categories, buffMessages = self.db.reminders, {}, {}, {}
    local active = options.enabled and not (options.hideInCombat and InCombatLockdown())
        and not (options.groupOnly and #self:GroupMembers() == 0)
    local function warn(category, message)
        categories[category] = true; messages[#messages + 1] = message
    end
    if active then
        local stock = self:SupplyStatus()
        local _, profile = self:ActiveProfile()
        if options.food and stock.food < math.min(options.lowFood, profile.food) then
            warn("refreshments", string.format("Need %d more food (%d/%d). Click Prepare or the food/water menu.", profile.food-stock.food, stock.food, profile.food))
        end
        if options.water and stock.water < math.min(options.lowWater, profile.water) then
            warn("refreshments", string.format("Need %d more water (%d/%d). Click Prepare or the food/water menu.", profile.water-stock.water, stock.water, profile.water))
        end
        if options.gems and stock.missingGems > 0 then
            for _, definition in ipairs(self.spells) do
                if definition.category == "mana" and definition.item and self:KnownSpell(definition.ranks[1]) and self:ItemCount(definition.item) == 0 then
                    local query = C_Item and C_Item.GetItemInfo or GetItemInfo
                    local name = query and self:Readable(query(definition.item)) or self:SpellInfo(definition.ranks[1])
                    warn("mana", "Missing " .. (name or "mana gem") .. ". Click Prepare or the mana menu.")
                end
            end
        end
        if options.armor or options.intellect then
            local armorRanks, intellectRanks = {}, {}
            local armorKnown, intellectKnown, armorName
            for _, definition in ipairs(self.spells) do
                if definition.category == "armor" or definition.ranks[1] == 1459 or definition.ranks[1] == 23028 then
                    for _, id in ipairs(definition.ranks) do
                        if definition.category == "armor" then
                            armorRanks[#armorRanks + 1] = id
                            if self:KnownSpell(id) then armorKnown = true; armorName = self:SpellInfo(id) end
                        else
                            intellectRanks[#intellectRanks + 1] = id
                            intellectKnown = intellectKnown or self:KnownSpell(id)
                        end
                    end
                end
            end
            local buffs = not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) and self:PlayerBuffs() or nil
            if options.armor and armorKnown and self:HasPlayerBuff(armorRanks, buffs) == false then
                local missing = (armorName or "Mage armor") .. " missing"
                buffMessages[#buffMessages + 1] = missing
                warn("armor", missing .. ". Open Armor or use the Armor keybinding.")
            end
            if options.intellect and intellectKnown and self:HasPlayerBuff(intellectRanks, buffs) == false then
                local missing = (self:SpellInfo(1459) or "Arcane Intellect") .. " missing"
                buffMessages[#buffMessages + 1] = missing
                warn("buffs", missing .. ". Open Buffs or use the Intellect keybinding.")
            end
        end
        if options.reagents then
            local warned = {}
            for _, definition in ipairs(self.spells) do
                if definition.reagent and not warned[definition.reagent] and self:ItemCount(definition.reagent) < options.lowReagents then
                    for _, id in ipairs(definition.ranks) do
                        if self:KnownSpell(id) then
                            local count = self:ItemCount(definition.reagent)
                            local query = C_Item and C_Item.GetItemInfo or GetItemInfo
                            local name = query and self:Readable(query(definition.reagent)) or "reagent"
                            warn(definition.category, string.format("Need %d more %s (have %d) for %s.", options.lowReagents-count, name or "reagents", count, self:SpellInfo(id) or "learned spell"))
                            warned[definition.reagent] = true; break
                        end
                    end
                end
            end
        end
    end
    self.reminderMessages = messages
    self.buffReminderText:SetText(table.concat(buffMessages, "\n"))
    self.buffReminderFrame:SetSize(280, 38 + #buffMessages * 24)
    self.buffReminderFrame:SetShown(#buffMessages > 0 and self.db.visible)
    self.reminderGlow:SetShown(#messages > 0)
    for category, glow in pairs(self.reminderGlows) do glow:SetShown(categories[category] == true) end
    self:RefreshPreparationUI()
end

-- Direct queries isolate our long-duration buffs from unrelated secret auras.
-- An unavailable result remains unknown, rather than pretending a buff is missing.
function addon:HasPlayerBuff(ids, fallback)
    local query = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
    local unknown = false
    for _, id in ipairs(ids) do
        if query then
            local ok, aura = pcall(query, id)
            if not ok or (issecretvalue and issecretvalue(aura)) then unknown = true
            elseif aura ~= nil then return true end
        elseif fallback then
            if fallback[id] then return true end
        else unknown = true end
    end
    if unknown then return nil end
    return false
end

function addon:RefreshPreparationUI()
    if not self.settings then return end
    if self.settings.preparationSummary then
        local name, profile = self:ActiveProfile()
        for kind, input in pairs(self.settings.preparationInputs or {}) do
            if not input.HasFocus or not input:HasFocus() then input:SetText(tostring(profile[kind])) end
        end
        local stock = self:SupplyStatus()
        local estimate, members = self:EstimateSupplies()
        self.settings.preparationSummary:SetText(string.format(
            "Active profile: %s\nFood: %d / %d • Water: %d / %d\nMana gems: %d carried • %d learned gems missing\nGroup still needs: %d food, %d water (%d recipients; includes your reserves)",
            name, stock.food, profile.food, stock.water, profile.water, stock.gems, stock.missingGems,
            estimate.food, estimate.water, #members))
    end
    if self.settings.distributionText then
        self:PruneDistribution()
        local rows, included = {}, {}
        local function row(member)
            local entry = self.db.preparation.trackTrades and self.distribution[member.key]
            local preset = self.db.vending.presets[member.class] or self.db.vending.presets.UNKNOWN
            local food, water = entry and entry.food or 0, entry and entry.water or 0
            local state = food >= preset.food and water >= preset.water and "Supplied" or (entry and "Partial" or "Not supplied")
            rows[#rows + 1] = string.format("%s • %s • %s\nFood %d/%d • Water %d/%d", member.name, member.class or "Unknown", state, food, preset.food, water, preset.water)
            included[member.key] = true
        end
        for _, member in ipairs(self:GroupMembers()) do row(member) end
        for key, entry in pairs(self.distribution) do
            if self.db.preparation.trackTrades and not included[key] then
                row({name=entry.name, class=entry.class or "UNKNOWN", key=key})
            end
        end
        self.settings.distributionText:SetText(#rows > 0 and table.concat(rows, "\n\n") or "No group members or completed supply trades yet.")
        self.settings.distributionContent:SetSize(500, math.max(300, #rows * 52))
    end
end

local bindings = {
    Orb="Orb action", Evocation="Evocation", EatDrink="Eat and drink",
    Blink="Blink", Counterspell="Counterspell", RemoveCurse="Remove Lesser Curse", Polymorph="Polymorph",
    Prepare="Prepare supplies", Intellect="Self: Arcane Intellect", Armor="Self: best learned armor",
}
BINDING_HEADER_ARCANUM = "Arcanum Forever"
for key, label in pairs(bindings) do _G["BINDING_NAME_CLICK Arcanum" .. key .. "Key:LeftButton"] = label end

function addon:CreatePreparationButtons()
    self.keyButtons = {}
    for key in pairs(bindings) do
        local button = CreateFrame("Button", "Arcanum" .. key .. "Key", UIParent, "SecureActionButtonTemplate")
        button:SetSize(1, 1); button:SetPoint("BOTTOMLEFT"); button:SetAlpha(0); button:EnableMouse(false)
        button:RegisterForClicks("AnyDown", "AnyUp"); button:SetAttribute("useOnKeyDown", false)
        self.keyButtons[key] = button
    end
    local prepare = CreateFrame("Button", "ArcanumPrepareButton", self.frame, "SecureActionButtonTemplate,UIPanelButtonTemplate")
    prepare:SetSize(148, 22); prepare:RegisterForClicks("AnyDown", "AnyUp")
    prepare:SetAttribute("useOnKeyDown", false)
    prepare:SetScript("OnEnter", function()
        if not self.db.showTooltips then return end
        GameTooltip:SetOwner(prepare, "ANCHOR_RIGHT"); GameTooltip:SetText("Prepare supplies")
        GameTooltip:AddLine(self.prepareMessage or "", 1, 1, 1, true)
        GameTooltip:AddLine("Each click casts once outside combat. Missing gems come first, then water and food.", 0.5, 0.8, 1, true)
        GameTooltip:Show()
    end)
    prepare:SetScript("OnLeave", function() GameTooltip:Hide() end)
    prepare:HookScript("OnClick", function(_, _, down)
        if not down then self:DebugLog("prepare click", self.prepareMessage) end
    end)
    self.prepareButton = prepare
    local elapsed = 0
    self.preparationTicker = CreateFrame("Frame")
    self.preparationTicker:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed >= 2 then elapsed = 0; self:UpdateReminders() end
    end)
end

function addon:RefreshPreparationActions(actions)
    if not self.keyButtons then return end
    local function bind(button, action)
        button:SetAttribute("type1", action and action.kind or "")
        button:SetAttribute("spell1", action and action.kind == "spell" and action.id or nil)
        button:SetAttribute("item1", action and action.kind == "item" and ("item:" .. action.id) or nil)
        button:SetAttribute("macrotext1", action and action.kind == "macro" and action.macro or nil)
        button:SetAttribute("unit1", action and action.self and "player" or nil)
    end
    bind(self.keyButtons.Orb, self.sphere.action)
    bind(self.keyButtons.Evocation, self.sphere.shiftAction)
    local candidates = {Blink=1953, Counterspell=2139, RemoveCurse=475, Polymorph=118}
    for key, base in pairs(candidates) do
        local selected
        for _, action in ipairs(actions.utility) do if action.kind == "spell" and action.baseSpell == base then selected = action end end
        bind(self.keyButtons[key], selected)
    end
    local intellect, armor
    for _, action in ipairs(actions.buffs) do if action.kind == "spell" and action.id ~= 23028 and action.name == self:SpellInfo(1459) then intellect = action end end
    for _, action in ipairs(actions.armor) do if action.kind == "spell" then armor = action end end
    bind(self.keyButtons.Intellect, intellect)
    bind(self.keyButtons.Armor, armor)
    self.keyButtons.Intellect:SetAttribute("unit1", "player")
    self.keyButtons.Armor:SetAttribute("unit1", "player")
    bind(self.keyButtons.EatDrink, self:EatDrinkAction(actions))
    self:RefreshPrepareButton(actions)
end

function addon:RefreshPrepareButton(actions)
    local stock, step, kind = self:SupplyStatus()
    local _, profile = self:ActiveProfile()
    for index = #actions.mana, 1, -1 do
        local action = actions.mana[index]
        if action.kind == "spell" and action.conjure and action.countItem and self:ItemCount(action.countItem) == 0 then
            step, kind = action, "Gem"; break
        end
    end
    if not step then
        for _, wanted in ipairs({"water", "food"}) do
            if stock[wanted] < profile[wanted] then
                for _, action in ipairs(actions.refreshments) do
                    local supply = action.kind == "spell" and action.conjure and self.supplyItems[action.countItem]
                    if supply and supply.kind == wanted then step, kind = action, wanted == "water" and "Water" or "Food"; break end
                end
                if step then break end
            end
        end
    end
    local ready = stock.missingGems == 0 and stock.food >= profile.food and stock.water >= profile.water
    self.prepareAction = step
    self.prepareMessage = step and ("Next: " .. step.name .. string.format(". Food %d/%d; water %d/%d; %d gems missing.", stock.food,profile.food,stock.water,profile.water,stock.missingGems))
        or ready and "All preparation targets met."
        or "Learn the missing conjure spells to reach your preparation targets."
    self.prepareButton:SetText(step and ("Prepare: " .. kind) or ready and "Prepared!" or "Prepare: unavailable")
    for _, button in ipairs({self.prepareButton, self.keyButtons.Prepare}) do
        button:SetAttribute("type1", step and "macro" or "")
        button:SetAttribute("macrotext1", step and ("/cast [nocombat] " .. step.name) or nil)
    end
    local offset = 30
    self.prepareButton:ClearAllPoints()
    self.prepareButton:SetPoint("TOP", self.frame, "CENTER", 0, -(self.db.radius + offset))
    self.prepareButton:SetShown(self.db.preparation.showPrepare)
    self.buffReminderFrame:ClearAllPoints()
    self.buffReminderFrame:SetPoint("TOP", self.frame, "CENTER", 0,
        -(self.db.radius + offset + (self.db.preparation.showPrepare and 32 or 0)))
end

function addon:EatDrinkAction(actions)
    local food, water
    for _, action in ipairs(actions.refreshments) do
        local supply = action.kind == "item" and self.supplyItems[action.id]
        if supply and supply.kind == "food" then food = action.id end
        if supply and supply.kind == "water" then water = action.id end
    end
    local lines = {}
    if food then lines[#lines + 1] = "/use [nocombat] item:" .. food end
    if water then lines[#lines + 1] = "/use [nocombat] item:" .. water end
    if #lines > 0 then return {kind="macro", name="Eat + Drink (outside combat)", macro=table.concat(lines, "\n"), self=true} end
end
