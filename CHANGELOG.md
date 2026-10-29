# Changelog

All notable changes to CoolBarFrame are documented in this file.

## [Unreleased]

### Changed
- The addon no longer overwrites Blizzard's global `FindBaseSpellByID`
  (it is unused here and replacing a Blizzard global risks taint).

### Fixed
- Removing an icon from a bar now also resets its charge/stack badge scale,
  and restores the icon to the viewer's current icon scale instead of the
  scale captured the first time the icon was seen.
- A bar anchored to another bar kept its anchor only by luck: loading in,
  changing spec or changing talents placed bars one at a time, and a bar
  anchored to a bar created later was permanently reset to the screen
  centre. All bars now exist before any is placed, and a missing anchor
  target only places the bar temporarily without touching the saved anchor.
- Edit mode now follows the Cooldown Manager window through an explicit
  open/closed state instead of a toggle, so closing the window or the
  options frame during combat no longer leaves edit mode stuck on. The
  `ADDON_RESTRICTION_STATE_CHANGED` payload is honoured (combat and boss
  encounters), and `/cbm` during a restriction opens edit mode as soon as
  it ends.
- Opening and closing edit mode no longer calls Blizzard's cooldown viewer
  `Layout()` or fires its `CooldownViewerSettings.OnShow` event from addon
  code, which ran Blizzard's secret-value code tainted; the window is
  opened with `ShowUIPanel`/`HideUIPanel`. Icons removed from a bar return to
  the slot Blizzard last gave them.
- Spec and talent changes no longer close and reopen the Cooldown Manager
  window to rebuild the bars.
- Zoning or any loading screen no longer stacks another set of hooks and
  option widgets: edit mode toggled itself twice (the Cooldown Manager
  window closed right after opening) and the options frame accumulated
  duplicate controls. Setup now runs once; only the bars are rebuilt.
- A bar can no longer be anchored to itself or to a bar that depends on it
  through a longer chain (A to B to C to A). Typing or dragging such an
  anchor is rejected with a message, and a loop already in saved data is
  detached on load instead of raising `SetPoint` errors.
- Option edit boxes accept negative numbers and decimals (e.g. an offset of
  `-50`); invalid text restores the previous value.

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
