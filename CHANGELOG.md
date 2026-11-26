# Changelog

## 1.1.4 — November 25, 2026

- Fix clicking a nearby player’s name in Group Supplies to request a trade.
- Give the Group Supplies coverage selector a dropdown field and a compact options list.
- Remind mages with Ice Barrier to refresh Frigid Power, with an optional shield alert.

## 1.1.3 — November 23, 2026

### November 23 — serving a party or raid

- Print why Drive-by Intellect was skipped or failed in the player’s chat.
- Default the center action to Eat + Drink. Offer a one-time switch to Mana
  Gem when the mage can conjure one.
- Open Group Supplies on demand using the button below the mage circle
  while grouped, the Vending options, or `/arc supplies`.
- Group Supplies lets you cover the whole group, your raid subgroup, selected
  subgroups, or handpicked players. Mark someone as declined or handled
  elsewhere, and use Review to take them back.
- Mages with coordination enabled split overlapping coverage and share
  confirmed food and water deliveries, including partial orders. Other group
  members can trade and request refills by whisper with any addon setup.
- See how many waiting players you can serve from your bags. Nearby players
  with a complete order rise to the top. When bag space runs out, the conjure
  button pauses and becomes available again when there is room.

### November 22: separate personal preparation and group supplies

- Click a Group Supplies name to open a nearby player's trade without changing
  your target. Show out-of-range feedback and preserve an existing trade.
- Use food/water icon headers with tooltips. Move all group display/request
  options into Vending; Preparation now shows personal readiness only.
- Rename the trade action to Add requested supplies. Show one clear next-step
  status, including exact shortages and the final manual confirmation reminder.
  Move bag stock/reserve details into the status tooltip and shorten the panel.
- Move Open Group Supplies to the Vending settings page.
- Streamline Group Supplies: compact class-colored rows, one conjuring summary,
  and help tooltip for bag stock, reserves, and instructions. Remove repeated
  status text. Minimize to a short header that stays in place and remembers its
  state; keep minimize/close controls above and outside the title drag region.
- Prepared now covers only your own food, water, and learned mana gems.
- Add a movable, collapsible Group Supplies window for party/raid requests.
  Show bag stock, personal reserves, outstanding requests, and supplies still
  to conjure. Edit individual food/water amounts (0 skips), skip a person, or
  Add back someone supplied. Conjure next casts one learned, usable rank per click.
- Completed trades reduce requests; fully supplied people disappear from the
  list. Session requests survive reloads and reset when leaving the group.
- Group members can whisper `!food`, `!water`, `!both`, or a custom amount such
  as `!water 40` (1–200; 10-second cooldown). New requests return supplied people
  to the queue. Accept no requests from outside the online party/raid.
- Vending uses the recipient's remaining group request. Group tracking works
  independently of optional delivery history. Personal Prepared stays separate.
- `/arc supplies` opens the window. Vending settings control whisper requests.
  UI edits and conjuring remain outside combat;
  whisper requests received during combat appear afterward.

### November 21: target and delivery fixes

- Keep personal food/water amounts separate from automatic group totals. Editing
  what you keep no longer switches Automatic to a fixed Manual target.
- Preserve accepted supply trades through trade-window closing/reset events
  until the client's success message confirms completion. Resolve missing NPC
  GUIDs to a unique group recipient and refresh Prepared immediately afterward.
- With 20 food and 20 water kept for yourself and a rogue needing 20 food,
  prepare for 40 food / 20 water. After giving the rogue a stack, the target
  falls to 20 / 20 and you remain Prepared with your personal supplies.

## 1.1.2 — November 21, 2026

- Group all keybindings in their own collapsible Arcanum section, matching
  the game's other addon categories.
- Add a "Toggle circle" keybind under Arcanum. Hide or show the circle
  outside combat without adding a screen button. No key is assigned by default.
- Prepared now automatically plans food and water for online party or raid
  members using Vending class presets, plus your personal targets/reserves.
  Counts you once and subtracts recent completed deliveries while tracking is on.
- Check usable supply ranks for each recipient's level and conjure the exact
  learned rank needed. Unknown levels use level-one supplies. High-rank stock
  cannot mark a lower-level recipient as prepared.
- Return to personal targets when solo. Keep Personal and Manual overrides,
  including saved party/raid totals. Editing automatic totals selects Manual.
- Show group totals and remaining supplies in Prepare's tooltip, with a
  recipient breakdown. Refresh as the roster, inventory, and delivery history
  change. Preparation remains one deliberate click per cast, outside combat.

## 1.1.1 — November 15, 2026

- Add a native row of up to six player-applied self-debuffs for Arcane Blast and
  similar effects. The client supplies the real icon, name, stacks and timer;
  other short self-effects may appear too. Exclude effects with a base duration
  over 60 seconds, such as long-running camp/rest effects. No restricted spell-ID matching or aura
  visibility inspection is used. The Arcane Blast option controls
  this row. Threshold sounds still need readable counts.
- Move combat Ignite and Winter's Chill visuals to native player-owned target
  filters. Preserve their visibility switches and readable-only sound behavior.
- Add `/arc procs test arcane`: preview the compact round Arcane Blast icon at
  four simulated stacks without learning or casting it. Existing test-all mode
  includes the new icon. Preview ends after 30 seconds or entering combat.
- In-game icon preview verified; actual Arcane Blast combat activation still
  needs player confirmation.

## 1.1.0 — November 15, 2026 (stable release)

- **Decurse UI update:** Match the Comprehend window's blue tiles and gold trim in the curse helper.
  Fit the frame and short drag header to the current roster; locking removes
  header space. Preserve secure decurse actions and purple curse indicators.

- **Trade bug fixes:** Prefer complete usable food/water stacks when filling class presets, instead
  of sending small newer-rank batches first. Choose the largest matching-rank
  batch that can be offered, consolidating partial bag stacks when needed.
  Preserve exact targets, recipient-level restrictions, and personal reserves.

## 1.0.7 — November 14, 2026 (stable release)

- Credit Hollow Bell Studios as the addon author. Add an optional, copyable
  Buy Me a Coffee link under `/arc` → Support.

## 1.0.6 — November 12, 2026 (stable release)

- Fix excessive Comprehend bag scans during auto-sort: combine rapid item lock,
  bag, player aura, and item-data events into one refresh after a 200ms quiet
  period. Stop the refresh ticker when idle and skip queued scans while disabled
  or in combat. Keep immediate skill/option refreshes and click-time validation.

## 1.0.5 — November 10, 2026 (stable release)

- Restyle the Comprehend popup after Blizzard's Friends list: brown-and-gold
  title strip, spell emblem, blue item rows, scroll icons, left-aligned text,
  gold separators, and full-row highlighting. Keep the entire ready row clickable
  and unavailable scrolls dimmed with an explicit Locked label.
- Match the Missing Buffs reminder style: compact dark panel, thin dialog border,
  gold heading and clickable gold scroll names, muted locked scrolls, and small
  requirement/count text. Show the popup's off-switch location in its footer.
- Separate scroll rows with thin gold dividers and a subtle clickable background,
  a ready-arrow indicator, and a stronger hover highlight. Clarify that clicking
  anywhere on a ready row deciphers one scroll.
- Add a movable Comprehend popup that appears only with learned Comprehend
  Scroll and eligible untranslated scrolls in your carried bags. Check the
  localized Comprehension requirement against current skill and bonuses.
- List each untranslated scroll type with its bag quantity; dim unmet requirements
  and only open when at least one type is eligible. Click to securely cast
  Comprehend on one scroll. Refresh after bag/skill changes and hide in combat.
- Save the position; `/arc scrolls` reopens a dismissed eligible list and
  `/arc scrolls reset` restores its position. Disable under Preparation.
- Move Missile Barrage, Clearcasting, Fingers of Frost, and Heating Up combat
  displays to Blizzard's native aura system so protected Lua buff reads do not
  delay their icons until combat ends. Use native timers and stack displays.
- Use native gain sounds for Missile Barrage, Clearcasting, and Fingers of Frost;
  respect master/per-effect switches and avoid duplicate sounds in preview mode.
- Keep enabled combat alerts in fixed slots without inspecting protected
  visibility. Heating Up uses a native stack bar in combat; threshold sounds,
  Arcane Blast, and personal enemy effects still require readable aura data.
- Correct Arcane Blast lookup to search harmful player auras. Add
  `/arc procs status` for native display/sound registration diagnostics.

## 1.0.4 — November 8, 2026 (stable release)

- Refresh the vending panel with a larger class-colored recipient name,
  aligned Food/Water offered counts and editable targets, and a prominent
  green completion status. Keep bag stock and configured reserves secondary.
- Reduce unused space, use consistent Food then Water button order, and move
  detailed action explanations into hover tooltips, including disabled buttons.
- Label the primary action "Add to trade", show the eligible full-stack amount
  on Food/Water buttons (for example, "+20 Water"), and explicitly prompt
  "Supplies ready — Review and press Trade" when targets are met.

## 1.0.3 — November 8, 2026 (stable release)

- **Incense Candle reminder fix:** Arcane Intellect is no longer reported as
  missing while the Candle's Intellect benefit is active inside Camp Benefits.
  Camps without a Candle still leave the reminder active.
- **Try Drive-by Intellect:** assign a key under Options → Keybindings →
  Arcanum Forever → Drive-by Intellect (mouseover, outside combat). Hover a
  friendly player or unit frame and press your key to buff them without
  changing targets, using a learned rank appropriate for their level.
  Configure its filters and feedback in `/arc` → Buffs / Travel.
- Include the optional mage curse helper introduced in local testing below:
  click named party/raid squares to cast Remove Lesser Curse, including in combat.
  Open `/arc curses` to configure it or `/arc curses test` to preview it.

- Count the active Incense Candle Intellect benefit as satisfying the Arcane
  Intellect reminder. A generic Camp Benefits aura or simply carrying/placing
  a candle does not suppress the warning. The warning returns when neither
  Intellect nor the candle benefit is active.
- Fix detection in Forever's combined Camp Benefits buff by checking its
  listed Incense Candle benefit, rather than expecting a separate Candle aura.

## 1.0.2-local — November 6, 2026 (local testing)

- Add an optional mage curse helper with named party/raid squares. Each left-click
  securely casts learned Remove Lesser Curse on that square's unit without
  changing the current target, including during combat.
- Use Blizzard's native Curse-filtered aura slot for restricted combat highlights
  when available. Readable curses also show purple status; unreadable aura data
  is explicitly marked ? and never interpreted as clean.
- Add readable range, dead, and offline indicators, independent position and
  scale, hide-while-solo, and an optional throttled sound for readable new curses.
- Add a non-casting preview, `/arc curses` options, `/arc curses test`, and
  `/arc curses stop`. Layout and visibility changes defer during combat.

## 1.0.1 — November 5, 2026 (stable release)

- Add a Drive-by Intellect keybinding under Arcanum Forever. Outside combat,
  hover a friendly player or unit frame and press it to cast the highest learned
  Arcane Intellect rank appropriate for that player's level without retargeting.
- Add Buffs / Travel switches for the binding, friendly-target fallback, a
  mana-user filter, skipping confirmed equal/stronger Intellect, successful-cast
  confirmation, and optional sound (off by default).
- Unreadable buff information does not block casting. Unknown player levels use
  the lowest learned rank. Combat clicks are explicitly suppressed to keep the
  recipient and rank checks safe; the ordinary buff buttons remain available.

## 1.0.0 — November 4, 2026 (stable release)

- Promote Arcanum Forever to its first stable release for WoW: Forever 1.60.1.
- Retain the existing orb, learned-spell flyouts, preparation tools, vending,
  reminders, messages, proc alerts, and personal Ignite tracking.
- Remove beta labeling from the current release and player documentation.
- Preserve the Arcanum folder, character settings, and saved trade history.

## 0.9.9 — October 17, 2026 (public beta)

- Remove Wake of Fire tracking, settings, and previews following its removal in
  the current Forever beta. Clear its obsolete saved effect settings.
- Give Ignite an explicit fire icon instead of relying on its hidden aura's icon.
- Make maximum stacks stand out with a thicker, bright gold halo, gold stack
  numbers, and a MAX STACKS callout. The halo disappears when a charge is spent
  or stacks become unreadable.

## 0.9.8-local — October 17, 2026 (local prototype)

- Add a movable, scalable row of round spell icons with action callouts, charges,
  and readable remaining durations, independent of the main circle.
- Track Clearcasting, Missile Barrage, Fingers of Frost, Heating Up, Arcane Blast,
  Winter's Chill, and personal Ignite. Recognize Wake of Fire if the client still
  supplies its older beta buff; never infer it from kills.
- Add individual visibility, sound switches, four original sound choices, and
  sound previews under Procs. Stack alerts sound at their useful thresholds;
  Ignite, Winter's Chill, and Arcane Blast are silent by default.
- Add `/arc procs` and a test panel for simulated gains, stacks, consumption,
  expiration, and simultaneous alerts without needing talents. `/arc procs test`
  previews every effect; `/arc procs stop` ends it. Tests end automatically after
  30 seconds or on entering combat and never alter saved effect switches.
- Replace the old Ignite stack panel with personal Ignite in the shared row;
  another mage's Ignite is no longer presented as yours. Protected aura values
  are never used for arithmetic or sound decisions, and unknown ownership hides
  target alerts. Keep Support as the final options button.

## 0.9.7 — October 6, 2026 (public beta)

- Add Forever's Comprehend Scroll to the Utility flyout, visible only when learned.

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
