# Changelog

All notable changes to CoolBarFrame are documented in this file.

## [Unreleased]

### Changed
- The options frame is rebuilt from Blizzard's own templates (panel frame,
  stepper sliders, input boxes, panel buttons) and opens beside the Cooldown
  Manager window until you move it. It is titled "CoolBarFrame", groups
  its controls under Layout, Position and Anchor, and uses the buttons
  "New bar" and "Delete bar". The help window, the in-frame hint, the
  update-notice box and the bottom Close button are gone; a shortcuts
  tooltip on the info icon replaces the help window.
- All option widgets are unnamed or named under `CoolBarFrameOptions`
  instead of generic globals such as `ScaleHandle` or `OrientationSwapper`,
  and the frame itself is now `CoolBarFrameOptions` (was `CBMOptionsFrame`).
- Saved data is now schema 2. Loading older data merges the full set of bar
  defaults into every saved bar without overwriting your values, detaches
  anchor loops, and keeps the pre-migration bars in `CoolBarDB.backup`. A
  migration that fails restores the bars and no longer stamps the new
  version.
- Cooldown viewer layout passes no longer allocate: bar icon lists are
  reused, no closure is created per icon, and the options frame is only
  refreshed while it is visible (it catches up when opened).
- Creating a bar during combat no longer calls the restricted
  `SetPropagateMouseClicks`; it is applied when combat ends, like the same
  call on Blizzard's icons.
- The addon no longer forces the cooldown viewers and Tracked Buffs icons
  visible from its own `UpdateShownState` hooks; with the Cooldown Manager
  window open (which edit mode now requires) Blizzard already shows them.
  Per-icon bookkeeping moved out of Blizzard's frame tables, and the click
  handler on icons is added with `HookScript` instead of replacing
  `OnMouseDown`.
- The addon no longer overwrites Blizzard's global `FindBaseSpellByID`
  (it is unused here and replacing a Blizzard global risks taint).

### Fixed
- Refreshing the options frame (selecting a bar, a layout pass, a loading
  screen) re-applied every shown value as if you had typed it, so selecting
  two bars with Shift copied the first bar's scale and padding onto the
  others. Refreshing now only redisplays; values are written only when you
  change a control. Controls that do not apply to a multi-bar selection are
  properly disabled (sliders, edit boxes and buttons), not just dimmed.
- Dropping a bar after a drag could turn a round offset such as `10` or
  `-50` into `1` or `-5`: the rounding helper stripped trailing zeros from
  whole numbers.
- A saved bar missing fields such as padding, scale or offsets (written by
  an older version) raised errors when the bars were built or laid out;
  every saved bar is now completed from the defaults on load.
- Rebuilding the bars (loading screen, spec or talent change) left the
  icon-to-bar lookup pointing at released bars and queued no layout, so
  icons stayed where they were until Blizzard next laid a viewer out. The
  lookup is cleared and a layout is queued.
- Releasing the mouse after a bar drag while holding Shift, Ctrl or Alt left
  the bar stuck to the cursor; the drag now always ends on release.
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
- Releasing an anchor-handle drag over empty space or with a modifier held
  left the blue anchor line following the cursor.

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
