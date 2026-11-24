local character = "first-mage"
function UnitGUID() return character end
local shown, blocked = 0, false
local dialog
StaticPopupDialogs = {}
function StaticPopup_Show(name)
    if blocked then return end
    shown = shown + 1
    dialog = assert(StaticPopupDialogs[name])
    return {}
end

known[5504], inventory[5350] = true, 6
fire("ADDON_LOADED", "Arcanum")
fire("PLAYER_ENTERING_WORLD")
assert(addon.db.centerAction == "eatdrink" and shown == 0)

combat = true
known[759] = true
fire("SPELLS_CHANGED")
assert(shown == 0 and addon.sphere.displayMode == "eatdrink")
combat, blocked = false, true
fire("PLAYER_REGEN_ENABLED")
assert(shown == 0 and addon.character.manaGemCenterSetup == "waiting")
blocked = false
fire("SPELLS_CHANGED")
assert(shown == 1 and addon.sphere.displayMode == "eatdrink")
assert(dialog.button2 == "Keep Eat + Drink")

-- Dismissing the one-time offer leaves Eat + Drink selected through zoning,
-- a saved settings reload, and learning a higher gem.
addon:InitializeSettings()
fire("PLAYER_ENTERING_WORLD")
known[3552] = true
fire("SPELLS_CHANGED")
assert(shown == 1 and addon.sphere.displayMode == "eatdrink")

character = "existing-mage"
ArcanumDB.characters[character] = {settings={centerAction="gem"}}
known[759], known[3552] = nil, nil
addon:InitializeSettings()
fire("PLAYER_ENTERING_WORLD")
assert(addon.sphere.displayMode == "eatdrink" and shown == 1)
known[759] = true
fire("SPELLS_CHANGED")
assert(shown == 2)
dialog.OnAccept()
assert(addon.db.centerAction == "gem" and addon.sphere.displayMode == "gem")
inventory[5514] = 1
fire("BAG_UPDATE_DELAYED")
assert(addon.sphere:GetAttribute("item1") == "item:5514")

character = "evocation-mage"
ArcanumDB.characters[character] = {settings={centerAction="evocation"}}
addon:InitializeSettings()
fire("PLAYER_ENTERING_WORLD")
assert(shown == 2 and addon.sphere.displayMode == "evocation")

character = "already-trained-mage"
ArcanumDB.characters[character] = {settings={centerAction="gem"}}
addon:InitializeSettings()
fire("PLAYER_ENTERING_WORLD")
assert(shown == 2 and addon.sphere.displayMode == "gem")

character = "new-trained-mage"
addon:InitializeSettings()
fire("PLAYER_ENTERING_WORLD")
assert(shown == 3 and addon.sphere.displayMode == "eatdrink")
io.write("Passed center-action defaults, migration, combat deferral, and one-time Mana Gem offer.\n")
