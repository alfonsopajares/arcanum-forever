local checks = 0
local function check(condition, message)
    assert(condition, message)
    checks = checks + 1
end

local auras, cooldown, queried = {}, {isEnabled=true, duration=0}, nil
C_UnitAuras = {GetPlayerAuraBySpellID=function(id) return auras[id] end}
C_Spell.GetSpellCooldown = function(id)
    queried = id
    return cooldown
end
spellNames[11426], spellNames[13033] = "Ice Barrier", "Ice Barrier"
fire("ADDON_LOADED", "Arcanum")
fire("PLAYER_ENTERING_WORLD")
addon:OpenSettings("Reminders")
local options = addon.db.reminders
check(options.iceBarrier and not options.iceBarrierShield, "Frigid Power upkeep defaults on and shield upkeep defaults off")
check(not addon.settings.iceBarrierOptions:IsShown() and not addon.buffReminderFrame:IsShown(),
    "mages who do not know Ice Barrier have no reminder or related settings")

known[11426], known[13033] = true, true
fire("SPELLS_CHANGED")
check(addon.settings.iceBarrierOptions:IsShown(), "learning Ice Barrier exposes its reminder settings")
check(addon.reminderGlows.defenses:IsShown() and addon.buffReminderText.text == "Refresh Ice Barrier" and queried == 13033,
    "missing Frigid Power prompts a refresh using the highest known rank's cooldown")

auras[1326891] = {}
fire("UNIT_AURA", "player")
check(not addon.buffReminderFrame:IsShown(), "Frigid Power satisfies the default reminder even after the shield breaks")
options.iceBarrierShield = true
addon:UpdateReminders()
check(addon.buffReminderText.text == "Ice Barrier shield missing", "the optional shield reminder detects a broken shield")
auras[11426] = {}
fire("UNIT_AURA", "player")
check(not addon.buffReminderFrame:IsShown(), "an active lower-rank shield satisfies the shield option")

auras, cooldown = {}, {isEnabled=true, duration=30}
fire("UNIT_AURA", "player")
check(not addon.buffReminderFrame:IsShown(), "a missing buff does not alert while Barrier is on cooldown")
cooldown = {isEnabled=true, duration=0}
addon.preparationTicker.scripts.OnUpdate(addon.preparationTicker, 2)
check(addon.buffReminderText.text == "Refresh Ice Barrier", "the reminder returns when the cooldown ends without an aura event")

cooldown = {isEnabled=true, duration=secretNumber()}
addon:UpdateReminders()
check(not addon.buffReminderFrame:IsShown(), "protected cooldown data does not produce an alert")
cooldown = {isEnabled=true, duration=0}
auras[1326891], auras[11426] = secretNumber(), secretNumber()
addon:UpdateReminders()
check(not addon.buffReminderFrame:IsShown(), "protected aura data does not count as missing")

auras = {}
options.iceBarrier, options.iceBarrierShield = false, false
addon:UpdateReminders()
check(not addon.buffReminderFrame:IsShown(), "both Ice Barrier alerts can be disabled")
options.iceBarrier = true
combat = true
fire("PLAYER_REGEN_DISABLED")
check(not addon.buffReminderFrame:IsShown(), "Ice Barrier respects the hide-in-combat reminder setting")
combat = false
fire("PLAYER_REGEN_ENABLED")
check(addon.buffReminderFrame:IsShown(), "the alert resumes after combat")

known[11426], known[13033] = nil, nil
fire("SPELLS_CHANGED")
check(not addon.settings.iceBarrierOptions:IsShown() and not addon.buffReminderFrame:IsShown(),
    "unlearning the spell hides the alert and settings")
io.write("Passed ", checks, " Ice Barrier reminder checks.\n")
