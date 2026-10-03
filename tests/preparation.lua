local checks = 0
local function check(value, message) assert(value, message); checks = checks + 1 end
local clockTime = 100
GetTime = function() return clockTime end
local party, raid, buffs = 0, false, {}
IsInRaid = function() return raid end
GetNumGroupMembers = function() return raid and party + 1 or party + 1 end
GetNumSubgroupMembers = function() return party end
UnitGUID = function(unit) return unit == "player" and "player-guid" or unit == "raid1" and "player-guid" or unit == "NPC" and "party1-guid" or unit .. "-guid" end
UnitName = function(unit) return unit == "NPC" and "Priest" or unit == "player" and "Mage" or unit == "party1" and "Priest" or "Rogue" end
UnitClass = function(unit) return "Class", (unit == "party1" or unit == "NPC" or unit == "raid2") and "PRIEST" or (unit == "player" or unit == "raid1") and "MAGE" or "ROGUE" end
C_UnitAuras = {GetAuraDataByIndex=function(_, index) return buffs[index] end}
ERR_TRADE_COMPLETE = "Trade complete."
addon.db.reminders = {}
addon:MergeDefaults(addon.db.reminders, addon.defaults.reminders)
addon.db.preparation.profile = "auto"
check(addon:ActiveProfile() == "solo", "automatic preparation selects solo outside a group")
party = 2
check(addon:ActiveProfile() == "party", "automatic preparation selects party")
raid = true
check(addon:ActiveProfile() == "raid", "automatic preparation selects raid")
check(#addon:GroupMembers() == 2, "raid supply estimate excludes yourself")
raid = false
addon.db.vending.reserveFood, addon.db.vending.reserveWater = 10, 20
local estimate = addon:EstimateSupplies()
check(estimate.food == 50 and estimate.water == 60, "group estimate adds class presets and personal reserves")
addon.distribution["party1-guid"] = {name="Priest", class="PRIEST", food=10, water=20, time=clockTime}
estimate = addon:EstimateSupplies()
check(estimate.food == 40 and estimate.water == 40, "group estimate subtracts actual recent deliveries")
addon:SetTargetsFromGroup()
check(addon.db.preparation.profiles.party.food == 40 and addon.db.preparation.profiles.party.water == 40, "group estimate can become preparation targets")
check(addon.db.vending.presets.PRIEST.water == 40, "preparation targets do not change vending quantities")
addon.db.preparation.trackTrades = false
estimate = addon:EstimateSupplies()
check(estimate.food == 50 and estimate.water == 60, "disabling distribution ignores past deliveries in estimates")
addon.db.preparation.trackTrades = true
clockTime = clockTime + 1801
addon:PruneDistribution()
check(next(addon.distribution) == nil, "delivery history expires after configured time")

local savedOffer = addon.TradeOffer
addon.TradeOffer = function() return {food=20, water=40} end
addon.trade = {open=true, key="party1-guid", name="Priest", class="PRIEST"}
addon:DistributionEvent("TRADE_ACCEPT_UPDATE", 1)
check(next(addon.distribution) == nil, "accepting a trade does not record a delivery")
addon:DistributionEvent("TRADE_CLOSED")
addon:DistributionEvent("UI_INFO_MESSAGE", 0, ERR_TRADE_COMPLETE)
check(addon.distribution["party1-guid"].water == 40, "completed trade records actual food and water after close")
addon:DistributionEvent("UI_INFO_MESSAGE", 0, ERR_TRADE_COMPLETE)
check(addon.distribution["party1-guid"].water == 40, "repeated success message cannot duplicate delivery")
addon:ResetDistribution()
addon:DistributionEvent("TRADE_ACCEPT_UPDATE", 1)
addon:DistributionEvent("TRADE_ACCEPT_UPDATE", 0)
addon:DistributionEvent("UI_INFO_MESSAGE", 0, ERR_TRADE_COMPLETE)
check(next(addon.distribution) == nil, "revoked acceptance cannot record a delivery")
addon:DistributionEvent("TRADE_ACCEPT_UPDATE", 1)
addon:DistributionEvent("TRADE_CLOSED")
clockTime = clockTime + 6
addon:DistributionEvent("UI_INFO_MESSAGE", 0, ERR_TRADE_COMPLETE)
check(next(addon.distribution) == nil, "late unrelated success message cannot record a cancelled trade")
addon:DistributionEvent("TRADE_ACCEPT_UPDATE", 1)
addon:DistributionEvent("TRADE_PLAYER_ITEM_CHANGED")
addon:DistributionEvent("UI_INFO_MESSAGE", 0, ERR_TRADE_COMPLETE)
check(next(addon.distribution) == nil, "changed offer invalidates the accepted delivery snapshot")
addon:DistributionEvent("TRADE_ACCEPT_UPDATE", 1)
addon:DistributionEvent("TRADE_SHOW")
addon:DistributionEvent("UI_INFO_MESSAGE", 0, ERR_TRADE_COMPLETE)
check(next(addon.distribution) == nil, "new trade clears stale accepted snapshot")
addon.TradeOffer = savedOffer
addon.trade.open = false

known[168], known[1459], known[759], known[3552], known[3561] = true, true, true, false, true
inventory[5514], inventory[5513], inventory[5350], inventory[2288], inventory[1113], inventory[5349], inventory[17031] = 0, 0, 0, 0, 0, 0, 0
buffs = {}
addon:UpdateReminders()
check(addon.reminderGlow:IsShown() and addon.reminderGlows.armor:IsShown() and addon.reminderGlows.buffs:IsShown(), "missing learned armor and intellect get visual reminders")
check(addon.reminderGlows.mana:IsShown() and addon.reminderGlows.teleports:IsShown(), "missing learned gem and low learned-spell reagents get reminders")
check(addon.reminderGlows.refreshments:IsShown(), "low food and water stock get reminders")
buffs = {{spellId=168},{spellId=1459}}
inventory[5514], inventory[5350], inventory[1113], inventory[17031] = 1, 40, 20, 5
addon:UpdateReminders()
check(not addon.reminderGlow:IsShown(), "reminders clear when buffs and stock are restored")
buffs = {{spellId=secretNumber()}}
inventory[5350] = 0
addon:UpdateReminders()
check(not addon.reminderGlows.armor:IsShown() and not addon.reminderGlows.buffs:IsShown(), "secret buff fields suppress missing-buff reminders")
local directBuffs = {}
C_UnitAuras.GetPlayerAuraBySpellID = function(id) return directBuffs[id] end
addon:UpdateReminders()
check(addon.reminderGlows.armor:IsShown() and addon.reminderGlows.buffs:IsShown(), "direct buff queries detect missing armor and Intellect despite unrelated secret auras")
check(addon.buffReminderFrame:IsShown() and addon.buffReminderText.text:find("Frost Armor missing",1,true)
    and addon.buffReminderText.text:find("Arcane Intellect missing",1,true), "missing buffs have visible named reminders without hovering")
check(addon.buffReminderFrame.template == "BackdropTemplate" and addon.buffReminderFrame.height == 86
    and addon.buffReminderFrame.parent == UIParent, "missing buffs use a framed alert sized for two readable lines and safe to update in combat")
directBuffs[168], directBuffs[1459] = {spellId=secretNumber()}, {spellId=secretNumber()}
addon:UpdateReminders()
check(not addon.buffReminderFrame:IsShown() and not addon.reminderGlows.buffs:IsShown(), "present buffs clear reminders without reading protected aura fields")
C_UnitAuras.GetPlayerAuraBySpellID = function(id) if id == 168 then error("restricted aura") end end
addon:UpdateReminders()
check(not addon.reminderGlows.armor:IsShown() and addon.reminderGlows.buffs:IsShown(), "unavailable armor lookup does not suppress a readable Intellect reminder")
C_UnitAuras.GetPlayerAuraBySpellID = function(id) if id == 168 then return secretNumber() end end
addon:UpdateReminders()
check(not addon.reminderGlows.armor:IsShown(), "secret direct aura result is unknown rather than treated as missing")
C_UnitAuras.GetPlayerAuraBySpellID = nil
addon:UpdateReminders()
check(addon.reminderGlows.refreshments:IsShown(), "unknown buffs do not suppress readable supply reminders")
addon.db.reminders.enabled = false
addon:UpdateReminders()
check(not addon.reminderGlow:IsShown() and not addon.reminderGlows.refreshments:IsShown(), "master off switch clears every reminder")
check(not addon.buffReminderFrame:IsShown(), "master switch also hides visible buff reminder text")
addon.db.reminders.enabled = true
addon.db.reminders.water = false
addon:UpdateReminders()
check(not addon.reminderGlows.refreshments:IsShown(), "individual water reminder can be turned off")
addon.db.reminders.water = true
combat = true
addon:UpdateReminders()
check(not addon.reminderGlow:IsShown(), "combat hides reminders by default")
addon.db.reminders.hideInCombat = false
addon:UpdateReminders()
check(addon.reminderGlows.refreshments:IsShown(), "reminders can be enabled during combat without secure mutations")
addon.db.reminders.enabled = false
addon:SettingsChanged()
check(not addon.reminderGlow:IsShown(), "master off switch works immediately during combat")
combat = false
addon.db.reminders.enabled, addon.db.reminders.groupOnly = true, true
party = 0
addon:UpdateReminders()
check(not addon.reminderGlow:IsShown(), "group-only reminders remain quiet while solo")
addon.db.reminders.groupOnly = false
known[759] = false
addon:UpdateReminders()
check(not addon.reminderGlows.mana:IsShown(), "unlearned gem abilities never trigger missing-gem warning")

inventory[5350], inventory[2288], inventory[5349], inventory[1113] = 3, 20, 4, 20
known[5505], known[597], known[759], known[12051] = true, true, true, true
inventory[5514] = 1
addon.db.centerAction = "gem"
addon:ApplySettings()
local macro = addon.keyButtons.EatDrink:GetAttribute("macrotext1")
check(macro:find("/use [nocombat] item:1113", 1, true) and macro:find("/use [nocombat] item:2288", 1, true), "eat and drink uses best carried learned ranks in one secure macro")
check(addon.keyButtons.EatDrink:GetAttribute("macrotext1") == macro, "eat-and-drink keybinding uses same secure action")
check(addon.keyButtons.Orb:GetAttribute("item1") == "item:5514" and addon.keyButtons.Evocation:GetAttribute("spell1") == 12051, "orb and Evocation bindings match current learned actions")
check(addon.keyButtons.Blink:GetAttribute("type1") == "", "unlearned utility bindings stay unassigned")
known[1953] = true
fire("SPELLS_CHANGED")
check(addon.keyButtons.Blink:GetAttribute("spell1") == 1953, "learning Blink enables its binding")
combat = true
inventory[2288] = 0
addon:RefreshActions()
check(addon.keyButtons.EatDrink:GetAttribute("macrotext1") == macro, "eat-and-drink macro remains frozen during combat")
combat = false
fire("PLAYER_REGEN_ENABLED")
check(addon.keyButtons.EatDrink:GetAttribute("macrotext1"):find("item:5350", 1, true), "eat-and-drink action refreshes after combat")
check(addon.centerCooldown.start == 12 and addon.centerCooldown.duration == 120, "gem cooldown uses native cooldown widget")
addon.db.centerCooldown = false
addon:UpdateActionDisplays()
check(addon.centerCooldown.start == nil, "orb cooldown ring can be disabled")
addon.db.centerCooldown = true
addon.db.centerAction = "water"
addon:ApplySettings()
check(addon.centerCooldown.start == nil, "water display has no mana-recovery cooldown ring")
C_Spell.GetSpellCooldownDuration = function() return {secret=true} end
addon.db.centerAction = "evocation"
addon:ApplySettings()
check(addon.centerCooldown.durationObject.secret, "Evocation duration object passes straight to native widget")
addon:ApplySettings()
check(not addon.eatDrinkButton and addon.db.preparation.showEatDrink == nil, "separate consumption button and obsolete setting are removed")
addon:OpenSettings("Distribution")
check(addon.settings.pages.Distribution:IsShown() and addon.settings.distributionText.text, "distribution list is available in settings")
addon:OpenSettings("Reminders")
check(addon.settings.pages.Reminders:IsShown(), "reminder settings are available")
io.write("Passed ", checks, " preparation/reminder/binding checks using the real addon Lua.\n")
