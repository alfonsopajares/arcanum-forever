local _, addon = ...

addon.distribution = {}
local function now() return GetTime and GetTime() or 0 end

function addon:GroupMembers(includeOffline)
    local members, player = {}, UnitGUID and self:Readable(UnitGUID("player"))
    local raid = IsInRaid and self:Readable(IsInRaid()) == true
    local count = raid and (GetNumGroupMembers and self:Readable(GetNumGroupMembers()) or 0)
        or (GetNumSubgroupMembers and self:Readable(GetNumSubgroupMembers()) or 0)
    local seen = {}
    for index = 1, math.min(40, count) do
        local unit = (raid and "raid" or "party") .. index
        local name = self:Readable(UnitName(unit))
        local guid = UnitGUID and self:Readable(UnitGUID(unit))
        local key = guid or name
        local connected = not UnitIsConnected or self:Readable(UnitIsConnected(unit)) == true
        local isPlayer = UnitIsUnit and self:Readable(UnitIsUnit(unit, "player")) == true
        if name and (connected or includeOffline) and not isPlayer and (not player or guid ~= player) and not seen[key] then
            local _, class = UnitClass(unit)
            local level = UnitLevel and self:Readable(UnitLevel(unit))
            seen[key] = true
            local _, realm = UnitName(unit)
            realm = self:Readable(realm)
            if not realm or realm=="" then
                realm=GetNormalizedRealmName and self:Readable(GetNormalizedRealmName()) or GetRealmName and self:Readable(GetRealmName())
            end
            if type(realm)=="string" then realm=realm:gsub("%s","") end
            local subgroup = raid and GetRaidRosterInfo and self:Readable(select(3,GetRaidRosterInfo(index)))
            members[#members + 1] = {name=name, key=key, unit=unit, subgroup=subgroup or 1, class=self:Readable(class) or "UNKNOWN", online=connected,
                fullName=type(realm)=="string" and realm~="" and (name.."-"..realm) or name,
                level=type(level)=="number" and level>0 and level or 1}
        end
    end
    return members
end

function addon:ActiveProfile()
    return "solo", self.db.preparation.profiles.solo
end

-- Cache bag space between inventory events. A partial stack only helps its own rank.
function addon:GroupConjureRoom(item)
    if not self.supplyBagRoom then
        local api=C_Container
        if not (api and api.GetContainerNumFreeSlots and api.GetContainerItemInfo and api.GetContainerNumSlots) then return true end
        local room={}
        for bag=0,4 do
            local free,family=api.GetContainerNumFreeSlots(bag)
            if (self:Readable(free) or 0)>0 and self:Readable(family)==0 then room.any=true; break end
        end
        if not room.any then
            for bag=0,4 do
                for slot=1,self:Readable(api.GetContainerNumSlots(bag)) or 0 do
                    local info=self:Readable(api.GetContainerItemInfo(bag,slot))
                    local id=info and self:Readable(info.itemID)
                    if self.supplyItems[id] and self:Readable(info.isLocked)==false then
                        local count=self:Readable(info.stackCount)
                        local query=C_Item and C_Item.GetItemInfo or GetItemInfo
                        local maximum=query and self:Readable(select(8,query(id))) or 20
                        if count and count<maximum then room[id]=true end
                    end
                end
            end
        end
        self.supplyBagRoom=room
    end
    return self.supplyBagRoom.any or self.supplyBagRoom[item]
end

local function allocate(stock,definition,level,need)
    for rank=#definition.items,1,-1 do
        if definition.levels[rank]<=level then
            local used=math.min(need,stock[rank])
            need,stock[rank]=need-used,stock[rank]-used
        end
    end
    return need
end

-- Allocate low-level recipients first so unusable high ranks cannot mark them ready.
function addon:GroupPreparationProfile()
    local estimate, members = self:EstimateSupplies()
    local personal = self.db.preparation.profiles.solo
    estimate.food = estimate.food + math.max(0, personal.food - self.db.vending.reserveFood)
    estimate.water = estimate.water + math.max(0, personal.water - self.db.vending.reserveWater)
    estimate.group = true
    estimate.players = #members + 1
    estimate.breakdown = {}
    local demands = {}
    for _, member in ipairs(members) do
        local request=self:GetGroupSupplyRequest(member)
        local demand={level=member.level or 1,food=request.food,water=request.water}
        demands[#demands+1] = demand
        estimate.breakdown[#estimate.breakdown+1] = string.format("%s: %d food, %d water", member.name, demand.food, demand.water)
    end
    local level = UnitLevel and self:Readable(UnitLevel("player"))
    local reserve = {level=type(level)=="number" and level>0 and level or 1,
        food=math.max(personal.food,self.db.vending.reserveFood), water=math.max(personal.water,self.db.vending.reserveWater)}
    demands[#demands+1]=reserve
    estimate.breakdown[#estimate.breakdown+1] = string.format("You (including reserves): %d food, %d water",
        math.max(personal.food,self.db.vending.reserveFood),math.max(personal.water,self.db.vending.reserveWater))
    table.sort(demands,function(a,b) return a.level<b.level end)
    estimate.missing, estimate.nextSupply = {food=0,water=0}, {}
    local stock,definitions={},{}
    for _, definition in ipairs(self.spells) do
        if definition.kind then
            local kind, available = definition.kind, {}
            for rank,item in ipairs(definition.items) do available[rank]=self:ItemCount(item) end
            stock[kind],definitions[kind]=self:Clone(available),definition
            allocate(stock[kind],definition,reserve.level,reserve[kind])
            for _, demand in ipairs(demands) do
                local need=allocate(available,definition,demand.level,demand[kind])
                estimate.missing[kind]=estimate.missing[kind]+need
                if need>0 and not estimate.nextSupply[kind] then
                    for rank=#definition.ranks,1,-1 do
                        local id=definition.ranks[rank]
                        if definition.levels[rank]<=demand.level and self:KnownSpell(id) then
                            local name=self:SpellInfo(id)
                            if name and not self:GroupConjureRoom(definition.items[rank]) then
                                estimate.bagLimited=true
                            elseif name then estimate.nextSupply[kind]={kind="spell",conjure=true,id=id,name=name,
                                countItem=definition.items[rank],exactRank=true}; break end
                        end
                    end
                end
            end
        end
    end
    estimate.ready,estimate.near,estimate.readyCount={},{},0
    local waiting={}
    for index,member in ipairs(members) do
        local request=self:GetGroupSupplyRequest(member)
        if request.food+request.water>0 then
            local ok,near=false,false
            if CheckInteractDistance and member.unit then ok,near=pcall(CheckInteractDistance,member.unit,2) end
            estimate.near[member.key]=ok and self:Readable(near)==true
            waiting[#waiting+1]={member=member,request=request,index=index}
        end
    end
    table.sort(waiting,function(a,b)
        if estimate.near[a.member.key]~=estimate.near[b.member.key] then return estimate.near[a.member.key] end
        return a.index<b.index
    end)
    for _,row in ipairs(waiting) do
        local remaining=self:Clone(stock)
        local food=allocate(remaining.food,definitions.food,row.member.level or 1,row.request.food)
        local water=allocate(remaining.water,definitions.water,row.member.level or 1,row.request.water)
        if food+water==0 then
            stock=remaining
            estimate.ready[row.member.key]=true
            estimate.readyCount=estimate.readyCount+1
        end
    end
    return estimate
end

function addon:EditablePreparationProfile()
    return self.db.preparation.profiles.solo
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
    local members = {}
    for _, member in ipairs(self:GroupMembers()) do
        if not self:SupplyAssignment(member) then
            members[#members+1] = member
            local request=self:GetGroupSupplyRequest(member)
            estimate.food=estimate.food+request.food
            estimate.water=estimate.water+request.water
        end
    end
    return estimate, members
end

function addon:SetTargetsFromGroup()
    if self.OpenGroupSupplies then self:OpenGroupSupplies() end
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
    if event == "TRADE_SHOW" or event == "TRADE_REQUEST_CANCEL" then
        self.acceptedTrade, self.closedSupplyTrade = nil, nil; return
    end
    if event == "TRADE_PLAYER_ITEM_CHANGED" or event == "TRADE_TARGET_ITEM_CHANGED" then
        if not self.trade.open or self.closedSupplyTrade then return end
        self.acceptedTrade = nil; return
    end
    if event == "TRADE_ACCEPT_UPDATE" then
        if not self.trade.open or self.closedSupplyTrade then return end
        self.acceptedTrade = nil
        if self:Readable(first) ~= 1 or not self.trade.open then return end
        local totals = self:TradeOffer()
        if totals then
            local key = self.trade.key or self.trade.name
            -- NPC GUIDs can be unavailable: resolve a unique roster name while
            -- the trade is still open, so the delivery uses the roster's key.
            if key == self.trade.name then
                local match, ambiguous
                for _, member in ipairs(self:GroupMembers()) do
                    if member.name == self.trade.name then
                        if match then ambiguous = true else match = member.key end
                    end
                end
                if match and not ambiguous then key = match end
            end
            self.acceptedTrade = {key=key, name=self.trade.name,
                class=self.trade.class, food=totals.food, water=totals.water, time=now()}
        end
    elseif event == "TRADE_CLOSED" then
        if self.acceptedTrade and not self.closedSupplyTrade then
            self.acceptedTrade.closed = now()
            self.closedSupplyTrade, self.acceptedTrade = self.acceptedTrade, nil
        end
    elseif event == "UI_INFO_MESSAGE" then
        message = self:Readable(message)
        local snapshot = self.closedSupplyTrade or self.acceptedTrade
        if not snapshot or not ERR_TRADE_COMPLETE or message ~= ERR_TRADE_COMPLETE then return end
        self.acceptedTrade, self.closedSupplyTrade = nil, nil
        if snapshot.closed and now() - snapshot.closed > 5 then return end
        if snapshot.food + snapshot.water > 0 then
            self:SendMageMessage("trade", "success", {target=snapshot.name, food=snapshot.food, water=snapshot.water})
            if self.GroupSupplyDelivered then self:GroupSupplyDelivered(snapshot) end
        end
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
        self:RefreshActions()
        self:RefreshPreparationUI()
    end
end

function addon:ResetDistribution()
    self.distribution, self.acceptedTrade, self.closedSupplyTrade = {}, nil, nil
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

function addon:LearnedIceBarrier()
    for index = #self.iceBarrierRanks, 1, -1 do
        local spell = self.iceBarrierRanks[index]
        if self:KnownSpell(spell) then return spell end
    end
end

local frigidPower = {1326891}

local function iceBarrierReminder(self, spell, options, buffs)
    local missingPower = options.iceBarrier and self:HasPlayerBuff(frigidPower, buffs) == false
    local missingShield = options.iceBarrierShield and self:HasPlayerBuff(self.iceBarrierRanks, buffs) == false
    if not (missingPower or missingShield) then return end

    local query = C_Spell and C_Spell.GetSpellCooldown
    if not query then return end
    local ok, cooldown = pcall(query, spell)
    if not ok then return end
    cooldown = self:Readable(cooldown)
    if not cooldown or self:Readable(cooldown.isEnabled) ~= true or self:Readable(cooldown.duration) ~= 0 then return end

    local name = self:SpellInfo(spell) or "Ice Barrier"
    return missingPower and ("Refresh " .. name) or (name .. " shield missing")
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
        local food = profile.missing and profile.food-profile.missing.food or stock.food
        local water = profile.missing and profile.water-profile.missing.water or stock.water
        if options.food and food < math.min(options.lowFood, profile.food) then
            warn("refreshments", string.format("Need %d more food (%d/%d usable). Click Prepare or the food/water menu.", profile.food-food, food, profile.food))
        end
        if options.water and water < math.min(options.lowWater, profile.water) then
            warn("refreshments", string.format("Need %d more water (%d/%d usable). Click Prepare or the food/water menu.", profile.water-water, water, profile.water))
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
        local barrier = (options.iceBarrier or options.iceBarrierShield) and self:LearnedIceBarrier()
        local buffs
        if (options.armor or options.intellect or barrier) and not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then
            buffs = self:PlayerBuffs()
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
            if options.armor and armorKnown and self:HasPlayerBuff(armorRanks, buffs) == false then
                local missing = (armorName or "Mage armor") .. " missing"
                buffMessages[#buffMessages + 1] = missing
                warn("armor", missing .. ". Open Armor or use the Armor keybinding.")
            end
            if options.intellect and intellectKnown and self:HasPlayerBuff(intellectRanks, buffs) == false
                and self:HasIncenseIntellect() == false then
                local missing = (self:SpellInfo(1459) or "Arcane Intellect") .. " missing"
                buffMessages[#buffMessages + 1] = missing
                warn("buffs", missing .. ". Open Buffs or use the Intellect keybinding.")
            end
        end
        if barrier then
            local missing = iceBarrierReminder(self, barrier, options, buffs)
            if missing then
                buffMessages[#buffMessages + 1] = missing
                warn("defenses", missing .. ". Open Defenses to cast Ice Barrier.")
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

-- Forever bundles Candle into Camp Benefits (1229741). Its live tooltip lists
-- the individual benefits; the presence of the camp aura alone is insufficient.
function addon:CampHasIncense(index, name)
    local query = C_TooltipInfo and C_TooltipInfo.GetUnitBuff
    if not query then return nil end
    local ok, result = pcall(function()
        local tip = self:Readable(query("player", index))
        local lines = tip and self:Readable(tip.lines)
        if type(lines) ~= "table" then return nil end
        local unknown = false
        for _, line in ipairs(lines) do
            line = self:Readable(line)
            if not line then unknown = true
            else
                for _, field in ipairs({"leftText", "rightText"}) do
                    local raw = line[field]
                    local text = self:Readable(raw)
                    if issecretvalue and issecretvalue(raw) then unknown = true
                    elseif type(text) == "string" and text:find(name .. ":", 1, true) then return true end
                end
            end
        end
        if unknown then return nil end
        return false
    end)
    if ok then return result end
    return nil
end

function addon:HasIncenseIntellect()
    local direct = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
    if direct then
        local ok, aura = pcall(direct, 1229741)
        if not ok or (issecretvalue and issecretvalue(aura)) then return nil end
        if aura == nil then return false end
    end
    local query = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    if not query then return nil end
    local unknown = false
    for index = 1, 80 do
        local ok, aura = pcall(query, "player", index, "HELPFUL")
        if not ok then return nil end
        if issecretvalue and issecretvalue(aura) then unknown = true
        elseif aura == nil then
            if unknown then return nil end
            return false
        else
            local id = self:Readable(aura.spellId)
            if id == 1229741 then
                return self:CampHasIncense(index, self:SpellInfo(1307251) or "Incense Candle")
            end
            if not id then unknown = true end
        end
    end
    return nil
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
    if self.settings.iceBarrierOptions and self.settings.selected == "Reminders" then
        self.settings.iceBarrierOptions:SetShown(self:LearnedIceBarrier() ~= nil)
    end
    if self.settings.preparationSummary then
        local _, profile = self:ActiveProfile()
        local inputs = self:EditablePreparationProfile()
        for kind, input in pairs(self.settings.preparationInputs or {}) do
            if not input.HasFocus or not input:HasFocus() then input:SetText(tostring(inputs[kind])) end
        end
        local stock = self:SupplyStatus()
        self.settings.preparationSummary:SetText(string.format(
            "Your supplies: %d / %d food • %d / %d water\nMana gems: %d carried • %d learned gems missing",
            stock.food, profile.food, stock.water, profile.water, stock.gems, stock.missingGems))
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
    Toggle="Toggle circle",
    Orb="Orb action", Evocation="Evocation", EatDrink="Eat and drink",
    Blink="Blink", Counterspell="Counterspell", RemoveCurse="Remove Lesser Curse", Polymorph="Polymorph",
    Prepare="Prepare supplies", Intellect="Self: Arcane Intellect", Armor="Self: best learned armor",
    DriveBy="Drive-by Intellect (mouseover, outside combat)",
}
for key, label in pairs(bindings) do _G["BINDING_NAME_CLICK Arcanum" .. key .. "Key:LeftButton"] = label end

function addon:CreatePreparationButtons()
    self.keyButtons = {}
    for key in pairs(bindings) do
        local button = CreateFrame("Button", "Arcanum" .. key .. "Key", UIParent, "SecureActionButtonTemplate")
        button:SetSize(1, 1); button:SetPoint("BOTTOMLEFT"); button:SetAlpha(0); button:EnableMouse(false)
        button:RegisterForClicks("AnyDown", "AnyUp"); button:SetAttribute("useOnKeyDown", false)
        self.keyButtons[key] = button
    end
    self.keyButtons.Toggle:HookScript("OnClick",function(_,_,down)
        if not down then self:HandleCommand("toggle") end
    end)
    self:SetupDriveBy()
    local prepare = CreateFrame("Button", "ArcanumPrepareButton", self.frame, "SecureActionButtonTemplate,UIPanelButtonTemplate")
    prepare:SetSize(148, 22); prepare:RegisterForClicks("AnyDown", "AnyUp")
    prepare:SetAttribute("useOnKeyDown", false)
    prepare:SetScript("OnEnter", function()
        if not self.db.showTooltips then return end
        local tip = self:BeginTooltip(prepare, "Prepare supplies")
        self:TooltipControl("Left-click", "Conjure next supply")
        tip:AddLine(" ")
        tip:AddLine(self.prepareMessage or "", 1, 1, 1, true)
        for _, line in ipairs(self.prepareBreakdown or {}) do tip:AddLine(line, 0.7, 0.8, 1, true) end
        tip:AddLine("One cast per click, outside combat.", 0.6, 0.8, 1, true)
        self:TooltipSupplies()
        self:FinishTooltip()
    end)
    prepare:SetScript("OnLeave", function() self:HideTooltip() end)
    prepare:HookScript("OnClick", function(_, _, down)
        if not down then self:DebugLog("prepare click", self.prepareMessage) end
    end)
    self.prepareButton = prepare
    local supplies = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
    supplies:SetSize(116, 22)
    supplies:SetText("Group Supplies")
    supplies:SetScript("OnClick", function() self:OpenGroupSupplies() end)
    supplies:Hide()
    self.groupSuppliesButton = supplies
    for _, button in ipairs({prepare,self.keyButtons.Prepare}) do
        SecureHandlerWrapScript(button,"OnClick",button,[[
            if SecureCmdOptionParse("[combat] combat") then self:SetAttribute("type1","") end
        ]])
    end
    local elapsed = 0
    self.preparationTicker = CreateFrame("Frame")
    self.preparationTicker:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed >= 2 then
            elapsed = 0
            if self.preparationActions and not InCombatLockdown() then self:RefreshPrepareButton(self.preparationActions) end
            self:UpdateGroupSupplies()
            self:UpdateReminders()
        end
    end)
end

function addon:RefreshPreparationActions(actions)
    if not self.keyButtons then return end
    self.preparationActions = actions
    self:ConfigureDriveBy()
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
            if profile.missing and profile.missing[wanted]>0 then
                step,kind=profile.nextSupply[wanted],wanted=="water" and "Water" or "Food"
                if step then break end
            elseif not profile.missing and stock[wanted] < profile[wanted] then
                for _, action in ipairs(actions.refreshments) do
                    local supply = action.kind == "spell" and action.conjure and self.supplyItems[action.countItem]
                    if supply and supply.kind == wanted then step, kind = action, wanted == "water" and "Water" or "Food"; break end
                end
                if step then break end
            end
        end
    end
    local ready = stock.missingGems == 0 and (profile.missing and profile.missing.food==0 and profile.missing.water==0
        or not profile.missing and stock.food >= profile.food and stock.water >= profile.water)
    self.prepareAction = step
    self.prepareMessage = step and ("Next: " .. step.name .. string.format(". Food %d/%d; water %d/%d; %d gems missing.", stock.food,profile.food,stock.water,profile.water,stock.missingGems))
        or ready and "All preparation targets met."
        or "Learn the missing conjure spells to reach your preparation targets."
    self.prepareBreakdown=profile.breakdown
    if profile.group then
        self.prepareMessage=string.format("Preparing for %d players: %d food, %d water.\nStill needed: %d food, %d water.\n",profile.players,profile.food,profile.water,profile.missing.food,profile.missing.water)..self.prepareMessage
    end
    self.prepareButton:SetText(step and ("Prepare: " .. kind) or ready and "Prepared!" or "Prepare: unavailable")
    for _, button in ipairs({self.prepareButton, self.keyButtons.Prepare}) do
        button:SetAttribute("type1", step and (step.exactRank and "spell" or "macro") or "")
        button:SetAttribute("spell1", step and step.exactRank and step.id or nil)
        button:SetAttribute("macrotext1", step and not step.exactRank and ("/cast [nocombat] " .. step.name) or nil)
    end
end

function addon:LayoutPreparationButtons(grouped)
    local showPrepare = self.db.preparation.showPrepare
    local showBoth = showPrepare and grouped
    local y = -(self.db.radius + 30)
    self.prepareButton:ClearAllPoints()
    self.prepareButton:SetPoint("TOP", self.frame, "CENTER", showBoth and -61 or 0, y)
    self.prepareButton:SetShown(showPrepare)
    self.groupSuppliesButton:ClearAllPoints()
    if showBoth then
        self.groupSuppliesButton:SetPoint("LEFT", self.prepareButton, "RIGHT", 6, 0)
    else
        self.groupSuppliesButton:SetPoint("TOP", self.frame, "CENTER", 0, y)
    end
    self.groupSuppliesButton:SetShown(grouped)
    self.buffReminderFrame:ClearAllPoints()
    self.buffReminderFrame:SetPoint("TOP", self.frame, "CENTER", 0,
        y - ((showPrepare or grouped) and 32 or 0))
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
