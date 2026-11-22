# Color and surfaces

## Contents
- Notation
- System shape
- Ramps
- Role to step mapping
- Tokens
- Contrast
- Dark mode
- Gradients
- Shadows and elevation
- Radii
- Icons and image outlines

## Notation

- New system: `oklch()`, because its numbers behave like the ramp rules below.
- Existing system: keep its notation. A consistent hex palette beats hex with one `oklch()` scattered through it. Convert only when a migration is the task.
- P3 colors: declare the sRGB value first, override inside `@media (color-gamut: p3)`.
- High chroma clips out of sRGB at many L/H combinations; clamp to the max displayable chroma for that lightness and hue.
- Compute colors with a library (culori, colorjs.io, chroma.js); never eyeball a value you could calculate, and never report a contrast number you did not measure.

## System shape

- One neutral ramp, one accent ramp, and only the status ramps the product renders (`danger`, `warning`, `success`, `info`). A ramp nothing imports is maintenance for zero pixels.
- A second accent hue earns its place only when two things must be told apart at a glance, and never sits adjacent to the first.
- Neutrals carry 80–90% of the interface.
- One accent per view. Several colored backgrounds are fine only when they encode distinct states or categories.

## Ramps

A well-formed ramp:
- Even steps in perceived lightness (OKLCH L, not HSL lightness, which bunches at one end).
- Constant hue. More than 10° of spread across steps is visible drift.
- Chroma peaks mid-ramp and falls toward both ends; the extremes are nearly neutral.
- Denser at the light end: 50–200 close together, 800–950 further apart, so 50 and 100 read as two surfaces.
- Neither end reaches pure black or white.
- No two adjacent steps indistinguishable; if they are, drop one.

Several hues together: match perceived lightness exactly at each step, and match chroma as the same share of each hue's own maximum. Yellows and cyans peak far lower than reds and blues, so copying a C value leaves warnings weak beside dangers. Move a status hue that collides with the accent until destructive and primary read apart side by side.

Brand color: put it on the solid-fill step (500 / 9). Pin it only if contractually fixed; otherwise snap it onto the ramp so steps space evenly. If it fails contrast behind white text it stays the brand color, but interactive fills use a darker step. Never quietly darken the brand.

## Role to step mapping

| Role | Tailwind | Radix |
| --- | --- | --- |
| Page background | 50 | 1 |
| Subtle background | 50 | 2 |
| Component background | 100 | 3 |
| Component hover | 200 | 4 |
| Component active / selected | 200 | 5 |
| Subtle border | 200 | 6 |
| Border, separator | 300 | 7 |
| Strong border, focus ring | 400 | 8 |
| Solid fill | 500 | 9 |
| Low-contrast text | 700 | 11 |
| High-contrast text | 900 | 12 |

Tailwind steps are defined by lightness, so this mapping inverts in dark mode (page at 950, text at 50). Radix steps are defined by role and survive a theme change; prefer that model for new systems and put the role mapping in the semantic tier on Tailwind.

## Tokens

- Two tiers. Primitives name a value (`--blue-500`) and are never used in components. Semantic tokens name a job (`--color-text-secondary`, `--color-accent-solid`, `--color-bg-surface`) and are the only tier components reference.
- Never name a token for its appearance (`--color-blue-button`) or first use (`--color-sidebar-gray`).
- Reserve `accent` for the brand; let `primary` mean "most prominent in its group", so `--color-primary` and `--color-text-primary` don't collide.
- Never borrow a token because its value is right today. A separator used as text color breaks when borders get lighter. Missing role means add a token.
- One hue, one meaning across the interface; hues within 15° count as the same color. Accent on static text tells users to click something that does nothing.

## Contrast

Measure the foreground against the background it actually renders on (nearest painted ancestor, including opacity and any image underneath), in every appearance.

WCAG 2 (legal gate):

| Content | AA | AAA |
| --- | --- | --- |
| Text under 24px (under 18.5px bold) | 4.5:1 | 7:1 |
| Large text, 24px+ or 18.5px+ bold | 3:1 | 4.5:1 |
| UI components, graphics | 3:1 | n/a |

APCA (design decisions above the gate):

| Content | Minimum | Preferred |
| --- | --- | --- |
| Body text | Lc 75 | Lc 90 |
| Non-body text (labels, headlines) | Lc 60 | Lc 75 |
| Large text, 36px+ | Lc 45 | Lc 60 |
| UI components | Lc 30 | n/a |

- Body text is Lc 75, not Lc 60 (some sources say 60; that is the non-body floor).
- Lc 15 is the floor for a non-text element to be discernible at all.
- Lc is signed by polarity; compare absolute values. Mirrored pairs don't score the same, which is why light mode passes and dark mode fails.
- Light-vs-dark text crossover sits near 73% perceived lightness. Between ~60% and 73% the background looks light but white text still scores better.
- Fix by moving lightness, holding hue and chroma, then remeasure. Pushing lightness can leave gamut; reduce chroma to stay renderable.
- A ~75% lightness background caps even black text near Lc 60; body text needs a background near one extreme.
- Translucent headers and overlays: test against the lightest and darkest content that can scroll beneath, or make them opaque enough. Text over images needs a scrim or a measured worst region.
- `color-mix()`, relative color syntax and opacity modifiers resolve at render time; measure the rendered result.

## Dark mode

- Reverse the roles as a starting point, then reduce chroma, widen the dark end, and recheck every pair.
- Choose light or dark from the use scene (who, where, what ambient light), not from the product category.
- One switching mechanism. `prefers-color-scheme` setting some tokens and a `.dark` class setting others is a bug.
- Suppress transitions during the switch frame, or every color transition fires at once and the switch smears (recipe in [motion.md](motion.md#theme-switch)).

## Gradients

- Interpolation space is a look, not a correctness setting. Default `linear-gradient(in oklab, ...)`: even brightness, no hue surprises.
- `in oklch` when a two-hue gradient greys out in the middle; it sweeps around the hue wheel and stays vivid.
- The sRGB default muddies the midpoint.
- Palette ramps are always generated in a perceptual space regardless of output format.

## Shadows and elevation

Shadow-as-border, light mode (first layer is the 1px ring, then lift, then ambient):

```css
--shadow-border:
  0 0 0 1px oklch(0 0 0 / 0.06),
  0 1px 2px -1px oklch(0 0 0 / 0.06),
  0 2px 4px 0 oklch(0 0 0 / 0.04);
--shadow-border-hover:
  0 0 0 1px oklch(0 0 0 / 0.08),
  0 1px 2px -1px oklch(0 0 0 / 0.08),
  0 2px 4px 0 oklch(0 0 0 / 0.06);
```

Dark mode drops to a single white ring, because layered depth is invisible on dark backgrounds:

```css
--shadow-border: 0 0 0 1px oklch(1 0 0 / 0.08);
--shadow-border-hover: 0 0 0 1px oklch(1 0 0 / 0.13);
```

- Use shadows for depth on buttons, cards and containers; keep borders for structure (dividers, separators, selected and focus states).
- Declare elevation once: border or shadow, not both. The ghost card is a 1px border under a wide soft shadow.
- Real shadows have an offset and a soft blur. A zero-offset colored halo is decoration.
- Tint shadows from the surface hue on colored surfaces; use black alpha on neutral ones.
- Hard offset shadows (`4px 4px 0`) only in a world that is actually neobrutalist.
- Transition `box-shadow` on hover at 150ms with `ease`, naming the property (hover and color changes use `ease`, see [motion.md](motion.md#easing)).

## Radii

- Concentric: outer = inner + padding, when layers share a visible even inset. Past 24px of padding, treat layers as separate surfaces and choose each radius independently.
- Cards 12–16px. Pills only for small controls (chips, tags, small buttons).
- One shape scale per page; uniform large radius on everything is a tell.

## Icons and image outlines

- Stroke 1.5px beside regular (400) text, 2px beside semibold (600). One stroke weight per set, one icon library per surface.
- `currentColor`; states via CSS color and opacity, not separate assets. Outline is default, filled marks active.
- Images get a 1px outline at low opacity: `oklch(0 0 0 / 0.1)` in light, `oklch(1 0 0 / 0.1)` in dark. Pure black or white only, never slate, zinc or a tinted neutral, which reads as dirt on the edge.
- Optical over geometric alignment: play triangles, icons in buttons and asymmetric glyphs need a manual nudge.
