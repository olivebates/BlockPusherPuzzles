# Versioning and change history

- Keep a record of every substantive code, behavior, format, backend, build,
  and documentation change in `CHANGELOG.md` from now on. Add entries under
  `Unreleased`; group them into dated versions when preparing a release.
- `version.json` is the single source of truth for release and data versions.
  Godot and Convex must read it rather than duplicating version numbers.
- Bump `data_version` when persisted layouts or replay interpretation changes.
  A game release can change without a data-version bump.
- Keep older readable formats supported. Add explicit migrations when their
  fields change, update both Godot and Convex readers, and add regression tests
  before raising the current version. Do not silently reinterpret future data.
- Preserve historical compatibility fixtures; add new fixtures alongside them.
- Update the changelog with compatibility effects and required deployment or
  migration steps whenever versions change.
