local _, addon = ...

-- Clockwise from the top; categories without learned actions are hidden.
addon.categories = {
    { id = "buffs", label = "Buffs", icon = "Interface\\Icons\\Spell_Holy_MagicalSentry", description = "Intellect and group buffs" },
    { id = "armor", label = "Armor", icon = "Interface\\Icons\\Spell_Frost_FrostArmor02", description = "Armor selection and active buff" },
    { id = "portals", label = "Portals", icon = "Interface\\Icons\\Spell_Arcane_PortalStormWind", description = "Group travel destinations and reagents" },
    { id = "teleports", label = "Teleports", icon = "Interface\\Icons\\Spell_Arcane_TeleportStormWind", description = "Personal travel destinations" },
    { id = "mana", label = "Mana recovery", icon = "Interface\\Icons\\INV_Misc_Gem_Sapphire_02", description = "Mana gems and Evocation" },
    { id = "refreshments", label = "Food & water", icon = "Interface\\Icons\\INV_Drink_18", description = "Conjure, eat, and drink" },
    { id = "defenses", label = "Defenses", icon = "Interface\\Icons\\Spell_Frost_Frost", description = "Shields, wards, and defensive cooldowns" },
    { id = "utility", label = "Utility", icon = "Interface\\Icons\\Spell_Nature_Polymorph", description = "Polymorph, curse removal, and utility" },
    { id = "hearthstone", label = "Hearthstone", icon = "Interface\\Icons\\INV_Misc_Rune_01", description = "Return home", direct = true },
}
