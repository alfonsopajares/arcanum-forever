# Changelog

## 0.9.6 - October 4, 2026 (public beta)

- Always show Shift + left-click: Evocation in the center orb tooltip, with a
  not-learned label when unavailable. The shortcut still only casts learned Evocation.

## 0.9.5 — October 4, 2026 (local beta)

- Add dedicated blue/purple tooltips with opaque backgrounds and aligned controls.
- Show colored food, water, and mana gem counts on orb and preparation tooltips.
- Keep native spell/item details, with compact action and reagent rows.
- Match Hearthstone and minimap tooltips, and respect the tooltip visibility setting.
- Show the drag hint only when the circle is unlocked and outside combat.
- Keep styling on a dedicated Arcanum tooltip without changing Blizzard tooltips.


## 0.9.4 — October 4, 2026 (public beta)

- Move Hearthstone from orb middle-click to its own outer circle button with no
  flyout. Show its cooldown and home location tooltip; hide it when not carried.
- Include Hearthstone in circle visibility and ordering settings.

## 0.9.3 — October 4, 2026 (local beta)

- Add optional recipient-level ranks for Intellect, Dampen Magic, and Amplify
  Magic, including last-spell shortcuts. Use a conservative lowest learned rank
  during combat; retain highest-rank right-click self buffs.
- Add a middle-click Hearthstone shortcut on the orb, configurable in Buffs / Travel.
- Add an optional draggable minimap settings button with a saved position.

## 0.9.2 — October 4, 2026 (local beta)

- Cycle funny-message previews through all five lines using a separate preview
  cursor. Preview clicks never consume or reshuffle the in-game message rotation.

## 0.9.1 — October 4, 2026 (local beta)

- Use up/down arrows for category ordering and place Support last in options.
- Expand funny / roleplay to five messages per event and timing, with shuffled
  cycles that use every message before repeating. Previews leave cycles unchanged.

## 0.9.0 — October 4, 2026 (local beta)

- Redesigned options with a Blizzard-style frame, page headings, and icon navigation.
- Added configurable mage messages, original funny speeches, editable templates,
  local previews, successful-cast timing, and repeat throttling.
- Added clockwise category ordering and secure Shift-click last-spell shortcuts.
- Added optional Intellect/Armor timers, cooldown numbers, and mana color presets.
- Added opt-in reagent restocking with learned-spell checks, stock targets,
  per-visit spending limits, gold reserves, and bag confirmation. No bag sorting.

## 0.8.1 — October 4, 2026

- Close vending for the current trade, or collapse it to a reopening tab.
- Drag the vending title to save its position; reset it under Vending settings.
- Optional automatic collapse while enchanting, with manual reopening and restoration.
- Preserve manual visibility and position through trade and bag updates.

## 0.8.0 — October 3, 2026

Initial public beta of **Arcanum Forever** for WoW: Forever 1.60.1.

- Circular mage toolbox with highest-learned-rank spell menus.
- Mana Gem, Evocation, and combined Eat + Drink center actions.
- Prepare workflow, stock profiles, supply estimates, and optional reminders.
- Prominent missing-buff alert and independent target Ignite stack display.
- Food/water trade helper with class presets, full-stack controls, and reserves.
- Character-specific settings, copying, persistent delivery history, and logging.
- Ten optional native keybindings and configurable circle/flyouts.
- Approved Arcanum Forever logo and MIT license.

The project owner tested in game after every development release through 0.8.0.
The automated suite passes 236 behavioral checks and validates 10 keybindings.

## Development milestones

- **0.7.0:** Combined Eat + Drink center action and separate food/water counts;
  removed the redundant consumption button.
- **0.6.3:** Fixed duplicate Polymorph entries and variant/rank selection.
- **0.6.2:** Larger framed buff reminders; removed food use from the flyout and
  only the circle's Vending shortcut, preserving the trade helper.
- **0.6.1:** Direct buff lookups, visible buff names, and water-use flyout removal.
- **0.6.0:** Prepare, dropdowns, clearer trade feedback, character settings,
  persistent history, and troubleshooting log.
- **0.5.0 and earlier:** Initial circle, secure casting, learned-spell filtering,
  configurable center actions, preparation/reminders, bindings, and vending.
