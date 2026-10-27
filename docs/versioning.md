# Versions and compatibility

[`version.json`](../version.json) is the only editable source of version
numbers. Godot reads it through `DataVersion`; Convex imports the same file
through `dataVersion.ts`. It is explicitly packaged in the Web export.

| Setting | Current value | Meaning |
| --- | --- | --- |
| `release` | `1.0.0` | First release recorded in the changelog |
| `data_version` | `3` | Version written to every new save, level, and replay |
| `oldest_readable_data_version` | `1` | Oldest supported persisted data |
| `legacy_data_version` | `1` | Version of historical formats without a tag |

Release numbers and data versions serve different purposes. UI changes can
ship in a new release without changing the persisted schema. Increment the
data version when stored fields, object layouts, or replay interpretation
change. Do not duplicate these numbers in codec implementations.

## Stored formats

| Data | Container | Version location |
| --- | --- | --- |
| Campaign saves and backups | Binary `CPS1` | Compressed JSON `v` |
| Full world snapshots | Binary `CPP1` | Compressed JSON `v` |
| Packed editor levels | `CPE3:` | First two decoded bytes, unsigned little endian |
| Community levels | `CPE2:` | Compressed JSON `v`; embedded packed level is also checked |
| Replays | `CPR1:` | Compressed JSON `v`; embedded community/packed level is also checked |

Container names identify their wire layouts, not the game release or current
data version. CPE2 was already the metadata container, so the new explicitly
versioned packed layout uses CPE3. Its remaining bytes are the original CPE1
header and compressed cells, adding only two bytes before Base64 encoding.

Existing CPS1/CPP1/CPR1 payloads with `v: 1`, CPE1 packed levels, and CPE2
metadata without `v` remain readable. Versions 1 and 2 have the same gameplay
fields; version 2 makes tagging consistent across all containers. Legacy input
is upgraded when written again; importing or inspecting it does not rewrite
the source file. Version 3 assigns previously unused solid nibbles 7–14 to
Q platforms, one-way/pass through blocks, portal symbols, and default lightning.
Versions 1–2 retain their previous nibble validation. The header and compression
layout remain unchanged. New replay input adds Q recall in bit 5 (held) and
bit 13 (pressed); old input bits and state fields retain their meaning.
Unknown, malformed, and unsupported versions are rejected.
Support in the new reader does not make new files readable by older builds.
Opening an unsupported-version save or draft shows an explanation and Back;
it does not replace the file with a fresh game or an empty draft.

Changing only the version header does not constitute changing a puzzle.
Convex compares the original packed body when deciding whether likes and
replays need resetting and when validating an older run after an upgrade.
No bulk rewrite of existing cloud records is needed.

## For each future version

1. Record every substantive change under `Unreleased` in
   [`CHANGELOG.md`](../CHANGELOG.md), including fixes, formats, backend,
   packaging, and documentation. Move those entries to a dated release section
   and update `release` when preparing a release. Do not invent earlier history.
2. If persisted data changes, increase `data_version` and implement explicit
   migrations/readers for earlier supported versions in Godot and Convex.
   Never merely raise the accepted range if old fields need conversion.
   Keep `legacy_data_version` fixed; avoid dropping older read support.
3. Keep historical fixtures unchanged and add fixtures for the new version.
   Check current writes, old reads, nested versions, malformed/future versions,
   puzzle identity across upgrades, and save/replay behavior.
4. Run native compatibility checks and backend tests, then export and test in
   the browser to catch missing shared resources. Deploy compatible readers
   to Convex before releasing a client that writes the new format.

Validation commands from the repository root:

```powershell
./Godot_v4.7.2-stable_win64.exe --headless --path . --script tools/test_data_versions.gd
```

Run `npm.cmd run typecheck` and `npm.cmd test` in `backend`. The backend
`versioned-v2.json` fixture contains real Godot-generated data; the original
`godot.json` fixture remains unchanged. The `custom-v3.json` fixture adds
extended packed objects and a replay containing Q input. Use the HTML5 validation workflow in
the root README for exported-browser verification.
