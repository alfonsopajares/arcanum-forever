local checks = 0
local function check(condition, message)
    assert(condition, message)
    checks = checks + 1
end
known[1459], known[1460], known[168], known[5504], known[587], known[118] = true, true, true, true, true, true
inventory[5350] = 6
fire("ADDON_LOADED", "Arcanum")
check(SLASH_ARCANUM1 == "/arc", "primary command is /arc")
check(#messages == 1 and messages[1]:find("v" .. testAddonVersion, 1, true)
    and messages[1]:find("/arc for options", 1, true)
    and messages[1]:find("/arc toggle", 1, true), "login prints manifest version and command reminder")
fire("PLAYER_ENTERING_WORLD")
fire("PLAYER_ENTERING_WORLD")
check(#messages == 1, "zone transitions do not repeat the load reminder")
check(addon.frame ~= nil, "login initializes the UI")
check(addon.manaBar.value == manaCurrent and addon.manaBar.maximum == manaMaximum, "secret mana passes directly to the bar")
check(addon.manaText.values[1] == 0 and addon.centerLabel.text == "Mana Gem", "gem mode shows zero gems even when water is carried")
check(addon.sphere:GetAttribute("type1") == "" and addon.sphere:GetAttribute("item1") == nil, "mana gem never falls back to water")
check(addon.sphere:GetAttribute("shift-type1") == "" and addon.sphere:GetAttribute("shift-spell1") == nil, "unlearned Evocation is an explicit no-op without falling back to water")
check(addon.sphere.template == "SecureActionButtonTemplate" and addon.sphere.hooks.OnClick and not addon.sphere.scripts.OnClick,
    "orb actions preserve Blizzard's secure click handler")
check(addon.sphere:GetAttribute("*type2") == "", "right-click has no spell or item action")
check(addon.toggles.buffs:IsShown() and not addon.toggles.portals:IsShown(), "empty categories stay hidden")
local buffs = addon.menus.buffs.rows
check(#buffs == 1 and buffs[1].action.id == 1460, "highest learned rank selected; unlearned buffs excluded")
check(buffs[1]:GetAttribute("type") == "spell" and buffs[1]:GetAttribute("spell") == 1460, "secure spell action configured")
check(buffs[1]:GetAttribute("unit2") == "player", "right-click friendly spells targets self")
local refreshments = addon.menus.refreshments.rows
check(#refreshments == 2, "refreshments flyout contains learned conjures without duplicate drinking")
check(refreshments[2]:GetAttribute("type") == "spell" and refreshments[2]:GetAttribute("spell") == 587, "food conjuring remains configured")
check(refreshments[1].count.values[1] == 6, "carried water count remains on conjure action")
check(not addon.toggles.defenses:IsShown() and not addon.toggles.mana:IsShown(), "unlearned talent defenses and gems are absent")
known[3561] = true
fire("SPELLS_CHANGED")
check(addon.toggles.teleports:IsShown(), "learning a travel spell reveals its category")
check(addon.menus.teleports.rows[1].action.id == 3561 and #addon.menus.teleports.rows == 1, "only learned destination appears")
spellNames[999001] = "Arcane Intellect"
known[999001] = true
spellBook = {1459,1460,999001}
fire("SPELLS_CHANGED")
check(addon.menus.buffs.rows[1].action.id == 999001, "additional learned Forever rank discovered from spellbook")
known[999001] = false
fire("SPELLS_CHANGED")
check(addon.menus.buffs.rows[1].action.id == 1460, "unlearned spellbook entry is excluded")
known[7300] = secretNumber()
fire("SPELLS_CHANGED")
check(addon.menus.armor.rows[1].action.id == 168, "secret knowledge result is never treated as learned")
combat = true
known[2139] = true
inventory[5350] = 0
fire("BAG_UPDATE_DELAYED")
fire("SPELLS_CHANGED")
check(addon.refreshPending and refreshments[1].action.id == 5504, "secure attributes remain frozen during combat")
secureClick(addon.toggles.buffs)
check(addon.menus.buffs:IsShown(), "secure category opens during combat")
secureClick(addon.toggles.utility)
check(addon.menus.utility:IsShown() and not addon.menus.buffs:IsShown(), "secure toggles close other menus during combat")
secureClick(addon.toggles.utility)
check(not addon.menus.utility:IsShown(), "secure category closes during combat")
local visible = addon.db.visible
addon:HandleCommand("toggle")
check(addon.db.visible == visible, "layout command does not mutate protected frames in combat")
addon:UpdateMana()
addon:UpdateActionDisplays()
combat = false
fire("PLAYER_REGEN_ENABLED")
check(not addon.refreshPending and addon.menus.utility.rows[2].action.id == 2139, "deferred learned spell appears after combat")
check(refreshments[2].action.id == 587 and #refreshments == 2, "bag updates keep drinking out of the flyout")
UnitPowerPercent = nil
addon.db.centerAction = "evocation"
addon:ApplySettings()
addon:UpdateMana()
check(addon.manaText.format == "%d" and addon.manaText.values[1] == manaCurrent and addon.centerLabel.text == "Evocation", "Evocation displays protected current mana through native formatter")
addon.db.centerAction = "gem"
addon:ApplySettings()
known[5505] = true
inventory[5350], inventory[2288] = 2, 4
fire("BAG_UPDATE_DELAYED")
check(refreshments[1].action.id == 5505 and addon.keyButtons.EatDrink:GetAttribute("macrotext1"):find("item:2288",1,true), "conjure and drink button prefer highest known available rank")
inventory[2288] = 0
fire("BAG_UPDATE_DELAYED")
check(addon.keyButtons.EatDrink:GetAttribute("macrotext1"):find("item:5350",1,true), "drink button falls back to carried lower rank")
known[759], inventory[5514] = true, 1
fire("SPELLS_CHANGED")
check(#addon.menus.mana.rows == 2 and addon.menus.mana.rows[2].action.id == 5514, "learned mana gem has separate conjure and use actions")
known[11958], known[12472] = true, true
fire("SPELLS_CHANGED")
check(addon.menus.defenses.rows[1].action.id == 12472 and addon.menus.defenses.rows[2].action.id == 11958,
    "Forever Cold Snap and Ice Block IDs are bound separately")
secureClick(addon.toggles.refreshments)
fire("BAG_UPDATE_DELAYED")
check(addon.menus.refreshments:IsShown(), "bag refresh preserves the open menu")
local previousKnown = C_SpellBook.IsSpellKnown
C_SpellBook.IsSpellKnown = nil
IsSpellKnown = function(id) return known[id] or false end
check(addon:KnownSpell(1459) and not addon:KnownSpell(10059), "legacy learned-spell API fallback is accurate")
C_SpellBook.IsSpellKnown = previousKnown
C_Spell.GetSpellCooldownDuration = nil
C_Spell.GetSpellCooldown = function() return {startTime=secretNumber(), duration=secretNumber()} end
addon:UpdateActionDisplays()
check(addon.menus.buffs.rows[1].cooldown.start == nil, "unreadable legacy cooldown values are not inspected")
addon:HandleCommand("reset")
check(addon.frame:IsShown(), "layout reset works out of combat")
combat = true
secureClick(addon.toggles.buffs, "_onenter")
check(addon.menus.buffs:IsShown(), "hover opens the flyout in combat")
check(addon.menus.buffs.autoWatch[addon.toggles.buffs], "hover region includes its category button")
tickAutoHide(0.2, {})
check(addon.menus.buffs:IsShown(), "small pointer gap does not close the flyout immediately")
tickAutoHide(1, addon.menus.buffs)
check(addon.menus.buffs:IsShown(), "flyout stays open while pointer is inside")
tickAutoHide(0.4, {})
check(not addon.menus.buffs:IsShown(), "un-pinned flyout closes after pointer leaves")
secureClick(addon.toggles.buffs, "_onenter")
secureClick(addon.toggles.buffs)
tickAutoHide(2, {})
check(addon.menus.buffs:IsShown() and addon.menus.buffs:GetAttribute("pinned"), "click pins the hovered flyout")
secureClick(addon.toggles.buffs)
check(not addon.menus.buffs:IsShown(), "second click closes the pinned flyout")
check(addon.menus.buffs.rows[1].width == 40 and addon.menus.buffs.rows[1].label == nil,
    "flyout uses compact action icons rather than tooltip-like text rows")
check(addon.toggles.buffs.hooks.OnEnter and not addon.toggles.buffs.scripts.OnEnter,
    "tooltip suppression hooks do not replace secure hover handlers")
combat = false
known[759], known[3552], known[12051] = true, true, true
inventory[5514], inventory[5513] = 1, 1
addon.db.centerAction = "gem"
fire("SPELLS_CHANGED")
check(addon.sphere:GetAttribute("item1") == "item:5513", "orb selects highest learned carried mana gem")
check(addon.manaText.values[1] == 2 and addon.centerLabel.text == "Mana Gem", "gem display totals all carried gem ranks")
check(addon.sphere:GetAttribute("shift-type1") == "spell" and addon.sphere:GetAttribute("shift-spell1") == 12051, "learned Evocation binds only to Shift-left")
inventory[5513] = 0
fire("BAG_UPDATE_DELAYED")
check(addon.sphere:GetAttribute("item1") == "item:5514", "orb falls back to a carried lower gem")
inventory[5514] = 0
fire("BAG_UPDATE_DELAYED")
check(addon.sphere:GetAttribute("type1") == "" and addon.sphere:GetAttribute("item1") == nil, "missing gems clear the action instead of drinking after gems are learned")
addon.db.centerAction = "water"
addon:ApplySettings()
check(addon.db.centerAction == "eatdrink" and addon.sphere:GetAttribute("macrotext1"):find("item:5350",1,true), "legacy water option migrates to combined consumption using carried water")
inventory[2288] = 4
fire("BAG_UPDATE_DELAYED")
check(addon.manaText.values[1] == 0 and addon.manaText.values[2] == 6 and addon.centerLabel.text == "Eat + Drink", "combined display totals food and water separately across carried ranks")
inventory[2288] = 0
fire("BAG_UPDATE_DELAYED")
combat = true
addon.db.centerAction = "evocation"
addon:SettingsChanged()
check(addon.sphere:GetAttribute("macrotext1"):find("item:5350",1,true) and addon.settingsPending, "orb setting changes are deferred during combat")
addon.sphere.hooks.OnClick(addon.sphere, "RightButton", false)
check(addon.settings:IsShown(), "right-click opens options even in combat")
combat = false
fire("PLAYER_REGEN_ENABLED")
check(addon.sphere:GetAttribute("type1") == "spell" and addon.sphere:GetAttribute("spell1") == 12051 and addon.sphere:GetAttribute("item1") == nil,
    "Evocation selection applies after combat and clears the item binding")
known[12051] = false
fire("SPELLS_CHANGED")
check(addon.sphere:GetAttribute("type1") == "" and addon.sphere:GetAttribute("shift-type1") == "", "unlearned Evocation clears both bindings")
known[759], known[3552] = false, false
addon.db.centerAction = "gem"
fire("SPELLS_CHANGED")
check(addon.sphere:GetAttribute("item1") == nil and addon.manaText.values[1] == 0, "unlearned gems remain unassigned even with water available")
addon.db.centerAction = "water"
addon:ApplySettings()
inventory[5350] = 0
fire("BAG_UPDATE_DELAYED")
check(addon.sphere:GetAttribute("type1") == "", "missing water leaves leveling click unassigned")
check(addon.manaText.values[1] == 0 and addon.manaText.values[2] == 0 and addon.centerLabel.text == "Eat + Drink", "empty food and water inventory displays both zeros")
inventory[5350], inventory[5514], known[759] = 2, 1, true
addon.db.centerAction = "gem"
fire("BAG_UPDATE_DELAYED")
spellNames[28271], spellNames[28272], spellNames[12826] = "Polymorph", "Polymorph", "Polymorph"
spellBook = {118}
local function polymorphs()
    local ids = {}
    for _, action in ipairs(addon:BuildActions().utility) do
        if action.name == "Polymorph" then ids[#ids+1] = action.id end
    end
    return ids
end
local ids = polymorphs()
check(#ids == 1 and ids[1] == 118, "unlearned cosmetic variants cannot rediscover sheep and duplicate it")
known[28272], known[12826] = true, true
spellBook = {118,12826,28272}
ids = polymorphs()
check(#ids == 2 and ids[1] == 12826 and ids[2] == 28272, "learned sheep rank and pig remain distinct even with the same localized name")
fire("SPELLS_CHANGED")
check(addon.keyButtons.Polymorph:GetAttribute("spell1") == 12826, "Polymorph binding selects sheep's highest rank rather than a same-name variant")
spellNames[999002], known[999002] = "Polymorph", true
spellBook = {118,12826,999002,28272}
ids = polymorphs()
check(#ids == 2 and ids[1] == 999002 and ids[2] == 28272, "additional learned Forever rank is discovered without absorbing cosmetic variants")
known[28272], known[12826], known[999002], spellBook = nil, nil, nil, {}
fire("SPELLS_CHANGED")
addon.db.centerAction = "eatdrink"
inventory[5349], inventory[5350], inventory[2288], known[12051] = 7, 2, 4, true
addon:ApplySettings()
local meal = "/use [nocombat] item:5349\n/use [nocombat] item:2288"
check(addon.sphere:GetAttribute("type1") == "macro" and addon.sphere:GetAttribute("macrotext1") == meal, "orb securely consumes both best learned carried supplies outside combat")
check(addon.manaText.values[1] == 7 and addon.manaText.values[2] == 6, "orb shows separate food and water totals")
check(addon.keyButtons.Orb:GetAttribute("macrotext1") == meal and addon.keyButtons.EatDrink:GetAttribute("macrotext1") == meal, "orb and independent meal bindings match the combined action")
check(addon.sphere:GetAttribute("shift-spell1") == 12051 and addon.sphere:GetAttribute("shift-macrotext1") == nil, "Shift-click retains only Evocation without consuming supplies")
combat = true
inventory[5350], inventory[2288] = 0, 0
fire("BAG_UPDATE_DELAYED")
check(addon.sphere:GetAttribute("macrotext1") == meal, "combined secure action is frozen while combat blocks bag rebinding")
combat = false
fire("PLAYER_REGEN_ENABLED")
check(addon.sphere:GetAttribute("macrotext1") == "/use [nocombat] item:5349", "food-only inventory still has a usable center action")
inventory[5349] = 0
fire("BAG_UPDATE_DELAYED")
check(addon.sphere:GetAttribute("type1") == "" and addon.sphere:GetAttribute("macrotext1") == nil
    and addon.keyButtons.Orb:GetAttribute("macrotext1") == nil, "empty bags clear stale macros from orb and its binding")
inventory[5349], inventory[5350] = 7, 2
addon.db.centerAction = "gem"
addon:ApplySettings()
check(addon.sphere:GetAttribute("macrotext1") == nil and addon.keyButtons.Orb:GetAttribute("macrotext1") == nil
    and addon.keyButtons.EatDrink:GetAttribute("type1") == "macro", "switching center mode clears meal macro and retains independent consumption binding")
io.write("Passed ", checks, " behavioral checks using the real addon Lua.\n")
