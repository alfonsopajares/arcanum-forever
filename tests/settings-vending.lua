local checks = 0
local function check(value, message) assert(value, message); checks = checks + 1 end

SlashCmdList.ARCANUM("")
check(addon.settings:IsShown() and addon.settings.pages.Circle:IsShown(), "bare /arc opens options")
SlashCmdList.ARCANUM("toggle")
check(not addon.db.visible and not addon.frame:IsShown(), "/arc toggle hides the circle")
SlashCmdList.ARCANUM("toggle")
check(addon.db.visible and addon.frame:IsShown(), "/arc toggle shows the circle again")
addon:OpenSettings("Vending")
check(addon.settings.pages.Vending:IsShown() and not addon.settings.pages.Circle:IsShown(), "settings tabs select the correct panel")
check(addon.db.vending.presets.MAGE.water == 40 and addon.db.vending.presets.ROGUE.water == 0, "class defaults match agreed presets")
addon.db.vending.presets.MAGE.water = 35
check(addon.defaults.vending.presets.MAGE.water == 40, "saved nested settings do not alias defaults")
addon.db.scale, addon.db.radius, addon.db.rotation = 140, 120, 30
addon.db.iconsPerRow = 2
addon.db.categoryEnabled.buffs = false
addon:SettingsChanged()
check(addon.frame.scale == 1.4 and not addon.toggles.buffs:IsShown(), "size and category visibility settings affect the circle")
check(addon.menus.refreshments.rows[2].point[5] == -6, "icons-per-row setting relayouts the two conjure buttons")
addon.db.hover = false
addon:SettingsChanged()
secureClick(addon.toggles.utility, "_onenter")
check(not addon.menus.utility:IsShown(), "click-only setting disables hover opening")
secureClick(addon.toggles.utility)
check(addon.menus.utility:IsShown(), "click opening still works when hover is disabled")
combat = true
addon.db.scale = 170
addon:SettingsChanged()
check(addon.settingsPending and addon.frame.scale == 1.4, "combat changes are saved and deferred")
addon:OpenSettings("Display")
check(addon.settings.pages.Display:IsShown(), "settings can open during combat")
combat = false
fire("PLAYER_REGEN_ENABLED")
check(addon.frame.scale == 1.7 and not addon.settingsPending, "settings apply after combat")
addon:HandleCommand("reset")
check(addon.db.scale == 100 and addon.db.vending.presets.MAGE.water == 35, "layout reset preserves vending presets")

local bags, offer, cursor, timers = {}, {}, nil, {}
local bagSlots = 12
local function bag(id) bags[id] = bags[id] or {}; return bags[id] end
local function empty() for slot = 1, bagSlots do if not bag(0)[slot] then return slot end end end
local function place(item) local slot = assert(empty(), "mock bag full"); bag(0)[slot] = item end
local function copy(item) return item and {id=item.id, count=item.count} end
TradeFrame = CreateFrame("Frame", "TradeFrame", UIParent)
UnitClass = function(unit) if unit == "NPC" then return "Priest", "PRIEST" end; return "Mage", "MAGE" end
UnitLevel = function() return 60 end
UnitName = function() return "Test Priest" end
C_Timer = {After=function(_, fn) timers[#timers + 1] = fn end}
local function drain()
    local steps = 0
    while #timers > 0 do
        steps = steps + 1; assert(steps < 150, "unbounded trading retries")
        table.remove(timers, 1)()
    end
end
C_Container.GetContainerNumSlots = function(id) return id == 0 and bagSlots or 0 end
C_Container.GetContainerNumFreeSlots = function(id)
    local n = 0; for slot = 1, bagSlots do if not bag(id)[slot] then n = n + 1 end end
    return id == 0 and n or 0, 0
end
C_Container.GetContainerItemInfo = function(id, slot)
    local item = bag(id)[slot]
    return item and {itemID=item.id, stackCount=item.count, isLocked=false}
end
C_Container.SplitContainerItem = function(id, slot, n)
    assert(cursor == nil, "cursor occupied")
    local item = assert(bag(id)[slot]); assert(n < item.count and n > 0)
    item.count = item.count - n; cursor = {id=item.id, count=n}
end
C_Container.PickupContainerItem = function(id, slot)
    if cursor then
        local existing = bag(id)[slot]
        if existing then
            assert(existing.id == cursor.id, "merge requires matching items")
            local amount = math.min(20 - existing.count, cursor.count)
            existing.count, cursor.count = existing.count + amount, cursor.count - amount
            if cursor.count == 0 then cursor = nil end
        else bag(id)[slot], cursor = cursor, nil end
    else cursor, bag(id)[slot] = bag(id)[slot], nil end
end
GetTradePlayerItemInfo = function(slot)
    local item = offer[slot]
    if item then return "Item", nil, item.count, nil, nil, nil, nil, item.id end
end
GetCursorInfo = function() if cursor then return "item", cursor.id end end
ClickTradeButton = function(slot)
    if cursor then assert(not offer[slot]); offer[slot], cursor = cursor, nil
    else cursor, offer[slot] = offer[slot], nil end
end
ClearCursor = function() if cursor then place(cursor); cursor = nil end end
local function resetTrade()
    fire("TRADE_CLOSED"); bags, offer, cursor, timers = {}, {}, nil, {}
    fire("TRADE_SHOW"); drain()
end
known[5504], known[5505], known[587], known[597] = true, true, true, true
resetTrade()
check(addon.trade.targets.food == 20 and addon.trade.targets.water == 40, "trade uses recipient class preset")
check(addon.tradeUI.parent == UIParent and addon.tradeUI.strata == "FULLSCREEN_DIALOG", "vending panel is independent of the trade window hierarchy and above normal windows")
check(addon.tradeUI.template == "BasicFrameTemplateWithInset", "vending uses Blizzard's native framed panel")
TradeFrame:Hide(); TradeFrame.hooks.OnHide()
check(not addon.tradeUI:IsShown(), "independent vending panel hides with the trade window")
addon:UpdateTradeUI()
check(not addon.tradeUI:IsShown(), "updates cannot reopen vending while trade window is hidden")
TradeFrame:Show(); addon:UpdateTradeUI()
check(addon.tradeUI:IsShown(), "vending follows the visible trade window again")
bag(0)[1], bag(0)[2], bag(0)[3] = {id=2288,count=20}, {id=2288,count=20}, {id=1113,count=20}
addon:FillTrade(); addon:FillTrade(); drain()
local totals = addon:TradeOffer()
check(totals.water == 40 and totals.food == 20, "fill reaches class totals; an in-flight second click is harmless")
addon:FillTrade(); drain()
totals = addon:TradeOffer()
check(totals.water == 40 and totals.food == 20, "repeated completed fill does not double supplies")
check(addon.trade.message:find("Preset total reached"), "successful fill reports completion without accepting trade")
addon:ClearTradeSupplies()
totals = addon:TradeOffer()
check(totals.food == 0 and totals.water == 0, "clear returns only owned supply stacks")

resetTrade()
offer[1] = {id=5350,count=5}
offer[2] = {id=9999,count=1}
bag(0)[1] = {id=2288,count=20}
addon.trade.targets = {food=0,water=12}
addon:FillTrade(); drain()
totals = addon:TradeOffer()
check(totals.water == 12, "manual lower-rank supply counts toward total, with exact stack split")
check(offer[1].count == 5 and offer[2].id == 9999, "filling preserves existing trade items")
addon:ClearTradeSupplies()
totals = addon:TradeOffer()
check(totals.water == 5 and offer[2].id == 9999, "clear preserves manually added supplies and unrelated items")

resetTrade()
bag(0)[1] = {id=2288,count=20}
addon.db.vending.reserveWater = 6
addon.trade.targets = {food=0,water=20}
addon:FillTrade(); drain()
totals = addon:TradeOffer()
check(totals.water == 14, "reserve amount is kept in bags")
check(addon.trade.message:find("Short 6 water"), "shortage is explicit")
addon.db.vending.reserveWater = 0

resetTrade()
bag(0)[1] = {id=2288,count=20}
addon.trade.targets = {food=0,water=7}
for slot = 2, 12 do bag(0)[slot] = {id=9999,count=1} end
addon:FillTrade(); drain()
totals = addon:TradeOffer()
check(totals.water == 0 and addon.trade.message:find("free bag slot"), "full bags stop exact split without overfilling")

resetTrade()
bag(0)[1], bag(0)[2] = {id=2288,count=20}, {id=5350,count=20}
addon.trade.level = 1
addon.trade.targets = {food=0,water=20}
addon:FillTrade(); drain()
check(offer[1].id == 5350, "recipient level filters higher food/water ranks")

resetTrade()
bag(0)[1] = {id=2288,count=20}
addon.trade.targets = {food=0,water=20}
combat = true
addon:FillTrade()
check(not addon.trade.job and offer[1] == nil, "vending never moves inventory during combat")
combat = false
cursor = {id=9999,count=1}
addon:FillTrade(); drain()
check(cursor.id == 9999 and offer[1] == nil, "user cursor is preserved")
cursor = nil

resetTrade()
bag(0)[1], bag(0)[2] = {id=2288,count=20}, {id=2288,count=20}
addon.trade.targets = {food=0,water=40}
addon:FillTrade()
fire("TRADE_CLOSED"); drain()
check(offer[2] == nil and not addon.trade.job, "closing a trade cancels queued moves")

resetTrade()
bag(0)[1], bag(0)[2] = {id=2288,count=20}, {id=2288,count=20}
addon:FillTrade("water"); drain()
totals = addon:TradeOffer()
check(totals.water == 20, "+ Water adds one stack-sized amount")
addon:FillTrade("water"); drain()
totals = addon:TradeOffer()
check(totals.water == 40, "manual + Water can intentionally add another stack")
resetTrade()
local splitCalls = 0
local originalSplit = C_Container.SplitContainerItem
C_Container.SplitContainerItem = function(...) splitCalls = splitCalls + 1; return originalSplit(...) end
bag(0)[1], bag(0)[2] = {id=1113,count=20}, {id=1113,count=11}
offer[1] = {id=1113,count=9}
addon.db.vending.reserveFood = 10
addon:FillTrade("food"); drain()
check(offer[2].count == 20 and not offer[3] and bag(0)[2].count == 11 and splitCalls == 0, "+ Food moves a whole stack despite existing partial offers and reserves")
resetTrade()
bag(0)[1] = {id=1113,count=20}
addon:FillTrade("food"); drain()
check(not offer[1] and bag(0)[1].count == 20 and splitCalls == 0 and addon.trade.message:find("reserve"), "insufficient reserve blocks whole-stack add without splitting")
addon.db.vending.reserveFood = 0
addon:FillTrade("food"); addon:FillTrade("food"); drain()
check(offer[1].count == 20 and not offer[2] and splitCalls == 0, "+ Food with zero reserve adds exactly one intact stack")
addon:ClearTradeSupplies()
check(not offer[1], "whole-stack adds are tracked for clearing")
resetTrade()
bag(0)[1], bag(0)[2] = {id=1113,count=11}, {id=1113,count=9}
addon:FillTrade("food"); drain()
check(not offer[1] and bag(0)[1].count == 11 and bag(0)[2].count == 9, "manual stack add does not process partial bag stacks")
C_Container.SplitContainerItem = originalSplit
resetTrade()
for slot = 1, 12 do bag(0)[slot] = {id=1113,count=1} end
addon.trade.targets = {food=20,water=0}
addon:FillTrade(); drain()
totals = addon:TradeOffer()
check(totals.food == 12 and offer[1].count == 12 and not offer[2], "single food items combine into one shortage stack, even with full bags")
check(addon.trade.message:find("Short 8 food"), "combined shortage is reported")
addon:ClearTradeSupplies()
check(addon:TradeOffer().food == 0, "combined stacks remain clearable")

resetTrade()
bag(0)[1], bag(0)[2], bag(0)[3] = {id=2288,count=12}, {id=2288,count=12}, {id=2288,count=12}
addon.trade.targets = {food=0,water=36}
addon:FillTrade(); drain()
check(offer[1].count == 20 and offer[2].count == 16 and not offer[3], "small batches become a full stack and one final partial stack")

resetTrade()
bag(0)[1], bag(0)[2] = {id=2288,count=8}, {id=2288,count=8}
addon.db.vending.reserveWater = 6
addon.trade.targets = {food=0,water=20}
addon:FillTrade(); drain()
check(offer[1].count == 10 and not offer[2] and select(2, addon:SupplyStacks("water")) == 6, "combining preserves exact personal reserves")
addon.db.vending.reserveWater = 0
resetTrade()
bagSlots = 24
for slot = 1, 20 do bag(0)[slot] = {id=1113,count=1} end
addon.trade.targets = {food=20,water=0}
addon:FillTrade(); drain()
check(offer[1].count == 20 and not offer[2], "twenty single items fill one complete trade stack")
bagSlots = 12

resetTrade()
bag(0)[1], bag(0)[2] = {id=2288,count=3}, {id=5350,count=3}
addon.trade.targets = {food=0,water=6}
addon:FillTrade(); drain()
check(offer[1].id == 2288 and offer[1].count == 3 and offer[2].id == 5350 and offer[2].count == 3, "different supply ranks remain separate")

resetTrade()
bag(0)[1], bag(0)[2] = {id=1113,count=1}, {id=1113,count=1}
addon.trade.targets = {food=20,water=0}
addon:FillTrade()
fire("TRADE_CLOSED"); drain()
check(not offer[1] and not addon.trade.job and not cursor, "closing during consolidation stops before adding an offer")
fire("TRADE_CLOSED")
resetTrade()
check(addon.db.vending.collapseEnchanting and addon.tradeUI:IsShown(), "new setting defaults to auto collapse without hiding regular trades")
addon.tradeUI.collapseButton.scripts.OnClick()
fire("TRADE_PLAYER_ITEM_CHANGED")
check(not addon.tradeUI:IsShown() and addon.tradeTab:IsShown(), "manual collapse survives trade updates with a reopening tab")
addon.tradeTab.scripts.OnClick()
check(addon.tradeUI:IsShown() and not addon.tradeTab:IsShown(), "collapsed tab reopens vending in the current trade")
addon.tradeUI.closeButton.scripts.OnClick()
fire("BAG_UPDATE_DELAYED")
check(not addon.tradeUI:IsShown() and not addon.tradeTab:IsShown(), "close stays hidden after bag updates")
resetTrade()
check(addon.tradeUI:IsShown(), "next trade restores a dismissed panel")
addon.trade.job = {moves=0}
addon:CloseTradePanel()
check(not addon.trade.job, "dismissing vending stops pending inventory moves")
resetTrade()
ProfessionsFrame = CreateFrame("Frame")
C_TradeSkillUI = {GetBaseProfessionInfo=function() return {professionID=333} end}
addon.tradeWatcher.scripts.OnUpdate(nil, 0.2)
check(not addon.tradeUI:IsShown() and addon.tradeTab:IsShown(), "opening enchanting automatically collapses vending")
C_TradeSkillUI.GetBaseProfessionInfo = function() return {professionID=197} end
addon.tradeWatcher.scripts.OnUpdate(nil, 0.2)
check(addon.tradeUI:IsShown(), "other professions do not trigger enchanting collapse")
C_TradeSkillUI.GetBaseProfessionInfo = function() return {professionID=333} end
addon.tradeWatcher.scripts.OnUpdate(nil, 0.2)
addon.tradeTab.scripts.OnClick()
addon.tradeWatcher.scripts.OnUpdate(nil, 0.2)
check(addon.tradeUI:IsShown(), "explicit reopen overrides auto collapse for this enchanting session")
ProfessionsFrame:Hide()
addon.tradeWatcher.scripts.OnUpdate(nil, 0.2)
ProfessionsFrame:Show()
addon.tradeWatcher.scripts.OnUpdate(nil, 0.2)
check(addon.tradeTab:IsShown(), "reopening enchanting starts a new automatic collapse session")
ProfessionsFrame:Hide()
addon.tradeWatcher.scripts.OnUpdate(nil, 0.2)
check(addon.tradeUI:IsShown(), "closing enchanting restores an automatically collapsed panel")
addon.tradeUI.collapseButton.scripts.OnClick()
ProfessionsFrame:Show(); addon.tradeWatcher.scripts.OnUpdate(nil, 0.2)
ProfessionsFrame:Hide(); addon.tradeWatcher.scripts.OnUpdate(nil, 0.2)
check(addon.tradeTab:IsShown(), "closing enchanting preserves manual collapse")
addon.tradeTab.scripts.OnClick()
addon.tradeUI.GetLeft = function() return 520 end
addon.tradeUI.GetTop = function() return 740 end
addon.tradeUI.dragHandle.scripts.OnDragStart()
addon.tradeUI.dragHandle.scripts.OnDragStop()
fire("TRADE_PLAYER_ITEM_CHANGED")
check(addon.db.vending.position.x == 520 and addon.tradeUI.point[4] == 520, "dragged position is saved and preserved across updates")
resetTrade()
check(addon.tradeUI.point[4] == 520, "next trade retains saved position")
addon:ResetTradePosition()
check(addon.db.vending.position.x == nil and addon.tradeUI.point[2] == TradeFrame, "reset restores the default trade-side anchor")
ProfessionsFrame:Show()
addon.db.vending.collapseEnchanting = false
addon:SettingsChanged()
check(addon.tradeUI:IsShown(), "auto collapse can be disabled while enchanting is open")
addon.db.vending.enabled = false; addon:SettingsChanged()
check(not addon.tradeUI:IsShown() and not addon.tradeTab:IsShown(), "disabling vending hides both panel and tab")
addon.db.vending.enabled = true; addon.db.vending.collapseEnchanting = true
ProfessionsFrame:Hide()
fire("TRADE_CLOSED")
check(not addon.tradeWatcher:IsShown() and not addon.tradeTab:IsShown(), "closing a trade stops monitoring and hides the tab")
ProfessionsFrame, C_TradeSkillUI = nil, nil
io.write("Passed ", checks, " settings/vending checks using the real addon Lua.\n")
