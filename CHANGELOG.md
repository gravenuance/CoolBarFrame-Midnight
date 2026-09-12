# Changelog

All notable changes to CoolBarFrame are documented in this file.

## [Unreleased]

## [0.3] - 2026-09-12

### Fixed
- `SetBarPoint`'s UIParent-recovery fallback (used when a bar's anchor
  target frame can't be found) added the bar's width/height instead of
  subtracting it, jumping the bar by its own size when it recovered.
- Charge/stack count badges scaled relative to an already-scaled parent
  icon, compounding quadratically with the bar scale slider instead of
  tracking it linearly.
- `ADDON_RESTRICTION_STATE_CHANGED` tried to force edit mode off on
  combat entry, but `ToggleEditMode`'s own combat guard silently
  no-opped it, leaving edit mode (and bar interactivity) on during
  combat.
- A bar entry loaded without an `icons` field could crash on load;
  `CoolBarDB` now goes through a real migration path instead of
  blindly stamping the schema version every load.

### Changed
- Calls that mutate Blizzard's own cooldown-viewer icon frames
  (`SetPoint`/`SetScale`/`SetAlpha`) are now wrapped in `pcall`, since
  Patch 12.1's `ManagedAuraContainer` rework can turn those into
  forbidden frames; an affected icon is now skipped instead of
  aborting the whole layout pass.
- Added Interface `120105` (Patch 12.1.5, PTR) alongside existing
  12.0.5 / 12.0.7 / 12.1 support.

## [0.2] - 2026-08-09

### Added
- `.gitignore` and `README.md`.

### Changed
- Repo hygiene cleanup; updated for Patch 12.1.

## [0.1] - 2026-03-31

### Added
- Initial core functionality: custom cooldown bars built from Blizzard's
  Essential, Utility, and Tracked Buffs Cooldown Manager icons, with
  per-bar scale, padding, orientation, and anchoring.
