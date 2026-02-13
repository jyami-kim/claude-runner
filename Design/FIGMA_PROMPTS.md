# Figma AI Generation Prompts

아래 프롬프트를 Figma의 "Make designs" 또는 AI generation 기능에 붙여넣기하세요.
각 섹션별로 별도 프레임을 생성하는 것을 권장합니다.

---

## Prompt 1: Menu Bar Icon - All States (가로 신호등 아이콘 8종)

```
Design a macOS menu bar status icon showing a horizontal traffic light with 3 circles in a row.

Canvas: 72x36px (2x retina, renders as 36x18pt)
Background: transparent
Circle diameter: 20px (10pt) each
Circle spacing: 4px (2pt) gap between circles
Order left to right: Red, Yellow, Green

Colors:
- Red (Permission): #FF453A
- Yellow (Waiting): #FFD60A
- Green (Active): #30D158
- Dim state: same colors at 15% opacity

Create 8 icon variants side by side, each in its own frame (72x36px):

1. "Idle" - All 3 circles dim (15% opacity). No badges.
2. "Active x1" - Only green circle bright. Red and yellow dim.
3. "Waiting x1" - Only yellow circle bright. Red and green dim.
4. "Permission x1" - Only red circle bright. Yellow and green dim.
5. "Active x3 + Badge" - Green bright with a small black pill badge showing "3" in white above it. Red and yellow dim.
6. "Waiting x2 + Badge" - Yellow bright with badge "2". Red and green dim.
7. "Mixed: Red 1 + Yellow 2" - Red bright (no badge, count=1), Yellow bright with badge "2", Green dim.
8. "Mixed: All Active" - All 3 circles bright. Red badge "2", Yellow badge "3", Green badge "4".

Badge spec:
- Size: 18x18px pill shape (9x9pt), fully rounded corners
- Background: #000000 at 75% opacity
- Text: white, 14px bold (7pt), centered
- Position: top-right corner of the parent circle, slightly overlapping

Label each variant below the frame. Use a dark gray (#1C1C1E) background behind each icon to simulate the macOS menu bar.
```

---

## Prompt 2: Popover UI - Session List (세션 목록 팝오버)

```
Design a macOS NSPopover dropdown panel for a menu bar app called "claude-runner". This popover shows a list of active Claude Code sessions with their status.

Frame size: 260x280px
Style: Native macOS popover look, with subtle rounded corners, drop shadow, and the small arrow/triangle pointing up to the menu bar. Use system-like styling.

Layout (top to bottom):

1. HEADER (padding: 12px horizontal, 10px top, 6px bottom)
   - Text "claude-runner" in 13px semibold, primary text color

2. DIVIDER - thin 1px line, system gray

3. SESSION LIST (3 rows, each with 12px horizontal padding, 6px vertical padding)

   Row 1:
   - Red circle dot (8px diameter, #FF453A)
   - 8px gap
   - Text "web-frontend" in 12px medium weight, primary color
   - Right-aligned: "1m" in 11px monospace, secondary gray color

   Row 2:
   - Yellow circle dot (8px, #FFD60A)
   - 8px gap
   - Text "my-api-server" in 12px medium
   - Right: "15m" in 11px monospace, secondary

   Row 3:
   - Green circle dot (8px, #30D158)
   - 8px gap
   - Text "claude-runner" in 12px medium
   - Right: "2m" in 11px monospace, secondary

4. DIVIDER - thin 1px line

5. FOOTER (padding: 12px horizontal, 8px vertical)
   - Left: gear icon + "Settings" in 11px, secondary gray
   - Right: "⌘Q Quit" in 11px, secondary gray

Create TWO versions side by side:
- Left: Dark mode (dark background, light text)
- Right: Light mode (light background, dark text)

The rows should be sorted by priority: red (permission) first, then yellow (waiting), then green (active).
```

---

## Prompt 3: Popover UI - Empty State (빈 상태)

```
Design a macOS NSPopover dropdown panel for "claude-runner" showing an empty state when no Claude Code sessions are running.

Frame size: 260x180px
Style: Same native macOS popover as the session list version.

Layout:

1. HEADER (padding: 12px horizontal, 10px top, 6px bottom)
   - Text "claude-runner" in 13px semibold

2. DIVIDER

3. EMPTY STATE (centered, padding: 12px horizontal, 16px vertical)
   - Text "No active sessions" in 12px, secondary gray color
   - Horizontally centered

4. DIVIDER

5. FOOTER
   - Left: gear icon + "Settings" in 11px secondary
   - Right: "⌘Q Quit" in 11px secondary

Create TWO versions: dark mode and light mode.
```

---

## Prompt 4: Full App Context (전체 앱 시각화)

```
Create a mockup showing a macOS desktop with the menu bar app "claude-runner" in action.

Show:
1. The macOS menu bar at the top of the screen (dark bar)
2. In the menu bar's right section (near WiFi, battery icons), show a small horizontal traffic light icon with 3 tiny circles: red bright, yellow bright with a "2" badge, green dim
3. Below that icon, show an open popover/dropdown panel (260px wide) with:
   - Header: "claude-runner"
   - 3 session rows:
     * Red dot + "web-frontend" + "1m"
     * Yellow dot + "my-api-server" + "15m"
     * Yellow dot + "data-pipeline" + "8m"
   - Footer: "Settings" on left, "⌘Q Quit" on right
4. The popover has a small upward-pointing arrow connecting it to the menu bar icon

Style: Clean, minimal, native macOS look. Dark mode preferred.
Colors: Red #FF453A, Yellow #FFD60A, Green #30D158

This should look like a real screenshot of the app running on macOS.
```

---

## Prompt 5: Component Sheet (컴포넌트 정리)

```
Create a design component sheet for the "claude-runner" macOS menu bar app.

Organize in a clean grid layout:

SECTION 1: Color Palette
- 3 bright state colors with hex labels:
  Red (Permission): #FF453A
  Yellow (Waiting): #FFD60A
  Green (Active): #30D158
- 3 dim state colors (same colors at 15% opacity)
- Badge: #000000 at 75% opacity, text #FFFFFF

SECTION 2: State Dots (for popover rows)
- 3 circles, 8px each: red, yellow, green with labels

SECTION 3: Typography
- Header: 13px Semibold "claude-runner"
- Project name: 12px Medium "my-project"
- Elapsed time: 11px Monospace "15m"
- Footer: 11px Regular "Settings" / "⌘Q Quit"
- Empty state: 12px Regular "No active sessions"

SECTION 4: Icon States
- Show all 8 traffic light icon variants in a 2x4 grid with labels

SECTION 5: Spacing Reference
- Show key measurements: row padding (12px H, 6px V), dot-text gap (8px), circle diameter (10pt), circle spacing (2pt)

Use a clean white background with subtle grid lines. Label everything clearly.
```

---

## 사용법

1. Figma에서 새 페이지 생성 (예: "claude-runner designs")
2. Figma AI / "Make designs" 기능 열기
3. 위 프롬프트를 하나씩 붙여넣어 프레임 생성
4. 생성된 디자인을 리뷰하고 필요 시 수정
5. 완성되면 URL을 공유 → `get_design_context`로 코드 변환

### 프롬프트 우선순위
1. **Prompt 4** (Full App Context) - 전체 느낌 먼저 확인
2. **Prompt 1** (Icon States) - 핵심 아이콘 디자인
3. **Prompt 2** (Session List) - 메인 UI
4. **Prompt 3** (Empty State) - 보조 UI
5. **Prompt 5** (Component Sheet) - 정리용
