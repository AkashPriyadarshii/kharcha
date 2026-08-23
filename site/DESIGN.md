---
version: 1.0
name: Kharcha-Elite-Design-System
description: "A maximum-fidelity fintech design system merging the ultra-minimalism of Vercel, the deep dark-mode purity of Linear, the typographic precision of Stripe, and the spatial presentation of Apple. Built for a private, offline-first UPI tracker. The system relies on a true-black OLED canvas, structural 1px gridlines, and a singular neon-mint accent. Typography is tightly tracked, geometric, and enforces tabular figures for all financial data."

colors:
  # Primary Accents (Supabase/Linear inspired)
  primary: "#00E599"       # High-visibility Neon Mint
  primary-hover: "#33ECAE"
  primary-focus: "#00B377"
  primary-alpha: "rgba(0, 229, 153, 0.15)"
  
  # Dark Mode Canvas (OLED/Linear focus)
  canvas: "#000000"        # True OLED Black
  surface-1: "#0A0B0C"     # Deepest elevation
  surface-2: "#121315"     # Cards and panels
  surface-float: "rgba(18, 19, 21, 0.7)" # Apple-style glass
  
  # Text on Dark
  ink: "#F7F8F8"           # Primary reading text
  ink-muted: "#8A8F98"     # Secondary labels
  ink-tertiary: "#55595F"  # Disabled/metadata
  
  # Structural Borders (Vercel brutalism)
  hairline: "#1F2023"      
  hairline-strong: "#2D2F34"
  
  # Light Mode Inversions (Stripe inspired)
  inverse-canvas: "#F9FAFB"
  inverse-surface: "#FFFFFF"
  inverse-ink: "#090A0B"
  inverse-ink-muted: "#525C6A"
  inverse-hairline: "#E5E7EB"
  
  # Financial Semantics
  semantic-expense: "#FF453A" # Apple Red
  semantic-income: "#32D74B"  # Apple Green
  semantic-warning: "#FF9F0A"

typography:
  display-xl:
    fontFamily: "'Manrope', 'Manrope', system-ui, sans-serif"
    fontSize: 72px
    fontWeight: 800
    lineHeight: 1.05
    letterSpacing: -2.5px
  display-lg:
    fontFamily: "'Manrope', 'Manrope', system-ui, sans-serif"
    fontSize: 56px
    fontWeight: 700
    lineHeight: 1.10
    letterSpacing: -1.5px
  heading-md:
    fontFamily: "'Manrope', 'Manrope', system-ui, sans-serif"
    fontSize: 32px
    fontWeight: 600
    lineHeight: 1.15
    letterSpacing: -0.8px
  body-base:
    fontFamily: "'Manrope', system-ui, sans-serif"
    fontSize: 16px
    fontWeight: 400
    lineHeight: 1.6
    letterSpacing: -0.2px
  numbers-financial:
    fontFamily: "'Manrope', system-ui, sans-serif"
    fontVariantNumeric: "tabular-nums"
    fontWeight: 600
    letterSpacing: 0px

components:
  button-primary:
    background: "var(--primary)"
    color: "#000000"
    borderRadius: "999px"
    padding: "12px 24px"
    transition: "transform 0.2s cubic-bezier(0.175, 0.885, 0.32, 1.275)"
    boxShadow: "0 0 20px rgba(0, 229, 153, 0.3)"
  
  button-ghost:
    background: "transparent"
    color: "var(--ink)"
    border: "1px solid var(--hairline)"
    borderRadius: "999px"
    backdropFilter: "blur(8px)"
  
  card-panel:
    background: "var(--surface-2)"
    border: "1px solid var(--hairline)"
    borderRadius: "16px"
    boxShadow: "0 4px 24px rgba(0, 0, 0, 0.4)"

layout:
  maxWidth: "1200px"
  gridColumns: 12
  sectionPadding: "120px 0"
---

# Kharcha: The Merged Architecture

## 1. Top 10 Design DNA Extraction
We analyzed the absolute apex of modern digital design (Linear, Stripe, Apple, Vercel, Supabase, Framer, Revolut, etc.) to extract the exact traits that signal "premium, trustworthy, and technologically superior":

1. **Linear**: Extreme dark-mode purity. True blacks, ultra-thin hairlines, and highly tracked-out negative letter spacing. Eliminates visual noise.
2. **Stripe**: Editorial-grade financial clarity. Tabular figures for all money formats. High-contrast typography that makes data the artwork.
3. **Apple**: Spatial awareness. UIs don't just sit flat; they float via `backdrop-filter` and scale smoothly via advanced Bezier curves. Scroll-linked macro animations.
4. **Vercel**: Brutal structural exactness. UI elements are bounded by absolute 1px lines. No gradient mush; just pure geometric grids.
5. **Supabase**: The power of a single, radioactive accent color against a void.

## 2. The Final Merged Plan ("The Obsidian Vault")

For Kharcha, we combine these paradigms into a layout that feels like an impenetrable, offline-first vault, yet moves with the fluidity of native OS software.

### A. The Anti-Slop Visual Narrative
- **Kill the Emojis**: Replaced with literal, code-rendered UI fragments.
- **Scroll-Driven Physics (Apple + Framer)**: As the user scrolls, a central high-res device mockup rotates and swaps UI states. The features are explained contextually as the phone animates, not in a static 3x2 grid.
- **The OLED Canvas (Linear + Vercel)**: Background is strictly `#000000`. Content lives in `#0A0B0C` cards delineated by `#1F2023` hairlines.

### B. Typography & Tone
- **Data over Adjectives**: No more "Clean, calm, rupee-first". The headline is a massive, tightly tracked `72px` statment: **"You pay via UPI. Kharcha logs it."**
- **Tabular Precision (Stripe)**: All ₹ amounts use `font-variant-numeric: tabular-nums` so numbers align perfectly vertically, projecting financial seriousness.

### C. The Interaction Model
- **Glassmorphic Navigation**: The header floats with a blur (`backdrop-filter`), mimicking iOS native materials.
- **Micro-interactions**: Buttons don't just change color; they possess physical weight. Hovering a primary CTA triggers a sub-pixel translation and a controlled `box-shadow` bloom.
