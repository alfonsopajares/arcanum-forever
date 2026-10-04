local checks = 0
local function check(value, message) assert(value, message); checks = checks + 1 end
combat = false
known, inventory, spellBook = {[1459]=true,[168]=true,[10059]=true,[118]=true,[12051]=true,[3561]=true}, {}, {}
local stamp = 100
GetTime = function() return stamp end
local buffs = {}
C_UnitAuras = {GetPlayerAuraBySpellID=function(id) return buffs[id] end}
addon.db.categoryOrder = {"portals","portals","invalid","armor"}
addon:RefreshActions()
local order = addon:OrderedCategories()
check(#order == #addon.categories and order[1].id == "portals" and order[2].id == "armor", "order ignores duplicates/stale IDs and retains every category")
addon:MoveCategory("armor", -1)
check(addon:OrderedCategories()[1].id == "armor", "category order changes actual circle placement")
check(addon.toggles.armor.point[4] == 0 or math.abs(addon.toggles.armor.point[4]) < 0.0001, "first visible category is at the top")
addon:HandleCommand("reset")
check(addon:OrderedCategories()[1].id == "buffs", "layout reset restores original category order")
local portal = addon.menus.portals.rows[1]
portal.hooks.PostClick(portal, "LeftButton", true)
check(not addon.db.lastSelections.portals, "mouse-down does not remember a duplicate selection")
portal.hooks.PostClick(portal, "LeftButton", false)
check(addon.toggles.portals:GetAttribute("shift-spell1") == 10059, "last selection becomes a secure shift-click spell")
shiftHeld = true
addon.menus.portals:Hide()
secureClick(addon.toggles.portals)
check(not addon.menus.portals:IsShown(), "shift-click shortcut does not open or pin a flyout")
shiftHeld = false
secureClick(addon.toggles.portals)
check(addon.menus.portals:IsShown(), "ordinary click still pins the flyout")
check(addon.toggles.portals.secureWrappers.OnClick and addon.toggles.portals.template:find("SecureActionButtonTemplate"), "menu uses a wrapper that preserves secure casting")
local function wrappedClick(frame, down)
    local fn = assert(loadstring(frame.secureWrappers.OnClick))
    setfenv(fn, setmetatable({self=frame,button="LeftButton",down=down},{__index=_G}))
    secure=true; local ok, err=pcall(fn); secure=false; assert(ok,err)
end
addon.menus.portals:SetAttribute("pinned",nil); addon.menus.portals:Hide()
wrappedClick(addon.toggles.portals,true)
check(not addon.menus.portals:IsShown(), "secure wrapper ignores mouse-down")
wrappedClick(addon.toggles.portals,false)
check(addon.menus.portals:IsShown(), "secure wrapper passes mouse-up arguments to menu code")
known[1460]=true
addon:RememberSelection("buffs",{kind="spell",id=1459})
addon:RefreshActions()
check(addon.toggles.buffs:GetAttribute("shift-spell1") == 1460, "remembered spell follows a newly learned rank")
combat = true
addon:RememberSelection("armor", addon.menus.armor.rows[1].action)
check(not addon.toggles.armor:GetAttribute("shift-spell1"), "new shortcuts are not rebound during combat")
combat = false
fire("PLAYER_REGEN_ENABLED")
check(addon.toggles.armor:GetAttribute("shift-spell1") == 168, "combat selection is applied afterwards")
known[10059] = nil
addon:RefreshActions()
check(not addon.toggles.portals:GetAttribute("shift-spell1"), "unlearned last spell clears its shortcut")
buffs[1459], buffs[168] = {expirationTime=stamp+119}, {expirationTime=stamp+9}
addon:UpdateBuffTimers()
check(addon.toggles.buffs.timer.text == "2m" and addon.toggles.armor.timer.text == "9s", "real buff expiration formats minutes and seconds")
stamp = stamp + 10; addon:UpdateBuffTimers()
check(addon.toggles.armor.timer.text == "", "expired buffs have no stale timer")
buffs[1459] = {expirationTime=secretNumber()}
addon:UpdateBuffTimers()
check(addon.toggles.buffs.timer.text == "", "secret expiration is never used in arithmetic")
buffs[1459] = secretNumber(); addon:UpdateBuffTimers()
check(addon.toggles.buffs.timer.text == "", "secret aura objects are never indexed")
buffs[1459] = {expirationTime=stamp+60}; addon.db.showBuffTimers=false; addon:UpdateBuffTimers()
check(addon.toggles.buffs.timer.text == "", "buff timer setting hides labels")
addon.db.showBuffTimers=true
addon:OpenSettings("Messages")
check(addon.settings.pages.Messages:IsShown() and addon.settings.tabs.Restocking, "new settings pages are accessible")
check(addon.settings.tabs.Support.point[3] < addon.settings.tabs.Restocking.point[3]
    and addon.settings.tabs.Restocking.point[3] < addon.settings.tabs.Messages.point[3], "Support is the final settings tab")
addon.settings.choices["Edit messages for"].choose("trade")
addon.settings.choices["Message style"].choose("custom")
addon.settings.messageInput:SetText("Thanks {target}!\n{food} food and {water} water.")
addon.settings.messageInput.scripts.OnEditFocusLost()
check(addon.db.messages.events.trade.custom:find("Thanks"), "custom multiline speech saves for selected event")
addon.settings.messageInput:SetText(string.rep("x",256))
addon.settings.messageInput.scripts.OnEditFocusLost()
check(addon.db.messages.events.trade.custom:find("Thanks") and addon.settings.status.text:find("255"), "oversized custom lines are rejected with visible feedback")
addon.settings.messageInput:SetText(addon.db.messages.events.trade.custom)

local chat = {}
SendChatMessage = function(value, channel) chat[#chat+1] = {value=value, channel=channel} end
addon.GroupMembers = function() return {{name="Nix",key="Nix",class="ROGUE"}} end
IsInRaid = function() return false end
IsInGroup = function() return false end
known[10059] = true
spellNames[10059] = "Portal: Stormwind"
addon.db.messages.enabled, addon.db.messages.channel = true, "group"
addon.messageTimes, addon.pendingSpeeches = {}, {}
addon.db.messages.events.portal.style = "useful"
fire("UNIT_SPELLCAST_SENT", "player", "", "p1", 10059)
fire("UNIT_SPELLCAST_START", "player", "p1", 10059)
check(#chat == 0, "success-only messages do not announce at cast start")
fire("UNIT_SPELLCAST_FAILED", "player", "p1", 10059)
check(#chat == 0, "failed portal casts do not announce readiness")
fire("UNIT_SPELLCAST_SENT", "player", "", "p2", 10059)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "p2", 10059)
check(#chat == 1 and chat[1].channel == "PARTY" and chat[1].value:find("Stormwind"), "successful portal routes destination announcement to party")
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "p2", 10059)
check(#chat == 1, "repeat throttle prevents duplicate announcements")
stamp = stamp + 31
addon.db.messages.events.portal.style="funny"
local first = addon:MessageText("portal","success",{destination="Ironforge"})
local second = addon:MessageText("portal","success",{destination="Ironforge"})
check(first ~= second, "random funny speeches avoid immediate repeats")
for _, entry in ipairs(addon.messageEvents) do
    local event = entry[1]
    local option = addon.db.messages.events[event]
    local originalStyle = option.style
    option.style = "funny"
    for _, phase in ipairs(event == "trade" and {"success"} or {"start","success"}) do
        addon.speechRotations = {}
        local seen, last = {}, nil
        for i = 1, 5 do
            local value = addon:MessageText(event,phase,{target="Nix",destination="Stormwind",food=20,water=40})
            check(not seen[value], event .. ":" .. phase .. " uses each of its five speeches once per cycle")
            seen[value], last = true, value
        end
        addon:MessageText(event,phase,{},true)
        check(#addon.speechRotations[event .. ":" .. phase].queue == 0, "preview does not refill or advance a completed rotation")
        addon.previewRotations = {}
        local previewSeen, previewFirst = {}, nil
        for i = 1, 5 do
            local value = addon:MessageText(event,phase,{target="Nix",destination="Stormwind",food=20,water=40},true)
            check(not previewSeen[value] and seen[value], "funny previews show each of the five actual messages")
            previewSeen[value] = true
            previewFirst = previewFirst or value
        end
        check(addon:MessageText(event,phase,{target="Nix",destination="Stormwind",food=20,water=40},true) == previewFirst,
            "sixth preview wraps to the beginning of its own cycle")
        check(#addon.speechRotations[event .. ":" .. phase].queue == 0, "preview cycling leaves the live message queue untouched")
        local nextCycle = addon:MessageText(event,phase,{target="Nix",destination="Stormwind",food=20,water=40})
        check(nextCycle ~= last and seen[nextCycle], "new cycle stays in the five-message pool and avoids a boundary repeat")
    end
    option.style = originalStyle
end
addon.speechRotations={}
addon.db.messages.events.portal.style="useful"
local practical = addon:MessageText("portal","success",{destination="Stormwind"})
check(practical == addon:MessageText("portal","success",{destination="Stormwind"}) and next(addon.speechRotations) == nil,
    "practical messages remain fixed and do not consume a funny rotation")
addon.db.messages.events.portal.style="funny"
fire("UNIT_SPELLCAST_SENT", "player", "Nix", "s1", 118)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "s1", 118)
check(chat[#chat].value:find("Nix"), "Polymorph uses the captured cast target")
addon.db.messages.events.trade.enabled = true
addon:SendMageMessage("trade","success",{target="Nix",food=20,water=40})
check(chat[#chat-1].value == "Thanks Nix!" and chat[#chat].value == "20 food and 40 water.", "custom speech expands tokens and sends separate lines")
local before = #chat
addon.db.messages.enabled = false
stamp = stamp + 31; addon:SendMageMessage("trade","success",{target="Nix"})
check(#chat == before, "message master switch suppresses every speech")
addon.db.messages.enabled=true; addon.db.messages.channel="local"
addon:SendMageMessage("portal","success",{destination="Stormwind"})
check(#chat == before, "local mode never sends chat to other players")
addon.db.messages.channel="group"
stamp = stamp + 31
addon.db.preparation.trackTrades=false
addon.acceptedTrade={name="Nix",key="Nix",food=20,water=40,time=stamp}
addon:DistributionEvent("UI_INFO_MESSAGE",nil,ERR_TRADE_COMPLETE)
local deliveryCount = #chat
check(chat[deliveryCount].value == "20 food and 40 water.", "completed trade speech works even with history tracking disabled")
addon:DistributionEvent("UI_INFO_MESSAGE",nil,ERR_TRADE_COMPLETE)
check(#chat == deliveryCount, "trade completion message is consumed only once")
before=deliveryCount
addon.db.messages.events.evocation.enabled=true
addon.db.messages.events.evocation.timing="both"
UnitChannelInfo = function() return "Evocation",nil,nil,stamp*1000,(stamp+8)*1000 end
fire("UNIT_SPELLCAST_SENT", "player", "", "e1", 12051)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "e1", 12051)
check(#chat == before, "Evocation initial success does not claim the channel completed")
fire("UNIT_SPELLCAST_CHANNEL_START", "player", "e1", 12051)
check(#chat == before+1, "Evocation can announce channel start")
fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "e1", 12051)
check(#chat == before+1, "early channel cancellation does not announce completion")
stamp = stamp + 31
fire("UNIT_SPELLCAST_SENT", "player", "", "e2", 12051)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "e2", 12051)
fire("UNIT_SPELLCAST_CHANNEL_START", "player", "e2", 12051)
stamp = stamp + 8
fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "e2", 12051)
check(#chat == before+3, "full Evocation channel delivers start and completion speech")

local purchases, money, free = {}, 100000, 1
C_Item.GetItemInfo = function(id) return "Reagent "..id,nil,nil,nil,nil,nil,nil,20 end
C_Container.GetContainerNumFreeSlots = function(bag) return bag == 0 and free or 0,0 end
C_Container.GetContainerNumSlots = function() return 0 end
GetMoney = function() return money end
GetMerchantNumItems = function() return 3 end
GetMerchantItemID = function(slot) return ({17020,17031,17032})[slot] end
local price, quantity, stock, extended = 100,1,-1,false
GetMerchantItemInfo = function() return "Reagent",nil,price,quantity,stock,true,extended end
BuyMerchantItem = function(slot, amount) purchases[#purchases+1]={slot=slot,amount=amount} end
addon.db.restock.enabled = false
fire("MERCHANT_SHOW")
check(#purchases == 0, "restocking is off by default")
addon.db.restock.enabled=true
fire("MERCHANT_SHOW")
check(#purchases == 1 and purchases[1].slot == 2 and purchases[1].amount == 10, "only learned spell reagents are bought to their targets")
fire("MERCHANT_UPDATE"); fire("BAG_UPDATE_DELAYED")
check(#purchases == 1, "unconfirmed purchase never duplicates on vendor or bag events")
inventory[17031] = 10
fire("BAG_UPDATE_DELAYED")
check(#purchases == 2 and purchases[2].slot == 3, "bag confirmation advances to the next needed reagent")
inventory[17032]=10; fire("BAG_UPDATE_DELAYED")
check(#purchases == 2, "fulfilled targets cause no extra purchases")
fire("MERCHANT_CLOSED"); inventory[17031]=0
fire("BAG_UPDATE_DELAYED")
check(#purchases == 2, "merchant close stops restocking")
addon.db.restock.maxGold=0.05
fire("MERCHANT_SHOW")
check(purchases[#purchases].amount == 5, "per-visit spending limit caps the purchase")
inventory[17031]=5; fire("BAG_UPDATE_DELAYED")
check(#purchases == 3, "spending cap persists across bag updates")
addon.db.restock.maxGold=5; money=10000
fire("MERCHANT_SHOW")
check(#purchases == 3, "gold reserve is retained")
money=100000; free=0
fire("MERCHANT_SHOW")
check(#purchases == 3, "full bags stop purchases")
C_Container.GetContainerNumSlots = function(bag) return bag == 0 and 1 or 0 end
C_Container.GetContainerItemInfo = function() return {itemID=17031,stackCount=18,isLocked=false} end
addon.db.restock.targets[17031]=20; inventory[17031]=18
fire("MERCHANT_SHOW")
check(purchases[#purchases].amount == 2, "existing partial stacks can be filled without empty slots")
free=1; C_Container.GetContainerNumSlots=function() return 0 end
inventory[17031]=0; extended=true
fire("MERCHANT_SHOW")
check(#purchases == 4, "special-currency purchases are skipped")
extended=false; price=secretNumber()
fire("MERCHANT_SHOW")
check(#purchases == 4, "protected merchant prices cannot trigger a purchase")
price=100; stock=3
fire("MERCHANT_SHOW")
check(purchases[#purchases].amount == 3, "limited vendor stock caps item quantity")
stock=-1; combat=true
fire("MERCHANT_SHOW")
check(#purchases == 5, "combat prevents vendor automation")
combat=false
inventory[17031]=0
fire("MERCHANT_SHOW")
local count = #purchases
stamp=stamp+4; fire("MERCHANT_UPDATE")
check(addon.restockVisit.stopped and #purchases == count, "unconfirmed or rejected purchase stops the visit rather than retrying")
inventory[17031]=0; money=1500
addon.db.restock.keepGold=0.1
fire("MERCHANT_SHOW")
local reserveCount=#purchases
check(purchases[reserveCount].amount == 5, "gold reserve caps first purchase against starting balance")
inventory[17031]=5
fire("BAG_UPDATE_DELAYED")
check(#purchases == reserveCount, "stale money information cannot spend the gold reserve after a bag confirmation")
io.write("Passed ",checks," customization, speech, timer, and restocking checks.\n")
