# Motion

## Contents
- Decide whether to animate
- Easing
- Durations
- Scale, origin, stagger
- Springs and interruption
- Properties and performance
- Recipes
- Theme switch
- Gestures
- Reduced motion and autoplay
- Reviewing motion

## Decide whether to animate

Ask in order; stop at the first "no".

1. **How often is it seen?**

| Frequency | Decision |
| --- | --- |
| 100+ times a day (shortcuts, command palette) | No animation |
| Tens of times a day (hover, list navigation) | Remove or make near-imperceptible |
| Occasional (modal, drawer, toast) | Standard animation |
| Rare (onboarding, first run, celebration) | Delight allowed |

Never animate keyboard-initiated actions.

2. **What is it for?** Feedback, spatial consistency (enters and exits the same way it is dismissed), state indication, preventing a jarring jump, or explanation. "Looks cool" on a frequent element means no.
3. **Is it the page's one authored moment?** One strong motion idea carried through a focal sequence beats the same entrance on every section. Never reinterpret every scrolled section as a staggered list.

Existing codebase: reuse its duration and easing tokens. Restraint skills ("no animation unless asked", "no custom curves") describe polish passes on existing Operate UI; follow them there.

## Easing

| Situation | Easing |
| --- | --- |
| Entering or exiting | ease-out |
| Moving or morphing on screen | ease-in-out |
| Hover, color change | `ease` |
| Constant motion (marquee, progress) | linear |
| Anything else | ease-out |

Never ease-in on UI: it delays movement at the moment the user is watching, so a 300ms ease-in dropdown feels slower than a 300ms ease-out one. Built-in keywords are too weak; define tokens once:

```css
--ease-out: cubic-bezier(0.23, 1, 0.32, 1);
--ease-in-out: cubic-bezier(0.77, 0, 0.175, 1);
--ease-drawer: cubic-bezier(0.32, 0.72, 0, 1); /* iOS-like sheet */
```

One project ease-out. Other skills use `cubic-bezier(0.16, 1, 0.3, 1)` or `cubic-bezier(0.2, 0, 0, 1)`; pick one and use it everywhere rather than mixing. No bounce or elastic curves by reflex.

## Durations

| Element | Duration |
| --- | --- |
| Button press feedback | 100–160ms |
| Tooltip, small popover | 125–200ms |
| Dropdown, select | 150–250ms |
| Routine state change | 150–300ms |
| Modal, drawer, view transition | 200–500ms |
| Authored focal entrance (Persuade) | 500–800ms |

- Everything except modals, drawers, view transitions and authored entrances stays under 300ms; a 180ms dropdown feels faster than a 400ms one.
- Exit faster and softer than enter.
- Long feedback reads as latency. A faster spinner makes loading feel faster.

## Scale, origin, stagger

- Press: `scale: 0.97` on `:active` via a transition, one token across the product, never below 0.95. Give pressable components a way to opt out where motion distracts.
- Enter from `scale(0.95)` plus `opacity: 0`, never `scale(0)`.
- Popovers and menus: set `transform-origin` to the trigger side (Radix exposes `--radix-popover-content-transform-origin`). Modals scale from center.
- Exit with a small fixed translate (about 12px), not the element's full height.
- Stagger list items 30–80ms apart; stagger semantic chunks of a rare staged entrance ~100ms apart. Cap total delay; never block interaction while it plays; never stagger high-frequency UI.

## Springs and interruption

- CSS transitions retarget mid-flight; keyframes restart. Use transitions for anything the user can retrigger quickly (hover, toggles, press), keyframes for one-shot sequences.
- Springs carry velocity through an interruption, which is why gesture-driven UI uses them.
- Default spring: critically damped (damping ratio 1.0, bounce 0), response about 0.3–0.4s. In Motion: `{ type: "spring", duration: 0.3, bounce: 0 }`.
- Bounce (damping ratio ~0.8) only when the gesture itself carried momentum: a flick, throw or drag release. Overshoot on a menu that faded in feels wrong.

## Properties and performance

- Animate `transform`, `opacity`, `filter` and `clip-path`. Never layout properties (`width`, `height`, `top`, `left`, `margin`, `padding`). Paint properties (`background`, `color`) only on small local elements.
- Name properties: `transition-property: transform, opacity`. Never `transition: all`; it animates whatever changes next, including theme colors.
- Blur at most 20px; heavy blur and large `backdrop-filter` surfaces are expensive, especially in Safari.
- `will-change` only on `transform`, `opacity`, `filter`, only when first-frame stutter is observed, never `will-change: all`.
- No window scroll listeners. Use `IntersectionObserver` for reveals or `animation-timeline: view()` / `scroll()` for scroll-linked motion, with a static fallback.
- CSS animations and WAAPI run off the main thread; JS-driven per-frame animation stalls under load.
- Pause looping animations when off-screen.
- Gate hover motion with `@media (hover: hover) and (pointer: fine)` so touch devices don't get stuck hover states.
- No enter animation on first render (`initial={false}` on `AnimatePresence`), unless the page entrance is the authored moment.

## Recipes

- **Enter:** from `opacity: 0; transform: translateY(12px); filter: blur(4px)` to rest, 250ms `var(--ease-out)`, for occasional content. Stretch it to 400ms only for a rare staged entrance.
- **Crossfade that looks off:** add `filter: blur(2px)` during the transition to mask the double image.
- **Icon swap:** scale 0.25 to 1, opacity 0 to 1, blur 4px to 0. Keep both icons in the DOM, one absolutely positioned; without a motion library cross-fade with `var(--ease-out)`, with one use a bounce-0 spring. (better-ui writes `cubic-bezier(0.2, 0, 0, 1)` here; the one project token wins.)
- **Image reveal on scroll:** `clip-path: inset(0 0 100% 0)` to `inset(0 0 0 0)` when it enters the viewport, once.
- **Comparison slider:** clip the top image with `clip-path: inset(0 50% 0 0)` and drive the right inset from drag position.
- **Underline animation:** a separate element scaled on `transform`, since only `text-decoration-color` animates reliably.

## Theme switch

Flipping themes fires every color transition at once and the switch smears. Inject `*,*::before,*::after{transition:none !important}`, read `document.body.offsetHeight` to force a style flush, then remove the style inside a nested `requestAnimationFrame` (two frames). Apply the same wrapper around an in-app toggle and the OS `prefers-color-scheme` change. `next-themes` ships it as `disableTransitionOnChange`.

## Gestures

- Dismiss on velocity, not only distance: `Math.abs(distance) / elapsedMs > 0.11` dismisses regardless of how far it travelled.
- Rubber-band past bounds instead of hard stops: `(overshoot * dimension * 0.55) / (dimension + 0.55 * Math.abs(overshoot))`.
- Require ~10px of movement (hysteresis) before committing to a direction, then track 1:1.
- Highlight on pointer-down, commit on pointer-up, allow cancel by dragging away.
- Call `setPointerCapture` while dragging so the gesture survives leaving the element.
- Only pay double-tap disambiguation delay where double-tap actually exists.

## Reduced motion and autoplay

Make motion opt-in:

```css
@media (prefers-reduced-motion: no-preference) {
  .card { transition: transform 200ms var(--ease-out); }
}
```

Tailwind: `motion-safe:` variants. Only where opt-in is impractical in an existing codebase, use the global fallback with `0.01ms` durations (not `none`, so `transitionend` and `animationend` still fire).

| Disable | Replace | Keep |
| --- | --- | --- |
| Parallax, autoplaying video and looping decoration, large movement across the screen | Slide, scale, zoom with an opacity crossfade; smooth scroll with an instant jump; auto-rotating carousels start paused | Spinners and progress, hover color and focus ring, brief press feedback |

- Anything moving, blinking or auto-updating for more than 5 seconds needs a visible pause control, regardless of the preference (muted hero video included).
- Toasts with an action or error stay until dismissed; timed ones last at least 5 seconds and pause on hover and focus.

## Reviewing motion

- Play it in slow motion (browser DevTools animation panel at 10–25%) or frame by frame; timing faults are invisible at full speed.
- Look again later with fresh eyes.
- Check each animation against the frequency table; delete before tuning.
