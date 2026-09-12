# CoolBarFrame (Cooldown Bar Manager)

CoolBarFrame lets you build your own custom cooldown bars out of icons pulled
from Blizzard's built-in Cooldown Manager (the Essential, Utility, and Tracked
Buffs viewers). Instead of being stuck with Blizzard's fixed groupings, you
can mix and match any cooldown or buff icon onto any number of bars, position
each bar independently (or anchor bars to one another), and tweak scale,
padding, and orientation per bar.

Supports retail WoW 12.0.5, 12.0.7, 12.1, and 12.1.5 (PTR).

## Usage

- `/cbm` — toggle edit mode (also opens automatically alongside Blizzard's
  Cooldown Manager editor).
- `/cbm new` — create a new bar.
- `/cbm delete` — delete the currently focused/selected bar(s).
- `/cbm reset` — reset `customBar0` back to the screen center.

While in edit mode:

- **Ctrl + Left Click** an icon to add or remove it from the focused bar.
- **Alt + Left Click** an icon, then Alt + Left Click a destination, to move
  or swap it to another bar/slot.
- **Shift + Left Click** a bar to multi-select it alongside others.
- **Drag** a bar to reposition it, or drag from one of its edge/corner
  handles to anchor it to another bar.

Bar layout, position, scale, and icon assignments are saved per account in
`CoolBarDB` and persist across characters and specs.
