local checks = 0
local function check(value, message) assert(value, message); checks = checks + 1 end
local exists, hostile, dead, aura = true, true, false, nil
UnitExists = function() return exists end
UnitCanAttack = function() return hostile end
UnitIsDeadOrGhost = function() return dead end
spellNames[12654] = "Ignite"
C_UnitAuras.GetUnitAuraBySpellID = function(unit,id)
    assert(unit == "target" and id == 12654)
    return aura
end
addon.db.showIgnite = true
addon:CreateIgniteDisplay()
local hud = addon.igniteDisplay
check(not hud:IsShown(), "Ignite display is hidden without the debuff")
check(hud.parent == UIParent and hud.point[1] == "CENTER" and hud.point[5] == -110,
    "Ignite is positioned centrally and independently of the circle")
check(hud.count.fontSize == 42, "Ignite stack count uses prominent outlined text")
aura = {spellId=12654,applications=3,sourceUnit="party1"}
fire("UNIT_AURA", "target")
check(hud:IsShown() and hud.count.values[1] == 3, "target aura event displays another mage's Ignite stacks")
aura.applications = 5
hud.scripts.OnUpdate(hud,0.2)
check(hud.count.values[1] == 5, "visible stack count refreshes promptly")
local secret = secretNumber()
aura.applications = secret
combat = true
fire("UNIT_AURA", "target")
check(hud:IsShown() and hud.count.values[1] == secret, "protected stacks pass untouched to native formatter during combat")
addon.db.showIgnite = false
addon:SettingsChanged()
check(not hud:IsShown(), "Ignite option disables the HUD immediately during combat")
combat = false
addon.db.showIgnite = true
aura.applications = 4
addon.db.visible = false
addon:UpdateIgniteDisplay()
check(hud:IsShown(), "Ignite remains independent of circle visibility")
hostile = false
fire("UNIT_FLAGS","target")
check(not hud:IsShown(), "friendly targets hide Ignite")
hostile, dead = true, true
fire("UNIT_HEALTH","target")
check(not hud:IsShown(), "dead target hides Ignite")
dead, exists = false, false
fire("PLAYER_TARGET_CHANGED")
check(not hud:IsShown(), "clearing target hides Ignite")
exists = true
aura = nil
fire("PLAYER_TARGET_CHANGED")
check(not hud:IsShown(), "changing to a target without Ignite clears the old counter")
aura = {applications=0}
addon:UpdateIgniteDisplay()
check(hud.count.values[1] == 1, "present non-stacking aura count displays one rather than zero")
aura = {}
addon:UpdateIgniteDisplay()
check(hud:IsShown() and hud.count.text == "?", "aura without a readable count displays unknown instead of inventing stacks")
C_UnitAuras.GetUnitAuraBySpellID = function() error("restricted") end
C_UnitAuras.GetAuraDataBySpellName = function(unit,name,filter)
    assert(unit == "target" and name == "Ignite" and filter == "HARMFUL")
    return {applications=2}
end
addon:UpdateIgniteDisplay()
check(hud:IsShown() and hud.count.values[1] == 2, "localized native name query is a fallback for restricted ID lookup")
C_UnitAuras.GetAuraDataBySpellName = nil
C_UnitAuras.GetAuraDataByIndex = function(_,index,filter)
    assert(filter == "HARMFUL")
    if index == 1 then return {spellId=secretNumber(),name=secretNumber()} end
    if index == 2 then return {spellId=12654,applications=4} end
end
addon:UpdateIgniteDisplay()
check(hud:IsShown() and hud.count.values[1] == 4, "fallback scan skips unrelated protected auras to find readable Ignite")
C_UnitAuras.GetAuraDataByIndex = function() error("restricted") end
addon:UpdateIgniteDisplay()
check(not hud:IsShown() and addon.igniteUnavailable, "unavailable aura data hides the HUD rather than showing a false count")
C_UnitAuras.GetUnitAuraBySpellID = function() return secretNumber() end
addon:UpdateIgniteDisplay()
check(not hud:IsShown(), "secret aura object is never indexed or interpreted")
C_UnitAuras = nil
UnitDebuff = function(_,index)
    if index == 1 then return "Ignite",nil,2,nil,nil,nil,nil,nil,nil,12654 end
end
addon:UpdateIgniteDisplay()
check(hud:IsShown() and hud.count.values[1] == 2, "legacy debuff API can provide actual Ignite stacks")
UnitExists = function() return secretNumber() end
addon:UpdateIgniteDisplay()
check(not hud:IsShown(), "protected target validity cannot trigger arithmetic or unsafe comparisons")
io.write("Passed ",checks," Ignite display checks.\n")
