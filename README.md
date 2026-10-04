# Arcanum Forever

![Arcanum Forever logo](branding/arcanum-forever-logo.png)

A circular mage toolbox for **World of Warcraft: Forever**. Keep your spells,
mana recovery, conjured supplies, and reminders together in one configurable orb.

**Version 0.9.4 — Beta.** Built for Forever 1.60.1 (interface 16001).
Compatibility with Retail and other Classic clients has not been verified.

## Features

- **Learned spells only.** Menus show the highest learned rank of your spells.
  Empty categories stay hidden, and learned Polymorph variants remain distinct.
- **Round spell flyouts.** Access buffs, armor, portals, teleports, mana recovery,
  conjuring, defenses, and utility spells. Hover to open a menu or click to pin it.
- **Choose your center action.** Use Mana Gem, Evocation, or Eat + Drink, with a
  matching item count or mana display inside the orb.
- **Prepare supplies.** Each click conjures the next missing learned mana gem,
  then water, then food, until your active preparation targets are met.
- **Buff and supply reminders.** A prominent Missing Buffs alert calls out
  missing armor and Arcane Intellect. Optional highlights warn about low food,
  water, reagents, and missing learned mana gems.
- **Ignite tracking.** A fire icon and large stack counter below screen center
  track Ignite on your current enemy target, including other mages' applications.
- **Food and water trading.** A Blizzard-style helper beside the trade window
  offers class presets, full-stack buttons, personal reserves, and shortage
  feedback. You review the offer and confirm the trade yourself.
- **Character-specific settings.** Customize each mage separately, copy settings
  from another mage, and retain recent completed-delivery history across reloads.
- **Optional keybindings.** Bind preparation, mana recovery, eating and drinking,
  utility spells, and self buffs.
- **Mage messages.** Choose practical announcements, random funny speeches, or
  your own text for portals, Polymorph, Evocation, and completed supply trades.
- **Reagent restocking.** Optionally refill reagents for learned spells at vendors,
  with item targets, a spending cap, and a gold reserve. Bags stay as you arranged them.
- **Personal layout.** Reorder circle categories, repeat the last selected spell
  with Shift-click, and show buff timers, cooldown numbers, and mana color presets.
- **Recipient-level buffs.** Adjust learned Intellect, Dampen Magic, and Amplify
  Magic ranks for lower-level targets outside combat, with a conservative combat rank.
- **Convenient shortcuts.** Click the standalone Hearthstone circle button, or open options
  from an optional draggable minimap button.

## Getting started

Log into a mage character and type `/arc` to open settings.

## Using the circle

Drag the center orb to move the circle while it is unlocked and you are outside
combat. Set its size, button spacing, rotation, and visible categories under
**Circle** settings.

Hover an outer button to open its flyout, then click a spell to cast it. Moving
away closes the flyout after the configured delay. Click an outer button to pin
its menu open; click it again to close it. Right-click a friendly buff or Remove
Lesser Curse to cast it on yourself.

**Shift + left-click an outer button** to repeat its last selected spell. The
shortcut is remembered per character and follows learned rank upgrades. A new
selection made during combat becomes the shortcut once combat ends. Reorder
categories under **Flyouts** using the up/down arrows; hidden categories keep their place.

Right-click the center orb to open settings. Left-click uses your chosen center
action. **Shift + left-click casts Evocation when learned**, regardless of your
selected center action.

**Left-click the standalone Hearthstone circle button** to return home. It has
no flyout, shows the item cooldown, and appears only while your Hearthstone is in
your bags. Hide it under **Circle** or reorder it under **Flyouts**. Middle-click
on the orb has no action.

The optional minimap button opens settings on click. Drag it around the minimap
to save its position, or hide it under **Circle** settings.

### Recipient-level buff ranks

Under **Buffs / Travel**, enable recipient-level ranks for Arcane Intellect,
Dampen Magic, and Amplify Magic. Outside combat, left-click chooses an appropriate
learned rank for your friendly target's level using the original vanilla rank
thresholds. It also applies to the outer button's Shift-click last-spell shortcut.
Right-click a flyout buff still uses the highest learned rank on yourself.

WoW restricts changing spell bindings during combat. Combat clicks therefore use
the lowest learned rank; normal recipient-level selection returns after combat.
Unreadable target levels also use the lowest learned rank. If no learned rank
meets a readable target's level requirement, left-click does nothing. Group buffs
retain their normal binding. Disable this option to always use the highest rank.

### Messages

Open **Messages** in `/arc` to enable or disable announcements independently of
reminders. Portals default to funny messages after successful casts; Polymorph
defaults to a practical announcement. Evocation and completed-trade messages are
optional. Messages go to your party or raid, or only to your own chat when solo.
Choose **Only me** to keep all messages private.

Each event has a style and timing: casting starts, successful completion, or
both. Evocation completion requires a full channel. Failed casts and cancelled
trades do not produce completion messages. A repeat delay prevents frequent
announcements of the same event. Funny / roleplay uses five messages per event
and timing, cycling through all five in shuffled order before starting another
cycle. The last message of one cycle never immediately repeats in the next.
Practical announcements and your own text do not rotate. Repeated funny previews
cycle through all five lines separately, without advancing the in-game rotation.

Custom text supports `{player}`, `{target}`, `{destination}`, `{food}`, `{water}`,
and `{phase}`. Use up to three lines, each no more than 255 bytes. The Preview
button displays a sample only to you without sending it to the group.

### Reagent restocking

Open **Reagents** in `/arc` and enable automatic restocking. It is disabled by
default. Set bag-stock targets for Arcane Powder, Rune of Teleportation, Rune of
Portals, and Light Feather. Only reagents needed by learned spells are purchased.

Restocking starts when you open a vendor and stops at your targets, the spending
limit for that visit, the gold you want to keep, vendor stock, or bag capacity.
Purchases use normal gold offers and wait for bag confirmation before proceeding.
This feature does not move or sort your existing items.

Under **Display**, optional Intellect/Armor timers appear beneath those category
buttons. Protected or unavailable duration information leaves the timer blank.
Cooldown numbers and mana display colors can also be changed there.

### Center action

Choose an action under `/arc` → **Display**.

| Option | Shown in the circle | Left-click action |
| --- | --- | --- |
| Mana Gem | Total mana gems in your bags | Uses your best carried learned mana gem |
| Evocation | Current mana | Casts Evocation when learned |
| Eat + Drink | Separate food and water totals | Uses your best carried learned conjured food and water together, outside combat |

Item totals include all carried ranks and exclude bank items. If only food or
water is available, Eat + Drink uses the supply you have. An unavailable center
action does nothing; Mana Gem never falls back to food or water.

### Prepare supplies

Set food and water targets under `/arc` → **Prep**. Automatic mode chooses your
Solo, Party, or Raid profile based on your group. You can select a profile
manually or estimate targets from the current group's class presets and recent
completed deliveries.

Each click performs **one conjuring cast outside combat**, in this order:

1. Missing mana gems you have learned to conjure.
2. Water, until the active water target is met.
3. Food, until the active food target is met.

The button updates when supplies arrive in your bags. **Prepared!** means your
learned mana gems and both stock targets are satisfied; further clicks do
nothing. Preparation never casts automatically. You can hide its button in Prep
settings and keep using its keybinding.

### Reminders and Ignite

Under `/arc` → **Reminders**, turn off all reminders with the master switch, or
disable food, water, mana gem, armor, Intellect, and reagent reminders separately.
Choose supply thresholds, combat suppression, and group-only display. Reminders
are silent and do not post messages in chat.

Ignite has a separate switch under `/arc` → **Display**. Its counter remains
available when the circle is hidden and disappears when Ignite ends, you lose
your target, or your target is friendly or dead.

### Vending and delivery history

Open `/arc` → **Vending** to enable or disable the trade helper, edit per-class
food and water totals, choose personal reserves, and limit supplies to ranks the
recipient can use. When a trade opens, the helper appears to its right.

Drag the vending title to move it; its position is saved for your mage. Use
**Reset vending position** in Vending settings to restore the default location.
The **–** button collapses it to a small reopening tab. **X** hides it for the
current trade; it returns on the next trade. Closing stops pending supply moves.
**Collapse while enchanting** is enabled by default and can be disabled. You can
reopen the tab while enchanting; otherwise the panel returns when enchanting
closes. A panel you collapsed manually stays collapsed.

- **Fill preset** adds only the amount still needed to reach the trade's totals.
  Repeated fills do not double a completed offer. It can combine matching bag
  stacks or split an exact final amount; splitting needs an empty general bag slot.
- **+ Food / + Water** adds one existing full stack unchanged. It does not split
  or combine supplies and respects your personal reserve.
- **Clear supplies** removes only stacks added by Arcanum whose item and quantity
  still match. Manually added items are left alone.

The panel shows offered amounts, targets, remaining quantities, eligible bag
stock, and reserves. Unavailable controls explain why they are disabled.
**Arcanum Forever never confirms a trade for you.** Inventory moves stop when
combat starts or the trade closes.

Under `/arc` → **Trades**, review completed deliveries, choose how long to retain
them, or reset the history. Cancelled trades are not counted. History is separate
for each mage and survives reloads and logouts until it expires.

## Commands and keybindings

| Command | Action |
| --- | --- |
| `/arc` | Opens settings |
| `/arc toggle` | Shows or hides the circle |
| `/arc lock` | Locks or unlocks the circle's position |
| `/arc reset` | Resets the circle's position and layout; preserves other settings |
| `/arc refresh` | Refreshes learned spells and carried items outside combat |
| `/arc help` | Prints command help |

In the game's **Key Bindings** settings, find **Arcanum Forever**. Available
bindings include Orb Action, Evocation, Eat + Drink, Prepare Supplies, Blink,
Counterspell, Remove Lesser Curse, Polymorph, Self: Arcane Intellect, and
Self: Best Learned Armor. No keys are assigned automatically.

The Eat + Drink keybinding works regardless of the selected center action.

## Settings and troubleshooting

Settings are saved automatically for each mage. Under **Support**, copy another
mage's settings without replacing your own delivery history.

When reporting a bug, include the addon version, game version, steps to reproduce
it, and the full error message. For preparation or trade issues, enable the
optional troubleshooting log under `/arc` → **Support**, reproduce the issue,
and include the relevant entries. The log keeps the latest 200 entries and can
be cleared or disabled at any time.

## Credits and license

Created by **Alfonso**. Inspired by the circular toolbox ideas of Necrosis and
the supply-management workflows of Conjurer. Arcanum Forever is independently
developed and is not a continuation of the older Arcanum addon.

Addon source code and bundled original artwork are licensed under the
[MIT License](LICENSE). World of Warcraft names and game assets belong to their
respective owners. This project is not affiliated with or endorsed by Blizzard
Entertainment.
