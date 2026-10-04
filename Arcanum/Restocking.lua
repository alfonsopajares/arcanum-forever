local _, addon = ...

addon.reagents = {{id=17020, label="Arcane Powder"}, {id=17031, label="Rune of Teleportation"}, {id=17032, label="Rune of Portals"}, {id=17056, label="Light Feather"}}

function addon:ReagentIsNeeded(id)
    for _, spell in ipairs(self.spells) do
        if spell.reagent == id then
            for _, rank in ipairs(spell.ranks) do if self:KnownSpell(rank) then return true end end
        end
    end
    return false
end

function addon:ReagentCapacity(id)
    local api = C_Container
    if not (api and api.GetContainerNumFreeSlots and api.GetContainerNumSlots and api.GetContainerItemInfo) then return 0 end
    local query = C_Item and C_Item.GetItemInfo or GetItemInfo
    local maximum = query and self:Readable(select(8, query(id)))
    if type(maximum) ~= "number" or maximum < 1 then return 0 end
    local capacity = 0
    for bag = 0, 4 do
        local free, family = api.GetContainerNumFreeSlots(bag)
        free, family = self:Readable(free), self:Readable(family)
        if type(free) == "number" and family == 0 then capacity = capacity + free * maximum end
        local slots = self:Readable(api.GetContainerNumSlots(bag))
        if type(slots) == "number" then
            for slot = 1, slots do
                local info = self:Readable(api.GetContainerItemInfo(bag, slot))
                if info and self:Readable(info.itemID) == id and self:Readable(info.isLocked) == false then
                    local count = self:Readable(info.stackCount)
                    if type(count) == "number" then capacity = capacity + math.max(0, maximum - count) end
                end
            end
        end
    end
    return capacity
end

function addon:RestockEvent(event)
    if event == "MERCHANT_CLOSED" then self.restockVisit = nil; return end
    if event == "MERCHANT_SHOW" then
        self.restockVisit = {spent=0}
        if self.db.restock.enabled and C_Item and C_Item.RequestLoadItemDataByID then
            for _, reagent in ipairs(self.reagents) do
                if self:ReagentIsNeeded(reagent.id) then C_Item.RequestLoadItemDataByID(reagent.id) end
            end
        end
    end
    local visit, options = self.restockVisit, self.db.restock
    if not visit or visit.stopped or not options.enabled or InCombatLockdown() or not BuyMerchantItem then return end
    if visit.pending then
        local p = visit.pending
        if self:ItemCount(p.id) < p.expected then
            if GetTime() - p.time > 3 then visit.stopped = true end
            return
        end
        visit.pending = nil
    end
    local money = GetMoney and self:Readable(GetMoney())
    local slots = GetMerchantNumItems and self:Readable(GetMerchantNumItems())
    if type(money) ~= "number" or type(slots) ~= "number" then return end
    visit.startMoney = visit.startMoney or money
    -- Bag confirmation can arrive before PLAYER_MONEY. Reserve already-issued
    -- purchases against the initial balance as well as the current balance.
    local budget = math.min(options.maxGold * 10000 - visit.spent,
        math.min(money, visit.startMoney - visit.spent) - options.keepGold * 10000)
    if budget <= 0 then return end
    for slot = 1, slots do
        local id = GetMerchantItemID and self:Readable(GetMerchantItemID(slot))
        if not id and GetMerchantItemLink then
            local link = self:Readable(GetMerchantItemLink(slot))
            id = type(link) == "string" and tonumber(link:match("item:(%d+)"))
        end
        local target = id and options.targets[id]
        if target and self:ReagentIsNeeded(id) then
            local price, quantity, available, purchasable, extended
            if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
                local info = self:Readable(C_MerchantFrame.GetItemInfo(slot))
                if info then price,quantity,available,purchasable,extended = info.price,info.stackCount,info.numAvailable,info.isPurchasable,info.hasExtendedCost end
            elseif GetMerchantItemInfo then
                local name, texture, usable
                name, texture, price, quantity, available, usable, extended = GetMerchantItemInfo(slot)
                purchasable = true
            end
            price, quantity, available = self:Readable(price), self:Readable(quantity), self:Readable(available)
            if type(price) == "number" and price > 0 and type(quantity) == "number" and quantity > 0
                and type(available) == "number" and self:Readable(purchasable) == true and self:Readable(extended) == false then
                local owned = self:ItemCount(id)
                local amount = math.min(target - owned, self:ReagentCapacity(id), math.floor(budget / price) * quantity)
                if available >= 0 then amount = math.min(amount, available) end
                local query = C_Item and C_Item.GetItemInfo or GetItemInfo
                local maximum = query and self:Readable(select(8, query(id)))
                if type(maximum) == "number" then amount = math.min(amount, maximum) end
                amount = math.floor(amount / quantity) * quantity
                if amount > 0 then
                    visit.spent = visit.spent + amount / quantity * price
                    visit.pending = {id=id, expected=owned+amount, time=GetTime()}
                    local ok = pcall(BuyMerchantItem, slot, amount)
                    if not ok then visit.stopped = true; return end
                    self:DebugLog("Reagent restock", string.format("Requested %d of item %d", amount, id))
                    return -- Wait for the bags to confirm this purchase before buying again.
                end
            end
        end
    end
end
