# MiniCompactRunes reference

## What it does

Tracks Death Knight runes and runic power in a simple flat-bar display: a runic power
bar at the bottom with a grid of 6 rune bars above it. Intended to sit near the
center of the screen so runes and runic power can be watched without looking at the
player frame.

The settings panel is built for every class, so the addon always shows up in
the AddOns list. The rune display itself stays Death Knight only: on any other
class the panel exists but no display is ever created, so its checkboxes and
sliders have nothing to affect.

## Facts

| Item | Value |
| --- | --- |
| Version | 2.2.7 |
| Author | Verz |
| Interface versions (TOC) | 120100, 50504, 40402, 38002, 38000, 30405 |
| Saved variables | MiniCompactRunesDB |
| Slash commands | /minicompactrunes, /minicr, /mcr (all open the settings panel) |
| Options location | Game options -> AddOns -> MiniCompactRunes |
| Bundled libraries | MiniFramework (author's shared framework) only |
| External dependencies | None |

## Features

### Runic power bar

- Sits at the bottom of the display. Blue fill, black background, 1 px black outline.
- Shows current runic power as a number centered on the bar when "Show text" is on.
- Updates from power events (UNIT_POWER_UPDATE, UNIT_DISPLAYPOWER).

### Rune bars

- 6 bars in a grid above the power bar. Grid shape comes from the "Columns" setting;
  rows are always 6 divided by columns (1 col = 6 rows, 2 = 3, 3 = 2).
- Bars are sorted by cooldown remaining, not by rune index. Ready runes group at the
  top-left; the most recently spent rune is the last bar (bottom-right).
- Ready runes are colored by spec: Blood dark red (0.51, 0, 0), Frost cyan
  (0, 0.99, 1), Unholy green (0.2, 0.8, 0.2). White if no spec is detected.
- Runes on cooldown fill up in the cooldown color (default light blue 0.2, 0.6, 1.0)
  and repaint 10 times per second while any rune is recharging; the timer stops when
  all runes are ready.

### Positioning and visibility

- Drag with the left mouse button to move; position is saved. Default position is
  bottom of the screen, 200 px up.
- "Locked" disables both dragging and mouse interaction.
- In combat the display uses full opacity (alpha 1.0). Out of combat it dims to
  alpha 0.3, or hides entirely if "Always show" is off.

## Settings

Single options panel, opened with /mcr or via Game options -> AddOns, built the
same way for every class. Its header carries a **Reset to Defaults** button,
which asks for confirmation and also moves the display back to its default
screen position.

| Setting | Type | Default | Range | Effect |
| --- | --- | --- | --- | --- |
| Always show | checkbox | on | - | Off: display hides completely out of combat. On: it stays visible but dimmed out of combat. |
| Show text | checkbox | on | - | Shows the runic power number on the power bar. |
| Locked | checkbox | off | - | Prevents dragging the display. |
| Power Width | slider | 120 | 50-800, step 10 | Width of the runic power bar. |
| Power Height | slider | 20 | 10-100 | Height of the runic power bar. |
| Runes Width | slider | 120 | 10-300 | Width of each rune bar. |
| Runes Height | slider | 20 | 10-100 | Height of each rune bar. |
| Power Gap | slider | 0 | 0-50 | Vertical gap between the rune grid and the power bar. |
| Runes Gap | slider | 6 | 0-20 | Gap between rune bars. |
| Columns | slider | 2 | 1-3 | Number of rune columns; rows adjust automatically (6 / columns). |

### Saved-variable-only values (no UI control)

These exist in MiniCompactRunesDB but have no options-panel control:

| Variable | Default | Purpose |
| --- | --- | --- |
| Scale | 1.0 | Overall scale of the display. |
| CombatAlpha | 1.0 | Opacity while in combat. |
| OutOfCombatAlpha | 0.3 | Opacity while out of combat (when "Always show" is on). |
| RuneCooldownRed / Green / Blue | 0.2 / 0.6 / 1.0 | Fill color of runes that are on cooldown. |

These have no options-panel control, so the Reset to Defaults button is the
only way to restore them from the UI.

## Version-gated behavior

- On Midnight (12.x) clients the settings panel cannot be opened during combat; the
  slash command prints "Can't do that during combat." instead. Pre-Midnight clients
  can open it in combat.
- No other behavior differs by patch, content type, or group size.

## Troubleshooting

| Symptom | Likely cause |
| --- | --- |
| Nothing shows at all | Character is not a Death Knight. The settings panel still exists, but no display is ever created outside that class. |
| Addon missing from the AddOns options list | Not expected on any class: the settings panel is built for every class now. |
| Display is faint / semi-transparent | You are out of combat; out-of-combat alpha defaults to 0.3. It returns to full opacity in combat. |
| Display disappears out of combat | "Always show" is unchecked. |
| Cannot drag the display | "Locked" is checked, or the display is currently hidden (out of combat with "Always show" off). |
| Rune color looks wrong / changed | Ready-rune color follows the current spec (Blood red, Frost cyan, Unholy green) and is not configurable in the UI. The cooldown fill color is only changeable via the RuneCooldownRed/Green/Blue saved variables. |
| Runes seem to be in the wrong order | Intentional: bars are sorted by remaining cooldown each update, not fixed per rune. |
| Slash command does not open options during a fight | Midnight clients block opening the settings panel in combat. |
