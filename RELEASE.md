# Release 1.1.4

- Submitted to CurseForge as file 9820577 on November 25, 2026. Release
  targets Forever 1.60.1 and publishes automatically after approval. Initial
  status was Processing File. Verified the saved changelog.
- Adds the Ice Barrier reminder and fixes and restyles controls in Group Supplies.
- Player install: `dist/Arcanum-Forever-1.1.4.zip`.
- SHA-256: ce9200fdcb044a8e72a7c75d02c8638bae28295732c3925f537762d40a0f2259.
- The archive contains 33 verified files. All 750 behavioral checks and 12
  keybindings passed, plus multi-client supply and Mana Gem prompt scenarios.

# Release 1.1.3

- Submitted to CurseForge as file 9783662 on November 23, 2026. Release
  targets Forever 1.60.1 and publishes automatically after approval. Initial
  status was Processing. Verified the saved player-facing changelog.
- Player install: `dist/Arcanum-Forever-1.1.3.zip`.
- SHA-256: dcb886318fa251b6034ae975e6ac85d02e8094323416aa1d28363df535c84465.
- The archive contains 33 verified files. All 733 behavioral checks and 12
  keybindings passed, plus multi-client supply and Mana Gem prompt scenarios.
- The uploaded ZIP includes the earlier preparation instructions in its
  README. The CurseForge changelog and source README describe Group Supplies.

## Local development notes

- Added click-to-trade roster names, food/water icon headers, clearer request
  wording and shortage status, a smaller trade panel, and consolidated Vending
  options. Automated validation: 713 behavioral checks and 12 keybindings pass.
- November 22: personal-only Prepared plus separate Group Supplies queue,
  editable requests/exclusions, completed-delivery removal, Add back, group-only
  whisper requests, and vending integration.
- Streamlined the group window and corrected minimize control layering, drag
  overlap, stable top anchoring, and saved collapsed state. 706 behavioral checks
  and 12 keybindings pass.
- Validation: 703 behavioral checks and 12 keybindings pass. Local Forever
  install verified against all 31 source files. Live visual check deferred
  because the player was actively using the client; no reload performed.
- Fix personal-versus-group target editing and preserve completed supply trade
  snapshots through window cleanup; match fallback trade names to group keys.
- Regression covers 40 food / 20 water before a rogue trade, then 20 / 20 and
  Prepared immediately after completion, including closing/reset event ordering.
- Live coordination between two mages remains to be verified.

# Release 1.1.2

- Automatic group preparation, personal/manual overrides, online recipients,
  completed-delivery subtraction, and recipient-level supply allocation.
- Includes Toggle circle keybind and a single collapsible Arcanum category.
- Player install: `dist/Arcanum-Forever-1.1.2.zip`.
- Automated validation: 688 behavioral checks and 12 native keybindings pass.
- CurseForge file 9744212 submitted November 21, 2026 as Release for 1.60.1.
  Saved changelog verified. As of November 23, status was Pending Release.
  Manual publication was selected.
- ZIP SHA-256: b857080d367a410006101bd9932756598a7dead79c8a42ed15dc53ce124a6ff2.
- Automated validation covers 32 new group preparation cases, in addition to
  the existing suite. Actual group preparation in game still needs testing.

# Release 1.1.1

- Native self-effect row targets Arcane Blast's restricted
  self-debuff case; native target slots cover personal Ignite and Winter's Chill.
- In-game preview: `/arc procs test arcane`; stop: `/arc procs stop`.
- Player install: `dist/Arcanum-Forever-1.1.1.zip`.
- Automated validation: 651 behavioral checks and 11 native keybindings pass.
- Live reload and four-stack Arcane Blast icon preview verified November 15,
  2026. Long-running Boosted Rest was excluded by the native 60-second filter.
- Real talented Arcane Blast combat activation has not been verified.
- CurseForge file 9631824 uploaded November 15, 2026 as Release for 1.60.1.
  Observed status: Processing. Manual publication selected after automatic
  approval review rejected automatic publication; not yet live.

# Release 1.1.0

- Prefer complete usable stacks and consolidate matching-rank partial stacks
  before offering tiny newer-rank conjured batches for a class preset.
- Restyle and compact the curse helper to match the Comprehend window; roster
  sizing and locked-header removal occur outside combat.
- Automated validation: 632 behavioral checks and 11 native keybindings pass,
  including a rogue's 20-food preset with mixed ranks, ten two-item batches,
  consolidation, and reserve preservation. Live trade confirmation still needed.
- Stable release for Forever 1.60.1, interface 16001.
- Player install: `dist/Arcanum-Forever-1.1.0.zip`.
- Checksum: `dist/Arcanum-Forever-1.1.0.zip.sha256`.
- CurseForge file 9630802 submitted November 15, 2026 as Release for 1.60.1
  with automatic publication after approval. Saved trade/decurse notes verified.

# Release 1.0.7

- Hollow Bell Studios author credit and optional copyable support link in Support.
- Player install: `dist/Arcanum-Forever-1.0.7.zip`; all 623 behavioral checks and
  11 native keybindings pass. Local installation hashes verified.
- CurseForge file 9622712 submitted November 14, 2026 as Release for 1.60.1;
  observed status Processing, automatic publication after approval.
- Public description studio credit and Buy Me a Coffee link verified live.

# Release 1.0.6

- Stable release for Forever 1.60.1, interface 16001.
- Player install: `dist/Arcanum-Forever-1.0.6.zip`.
- Checksum: `dist/Arcanum-Forever-1.0.6.zip.sha256`.
- CurseForge file: 9585393, submitted November 12, 2026 as a stable Release
  for 1.60.1 with automatic publication after approval. Saved changelog verified.
- Debounce Comprehend inventory events until 200ms after the last event.
- Validation: 623 behavioral checks and 11 native keybindings pass. Regression
  covers 100 item-lock events plus bag update yielding one settled scan, stale
  click safety, refreshed bag targets, idle cleanup, disabled popup, and combat.
- Actual bag-sort FPS improvement still needs confirmation in the live client.

# Release 1.0.5

- Stable release for Forever 1.60.1, interface 16001.
- Player install: `dist/Arcanum-Forever-1.0.5.zip`.
- Checksum: `dist/Arcanum-Forever-1.0.5.zip.sha256`.
- CurseForge file: 9550261, submitted November 10, 2026 as a stable Release
  for 1.60.1 with automatic publication after approval. Saved changelog verified.
- Includes the movable Comprehend scroll popup and native player combat proc
  displays for Missile Barrage, Clearcasting, Fingers of Frost, and Heating Up.
- The owner confirmed eligible and above-skill scroll behavior in game on
  November 10, 2026.
- Automated validation: 612 behavioral checks and 11 native keybindings pass.
  New regressions block all Lua aura reads during simulated combat and verify
  native display ownership, sound registration/toggles, and preview cleanup.
- Actual talented proc activation in live combat has not been verified. Native
  registration can be checked with `/arc procs status`. Threshold sounds and
  personal enemy effects remain dependent on readable aura data.

# Release 1.0.4

- Project: Arcanum Forever.
- Addon folder: Arcanum.
- Target: WoW: Forever 1.60.1, interface 16001.
- License: MIT, copyright 2026 Alfonso.
- Release classification: Release (stable).
- Project avatar: `branding/arcanum-forever-logo.png` (1254 × 1254 PNG).

## Validation

On October 3, 2026, the project owner confirmed in-game testing after every
development release through 0.8.0. This is owner-reported validation; automated
checks do not substitute for live gameplay.

On November 5, 2026, the project owner confirmed Drive-by Intellect works in game.

On November 8, 2026, the Candle reminder fix was verified in the live Forever
client with the active Incense Candle benefit inside Camp Benefits.

The automated suite passes 567 behavioral checks and validates 11 native
keybindings. Package validation checks paths, exact file contents, TOC load files,
license inclusion, and ZIP integrity.

## Deliverables

- Player install: `dist/Arcanum-Forever-1.0.4.zip`.
- Checksum: `dist/Arcanum-Forever-1.0.4.zip.sha256`.
- CurseForge file: 9518280, uploaded November 8, 2026 as a stable Release for
  1.60.1. Status at submission: Processing; automatic publication after approval.
- Developer repository: runtime source, tests, build tools, player/developer
  documentation, branding, and MIT license.

Only the install ZIP is uploaded as the CurseForge addon file. Tag its game
compatibility as Forever / 1.60.1. Use the approved PNG as the project avatar and
the player README as the basis for the public description. Game screenshots may
be added separately. Do not include local dependencies, publishing credentials,
or player saved variables in either public upload.

## Rebuilding

```sh
python -m pip install --target work/test-runtime -r requirements-dev.txt
python tests/run.py
python tools/package-addon.py
```

For later versions, update the TOC and changelog, repeat automated and in-game
validation, and package the new version. Keep the in-game folder named Arcanum.
