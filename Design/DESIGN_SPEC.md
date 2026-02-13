# claude-runner Design Specification

**Version:** 1.0
**Date:** 2026-02-13
**Status:** Draft for review

---

## Table of Contents

1. [Color Palette](#1-color-palette)
2. [Menu Bar Icon: Horizontal Traffic Light](#2-menu-bar-icon-horizontal-traffic-light)
3. [Popover Session List](#3-popover-session-list)
4. [Icon State Matrix](#4-icon-state-matrix)
5. [Implementation Notes](#5-implementation-notes)

---

## 1. Color Palette

### State Colors (Bright -- active state)

| State      | NSColor Name   | Hex       | RGB               | Usage                  |
|------------|----------------|-----------|-------------------|------------------------|
| Red        | Custom         | `#FF453A` | (255, 69, 58)     | Permission needed      |
| Yellow     | Custom         | `#FFD60A` | (255, 214, 10)    | Waiting for user input |
| Green      | Custom         | `#30D158` | (48, 209, 88)     | Actively working       |

> These match Apple's system accessibility-optimized colors (iOS/macOS dark-mode palette),
> chosen for strong contrast against the dark menu bar.

### State Colors (Dim -- inactive state)

Each bright color at **alpha 0.15**, rendered over the menu bar background:

| State      | Hex (approx on dark bg) | Alpha | Usage               |
|------------|------------------------|-------|---------------------|
| Red dim    | `#FF453A` @ 0.15       | 0.15  | No permission sessions |
| Yellow dim | `#FFD60A` @ 0.15       | 0.15  | No waiting sessions    |
| Green dim  | `#30D158` @ 0.15       | 0.15  | No active sessions     |

### Popover Colors

| Element              | Light Mode        | Dark Mode         |
|----------------------|-------------------|-------------------|
| Background           | System (default)  | System (default)  |
| Header text          | `.primary`        | `.primary`        |
| Project name         | `.primary`        | `.primary`        |
| Elapsed time         | `.secondary`      | `.secondary`      |
| Footer text/icons    | `.secondary`      | `.secondary`      |
| Dividers             | System default    | System default     |
| Empty state text     | `.secondary`      | `.secondary`      |

> SwiftUI `NSPopover` inherits system appearance automatically.
> No custom background colors needed.

### Badge Colors

| Element         | Value                         |
|-----------------|-------------------------------|
| Badge bg        | `#000000` @ alpha 0.75        |
| Badge text      | `#FFFFFF` (white)             |
| Badge border    | None                          |

### Session Row State Dot Colors (Popover)

Matches the bright state colors above, at full alpha:

| State      | SwiftUI Color                            |
|------------|------------------------------------------|
| Active     | `Color(red: 0.19, green: 0.82, blue: 0.35)` -- #30D158 |
| Waiting    | `Color(red: 1.0, green: 0.84, blue: 0.04)`  -- #FFD60A |
| Permission | `Color(red: 1.0, green: 0.27, blue: 0.23)`  -- #FF453A |

---

## 2. Menu Bar Icon: Horizontal Traffic Light

### Canvas & Dimensions

```
Total canvas:  36pt x 18pt   (NSStatusItem length = 38pt to add 1pt padding each side)
Circle radius:  5.0pt        (diameter = 10pt)
Circle spacing: 2.0pt        (gap between circle edges)

Total circle strip width = 3 * 10 + 2 * 2 = 34pt
Horizontal centering offset = (36 - 34) / 2 = 1pt

Vertical centering: circleY = (18 - 10) / 2 = 4pt
```

### Layout Diagram

```
         1pt                                     1pt
         |                                        |
         v                                        v
    ┌────────────────────────────────────────────────┐
    |                    36pt                         |  18pt
    |                                                 |
    |   ┌──────┐  2pt  ┌──────┐  2pt  ┌──────┐      |
    |   | RED  |  gap   | YEL  |  gap   | GRN  |     |
    |   | 10pt |        | 10pt |        | 10pt |     |
    |   └──────┘        └──────┘        └──────┘     |
    |                                                 |
    └─────────────────────────────────────────────────┘

    Circle centers (from left edge of canvas):
      Red center:    x=6,  y=9
      Yellow center: x=18, y=9
      Green center:  x=30, y=9
```

### Circle Coordinates (NSRect, origin bottom-left)

| Circle  | Origin (x, y) | Size        |
|---------|----------------|-------------|
| Red     | (1, 4)         | (10, 10)    |
| Yellow  | (13, 4)        | (10, 10)    |
| Green   | (25, 4)        | (10, 10)    |

### Badge Specifications

Badges appear when a state has **2 or more** sessions.

```
Badge dimensions:
  Height:     9pt
  Min width:  9pt (circular for single digit)
  Padding:    1.5pt horizontal padding around text
  Corner radius: 4.5pt (fully rounded = capsule)

Badge position:
  Anchored to top-right of the parent circle
  badgeX = circle.maxX - badgeWidth/2
  badgeY = circle.maxY - badgeHeight/2

Badge text:
  Font:   System bold, 7pt
  Color:  White (#FFFFFF)
  Align:  Centered in badge rect
```

Badge position diagram:

```
              ┌───┐
              │ 3 │  <-- badge (9pt tall, min 9pt wide)
        ┌─────┴─┬─┘
        │       │
        │  GRN  │  <-- state circle (10pt diameter)
        │       │
        └───────┘
```

### isTemplate

`image.isTemplate = false`

The icon uses custom colors (red, yellow, green) that must render as-is. Setting
`isTemplate = true` would cause macOS to render the image as a monochrome mask,
which would lose all color information.

---

## 3. Popover Session List

### Popover Container

```
Width:           260pt (fixed)
Max height:      ~360pt (header ~36pt + scroll area 300pt max + footer ~32pt)
Behavior:        .transient (closes on outside click)
Preferred edge:  .minY (below the menu bar button)
```

### Layout Structure

```
┌──────────────────────────────────────────┐
│                                          │
│  claude-runner                           │  Header: 13pt semibold, .primary
│                                          │  Padding: H=12, T=10, B=6
├──────────────────────────────────────────┤  Divider (system)
│                                          │
│  ● claude-runner                    2m   │  Row: dot 8pt + name 12pt med + time 11pt mono
│  ● my-api-server                   15m   │  Row padding: H=12, V=6
│  ● web-frontend                     1m   │  Dot-to-name spacing: 8pt
│                                          │
├──────────────────────────────────────────┤  Divider (system)
│                                          │
│  gear Settings                ⌘ Quit     │  Footer: 11pt, .secondary
│                                          │  Padding: H=12, V=8
└──────────────────────────────────────────┘
```

### Header

| Property        | Value                               |
|-----------------|-------------------------------------|
| Text            | "claude-runner"                     |
| Font            | `.system(size: 13, weight: .semibold)` |
| Color           | `.primary`                          |
| Padding top     | 10pt                                |
| Padding bottom  | 6pt                                 |
| Padding horiz   | 12pt                                |

### Session Row

| Property           | Value                                  |
|--------------------|----------------------------------------|
| State dot diameter | 8pt                                    |
| State dot color    | Bright state color (see palette)       |
| Dot-to-text gap    | 8pt                                    |
| Project name font  | `.system(size: 12, weight: .medium)`   |
| Project name color | `.primary`                             |
| Project name lines | 1, truncation: `.middle`               |
| Elapsed time font  | `.system(size: 11, design: .monospaced)` |
| Elapsed time color | `.secondary`                           |
| Row padding horiz  | 12pt                                   |
| Row padding vert   | 6pt                                    |
| Hover cursor       | `.pointingHand`                        |

Row layout: `HStack(spacing: 8) { dot, name, Spacer(), elapsed }`

### Empty State

| Property   | Value                                  |
|------------|----------------------------------------|
| Text       | "No active sessions"                   |
| Font       | `.system(size: 12)`                    |
| Color      | `.secondary`                           |
| Alignment  | Centered (`.frame(maxWidth: .infinity, alignment: .center)`) |
| Padding H  | 12pt                                   |
| Padding V  | 16pt                                   |

### Footer

| Property        | Value                               |
|-----------------|-------------------------------------|
| Layout          | `HStack { settings, Spacer(), quit }` |
| Settings icon   | SF Symbol `gear`                    |
| Settings label  | "Settings"                          |
| Settings font   | `.system(size: 11)`                 |
| Quit label      | "⌘ Quit" (using ⌘ glyph)           |
| Quit font       | `.system(size: 11)` (⌘ at size 10) |
| Color           | `.secondary`                        |
| Button style    | `.plain`                            |
| Padding horiz   | 12pt                                |
| Padding vert    | 8pt                                 |

---

## 4. Icon State Matrix

Below are ASCII representations of all 8 icon states. Circles are shown as
`( )` for dim and `(X)` for bright, where X = R/Y/G.

### a) Idle -- All dim, no sessions

```
    ┌──────────────────────────────────────┐
    │   ( )    ( )    ( )                  │  All circles at alpha 0.15
    └──────────────────────────────────────┘
    StateCounts: active=0, waiting=0, permission=0
```

### b) Active (1 session) -- Green bright only

```
    ┌──────────────────────────────────────┐
    │   ( )    ( )    (G)                  │  Green at alpha 1.0, others 0.15
    └──────────────────────────────────────┘
    StateCounts: active=1, waiting=0, permission=0
```

### c) Waiting (1 session) -- Yellow bright only

```
    ┌──────────────────────────────────────┐
    │   ( )    (Y)    ( )                  │  Yellow at alpha 1.0, others 0.15
    └──────────────────────────────────────┘
    StateCounts: active=0, waiting=1, permission=0
```

### d) Permission (1 session) -- Red bright only

```
    ┌──────────────────────────────────────┐
    │   (R)    ( )    ( )                  │  Red at alpha 1.0, others 0.15
    └──────────────────────────────────────┘
    StateCounts: active=0, waiting=0, permission=1
```

### e) Active (3 sessions) -- Green bright + badge "3"

```
    ┌──────────────────────────────────────┐
    │                              [3]     │  Badge: 7pt bold white on black pill
    │   ( )    ( )    (G)                  │  Green at alpha 1.0
    └──────────────────────────────────────┘
    StateCounts: active=3, waiting=0, permission=0
    Note: Badge appears only when count >= 2
```

### f) Waiting (2 sessions) -- Yellow bright + badge "2"

```
    ┌──────────────────────────────────────┐
    │               [2]                    │  Badge on yellow circle
    │   ( )    (Y)    ( )                  │  Yellow at alpha 1.0
    └──────────────────────────────────────┘
    StateCounts: active=0, waiting=2, permission=0
```

### g) Mixed: Red 1 + Yellow 2

```
    ┌──────────────────────────────────────┐
    │               [2]                    │  Badge on yellow only (count=2)
    │   (R)    (Y)    ( )                  │  Red at 1.0, yellow at 1.0, green dim
    └──────────────────────────────────────┘
    StateCounts: active=0, waiting=2, permission=1
    Note: Red has count=1, so no badge. Yellow has count=2, so badge "2".
```

### h) Mixed: All states active

```
    ┌──────────────────────────────────────┐
    │   [2]    [3]    [4]                  │  Badges on all three
    │   (R)    (Y)    (G)                  │  All circles at alpha 1.0
    └──────────────────────────────────────┘
    StateCounts: active=4, waiting=3, permission=2
    All counts >= 2 so all have badges.
```

---

## 5. Implementation Notes

### Current Code vs. This Spec

The existing implementation at `Sources/Extensions/NSImage+TrafficLight.swift` closely
matches this specification. Key values already in place:

| Property             | Current Code         | This Spec            | Match? |
|----------------------|----------------------|----------------------|--------|
| Canvas size          | 36 x 18             | 36 x 18             | Yes    |
| Circle diameter      | 10pt (radius 5)     | 10pt (radius 5)     | Yes    |
| Circle spacing       | 2pt                  | 2pt                  | Yes    |
| Dim alpha            | 0.15                 | 0.15                 | Yes    |
| Red color            | (1.0, 0.27, 0.23)   | (1.0, 0.27, 0.23)   | Yes    |
| Yellow color         | (1.0, 0.8, 0.0)     | (1.0, 0.84, 0.04)   | ADJUST |
| Green color          | (0.3, 0.85, 0.4)    | (0.19, 0.82, 0.35)  | ADJUST |
| Badge font           | 7pt bold             | 7pt bold             | Yes    |
| Badge bg             | black @ 0.75        | black @ 0.75         | Yes    |
| Badge text           | white                | white                | Yes    |
| Badge threshold      | count >= 2           | count >= 2           | Yes    |
| isTemplate           | false                | false                | Yes    |
| StatusItem length    | 38                   | 38                   | Yes    |

### Recommended Color Adjustments

The spec recommends switching to Apple's HIG-aligned accessible colors for better
recognition on both light and dark menu bars:

**Yellow:** Change from `(1.0, 0.8, 0.0)` to `(1.0, 0.84, 0.04)` -- slightly
warmer, matches Apple's `.systemYellow` dark variant (#FFD60A).

**Green:** Change from `(0.3, 0.85, 0.4)` to `(0.19, 0.82, 0.35)` -- matches
Apple's `.systemGreen` dark variant (#30D158).

These are subtle adjustments. The current colors are already good and the change
is optional.

### Popover Session Row Colors

The `SessionRow` in `SessionListView.swift` currently uses:
- Active: `Color(red: 0.3, green: 0.85, blue: 0.4)` -- should match icon green
- Waiting: `Color(red: 1.0, green: 0.8, blue: 0.0)` -- should match icon yellow
- Permission: `Color(red: 1.0, green: 0.27, blue: 0.23)` -- already matches icon red

Recommendation: Extract these into a shared `DesignTokens` enum or extension so
the menu bar icon and popover rows always use the same colors.

### Accessibility Considerations

1. The tooltip on the status item already provides state counts for screen readers.
2. Session rows should include `.accessibilityLabel` combining state + project name.
3. Color is not the sole indicator -- the positional encoding (left=red, center=yellow,
   right=green) provides a secondary signal for colorblind users.
4. Consider adding an option (Phase 2) for a high-contrast mode with outlined circles
   or distinct shapes (square/triangle/circle) for each state.

### Dark Menu Bar Appearance

macOS always renders the menu bar with a dark vibrancy material. The chosen colors
(bright against alpha-15 dim) provide strong contrast in this context. If Apple ever
introduces a light menu bar variant, the `isTemplate = false` approach would need
revisiting -- but this is not a current concern.

### Retina / Scale Factors

`NSImage` drawing blocks automatically handle @2x rendering. No explicit @2x assets
are needed. The coordinates above are in points, not pixels.

---

## Appendix: Full Popover Mockup (ASCII)

### With Sessions (3 sessions, sorted by priority)

```
    ┌───────────────────────────────┐
    │                               │
    │  claude-runner                │  13pt semibold
    │                               │
    ├───────────────────────────────┤
    │                               │
    │  ●  web-frontend         1m   │  Red dot (permission)
    │                               │
    │  ●  my-api-server       15m   │  Yellow dot (waiting)
    │                               │
    │  ●  claude-runner        2m   │  Green dot (active)
    │                               │
    ├───────────────────────────────┤
    │                               │
    │  gear Settings      ⌘ Quit    │  11pt secondary
    │                               │
    └───────────────────────────────┘

    Width: 260pt fixed
    Row height: ~24pt (6pt top + 12pt content + 6pt bottom)
```

### Empty State

```
    ┌───────────────────────────────┐
    │                               │
    │  claude-runner                │
    │                               │
    ├───────────────────────────────┤
    │                               │
    │                               │
    │     No active sessions        │  12pt secondary, centered
    │                               │
    │                               │
    ├───────────────────────────────┤
    │                               │
    │  gear Settings      ⌘ Quit    │
    │                               │
    └───────────────────────────────┘
```

---

## Appendix: Color Swatch Reference

```
    STATE COLORS (BRIGHT)

    Red (Permission)     ████████  #FF453A  rgb(255, 69, 58)
    Yellow (Waiting)     ████████  #FFD60A  rgb(255, 214, 10)
    Green (Active)       ████████  #30D158  rgb(48, 209, 88)

    STATE COLORS (DIM, alpha 0.15 over dark background)

    Red dim              ░░░░░░░░  #FF453A @ 15%
    Yellow dim           ░░░░░░░░  #FFD60A @ 15%
    Green dim            ░░░░░░░░  #30D158 @ 15%

    BADGE

    Badge background     ████████  #000000 @ 75%
    Badge text           ████████  #FFFFFF
```

---

*End of design specification.*
