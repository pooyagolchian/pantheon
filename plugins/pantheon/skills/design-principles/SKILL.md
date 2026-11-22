---
name: design-principles
description: Opinionated interface design reference with exact numbers and one resolved rule wherever popular design skills disagree. Covers picking the mode (persuade, operate, read, experience), hierarchy and spacing, type scale, OKLCH palettes and contrast, shadows and radii, motion timing and easing, interaction states, forms, accessibility, and the tells of generic AI-generated UI. Use when building or restyling a landing page, dashboard, settings screen, component or design system, when choosing colors, fonts, spacing or animation, when asked to "make it look good", "make it pop", "polish the UI", "this feels off", "review the design" or "why does this look AI-generated", and before shipping any frontend change. Names the specialist skills to load for deeper work.
---

# Design principles

Defaults for where no system exists yet. **Precedence:** a pinned brief or the project's own tokens, curves and notation win first; then this page's resolved rules; then a specialist skill's defaults; never your habit. Known differences to resolve this way: better-ui says press scale 0.96 and cross-fades icons with `cubic-bezier(0.2, 0, 0, 1)`, and impeccable uses `cubic-bezier(0.16, 1, 0.3, 1)`. This page uses 0.97 and one ease-out token unless the project already uses theirs.

## 1. Pick the mode first

Choose it from the surface being built, not the product: a dev tool's landing page is Persuade, a fashion brand's docs are Read.
- **Persuade** (landing, marketing, pricing): spend the boldness budget on **one** authored moment, such as a hero, a type treatment or a single motion sequence. Everything else stays quiet.
- **Operate** (apps, dashboards, settings, editors): scanability, consistency and native expectations outrank expression. Brand lives in precise details. Restrained by default.
- **Read** (docs, articles, changelogs): structure for comprehension first. Restrained by default.
- **Experience** (portfolio, gallery): the artifact leads from the first viewport and the interface recedes.

"Go all out" applies only to Persuade and Experience, and only to that one moment. A page where every section has an entrance has no moment.

## 2. Hierarchy and layout

- **Group with space, then backgrounds, then lines.** The gap between groups is at least 2x the gap within one (8px inside, 16px+ between). A divider is the last resort.
- **4px base spacing scale**, documented. It gives the 12/20px middle steps an 8-only scale misses. Put more space above a heading than below it.
- **Control spacing:** 12px between adjacent bordered or filled controls, 24px around borderless text or icon buttons, ~16px inline margin on mobile.
- **One filled primary action per view.** Put the color on the button background, not the label: accent text on a neutral button reads as a link.
- **Squint test:** blurred, the primary element, secondary element and groups still read in order.
- **Breakpoints come from the content**, not 768/1024 presets. Collapse late, prefer container queries, use logical properties (`padding-inline-start`), and never put a fixed width or height on a text container.
- **Viewport height:** "fits the first viewport" means `min-height: 100svh` (the small viewport, with mobile browser chrome shown). `100vh` is the large viewport, so content hides under that chrome. Use `dvh` only where resizing as the chrome shows and hides is acceptable. Use `min-height`, never `height`.
- **z-index** comes from one fixed scale (0/10/20/40/100/1000). Never use an arbitrary `9999`.
- **Persuade hero:** fits the first viewport, headline at most 2 lines, subtext at most 20 words, at most 4 text elements, nav 64–72px tall (80px max).

## 3. Typography

- **Role scale** (size/line-height/weight): Display 36/1.1/600, Title 24/1.2/600, Heading 18/1.3/600, Body 16/1.5/400, Caption 13/1.4/400. Emphasis is one weight step (400 to 500), not a size change.
- **Floors:** body 16px, UI text 14px, captions 13px, rarely below 12px. Inputs stay 16px on mobile, or iOS zooms the page.
- **Line-height:** headings ~1.1, body 1.5–1.6. Any text that wraps to 3+ lines gets at least 1.4, card descriptions included.
- **Tracking:** display -0.02em (floor -0.04em), small uppercase labels +0.05em, body 0.
- **Measure:** cap long text at 65ch (60–75 range).
- **Weights:** 400+ below 18px. Weights under 300 are display-only, at 28px+. At most 3 families.
- `text-wrap: balance` on headings, `pretty` on body text and descriptions, `font-variant-numeric: tabular-nums` on any number that changes.
- **Choosing a face:** derive it from the brief and subject; there is no whitelist. System stacks are right for Operate and Read. Persuade needs a face with a point of view. Never reach for the default font of the moment (Inter, Geist, Space Grotesk, Plus Jakarta Sans, Fraunces, Instrument Serif) just because it is the default.

## 4. Color and surfaces

- **Notation:** new systems use `oklch()`. In an existing codebase keep its notation; never scatter one OKLCH value into a hex system.
- **Ramps:** constant hue (more than 10° of drift is visible), even perceived-lightness steps, denser steps at the light end, chroma peaking mid-ramp, neither end pure black or white. Across hues, match each ramp's share of its own maximum chroma, not the same absolute C.
- **Neutrals carry 80–90% of the UI.** Map each role to a step: page bg 50/1, component bg 100/3, border 300/7, solid fill 500/9, secondary text 700/11, primary text 900/12 (Tailwind/Radix).
- **Tokens:** components use only semantic role tokens, never primitives like `--blue-500`. Never borrow a token because its value matches today. One hue means one thing (hues within 15° count as the same color).
- **Contrast:** WCAG is the legal gate (text 4.5:1, large text 3:1, UI parts 3:1). APCA decides design calls: body text needs **Lc 75** (Lc 90 preferred), other text Lc 60, 36px+ text Lc 45, UI Lc 30. Measure against the background the element actually renders on.
- **Fix contrast with lightness, not hue.** A mid-lightness (~75%) background caps even black text near Lc 60, so change the background instead. On colored surfaces, tint secondary text from the surface hue, never grey.
- **Dark mode is not inversion.** Reduce chroma, widen the dark end, recheck every pair, and use one switching mechanism.
- **Elevation is declared once, as a border or a shadow.** A 1px border under a wide soft shadow is the ghost card. Light mode uses three transparent layers; dark mode uses one white ring (values in the color reference).
- **Radii:** outer radius = inner radius + padding, with each radius chosen independently past 24px of padding. Cards use 12–16px. Pills are for small controls only. One shape scale per page.
- **Icons:** 1.5px stroke beside regular text, 2px beside semibold, one icon set per surface, `currentColor` for states. Emoji and Unicode glyphs never stand in for icons.

## 5. Motion

- **Frequency gate before anything else.** 100+ uses a day (keyboard shortcuts, command palette): no animation. Tens a day (hover, list navigation): barely perceptible or none. Occasional (modal, drawer, toast): standard. Rare (onboarding, celebration): delight allowed. Never animate keyboard-initiated actions.
- **Easing:** enter and exit use ease-out, movement on screen uses ease-in-out, hover and color changes (including hover shadows) use `ease`, constant motion uses linear. Never use ease-in on UI.
- **One project ease-out token**, default `cubic-bezier(0.23, 1, 0.32, 1)`. Ease-in-out is `cubic-bezier(0.77, 0, 0.175, 1)` and drawers use `cubic-bezier(0.32, 0.72, 0, 1)`. An existing project keeps its own curves.
- **Durations:** press 100–160ms, tooltip 125–200ms, dropdown 150–250ms, modal or drawer 200–500ms. Everything else in the UI stays under 300ms. Exits are faster than entrances. Only an authored focal entrance runs 500–800ms.
- **Press scale is one token, 0.97**, never below 0.95. Nothing enters from `scale(0)`: start at `scale(0.95)` with opacity 0. Popovers grow from their trigger; modals stay centered.
- **Animate only `transform`, `opacity`, `filter` and `clip-path`.** Name the properties and never write `transition: all`. Keep blur at 20px or less.
- **Interruptible:** use CSS transitions for anything that can be retriggered and keyframes only for one-shot sequences. Springs default to critically damped (no bounce, response ~0.4s); bounce is allowed only after a momentum gesture.
- **Reduced motion is opt-in, not an override:** put motion inside `@media (prefers-reduced-motion: no-preference)`. Reduced means fewer and gentler, not zero: crossfades replace slides and scales, parallax and autoplay go, and press feedback stays.
- Gate hover motion with `@media (hover: hover) and (pointer: fine)`. Nothing animates on first render, unless the page entrance is the Persuade page's one authored moment.

## 6. States and forms

- **Every interactive surface ships all states:** hover, active, `:focus-visible`, disabled, loading (a skeleton matching the final layout), empty (one clear next action), error (inline, naming the recovery), success. Build them with realistic content, not lorem ipsum.
- **Forms:** label above, error below, never a placeholder as the label. Keep submit enabled, validate on submit, focus the first invalid field, and never block paste.
- **Destructive actions** need a confirm dialog or an undo window. Toasts with an action or error stay until dismissed.
- **Theme the surfaces models skip:** `::selection`, `caret-color`, scrollbars, focus ring, `text-underline-offset`, tabular numerals.

## 7. Accessibility

- Use native elements first. Prefer the browser focus ring plus `outline-offset`. A custom ring is `outline: 2px solid var(--focus-ring); outline-offset: 2px`, checked against every adjacent color and in forced-colors mode. Never `outline: none` without a replacement.
- **Hit areas:** 24x24px is the WCAG AA floor, 44px the touch target, 40px the desktop target. A 20px target needs a 4px gap. Extend small targets with a pseudo-element.
- Color never carries meaning alone. Modals make the background `inert` and return focus to the trigger.
- The page must survive 200% zoom and reflow at 320px without horizontal scrolling.

## Forbidden AI-UI tells

1. **The AI palette:** purple, violet or cyan gradients, neon or colored glows, decorative glass and blobs. Translucent floating chrome that does a job is fine.
2. **Placeholder content:** Jane Doe, 99.99%, "Elevate / Seamless / Unleash", lorem ipsum, "Learn more", the hero-metric template, fake logo walls and testimonials.
3. **Happy-path-only UI** with no loading, empty, error, disabled or focus states.
4. **Cards as the default container:** identical icon+heading+text cards, nested cards, the 3-up feature row, bento by default.
5. **Uniform `rounded-2xl` with a soft shadow,** the ghost card, colored left-border accents thicker than 1px.
6. Gradient text, emoji as icons, eyebrow or kicker labels above headings, 01/02/03 section numbers that carry no sequence, em-dash overuse.

## Gotchas

- **Eyebrows are out:** no kicker label above any heading. The heading carries itself.
- **Restraint rules are mode rules.** "No custom easing / no tracking changes / no animation unless asked" (baseline-ui) holds for Operate polish passes on existing code. New systems get the one ease-out token and the display tracking above.
- **Placeholder text needs 4.5:1.** APCA lists Lc 30 for placeholder and disabled text, but WCAG is the gate and exempts only disabled text.
- A token whose value is right today but whose role is wrong breaks at the next theme change.
- `text-box: trim-both cap alphabetic` centers text in badges and buttons. Firefox lacks it, so treat it as an enhancement.

## Review procedure

1. Name the mode and check the design against it, not against your taste. A deliberate project choice you dislike is not a finding.
2. Run one batched pass: squint test, contrast of rendered pairs in light and dark, every state, 320px and 200% zoom, keyboard-only, reduced motion, and the tells list.
3. Fix the cheapest way first: delete it, then use the platform, then reuse a token, then correct the value, and only then add something.
4. Report one row per root cause as `severity | location | before | after | why`. Confirm once and stop. List anything you could not render as not verified.

## References

- [references/typography.md](references/typography.md): read when setting up a type scale, choosing or loading a font, or fixing wrapping, truncation or numerals.
- [references/color.md](references/color.md): read when building a palette, dark mode, gradients, shadows, radii or icons, or when measuring contrast.
- [references/motion.md](references/motion.md): read when adding or reviewing any animation, gesture, spring or reduced-motion behavior.
- [references/layout-and-states.md](references/layout-and-states.md): read when structuring a page, making it responsive, building forms and states, or auditing accessibility.

## Go deeper

Load a specialist by name when the task outgrows this page. If it isn't installed, these rules still stand.
- **New, distinctive surfaces:** `frontend-design` for an aesthetic direction, `impeccable` for the mode-driven craft and critique pipeline with its anti-pattern detector, and `design-taste-frontend` or `redesign-existing-projects` for landing-page and redesign rules.
- **One area in depth:** `better-typography`, `better-colors` (or `oklch-skill` for conversions and gamut), `better-layout`, `better-ui` (surfaces, icons, micro-motion), `better-accessibility`. `better-interface` routes among them.
- **Motion:** `animate` to build one animation, `emil-design-eng` and `apple-design` for feel and gestures, `animation-vocabulary` to name an effect, `improve-animations` or `find-animation-opportunities` for audits, `fixing-motion-performance` for jank.
- **Systems and docs:** `design-system-patterns` for token architecture, `create-design-md` or `extract-design-system` to capture an existing design, `ui-ux-pro-max` for style and palette lookup tables.
- **Audits:** `improve-ui`, `baseline-ui` (quick cleanup), `web-design-guidelines`, `accessibility` or `fixing-accessibility` (WCAG passes), `responsive-design`.
- **Stack:** `tailwind-best-practices`, `shadcn`, `next-best-practices` for how to express these rules in that stack.
