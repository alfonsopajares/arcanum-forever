local checks = 0
local function check(value, message) assert(value, message); checks = checks + 1 end
combat = false; known[1459] = true; known[168] = true
addon.db.visible = true
addon.db.reminders.enabled = true; addon.db.reminders.groupOnly = false; addon.db.reminders.hideInCombat = false
addon.db.reminders.intellect = true; addon.db.reminders.armor = true
local active, ordinary = false, false
spellNames[1307251] = "Incense Candle"
C_UnitAuras = {
    GetPlayerAuraBySpellID = function(id)
        if (ordinary and id == 1459) or (active and id == 1229741) then return {} end
    end,
    GetAuraDataByIndex = function(unit, index, filter)
        assert(unit == "player" and filter == "HELPFUL")
        if active and index == 1 then return {name="Camp Benefits", spellId=1229741} end
    end,
}
local campText = "Incense Candle: Intellect increased by 2.\n\nFaction Banner: Spirit increased by 14."
C_TooltipInfo = {GetUnitBuff = function(unit, index)
    assert(unit == "player" and index == 1)
    return {lines={{leftText="Camp Benefits"}, {leftText=campText}}}
end}
addon:UpdateReminders()
check(addon.reminderGlows.buffs:IsShown(), "missing Intellect warns without camp benefit")
active = true; addon:UpdateReminders()
check(not addon.reminderGlows.buffs:IsShown(), "live Forever combined camp tooltip clears missing Intellect")
check(not addon.buffReminderText.text:find("Arcane Intellect missing", 1, true), "Candle clears prominent Intellect text")
check(addon.reminderGlows.armor:IsShown(), "Candle does not suppress missing armor")
active = false; addon:UpdateReminders()
check(addon.reminderGlows.buffs:IsShown(), "Intellect reminder returns when camp expires")
ordinary = true; addon:UpdateReminders()
check(not addon.reminderGlows.buffs:IsShown(), "ordinary Intellect still satisfies reminder")
ordinary = false; active = true
campText = "Faction Banner: Spirit increased by 14."
addon:UpdateReminders()
check(addon.reminderGlows.buffs:IsShown(), "camp without Candle retains Intellect reminder")
spellNames[1307251] = "Localized Candle"
campText = "Localized Candle: Intellect increased by 2."
check(addon:HasIncenseIntellect() == true, "combined benefit uses localized Candle name")
campText = secretNumber()
check(addon:HasIncenseIntellect() == nil, "protected camp tooltip remains unknown")
C_TooltipInfo.GetUnitBuff = function() error("restricted tooltip") end
check(addon:HasIncenseIntellect() == nil, "restricted camp tooltip remains unknown")
C_TooltipInfo = nil
check(addon:HasIncenseIntellect() == nil, "unavailable camp tooltip remains unknown")
C_UnitAuras.GetAuraDataByIndex = function() return secretNumber() end
check(addon:HasIncenseIntellect() == nil, "protected aura remains unknown without unsafe indexing")
C_UnitAuras.GetAuraDataByIndex = function() error("restricted") end
check(addon:HasIncenseIntellect() == nil, "restricted scan remains unknown")
C_UnitAuras.GetAuraDataByIndex = nil
check(addon:HasIncenseIntellect() == nil, "unavailable aura API remains unknown")
io.write("Passed ", checks, " Incense Candle reminder checks.\n")
