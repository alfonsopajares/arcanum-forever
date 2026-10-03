# Developing Arcanum Forever

Arcanum Forever targets WoW: Forever 1.60.1, interface 16001. The public project
name differs from the stable in-game folder name, `Arcanum`.

## Project layout

- `Arcanum/`: addon source, manifest, native keybindings, UI artwork, and license.
- `branding/`: approved project logo and its generation notes.
- `tests/`: real Lua 5.1 execution with a mock WoW environment.
- `tools/`: packaging and artwork-generation utilities.
- `README.md`: player documentation.
- `CHANGELOG.md`: release history.
- `RELEASE.md`: release validation and upload guidance.

Local caches, ZIPs, logs, installation backups, and personal publishing helpers
are excluded from Git. No account credentials or player saved variables belong
in the repository.

## Running checks

Use Python 3.9 or later. From the repository root:

```sh
python -m pip install --target work/test-runtime -r requirements-dev.txt
python tests/run.py
```

The runner loads the addon in a real Lua 5.1 runtime supplied by Lupa, with mocked
game APIs and UI widgets. It covers learned spells, ranks, secure attributes,
protected values, combat deferral, food/water trade moves, reminders, preparation,
character settings, history persistence, dropdowns, and Ignite. It also checks
that native keybinding declarations match their secure buttons and labels.

These checks complement in-game testing; they cannot reproduce Blizzard's full
secure execution environment. The project owner tested in game after each
development release through version 0.8.0.

## Packaging

```sh
python tools/package-addon.py
```

This produces `dist/Arcanum-Forever-<version>.zip` and its SHA-256 checksum. It
uses an explicit runtime-file list, validates the TOC and archive contents, and
includes the MIT license and player README. It does not bundle tests, developer
dependencies, personal scripts, source-control files, or settings/backups.

Extract the ZIP into the Forever client's `Interface/AddOns` directory. Restart
the game when adding files or bindings; existing-file changes can use `/reload`.

## Implementation notes

The addon uses Blizzard secure templates for casting and item consumption.
Every cast requires player input, and Arcanum never confirms trades. Defer secure
action rebinding and circle layout changes until combat ends.

Treat protected game values as opaque. Pass protected numeric display values
directly to native formatting/widgets, and never perform arithmetic or branch on
them. When aura information cannot be identified safely, suppress the relevant
alert instead of inferring a buff or stack count.

Keep `ArcanumDB` character records and the `Arcanum` folder stable across updates
unless a deliberate migration is included. Use the selected version in the TOC
as the source of truth for packages.

`tools/generate-art.py` recreates the orb, mask, and ring assets without external
dependencies. The approved CurseForge logo is maintained separately in `branding`.
