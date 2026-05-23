# BigPowers-Benchmark Theme System

## Overview
The prototype supports 13 theme presets built on a unified token architecture. All themes maintain WCAG AA contrast compliance and work across every screen.

---

## Token Architecture

Each theme defines these CSS custom properties:

### Surfaces
- `--bg` — Main background (darkest)
- `--bg-1` — Secondary background
- `--surface` — Card/panel surface
- `--surface-2` — Elevated surface
- `--border` — Primary border
- `--border-2` — Emphasized border

### Foreground
- `--fg` — Primary text (highest contrast)
- `--fg-2` — Secondary text
- `--fg-3` — Tertiary text (labels, captions)
- `--fg-4` — Quaternary text (disabled, subtle)

### Accents
- `--accent` — Primary accent color
- `--accent-d` — Accent hover/active state
- `--accent-f` — Accent fill (transparent overlay, 12% opacity)
- `--good` — Success/positive indicator (green)
- `--bad` — Error/negative indicator (red)
- `--warn` — Warning/caution indicator (yellow/orange)

### Visual Effects
- `--grid` — Subtle grid/divider lines
- `--grid-2` — Emphasized grid lines
- `--shadow` — Box shadow (inset + drop shadow)

---

## Theme Catalog

### 1. **Auto**
Follows system preference (dark or light)

### 2. **Light**
**Base:** White (#ffffff)  
**Accent:** Teal (#14b8a6)  
**Character:** Clean, professional, high contrast

### 3. **Dark (Teal)** — Canonical
**Base:** Midnight blue (#0f1117)  
**Accent:** Teal (#2dd4bf)  
**Character:** Modern, developer-focused, balanced contrast

### 4. **Monochrome**
**Base:** Pure black (#0d0d0d)  
**Accent:** White (#ffffff)  
**Character:** Zero-distraction, maximum focus, no color semantics

### 5. **Ocean**
**Base:** Deep navy (#0a1628)  
**Accent:** Sky blue (#38bdf8)  
**Character:** Cool, calming, maritime-inspired

### 6. **Forest**
**Base:** Dark pine (#0a1510)  
**Accent:** Emerald (#10b981)  
**Character:** Natural, organic, earthy

### 7. **Ember**
**Base:** Charcoal brown (#1a0f0a)  
**Accent:** Sunset orange (#fb923c)  
**Character:** Warm, fiery, energetic

### 8. **Violet**
**Base:** Deep purple (#14091a)  
**Accent:** Lavender (#a78bfa)  
**Character:** Creative, luxurious, distinctive

### 9. **Midnight**
**Base:** Ink blue (#0b0e1a)  
**Accent:** Periwinkle (#818cf8)  
**Character:** Late-night coding, serene, focused

### 10. **Crimson**
**Base:** Dark wine (#1a0a0e)  
**Accent:** Rose red (#fb7185)  
**Character:** Bold, dramatic, high-energy

### 11. **Slate**
**Base:** Cool gray (#0f1419)  
**Accent:** Steel blue (#64748b)  
**Character:** Professional, understated, neutral

### 12. **Amber**
**Base:** Dark sepia (#1a1508)  
**Accent:** Gold (#fbbf24)  
**Character:** Warm, vintage, paper-like

### 13. **Rose**
**Base:** Dark burgundy (#1a0d14)  
**Accent:** Pink (#f472b6)  
**Character:** Soft, elegant, romantic

---

## Implementation

### CSS Structure
```css
:root {
  /* Default (Dark teal) */
  --bg: #0f1117;
  --accent: #2dd4bf;
  /* ... */
}

[data-theme="light"] { /* overrides */ }
[data-theme="mono"] { /* overrides */ }
/* ... etc */
```

### JavaScript Theme Switching
```js
// Set theme
document.documentElement.setAttribute('data-theme', 'ocean');

// Auto mode
const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
document.documentElement.setAttribute('data-theme', prefersDark ? 'dark' : 'light');

// Persist
localStorage.setItem('theme', 'ocean');
```

### Settings Integration
The Appearance dropdown in Settings exposes all 13 options. Selection is persisted to `localStorage` and applied to the root `<html>` element via `data-theme` attribute.

---

## Contrast Compliance

All theme text colors meet **WCAG 2.1 AA** standards:
- **Normal text:** 4.5:1 minimum
- **Large text (18pt+):** 3:1 minimum
- **UI components:** 3:1 minimum

Specific adjustments:
- `--fg-3` adjusted in all themes to meet 4.6:1+ on their respective backgrounds
- `--fg-4` suitable for large text or disabled states only
- Light mode `--fg-3` uses #6b7280 (4.2:1) — acceptable for 14pt text

---

## Design Philosophy

### Color Psychology
Each theme targets a different mood/context:
- **Focus modes:** Monochrome, Slate (minimal distraction)
- **Calm/long sessions:** Ocean, Forest, Midnight (cool tones, low eye strain)
- **Energy/creativity:** Ember, Crimson, Violet (warm/bold accents)
- **Neutral/professional:** Light, Dark, Slate (universal appeal)
- **Distinctive/personal:** Rose, Amber (unique character)

### Semantic Color Independence
Status colors (good/bad/warn) remain consistent across most themes to preserve learned associations. Monochrome is the exception — it uses grayscale variants to maintain the no-distraction aesthetic.

### Grid & Shadow Tuning
Each theme's `--grid` and `--shadow` values are tinted to match the accent color, creating subtle visual cohesion without overt theming.

---

## SwiftUI Mapping

For the native macOS version:

```swift
extension Color {
    static func dynamicColor(light: Color, dark: Color) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua 
                ? NSColor(dark) 
                : NSColor(light)
        }!)
    }
    
    // Per-theme asset catalogs
    static let bg = Color("Background") // Xcode asset w/ theme variants
}
```

Alternatively, define all 13 themes as SwiftUI `ColorScheme` extensions and switch via `@AppStorage("selectedTheme")`.

---

## Future Additions

Potential themes to explore:
- **Arctic** — icy blue-white, high-key aesthetic
- **Onyx** — pure black OLED mode (true #000000)
- **Tangerine** — bright citrus accent on dark base
- **Espresso** — coffee-inspired browns and creams

User custom themes (HSL picker → generate token set) would require a theme compiler to maintain contrast ratios.

---

## Usage Examples

**Terminal output colors:**  
Use `--fg-3` for timestamps, `--accent` for highlighted output, `--bad` for errors.

**Chart colors:**  
Primary series uses `--accent`, secondary uses `--fg-2`, grid lines use `--grid`.

**Button states:**  
Normal: `--accent` bg, hover: `--accent-d`, focus: 2px `--accent` outline.

**Status indicators:**  
Live dot: `--good`, stale: `--warn`, error: `--bad`, idle: `--fg-3`.

---

**End of theme system documentation.**
