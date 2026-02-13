# App Icon - Figma AI Generation Prompts

4가지 앱 아이콘 컨셉. 각각 Figma Make에 입력하세요.

---

## Concept 1: 클래식 신호등

```
Design a macOS app icon (512x512px) for a developer tool called "claude-runner".

Shape: macOS Big Sur style rounded squircle (superellipse, corner radius ~110px)

Background:
- Dark gradient from #1C1C1E (top-left) to #2C2C2E (bottom-right)
- Subtle inner shadow along the top edge for a glass-like depth effect
- Outer drop shadow: 0 4px 12px rgba(0,0,0,0.4)

Main element: Three horizontally aligned glowing circles centered in the icon
- Left circle: Red #FF453A
- Center circle: Yellow #FFD60A
- Right circle: Green #30D158
- Each circle diameter: ~90px
- Gap between circles: ~24px
- All three circles should glow brightly with:
  - Radial gradient within each circle (lighter center, slightly darker edge)
  - Soft outer glow/bloom effect in matching color (spread ~15px, opacity 30%)
  - Small white specular highlight near top-left of each circle (10% opacity)

Optional: A very subtle dark metallic horizontal bar behind the circles (#3A3A3C, height ~110px, rounded corners ~20px) to suggest a traffic light housing. Keep it minimal and barely visible.

Style: Premium, clean, native macOS feel. No text. The three colored circles should be the hero element, glowing against the dark background like real traffic lights at night.
```

---

## Concept 2: 미니멀 네온 도트

```
Design a macOS app icon (512x512px) for a developer tool called "claude-runner".

Shape: macOS Big Sur style rounded squircle (superellipse, corner radius ~110px)

Background:
- Near-black solid color #0D0D0F
- Very subtle radial gradient from center: #141416 in the middle fading to #0D0D0F at edges

Main element: Three small neon-glowing dots arranged horizontally in the center
- Left dot: Red #FF453A, diameter ~50px
- Center dot: Yellow #FFD60A, diameter ~50px
- Right dot: Green #30D158, diameter ~50px
- Gap between dots: ~40px
- The dots should appear to float in darkness

Neon glow effect for each dot:
- Inner core: bright, almost white center
- Middle: the saturated color
- Outer glow: large soft bloom in matching color, spread ~40px, opacity ~25%
- The glow should blend and slightly overlap between adjacent dots
- Overall feeling: neon signs in a dark room

Style: Ultra-minimal, moody, cinematic. Dark and elegant. The three tiny glowing dots against vast darkness. No text, no other decoration. Think of it as the menu bar icon enlarged into an artistic icon.
```

---

## Concept 3: Claude + 신호등 융합

```
Design a macOS app icon (512x512px) for a developer tool called "claude-runner" that bridges Claude AI and code monitoring.

Shape: macOS Big Sur style rounded squircle (superellipse, corner radius ~110px)

Background:
- Warm gradient inspired by Claude AI's brand colors
- Top-left: #D4A574 (warm tan/copper)
- Bottom-right: #8B5E3C (deeper brown)
- Subtle noise texture overlay at 3% opacity for organic feel

Main element: Three horizontally aligned circles in the lower-center area of the icon
- Left circle: Red #FF453A, diameter ~70px
- Center circle: Yellow #FFD60A, diameter ~70px
- Right circle: Green #30D158, diameter ~70px
- Gap between circles: ~18px
- Each circle has a thin dark outline (#00000020) and subtle inner shadow
- Circles sit on a subtle dark shelf/bar (#00000030, rounded rectangle behind them)

Above the circles: A subtle abstract symbol suggesting AI/code
- Option A: A minimal terminal cursor "▌" in white at ~40% opacity, centered above the dots
- Option B: A small sparkle/star symbol (like Claude's) in white at ~30% opacity
- Keep it very subtle - the traffic light dots are the main focus

Style: Warm, friendly, premium. The Claude-inspired warm tones combined with the cool traffic light colors create an interesting contrast. Should feel like a natural extension of the Claude ecosystem.
```

---

## Concept 4: 터미널 윈도우 신호등

```
Design a macOS app icon (512x512px) for a developer tool called "claude-runner".

Shape: macOS Big Sur style rounded squircle (superellipse, corner radius ~110px)

Background:
- Dark terminal-style background
- Main fill: #1E1E2E (deep blue-gray, like a modern terminal theme)
- Subtle vertical scanline texture at 2% opacity for retro terminal feel

Main element: A stylized macOS window title bar with traffic light buttons, but enlarged and heroic

Window frame (centered, ~380px wide, ~280px tall):
- Background: #2D2D3D with 1px border #3D3D4D
- Top bar: 40px tall, slightly lighter #353545
- Corner radius: 14px (top) / 8px (bottom)

Traffic light buttons in the top-left of the window frame:
- Arranged horizontally with ~12px gap
- Left: Red circle #FF453A, diameter ~36px
- Center: Yellow circle #FFD60A, diameter ~36px
- Right: Green circle #30D158, diameter ~36px
- Each with subtle inner shadow and a tiny white highlight dot
- Position: 16px from left edge, vertically centered in the title bar

Inside the window body (below the title bar):
- 3-4 lines of "code" represented as subtle horizontal bars
- Bar colors: #4D4D5D at varying widths (60%, 80%, 45%, 70% of window width)
- Bars height: 6px, corner radius: 3px, vertical gap: 10px
- One of the bars should be green-tinted (#30D158 at 20% opacity) to suggest active code execution
- A blinking cursor "▌" in #30D158 at the end of the last bar

Style: Developer-focused, recognizable macOS window metaphor. The traffic light buttons are the familiar close/minimize/expand buttons that every Mac developer knows, but here they represent session states. Clean and technical.
```

---

## 사용법

1. [Figma Make](https://www.figma.com/make/7rFnbVZPDLgD0wNuOFEpjZ/macOS-Traffic-Light-Icon) 열기
2. 4개 프롬프트를 하나씩 입력
3. 생성된 4개 아이콘 비교 후 최종 선택
4. 선택한 아이콘을 512x512px PNG로 export
5. `iconutil` 또는 온라인 도구로 `.icns` 변환
6. `Resources/AppIcon.icns`에 저장 후 `./install.sh` 재실행
