# Release 0.8.0

- Project: Arcanum Forever.
- Addon folder: Arcanum.
- Target: WoW: Forever 1.60.1, interface 16001.
- License: MIT, copyright 2026 Alfonso.
- Release classification: Beta.
- Project avatar: `branding/arcanum-forever-logo.png` (1254 × 1254 PNG).

## Validation

On October 3, 2026, the project owner confirmed in-game testing after every
development release through 0.8.0. This is owner-reported validation; automated
checks do not substitute for live gameplay.

The automated suite passes 236 behavioral checks and validates 10 native
keybindings. Package validation checks paths, exact file contents, TOC load files,
license inclusion, and ZIP integrity.

## Deliverables

- Player install: `dist/Arcanum-Forever-0.8.0.zip`.
- Checksum: `dist/Arcanum-Forever-0.8.0.zip.sha256`.
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
