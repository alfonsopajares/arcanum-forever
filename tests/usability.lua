local checks = 0
local function check(value, message) assert(value, message); checks = checks + 1 end

-- Prepare chooses only learned actions, advances after bag refreshes, and clears
-- both visible and keyboard secure actions when the targets are met.
known, inventory, spellBook = {[759]=true,[5504]=true,[587]=true,[1459]=true,[168]=true}, {}, {}
addon.db.preparation.profile = "solo"
addon.db.preparation.profiles.solo = {food=20,water=40}
addon:RefreshActions()
check(addon.prepareAction.id == 759, "preparation begins with a learned missing gem")
check(addon.prepareButton:GetAttribute("macrotext1") == "/cast [nocombat] Conjure Mana Agate", "prepare performs one safe cast per click")
check(addon.keyButtons.Prepare:GetAttribute("macrotext1") == addon.prepareButton:GetAttribute("macrotext1"), "prepare binding matches the visible button")
inventory[5514] = 1
fire("BAG_UPDATE_DELAYED")
check(addon.prepareAction.id == 5504, "gem inventory update advances preparation to water")
inventory[5350] = 40
fire("BAG_UPDATE_DELAYED")
check(addon.prepareAction.id == 587, "water target advances preparation to food")
inventory[5349] = 20
fire("BAG_UPDATE_DELAYED")
check(not addon.prepareAction and addon.prepareButton.text == "Prepared!", "preparation stops once stocked")
local onlyConjures = true
for _, row in ipairs(addon.menus.refreshments.rows) do
    if row.action and row.action.kind == "item" then onlyConjures = false end
end
check(onlyConjures, "food and water use icons are absent from the refreshments flyout")
local eatDrink = addon.keyButtons.EatDrink:GetAttribute("macrotext1")
check(eatDrink:find("item:5349",1,true) and eatDrink:find("item:5350",1,true), "dedicated Eat + Drink button retains food and water use")
check(not addon.vendingButton and addon.settings.pages.Vending and type(addon.FillTrade) == "function", "only the circle vending shortcut is removed; settings and trade helper remain")
check(addon.prepareButton:GetAttribute("type1") == "" and addon.keyButtons.Prepare:GetAttribute("macrotext1") == nil, "stocked prepare controls have no stale cast")
inventory[5350] = 0
known[5504] = nil
addon:RefreshActions()
check(not addon.prepareAction and addon.prepareButton.text == "Prepare: unavailable", "unlearned conjure spell is never offered")
known[5504] = true
addon:RefreshActions()
local previous = addon.prepareButton:GetAttribute("macrotext1")
combat = true
inventory[5350] = 40
addon:RefreshActions()
check(addon.prepareButton:GetAttribute("macrotext1") == previous, "preparation attributes remain frozen in combat")
combat = false
fire("PLAYER_REGEN_ENABLED")
check(addon.prepareButton:GetAttribute("type1") == "", "preparation catches up after combat")
check(addon.keyButtons.Intellect:GetAttribute("spell1") == 1459 and addon.keyButtons.Intellect:GetAttribute("unit1") == "player", "intellect shortcut targets yourself")
check(addon.keyButtons.Armor:GetAttribute("spell1") == 168, "armor shortcut uses a learned armor spell")

-- Selection lists expose all choices and choose the clicked entry, rather than
-- silently cycling through values. Exercise both client API paths.
local control = addon.settings.choices["Orb action and center display"]
control.scripts.OnClick()
check(control.menu:IsShown() and #control.menu.rows == 3, "fallback dropdown exposes all orb actions")
control.menu.rows[3].scripts.OnClick()
check(addon.db.centerAction == "eatdrink" and not control.menu:IsShown(), "dropdown selects combined food/water mode and closes")
UIDropDownMenu_Initialize = function(frame, fn) frame.initialize = fn end
UIDropDownMenu_CreateInfo = function() return {} end
local entries = {}
UIDropDownMenu_AddButton = function(info) entries[#entries+1] = info end
UIDropDownMenu_SetWidth = function(frame, width) frame.dropdownWidth = width end
UIDropDownMenu_SetText = function(frame, value) frame.caption = value end
addon:CreateSettings()
control = addon.settings.choices["Orb action and center display"]
control.initialize(control, 1)
check(#entries == 3 and entries[3].checked, "native dropdown exposes and checks the saved choice")
entries[2].func()
check(addon.db.centerAction == "evocation" and control.caption == "Evocation", "native dropdown selects the clicked option")

-- Saved character records persist independently of session uptime. Copying
-- settings must not copy another mage's delivery history or alias its tables.
local epoch, guid = 100000, "mage-A"
GetServerTime = function() return epoch end
GetTime = function() return 0 end
UnitGUID = function() return guid end
UnitName = function() return guid end
GetRealmName = function() return "Test Realm" end
ArcanumDB = {scale=135,centerAction="water",vending={reserveFood=12}}
addon:InitializeSettings()
check(ArcanumDB.schemaVersion == 2 and addon.db.scale == 135 and addon.db.vending.reserveFood == 12, "legacy settings migrate without losing saved preferences")
local a = addon.character
a.distribution.recipient = {food=20,water=40,time=epoch,name="Recipient"}
addon:InitializeSettings()
check(addon.distribution.recipient.water == 40 and addon.distribution == a.distribution, "history survives reload when session uptime resets")
guid = "mage-B"
addon:InitializeSettings()
check(addon.db.scale == 100 and not addon.distribution.recipient, "second mage starts with independent defaults and history")
addon.distribution.own = {food=5,water=0,time=epoch,name="Own recipient"}
local ownHistory = addon.distribution
combat = true
check(addon:CopyCharacterSettings("mage-A") and addon.settingsPending, "copying settings during combat saves and defers secure changes")
check(addon.distribution == ownHistory and addon.distribution.own and not addon.distribution.recipient, "copying settings preserves destination history")
addon.db.vending.reserveFood = 19
check(a.settings.vending.reserveFood == 12, "copied nested settings do not alias the source mage")
combat = false
fire("PLAYER_REGEN_ENABLED")
check(addon.frame.scale == 1.35 and not addon.positionPending, "copied appearance applies when combat ends")
check(not addon:CopyCharacterSettings("mage-B"), "copying from self is rejected")
epoch = epoch + 1801
guid = "mage-A"
addon:InitializeSettings()
check(next(addon.distribution) == nil, "persisted delivery history expires by wall-clock time")
addon.distribution.bad = {time="invalid"}
addon:PruneDistribution()
check(not addon.distribution.bad, "malformed saved history is discarded safely")
addon:ResetDistribution()
check(addon.distribution == addon.character.distribution, "reset replaces the persisted history reference")

addon:DebugLog("ignored", "disabled")
check(#addon.character.log == 0, "diagnostic logging is off by default")
addon.db.debugLogging = true
for index=1,205 do addon:DebugLog("Test", tostring(index)) end
check(#addon.character.log == 200 and addon.character.log[1].detail == "6", "diagnostic log retains only the latest 200 entries")
addon:InitializeSettings()
check(#addon.character.log == 200, "diagnostic log survives reload")
addon:ClearDebugLog()
check(#addon.character.log == 0, "diagnostic log can be cleared")

-- Read-only trade previews never move inventory and provide disabled reasons.
addon.TradeOffer = function() return {food=20,water=0}, {2}, {[1]={id=5349,count=20}} end
addon.SupplyStacks = function(_,kind) return {{id=kind=="food" and 5349 or 5350,count=20}}, 20 end
addon.trade = {open=true,targets={food=20,water=40},owned={},name="Recipient"}
addon.db.vending.reserveWater = 1
check(addon:TradeControlReason("water") ~= nil, "full stack button explains that the reserve prevents offering it")
addon.db.vending.reserveWater = 0
check(addon:TradeControlReason("water") == nil, "full stack button enables when the reserve permits it")
check(addon:TradeControlReason("fill") == nil, "preset fill permits useful partial progress")
check(addon:TradeControlReason("clear") ~= nil, "clear button disables when no owned supplies exist")
addon.trade.owned[1] = {id=5349,count=20}
check(addon:TradeControlReason("clear") == nil, "clear enables for matching owned supplies")
addon.trade.job = {}
check(addon:TradeControlReason("fill"):find("Waiting"), "active inventory move disables new actions")
addon.trade.job = nil
addon:UpdateTradeUI()
check(addon.tradeUI.status.text:find("40 needed",1,true) and addon.tradeUI.status.text:find("Keep for yourself",1,true), "trade preview shows deficits and personal reserves")
combat = true
addon:UpdateTradeUI()
check(not addon.tradeUI.buttons.water.enabled and addon.tradeUI.reasons.water.text:find("combat"), "disabled trade control displays its combat reason")
combat = false
io.write("Passed ", checks, " preparation workflow, dropdown, persistence, and trade feedback checks.\n")
