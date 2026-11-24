local _, addon = ...

addon.trade = {open = false, owned = {}}
addon.supplyItems = {}
for _, spell in ipairs(addon.spells) do
    if spell.kind then
        for rank, item in ipairs(spell.items) do
            addon.supplyItems[item] = {kind=spell.kind, rank=rank, level=spell.levels[rank], spell=spell.ranks[rank]}
        end
    end
end

function addon:TradeOffer()
    local totals, free, slots = {food=0, water=0}, {}, {}
    for slot = 1, 6 do
        local name, _, count, _, _, _, _, id = GetTradePlayerItemInfo(slot)
        if issecretvalue and issecretvalue(name) then return nil, "Trade items are unavailable." end
        if name == nil then
            free[#free + 1] = slot
        else
            id, count = self:Readable(id), self:Readable(count)
            if type(id) ~= "number" and GetTradePlayerItemLink then
                local link = self:Readable(GetTradePlayerItemLink(slot))
                id = type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
            end
            if type(id) ~= "number" or type(count) ~= "number" then return nil, "Trade item details are unavailable." end
            slots[slot] = {id=id, count=count}
            local supply = self.supplyItems[id]
            if supply then totals[supply.kind] = totals[supply.kind] + count end
        end
    end
    return totals, free, slots
end

function addon:SupplyStacks(kind)
    local stacks, total = {}, 0
    local level = self.trade.level
    for bag = 0, 4 do
        local count = self:Readable(C_Container.GetContainerNumSlots(bag)) or 0
        for slot = 1, count do
            local info = self:Readable(C_Container.GetContainerItemInfo(bag, slot))
            if info then
                local id, n = self:Readable(info.itemID), self:Readable(info.stackCount)
                local supply = type(id) == "number" and self.supplyItems[id]
                if supply and supply.kind == kind and type(n) == "number" and self:KnownSpell(supply.spell) and
                    (not self.db.vending.bestRank or supply.level <= (level or 1)) then
                    total = total + n
                    if self:Readable(info.isLocked) == false then
                        stacks[#stacks + 1] = {bag=bag, slot=slot, id=id, count=n, rank=supply.rank}
                    end
                end
            end
        end
    end
    table.sort(stacks, function(a, b)
        if a.rank ~= b.rank then return a.rank > b.rank end
        return a.count > b.count
    end)
    return stacks, total
end

function addon:EmptySupplySlot()
    for bag = 0, 4 do
        local free, family = C_Container.GetContainerNumFreeSlots(bag)
        free, family = self:Readable(free), self:Readable(family)
        if type(free) == "number" and free > 0 and family == 0 then
            local count = self:Readable(C_Container.GetContainerNumSlots(bag)) or 0
            for slot = 1, count do
                if C_Container.GetContainerItemInfo(bag, slot) == nil then return bag, slot end
            end
        end
    end
end

-- Build a stack in the bags before offering it, rather than consuming a trade
-- slot for every small conjured batch. Never combine different item ranks.
function addon:PrepareSupplyStack(job, stacks, stack, desired)
    local query = C_Item and C_Item.GetItemInfo or GetItemInfo
    local maximum = query and self:Readable(select(8, query(stack.id))) or nil
    maximum = type(maximum) == "number" and maximum > 0 and maximum or 20
    local target = math.min(desired, maximum)
    if stack.count >= target then return false end
    for _, donor in ipairs(stacks) do
        if donor.id == stack.id and (donor.bag ~= stack.bag or donor.slot ~= stack.slot) then
            local amount = math.min(target - stack.count, donor.count)
            if amount < donor.count then
                C_Container.SplitContainerItem(donor.bag, donor.slot, amount)
            else
                C_Container.PickupContainerItem(donor.bag, donor.slot)
            end
            local cursor, id = GetCursorInfo()
            if cursor ~= "item" or self:Readable(id) ~= stack.id then
                self.trade.job = nil
                self:TradeMessage("The client did not pick up the supply stack.")
                return true
            end
            C_Container.PickupContainerItem(stack.bag, stack.slot)
            if GetCursorInfo() then
                ClearCursor()
                self.trade.job = nil
                self:TradeMessage("The client refused to combine supplies. Fill stopped.")
                return true
            end
            job.pending = {merge=true, bag=stack.bag, slot=stack.slot, id=stack.id, count=stack.count + amount}
            self:DebugLog("Bag merge", string.format("Item %d: combining %d into bag %d slot %d", stack.id, amount, stack.bag, stack.slot))
            job.moves = job.moves + 1
            self:TradeLater(job)
            return true
        end
    end
    return false
end

function addon:TradeMessage(message)
    self.trade.message = message
    self:DebugLog("Trade status", message)
    self:UpdateTradeUI()
end

-- Use the same eligible full stack for the button count and the actual offer.
function addon:TradeReserve(kind,eligibleOnly)
    local reserve=kind=="water" and self.db.vending.reserveWater or self.db.vending.reserveFood
    if not self.trade.groupRequest then return reserve end
    reserve=math.max(reserve,self.db.preparation.profiles.solo[kind])
    if eligibleOnly and self.db.vending.bestRank then
        -- Higher ranks kept for the mage can cover the reserve for a low-level trade.
        local level=self.trade.level or 1
        local playerLevel=UnitLevel and self:Readable(UnitLevel("player")) or 1
        for id,item in pairs(self.supplyItems) do
            if item.kind==kind and item.level>level and item.level<=playerLevel and self:KnownSpell(item.spell) then
                reserve=math.max(0,reserve-self:ItemCount(id))
            end
        end
    end
    return reserve
end

function addon:FullTradeStack(kind, stacks, total)
    if not stacks then stacks, total = self:SupplyStacks(kind) end
    local reserve = self:TradeReserve(kind,true)
    local query = C_Item and C_Item.GetItemInfo or GetItemInfo
    for _, stack in ipairs(stacks) do
        local maximum = query and self:Readable(select(8, query(stack.id))) or nil
        maximum = type(maximum) == "number" and maximum > 0 and maximum or 20
        if stack.count == maximum and total - stack.count >= reserve then return stack end
    end
end

-- Fill presets with the fewest trade stacks, rather than offering a tiny batch
-- of a newer rank before a complete, usable lower-rank stack. Rank still wins
-- ties once the amount and readiness of the stack are equal.
function addon:PresetTradeStack(stacks, desired)
    local grouped = {}
    for _, stack in ipairs(stacks) do
        grouped[stack.id] = (grouped[stack.id] or 0) + stack.count
    end
    local query = C_Item and C_Item.GetItemInfo or GetItemInfo
    local chosen, bestAmount, bestReady = nil, 0, false
    for _, stack in ipairs(stacks) do
        local maximum = query and self:Readable(select(8, query(stack.id))) or nil
        maximum = type(maximum) == "number" and maximum > 0 and maximum or 20
        local amount = math.min(desired, maximum, grouped[stack.id])
        local ready = stack.count >= amount
        if amount > bestAmount or (amount == bestAmount and
            ((ready and not bestReady) or (ready == bestReady and
                (not chosen or stack.rank > chosen.rank or
                    (stack.rank == chosen.rank and stack.count > chosen.count))))) then
            chosen, bestAmount, bestReady = stack, amount, ready
        end
    end
    return chosen
end

function addon:TradeControlReason(kind)
    if InCombatLockdown() then return "Available outside combat." end
    if self.trade.job then return "Waiting for the current move." end
    if GetCursorInfo and GetCursorInfo() then return "Clear the item on your cursor." end
    local totals, free, slots = self:TradeOffer()
    if not totals then return free end
    if kind == "clear" then
        for slot, owned in pairs(self.trade.owned) do
            local offered = slots[slot]
            if offered and offered.id == owned.id and offered.count == owned.count then return nil end
        end
        return "No Arcanum-added supplies."
    end
    if kind == "fill" and totals.food >= self.trade.targets.food and totals.water >= self.trade.targets.water then
        return "Request filled."
    end
    if not free[1] then return "No free trade slots." end
    for _, supplyKind in ipairs(kind == "fill" and {"water", "food"} or {kind}) do
        local stacks, total = self:SupplyStacks(supplyKind)
        local reserve = self:TradeReserve(supplyKind,true)
        if kind == "fill" then
            if totals[supplyKind] < self.trade.targets[supplyKind] and total > reserve and #stacks > 0 then return nil end
        else
            if self:FullTradeStack(supplyKind, stacks, total) then return nil end
            return "Need a full stack above your reserve."
        end
    end
    return "Conjure more or lower your reserves."
end

function addon:TradeLater(job)
    C_Timer.After(0.2, function()
        if self.trade.job ~= job then return end
        local ok, err = pcall(function() self:TradeStep(job) end)
        if not ok then
            self.trade.job = nil
            self:TradeMessage("Fill stopped: " .. tostring(err))
        end
    end)
end

function addon:TradeStep(job)
    if self.trade.job ~= job then return end
    if not self.trade.open or InCombatLockdown() then
        self.trade.job = nil
        self:TradeMessage("Fill stopped. Open the trade outside combat to continue.")
        return
    end
    local totals, free, slots = self:TradeOffer()
    if not totals then self.trade.job = nil; self:TradeMessage(free); return end
    if job.pending then
        local pending = job.pending
        if pending.split or pending.merge then
            local info = self:Readable(C_Container.GetContainerItemInfo(pending.bag, pending.slot))
            if info and self:Readable(info.itemID) == pending.id and self:Readable(info.stackCount) == pending.count and
                self:Readable(info.isLocked) == false then
                if pending.split then job.prepared = pending end
                job.pending = nil
            end
        else
            local offered = slots[pending.slot]
            if offered and offered.id == pending.id and offered.count == pending.count then
                self.trade.owned[pending.slot] = {id=offered.id, count=offered.count}
                self:DebugLog("Supply offered", string.format("Item %d: %d in trade slot %d", offered.id, offered.count, pending.slot))
                job.pending = nil
            end
        end
        if job.pending then
            job.waits = job.waits + 1
            if job.waits >= 20 then self.trade.job = nil; self:TradeMessage("The client did not confirm the move. Fill stopped."); return end
            self:TradeLater(job)
            return
        end
        job.waits = 0
    end
    if GetCursorInfo() then self.trade.job = nil; self:TradeMessage("Clear the cursor, then click Add to trade again."); return end
    if job.stackKind then
        if job.moves > 0 then
            self.trade.job = nil
            self:TradeMessage("One full " .. job.stackKind .. " stack added. Review and press Trade.")
            return
        end
        local stacks, total = self:SupplyStacks(job.stackKind)
        local chosen = self:FullTradeStack(job.stackKind, stacks, total)
        if not chosen then
            self.trade.job = nil
            self:TradeMessage("No full " .. job.stackKind .. " stack available above your reserve. Conjure more or lower the reserve in Options.")
            return
        end
        if not free[1] then self.trade.job = nil; self:TradeMessage("No free trade slots."); return end
        C_Container.PickupContainerItem(chosen.bag, chosen.slot)
        local cursor, id = GetCursorInfo()
        if cursor ~= "item" or self:Readable(id) ~= chosen.id then
            self.trade.job = nil; self:TradeMessage("The client did not pick up the requested stack."); return
        end
        ClickTradeButton(free[1])
        if GetCursorInfo() then ClearCursor(); self.trade.job = nil; self:TradeMessage("The trade move was refused; supplies stayed in your bags."); return end
        job.pending = {slot=free[1], id=chosen.id, count=chosen.count}
        job.moves = 1
        self:TradeLater(job)
        return
    end
    for _, kind in ipairs({"water", "food"}) do
        local need = math.max(0, job.targets[kind] - totals[kind])
        if need > 0 then
            local stacks, total = self:SupplyStacks(kind)
            local reserve = self:TradeReserve(kind,true)
            local available = math.max(0, total - reserve)
            if available > 0 and #stacks > 0 then
                if not free[1] then self.trade.job = nil; self:TradeMessage("No free trade slots. Review the offer before adding more."); return end
                if job.moves >= 128 then self.trade.job = nil; self:TradeMessage("Fill stopped after 128 inventory moves. Review the offer."); return end
                local prepared = job.prepared
                local stack = prepared and self.supplyItems[prepared.id].kind == kind and prepared
                    or self:PresetTradeStack(stacks, math.min(need, available))
                if stack == prepared then job.prepared = nil end
                if self:PrepareSupplyStack(job, stacks, stack, math.min(need, available)) then return end
                local amount = math.min(need, available, stack.count)
                if amount < stack.count then
                    local bag, slot = self:EmptySupplySlot()
                    if not bag then self.trade.job = nil; self:TradeMessage("One free bag slot is needed to split an exact amount."); return end
                    C_Container.SplitContainerItem(stack.bag, stack.slot, amount)
                    local cursor, id = GetCursorInfo()
                    if cursor ~= "item" or self:Readable(id) ~= stack.id then
                        self.trade.job = nil; self:TradeMessage("The client did not pick up the requested supply stack."); return
                    end
                    C_Container.PickupContainerItem(bag, slot)
                    if GetCursorInfo() then ClearCursor(); self.trade.job = nil; self:TradeMessage("The split was refused; supplies stayed in your bags."); return end
                    job.pending = {split=true, bag=bag, slot=slot, id=stack.id, count=amount}
                    self:DebugLog("Bag split", string.format("Item %d: exact remainder %d into bag %d slot %d", stack.id, amount, bag, slot))
                else
                    C_Container.PickupContainerItem(stack.bag, stack.slot)
                    local cursor, id = GetCursorInfo()
                    if cursor ~= "item" or self:Readable(id) ~= stack.id then
                        self.trade.job = nil; self:TradeMessage("The client did not pick up the requested supply stack."); return
                    end
                    ClickTradeButton(free[1])
                    if GetCursorInfo() then ClearCursor(); self.trade.job = nil; self:TradeMessage("The trade move was refused; supplies stayed in your bags."); return end
                    job.pending = {slot=free[1], id=stack.id, count=amount}
                end
                job.moves = job.moves + 1
                self:TradeLater(job)
                return
            end
        end
    end
    self.trade.job = nil
    local short = {}
    for _, kind in ipairs({"food","water"}) do
        local missing = job.targets[kind] - totals[kind]
        if missing > 0 then short[#short + 1] = missing .. " " .. kind end
    end
    self:TradeMessage(#short > 0 and ("Short " .. table.concat(short, " and ") .. ". Review the offer.") or "Preset total reached. Review and press Trade.")
end

function addon:FillTrade(extraKind)
    if not self.trade.open or not self.db.vending.enabled or InCombatLockdown() then return end
    if self.trade.job then return end
    if not (C_Container and C_Container.GetContainerItemInfo and C_Timer and C_Timer.After) then
        self:TradeMessage("This client does not provide the required bag APIs."); return
    end
    local totals, err = self:TradeOffer()
    if not totals then self:TradeMessage(err); return end
    local targets = {food=self.trade.targets.food, water=self.trade.targets.water}
    self:DebugLog("Fill requested", string.format("%s; targets food %d, water %d; offered %d/%d; reserves %d/%d",
        extraKind or "preset", targets.food, targets.water, totals.food, totals.water,
        self.db.vending.reserveFood, self.db.vending.reserveWater))
    self.trade.job = {targets=targets, stackKind=extraKind, moves=0, waits=0}
    self.trade.message = "Filling the offer…"
    local job = self.trade.job
    local ok, errorMessage = pcall(function() self:TradeStep(job) end)
    if not ok then self.trade.job = nil; self:TradeMessage("Fill stopped: " .. tostring(errorMessage)) end
    self:UpdateTradeUI()
end

function addon:ClearTradeSupplies()
    if not self.trade.open or InCombatLockdown() or self.trade.job or GetCursorInfo() then return end
    local totals, _, slots = self:TradeOffer()
    if not totals then return end
    for slot, owned in pairs(self.trade.owned) do
        local offered = slots[slot]
        if offered and offered.id == owned.id and offered.count == owned.count then
            local ok = pcall(ClickTradeButton, slot)
            if not ok then self:TradeMessage("The client refused to clear a supply stack."); return end
            if GetCursorInfo() then ClearCursor() end
        end
        self.trade.owned[slot] = nil
    end
    self:TradeMessage("Arcanum-added supplies cleared. Other trade items were left alone.")
end

function addon:IsEnchantingWindowOpen()
    local visible = false
    for _, frame in ipairs({ProfessionsFrame or false, TradeSkillFrame or false, CraftFrame or false}) do
        if frame and frame:IsShown() then visible = true end
    end
    if not visible then return false end
    if C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo then
        local ok, info = pcall(C_TradeSkillUI.GetBaseProfessionInfo)
        info = ok and self:Readable(info)
        if type(info) == "table" and self:Readable(info.professionID) == 333 then return true end
    end
    local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(7411)
    local name = info and self:Readable(info.name) or (GetSpellInfo and self:Readable(GetSpellInfo(7411)))
    if type(name) ~= "string" then return false end
    for _, query in ipairs({GetTradeSkillLine or false, GetCraftDisplaySkillLine or false}) do
        if query then
            local ok, skill = pcall(query)
            if ok and self:Readable(skill) == name then return true end
        end
    end
    return false
end

function addon:PositionTradeUI()
    local panel = self.tradeUI
    if not panel or self.trade.dragging then return end
    local position = self.db.vending.position
    panel:ClearAllPoints()
    if type(position.x) == "number" and type(position.y) == "number" then
        panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", position.x, position.y)
    else
        panel:SetPoint("TOPLEFT", TradeFrame, "TOPRIGHT", 8, -28)
    end
    self.tradeTab:ClearAllPoints()
    self.tradeTab:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
end

function addon:ResetTradePosition()
    if self.tradeUI then self.tradeUI:StopMovingOrSizing() end
    self.trade.dragging = nil
    self.db.vending.position = {}
    self:PositionTradeUI()
    self:UpdateTradeUI()
end

function addon:CloseTradePanel()
    self.tradeUI:StopMovingOrSizing()
    self.trade.dragging = nil
    self.trade.dismissed, self.trade.job = true, nil
    self:UpdateTradeUI()
end

function addon:RefreshTradeVisibility()
    if not self.tradeUI then return end
    local enchanting = self.db.vending.collapseEnchanting and self:IsEnchantingWindowOpen()
    if not enchanting then self.trade.enchantingOverride = nil end
    local collapsed = self.trade.collapsed or (enchanting and not self.trade.enchantingOverride)
    local visible = self.trade.open and self.db.vending.enabled and not self.trade.dismissed and TradeFrame:IsShown()
    self.tradeUI:SetShown(visible and not collapsed)
    self.tradeTab:SetShown(visible and collapsed)
end

function addon:CreateTradeUI()
    if not TradeFrame or self.tradeUI then return end
    -- Anchor beside TradeFrame without inheriting its window hierarchy.
    local panel = CreateFrame("Frame", "ArcanumVendingFrame", UIParent, "BasicFrameTemplateWithInset")
    panel:SetFrameStrata("FULLSCREEN_DIALOG")
    panel:SetFrameLevel(100)
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:SetSize(300, 314)
    local close = panel.CloseButton or CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function() self:CloseTradePanel() end)
    close:Show()
    panel:SetMovable(true)
    local drag = CreateFrame("Frame", nil, panel)
    drag:SetPoint("TOPLEFT", 8, -2); drag:SetSize(220, 26)
    drag:EnableMouse(true); drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function()
        self.trade.dragging = true; panel:StartMoving()
    end)
    drag:SetScript("OnDragStop", function()
        panel:StopMovingOrSizing(); self.trade.dragging = nil
        local x, y = panel:GetLeft(), panel:GetTop()
        if type(x) == "number" and type(y) == "number" then self.db.vending.position = {x=x, y=y} end
        self:PositionTradeUI()
    end)
    panel.dragHandle = drag
    local collapse = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    collapse:SetPoint("TOPRIGHT", -32, -4); collapse:SetSize(24, 20); collapse:SetText("–")
    collapse:SetScript("OnClick", function() self.trade.collapsed = true; self:RefreshTradeVisibility() end)
    panel.collapseButton, panel.closeButton = collapse, close
    local heading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    heading:SetPoint("TOPLEFT", 16, -5)
    heading:SetText("Arcanum • Vending")
    local function label(x, y, width, font)
        local value = panel:CreateFontString(nil, "OVERLAY", font or "GameFontNormalSmall")
        value:SetPoint("TOPLEFT", x, y); value:SetWidth(width); value:SetJustifyH("LEFT")
        return value
    end
    panel.title = label(20, -38, 260, "GameFontNormalLarge")
    panel.subtitle = label(20, -60, 260, "GameFontHighlightSmall")
    local function divider(y)
        local line = panel:CreateTexture(nil, "ARTWORK")
        line:SetPoint("TOPLEFT", 20, y); line:SetSize(260, 1)
        line:SetColorTexture(0.65, 0.52, 0.3, 0.35)
    end
    divider(-82)
    label(20, -94, 100):SetText("Supply")
    label(123, -94, 65):SetText("Offered")
    label(218, -94, 62):SetText("Request")
    panel.offered = {}
    for index, kind in ipairs({"food", "water"}) do
        local y = -119 - (index - 1) * 30
        label(20, y, 90, "GameFontHighlight"):SetText(kind == "food" and "Food" or "Water")
        panel.offered[kind] = label(123, y, 65, "GameFontHighlightLarge")
    end
    local banner = panel:CreateTexture(nil, "BACKGROUND")
    banner:SetPoint("TOPLEFT", 16, -182); banner:SetSize(268, 34)
    panel.statusBackground = banner
    panel.status = label(23, -185, 254, "GameFontHighlight")
    panel.status:SetSize(254, 28)
    panel.status:SetJustifyH("CENTER")
    local function button(value, x, y, width, handler)
        local control = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        control:SetSize(width, 22); control:SetPoint("TOPLEFT", x, y); control:SetText(value)
        control:SetScript("OnClick", handler)
        return control
    end
    panel.buttons = {
        fill=button("Add requested supplies", 20, -225, 260, function() self:FillTrade() end),
        food=button("+ Food", 20, -254, 126, function() self:FillTrade("food") end),
        water=button("+ Water", 154, -254, 126, function() self:FillTrade("water") end),
        clear=button("Clear supplies", 20, -283, 174, function() self:ClearTradeSupplies() end),
    }
    button("Settings", 202, -283, 78, function() self:OpenSettings("Vending") end)
    -- Keep full explanations on hover without crowding the compact panel.
    local hints = {
        fill="Add this player's remaining requested food and water. Review the offer, then press Trade.",
        food="Add one full food stack above your personal reserve.",
        water="Add one full water stack above your personal reserve.",
        clear="Remove supplies added by Arcanum from this trade.",
    }
    for kind, control in pairs(panel.buttons) do
        if control.SetMotionScriptsWhileDisabled then control:SetMotionScriptsWhileDisabled(true) end
        control:SetScript("OnEnter", function()
            GameTooltip:SetOwner(control, "ANCHOR_RIGHT")
            GameTooltip:SetText(hints[kind], 1, 0.82, 0, true)
            local reason = self:TradeControlReason(kind)
            if reason then GameTooltip:AddLine(reason, 1, 0.8, 0.4, true) end
            GameTooltip:Show()
        end)
        control:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    panel.statusHover = CreateFrame("Frame", nil, panel)
    panel.statusHover:SetPoint("TOPLEFT", 16, -182); panel.statusHover:SetSize(268, 34)
    panel.statusHover:EnableMouse(true)
    panel.statusHover:SetScript("OnEnter", function()
        GameTooltip:SetOwner(panel.statusHover, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.trade.message or "Review your offer, then press Trade in the trade window.", 1, 1, 1, true)
        local _,food=self:SupplyStacks("food")
        local _,water=self:SupplyStacks("water")
        GameTooltip:AddLine(string.format("Usable bags: %d food, %d water",food,water),0.7,0.8,1)
        GameTooltip:AddLine(string.format("Keep for yourself: %d food, %d water",self:TradeReserve("food"),self:TradeReserve("water")),0.7,0.8,1)
        GameTooltip:Show()
    end)
    panel.statusHover:SetScript("OnLeave", function() GameTooltip:Hide() end)
    panel.inputs = {}
    for index, kind in ipairs({"food","water"}) do
        local y = -115 - (index - 1) * 30
        local input = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
        input:SetSize(52, 24); input:SetPoint("TOPLEFT", 222, y)
        input:SetFontObject("GameFontHighlight")
        input:SetAutoFocus(false); input:SetMaxLetters(3)
        local function save()
            local value = tonumber(input:GetText())
            if value and not self.trade.job then self.trade.targets[kind] = math.floor(math.max(0, math.min(120, value))) end
            input:SetText(tostring(self.trade.targets[kind]))
            self:UpdateTradeUI()
        end
        input:SetScript("OnEnterPressed", function() save(); input:ClearFocus() end)
        input:SetScript("OnEditFocusLost", save)
        panel.inputs[kind] = input
    end
    self.tradeUI = panel
    local tab = CreateFrame("Button", "ArcanumVendingTab", UIParent, "UIPanelButtonTemplate")
    tab:SetSize(110, 26); tab:SetText("Vending  +")
    tab:SetFrameStrata("FULLSCREEN_DIALOG"); tab:SetFrameLevel(100)
    tab:SetClampedToScreen(true)
    tab:SetScript("OnClick", function()
        self.trade.collapsed, self.trade.enchantingOverride = false, true
        self:UpdateTradeUI()
    end)
    self.tradeTab = tab
    local watcher = CreateFrame("Frame", nil, UIParent)
    local elapsed = 0
    watcher:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed >= 0.2 then elapsed = 0; self:RefreshTradeVisibility() end
    end)
    self.tradeWatcher = watcher
    TradeFrame:HookScript("OnHide", function() panel:Hide(); tab:Hide(); watcher:Hide() end)
    TradeFrame:HookScript("OnShow", function()
        if self.trade.open then watcher:Show(); self:UpdateTradeUI() end
    end)
    tab:Hide(); watcher:Hide()
    panel:Hide()
end

function addon:UpdateTradeUI()
    if not self.trade.open then return end
    self:CreateTradeUI()
    if not self.tradeUI then return end
    local panel = self.tradeUI
    self:PositionTradeUI()
    self:RefreshTradeVisibility()
    if not TradeFrame:IsShown() then return end
    self.tradeWatcher:Show()
    local totals = self:TradeOffer()
    panel.title:SetText(self.trade.name)
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[self.trade.class]
    panel.title:SetTextColor(color and color.r or 1, color and color.g or 0.82, color and color.b or 0)
    local class = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[self.trade.class]
        or self.trade.class or "Custom"
    panel.subtitle:SetText(class:sub(1,1) .. class:sub(2):lower() .. (self.trade.groupRequest and " • Group request" or " • Class request"))
    local _, food = self:SupplyStacks("food")
    local _, water = self:SupplyStacks("water")
    local reserveFood, reserveWater = self:TradeReserve("food",true),self:TradeReserve("water",true)
    local ready = totals and totals.food >= self.trade.targets.food and totals.water >= self.trade.targets.water
    local status, r, g, b
    if InCombatLockdown() then status, r, g, b = "Available outside combat", 1, 0.75, 0.35
    elseif self.trade.job then status, r, g, b = "Adding supplies…", 1, 0.82, 0
    elseif ready then
        status, r, g, b = self.trade.targets.food+self.trade.targets.water==0 and "No supplies requested" or "Request filled\nReview and confirm trade", 0.4, 1, 0.5
    else
        status, r, g, b = "Ready to add", 1, 0.82, 0
        if totals then
            local missingFood=math.max(0,self.trade.targets.food-totals.food-math.max(0,food-reserveFood))
            local missingWater=math.max(0,self.trade.targets.water-totals.water-math.max(0,water-reserveWater))
            if missingFood>0 and missingWater>0 then status=string.format("Need %d food + %d water",missingFood,missingWater)
            elseif missingFood>0 then status=string.format("Need %d more food",missingFood)
            elseif missingWater>0 then status=string.format("Need %d more water",missingWater) end
        end
    end
    if totals then
        for _, kind in ipairs({"food", "water"}) do
            panel.offered[kind]:SetText(tostring(totals[kind]))
            local met = totals[kind] >= self.trade.targets[kind]
            panel.offered[kind]:SetTextColor(met and 0.4 or 1, met and 1 or 0.82, met and 0.5 or 0.35)
        end
    else
        status, r, g, b = "Trade details unavailable", 1, 0.75, 0.35
        panel.offered.food:SetText("?"); panel.offered.water:SetText("?")
    end
    for kind, control in pairs(panel.buttons) do
        if kind == "food" or kind == "water" then
            local stack = self:FullTradeStack(kind)
            local name = kind == "food" and "Food" or "Water"
            control:SetText(stack and string.format("+%d %s", stack.count, name) or ("+ " .. name))
        end
        local reason = self:TradeControlReason(kind)
        control:SetEnabled(reason == nil)
        if kind == "fill" and reason and not ready and not self.trade.job and not InCombatLockdown() then
            if reason~="Conjure more or lower your reserves." then status=reason end
            r,g,b=1,0.75,0.35
        end
    end
    panel.status:SetText(status)
    panel.status:SetTextColor(r, g, b)
    panel.statusBackground:SetColorTexture(r * 0.15, g * 0.15, b * 0.15, 0.85)
end

function addon:VendingEvent(event)
    if event == "TRADE_SHOW" then
        local _, class = UnitClass("NPC")
        class = self:Readable(class)
        local level = self:Readable(UnitLevel("NPC"))
        self.trade = {open=true, owned={}, class=class, name=self:Readable(UnitName("NPC")) or "Recipient",
            level=type(level)=="number" and level > 0 and level or nil, message="Add to trade tops up this player's food and water targets. Review the offer, then press Trade."}
        self.trade.key = UnitGUID and self:Readable(UnitGUID("NPC")) or self.trade.name
        local preset = self.db.vending.presets[class or "UNKNOWN"] or self.db.vending.presets.UNKNOWN
        self.trade.targets = {food=preset.food, water=preset.water}
        local requested,key=self:GroupSupplyTradeTargets(self.trade.name,self.trade.key)
        if requested then
            self.trade.targets=requested
            self.trade.groupBaseline={food=requested.food,water=requested.water}
            self.trade.key=key
            self.trade.groupRequest=true
        end
        self:UpdateTradeUI()
        if self.tradeUI then
            for kind, input in pairs(self.tradeUI.inputs) do input:SetText(tostring(self.trade.targets[kind])) end
        end
        if C_Timer then C_Timer.After(0, function() self:UpdateTradeUI() end) end
    elseif event == "TRADE_CLOSED" then
        if self.tradeUI then self.tradeUI:StopMovingOrSizing() end
        self.trade.dragging = nil
        self.trade.open, self.trade.job = false, nil
        if self.tradeUI then self.tradeUI:Hide() end
        if self.tradeTab then self.tradeTab:Hide(); self.tradeWatcher:Hide() end
    elseif self.trade.open then
        self:UpdateTradeUI()
    end
end
