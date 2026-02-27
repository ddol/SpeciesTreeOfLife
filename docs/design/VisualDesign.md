# Species: Tree of Life — Visual Design Spec

**Status:** Draft v0.1  
**Date:** 2026-02-26  
**Audience:** UI designers, iOS/macOS SwiftUI engineers  

---

## Table of Contents

1. [Visual Identity Overview](#1-visual-identity-overview)
2. [Colour System](#2-colour-system)
3. [Typography](#3-typography)
4. [Shape Language & Illustration Style](#4-shape-language--illustration-style)
5. [Texture & Surface Treatment](#5-texture--surface-treatment)
6. [Composition Rules](#6-composition-rules)
7. [Motion & Animation](#7-motion--animation)
8. [Component Patterns](#8-component-patterns)
9. [SwiftUI Design Tokens](#9-swiftui-design-tokens)
10. [Platform Adaptations](#10-platform-adaptations)

---

## 1. Visual Identity Overview

**Species: Tree of Life** uses a bold, playful, modernist aesthetic built from simple geometric shapes and chunky sculptural forms. The style evokes cut paper, soft-painted wood, or a hand-crafted nature exhibit — physical, tactile, and curious.

### Core Principles

| Principle | Expression |
|---|---|
| **Bold & Geometric** | Oversized simple forms dominate each scene. Circles, arcs, rounded rectangles, leaf-tear shapes. No fine detail; every element reads at a glance. |
| **Handcrafted, Not Digital** | Flat-vector shapes with a subtle grain, soft edge shading, and occasional speckle. "Collage" not "glossy." |
| **Deep & Saturated** | Backgrounds are rich, dark gradients. Accent forms are bright but used sparingly. Never neon, never washed-out. |
| **Spacious** | One focal form per scene with room to breathe. Supporting elements add rhythm, not clutter. |
| **Curious & Whimsical** | Compositions imply transformation, orbit, growth. The visual language mirrors the biological theme: things connect, branch, and evolve. |

---

## 2. Colour System

### 2.1 Background Gradients

Each major context has a defining background gradient. Gradients run from a deeper shade at the edges (vignette) to a slightly lighter shade at the centre, pulling the eye inward.

| Context | Gradient Name | Start (edge) | End (centre) | Use |
|---|---|---|---|---|
| Taxonomy browser | Forest Night | `#0D2818` | `#1A4A2E` | Tree browsing; green-world feel |
| Species detail | Deep Canopy | `#1A3020` | `#2D5A38` | Individual species pages |
| Compare view | Wine Dusk | `#2A0D1A` | `#4A1A2E` | Two-species comparison |
| Favourites | Midnight Grove | `#0D0D2A` | `#1A1A40` | Saved species list |
| Search | Slate Earth | `#1A1A1A` | `#2D2D2D` | Search results; neutral backdrop |
| Settings | Deep Slate | `#141420` | `#20202E` | Settings & privacy screens |

### 2.2 Accent Colours

Bright accent forms sit on top of the dark backgrounds. Use sparingly — one to two per scene maximum.

| Token | Hex | Role |
|---|---|---|
| `accentSunYellow` | `#F5C842` | Focal illustration highlight; "alive" energy |
| `accentCoralRed` | `#E8553A` | Conservation alerts; danger-state badges |
| `accentSkyTeal` | `#3ABDE8` | Compare arcs; relationship lines; water habitats |
| `accentLeafGreen` | `#5CC45A` | Active state; "safe" conservation status |
| `accentBoneWhite` | `#F5F0E8` | Typography; icon fills on dark backgrounds |
| `accentPebbleGrey` | `#8A8A8A` | Secondary text; disabled states |

### 2.3 Taxonomy Rank Colours

Each taxonomic rank has a dedicated colour used in rank badges, tree-node dots, and breadcrumb chips.

| Rank | Colour | Hex |
|---|---|---|
| Domain | `rankDomain` | `#C084FC` (soft lavender) |
| Kingdom | `rankKingdom` | `#818CF8` (iris blue) |
| Phylum | `rankPhylum` | `#38BDF8` (sky blue) |
| Class | `rankClass` | `#34D399` (mint) |
| Order | `rankOrder` | `#A3E635` (lime) |
| Family | `rankFamily` | `#FDE68A` (pale gold) |
| Genus | `rankGenus` | `#FB923C` (amber) |
| Species | `rankSpecies` | `#F87171` (rose) |

### 2.4 Conservation Status Colours

| IUCN Code | Colour | Hex |
|---|---|---|
| LC (Least Concern) | `conservationLC` | `#5CC45A` |
| NT (Near Threatened) | `conservationNT` | `#A3E635` |
| VU (Vulnerable) | `conservationVU` | `#F5C842` |
| EN (Endangered) | `conservationEN` | `#FB923C` |
| CR (Critically Endangered) | `conservationCR` | `#E8553A` |
| EW (Extinct in Wild) | `conservationEW` | `#C084FC` |
| EX (Extinct) | `conservationEX` | `#8A8A8A` |
| NE / DD (Not Evaluated / Data Deficient) | `conservationUnknown` | `#4A4A4A` |

---

## 3. Typography

### 3.1 Type Choices

| Use | Typeface | Style | Size Range | Colour |
|---|---|---|---|---|
| Heading / Species name | SF Pro Rounded | Bold | 28–40 pt | `accentBoneWhite` |
| Scientific name | SF Pro Rounded | Bold Italic | 20–28 pt | `accentBoneWhite` |
| Body / Description | SF Pro Text | Regular | 15–17 pt | `accentBoneWhite` at 85% opacity |
| Rank badge label | SF Pro Rounded | Semibold | 11–13 pt | White on rank colour |
| Caption / Secondary | SF Pro Text | Regular | 12–14 pt | `accentPebbleGrey` |
| Tab labels | SF Pro Rounded | Medium | 11 pt | System tab bar defaults |

SF Pro Rounded is the system-provided rounded variant available on iOS 17+ and macOS 14+. No custom font loading is required.

### 3.2 Principles

- **Minimal text.** Visuals stay primary. Use labels and headings sparingly.
- **Plenty of breathing room.** Line height ≥ 1.4×. Generous margins (≥ 20 pt side padding).
- **White on dark, always.** Never dark text on a dark gradient. Never small light-on-dark body copy below 14 pt.
- **Scientific names in italics.** Matches biological convention and helps children distinguish common names from scientific names.

---

## 4. Shape Language & Illustration Style

### 4.1 Core Vocabulary

All illustration shapes derive from a small vocabulary of simple geometric primitives:

| Shape | Used for |
|---|---|
| **Filled circle / ellipse** | Organism body forms; planet-like cells; seed pods |
| **Rounded rectangle** | Leaf forms; body segments; habitat blocks |
| **Arc / partial ring** | Branch paths; orbit trails; relationship connectors |
| **Teardrop / leaf** | Plant parts; single-cell organisms; drop elements |
| **Polygon (5–8 sides, rounded)** | Radial forms; coral; crystal structures |
| **Dotted path** | Motion trail; migration route; evolutionary branch hint |
| **Concentric rings** | Growth rings; clade depth; zoom-level rings |

### 4.2 Illustration Scale

Each illustration has one **oversized focal form** that fills 40–60% of the available space. This is the "hero" — the main organism or concept. Supporting elements are significantly smaller (10–25% of focal size) and arranged around the focal form.

### 4.3 Transformation Sequences

Many illustrations show a concept as a **step-by-step transformation**: a shape splits, rotates, fans out, or reconfigures across 3–5 stages arranged left-to-right or radially. This directly mirrors biological themes (cell division, phylogenetic branching, metamorphosis).

Each stage is a discrete visual state — not a mid-animation blur. The sequence reads like a kinetic sculpture frozen at key frames.

### 4.4 Supporting Element Arrangements

Supporting elements use one of these arrangements:

- **Arc**: 3–7 small elements placed along a curved path around the focal form.
- **Radial burst**: elements radiating outward from a central point, evenly spaced angularly.
- **Dotted trail**: a dashed/dotted line (3–8 dots) implying direction of movement.
- **Ring halo**: a thin circle or partial arc orbiting the focal form.

Never use a strict grid. Arrangements should feel organic but intentional.

---

## 5. Texture & Surface Treatment

### 5.1 Grain

All filled shapes have a subtle grain overlay — a noise texture at 2–4% opacity. This transforms flat digital vectors into something that feels printed or painted.

- Grain scale: fine (roughly 1–2 px grain at 1× resolution).
- Apply as a multiply-blend or screen-blend texture layer over the solid fill.
- Do not apply grain to the background gradient itself (the gradient vignette already adds depth).

### 5.2 Soft Edge Shading

Large filled shapes have a very subtle inner shadow or gradient to imply mild three-dimensionality:

- A slightly darker (10–15% darker) variant of the fill colour at the bottom/trailing edge.
- Radial gradient from 100% opacity at centre to ~90% at edge — just enough to feel "solid, not flat."
- Never use drop shadows or outer glow. All depth is implied by edge shading, not external shadow.

### 5.3 Speckle Accent

Some illustrations include a scattered speckle pattern — tiny filled circles (2–4 px diameter) at random positions within or around a form. Speckle count: 8–20 per illustration. Used to suggest texture in organic forms (bark, sand, scales) without detail.

---

## 6. Composition Rules

### 6.1 Scene Anatomy

```
┌────────────────────────────────────────────┐
│  ░░░░░░░░ deep gradient background ░░░░░░  │
│                                            │
│        ·  · [small element]  ·             │
│     ·                            ·         │
│  [small]     ╔══════════════╗    [small]   │
│              ║  FOCAL FORM  ║              │
│  [small]     ║  (40-60% W)  ║    [small]  │
│              ╚══════════════╝              │
│     ·                            ·         │
│        ·  ·  [label text]  ·               │
│                                            │
└────────────────────────────────────────────┘
```

- One focal form per scene. Never two forms of equal visual weight.
- 20–30 pt padding from screen edge to any element.
- Text label is centred below the focal form, or anchored top-left/right if the focal form uses the full height.

### 6.2 Vignette

Apply a radial gradient vignette from 0% opacity at centre to 20–30% black at edges. The vignette is subtle — it darkens the edges to draw the eye inward without creating a "TV screen" effect.

### 6.3 Negative Space

At least 30–40% of any scene should be the background (no elements). Scenes must feel spacious. When in doubt, remove a supporting element rather than add one.

---

## 7. Motion & Animation

### 7.1 Principles

- **Purposeful.** Animation must communicate meaning (transition between states, indicate loading, reveal a relationship). Decoration-only animation is prohibited.
- **Short.** All transitions ≤ 400 ms. Idle loops (if used) ≤ 2 s cycle.
- **Organic but restrained.** Use spring physics for entrances; ease-out for exits. No bouncing or elastic overshoot on destructive actions (deletion, navigation back).
- **Respectful of accessibility.** All animations must respect `UIAccessibility.isReduceMotionEnabled` / `NSWorkspace.accessibilityDisplayShouldReduceMotion`. When reduce-motion is on, replace animated transitions with a simple cross-dissolve (≤ 200 ms).

### 7.2 Transition Vocabulary

| Transition | Animation | Duration |
|---|---|---|
| Navigate deeper into tree | Focal form scales up + slides left; parent slides out left | 300 ms spring |
| Navigate back up the tree | Parent slides in from left; child scales down | 250 ms ease-out |
| Open species detail | Focal form expands from list thumbnail position | 350 ms spring |
| Add to favourites | Heart icon scales up then settles; brief particle burst (3–5 dots radiate out) | 300 ms spring |
| Remove from favourites | Heart icon scales down; colour drains | 200 ms ease-out |
| Compare species A ↔ B | Two panels slide in from opposing sides | 300 ms spring |
| Tab switch | Standard SwiftUI tab transition (cross-dissolve) | System default |

### 7.3 Idle / Ambient Animations (Optional)

Idle animations may be used on empty states and loading screens only. Specifications:

- **Loading indicator:** A single circle that traces a dotted arc, rotating at 1 revolution/2 s.
- **Empty state:** The focal illustration gently bobs vertically (±4 pt, 3 s sine cycle, ease-in-out).
- Both must stop when `isReduceMotionEnabled` is true.

---

## 8. Component Patterns

### 8.1 Rank Badge

A small pill (rounded rectangle) filled with the rank's designated colour, containing the rank name in white SF Pro Rounded Semibold 12 pt.

```
  ╭──────────╮
  │  Species  │   ← rose (#F87171) fill, white text
  ╰──────────╯
```

### 8.2 Species Row (List)

```
  ┌────────────────────────────────────────┐
  │ [40×40 image]  Scientific name         │
  │                Common name · [Badge]   │
  └────────────────────────────────────────┘
```

- Image: rounded-square, 40×40 pt, placeholder uses the rank's colour as background with an SF Symbol silhouette.
- Scientific name: SF Pro Rounded Bold 16 pt, bone white.
- Common name: SF Pro Text Regular 14 pt, 70% bone white.
- Badge: rank badge pill at trailing edge.

### 8.3 Breadcrumb Path

Horizontally scrollable row of tappable chips: `Domain  ›  Kingdom  ›  …  ›  Species`. Each chip: rounded, 28 pt height, rank colour fill, white text. The active (rightmost) chip is full-opacity; ancestors are 60% opacity.

### 8.4 Conservation Status Badge

A small filled circle (10 pt diameter) followed by the IUCN code in 12 pt text. Colour from §2.4.

```
  ● EN   ← orange (#FB923C) dot, orange text
```

### 8.5 Focal Illustration Card

Used in species detail, compare view, and the favourites list:

- Full-width card with the background gradient of the current context.
- Illustration centred in a ~200 pt square zone.
- Supporting elements arranged in an arc or radial burst behind the focal form.
- Subtle grain texture over the entire card.
- Species name anchored bottom-left of the card in SF Pro Rounded Bold 24 pt.

---

## 9. SwiftUI Design Tokens

These tokens are defined in `STOLSharedUI/Sources/STOLSharedUI/DesignSystem/`. Each file is a plain Swift enum with static properties — no classes, no singletons.

### `STOLColors`

```
// Context gradient backgrounds
STOLColors.Background.forestNight      → LinearGradient / RadialGradient
STOLColors.Background.deepCanopy       → LinearGradient / RadialGradient
STOLColors.Background.wineDusk         → LinearGradient / RadialGradient
STOLColors.Background.midnightGrove    → LinearGradient / RadialGradient
STOLColors.Background.slateEarth       → LinearGradient / RadialGradient

// Accent colours
STOLColors.Accent.sunYellow            → Color
STOLColors.Accent.coralRed             → Color
STOLColors.Accent.skyTeal              → Color
STOLColors.Accent.leafGreen            → Color
STOLColors.Accent.boneWhite            → Color
STOLColors.Accent.pebbleGrey           → Color

// Rank colours (keyed by TaxonRank)
STOLColors.rank(_ rank: TaxonRank)     → Color

// Conservation colours (keyed by IUCN code string)
STOLColors.conservation(_ code: String) → Color
```

### `STOLTypography`

```
STOLTypography.speciesHeading          → Font   // SF Pro Rounded Bold 28–40 pt
STOLTypography.scientificName          → Font   // SF Pro Rounded Bold Italic 20–28 pt
STOLTypography.body                    → Font   // SF Pro Text Regular 15–17 pt
STOLTypography.rankBadge               → Font   // SF Pro Rounded Semibold 12 pt
STOLTypography.caption                 → Font   // SF Pro Text Regular 12–14 pt
```

### `STOLShapes`

```
STOLShapes.rankBadgeShape              → RoundedRectangle(cornerRadius: 6)
STOLShapes.cardShape                   → RoundedRectangle(cornerRadius: 20)
STOLShapes.thumbnailShape              → RoundedRectangle(cornerRadius: 8)
STOLShapes.focalIllustrationShape      → Circle (used as clip mask)
```

### `STOLMotion`

```
STOLMotion.navigationEnter             → Animation  // .spring(response: 0.3, dampingFraction: 0.85)
STOLMotion.navigationExit              → Animation  // .easeOut(duration: 0.25)
STOLMotion.detailExpand                → Animation  // .spring(response: 0.35, dampingFraction: 0.8)
STOLMotion.favouriteAdd                → Animation  // .spring(response: 0.3, dampingFraction: 0.7)
STOLMotion.reduceMotionFallback        → Animation  // .easeInOut(duration: 0.2)
```

All motion tokens check `AccessibilityProperties.reduceMotion` and substitute `STOLMotion.reduceMotionFallback` automatically via a `View` extension (`View.stolAnimation(_:)`).

---

## 10. Platform Adaptations

### iOS / iPadOS

- Full-screen gradient backgrounds using `ZStack` with `ignoresSafeArea()`.
- `NavigationSplitView` on iPad (regular width); `NavigationStack` on iPhone (compact width).
- Illustrations rendered as `Canvas` or `ZStack` of SwiftUI shapes — no UIKit drawing required.
- Haptic feedback on favourite toggle: `UIImpactFeedbackGenerator(style: .light).impactOccurred()`.

### macOS

- Window minimum size: 700 × 480 pt.
- Three-column `NavigationSplitView`: tree sidebar / list / detail.
- Gradient backgrounds applied to each column independently (not full-window bleed).
- No haptic feedback. Subtle scale animation on hover instead.
- Toolbar buttons use standard macOS styling; no custom toolbar chrome.
- Rounded sans-serif: system font `.rounded` design on macOS 14+ uses SF Pro Rounded automatically via `.fontDesign(.rounded)`.
