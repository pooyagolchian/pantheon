# Layout, states and accessibility

## Contents
- Grouping and hierarchy
- Spacing
- Responsive structure
- Persuade pages
- Interaction states
- Forms
- Browser surfaces
- Focus and keyboard
- Hit areas
- Semantics and announcements
- Zoom and reflow
- Severity on sight

## Grouping and hierarchy

- Group by meaning with proximity first, background shapes second, separator lines last. Inter-group gap at least 2x intra-group (8px within, 16px+ between), or grouping reads as noise.
- Most important content near the top and the leading edge. Think leading/trailing, not left/right.
- Every control has a background shape, border or consistent placement zone; a control styled like adjacent text does not read as a control.
- Pick alignment edges and keep them; every stray edge is noise. One spacing step per level of subordination (16px is a good default).
- Squint test: blurred, primary, secondary and major groups still read in order.
- Exactly one filled primary action per view; peers stay neutral.
- Content bleeds, controls float: backgrounds and media reach the viewport edges; text and controls stay inside layout margins and `env(safe-area-inset-*)`.
- A modal only for a task that needs interruption or protected focus.

## Spacing

- Documented scale on a 4px base: 4, 8, 12, 16, 20, 24, 32, 40, 48, 64, 80, 96. Use `gap` for sibling rhythm over child margins.
- Rhythm comes from contrast between tight and generous intervals; uniform spacing everywhere is monotone.
- More space above a heading than below it, so the heading binds to its own section.

| Between | Starting point |
| --- | --- |
| Adjacent bordered or filled controls | 12px |
| Around borderless text or icon buttons | 24px |
| Unrelated control groups | 24px+ |
| Mobile inline layout margin | ~16px |
| Next carousel item peek | 16–32px |

- Full-width mobile buttons stay inside the margins with a visible radius; bottom padding `calc(16px + env(safe-area-inset-bottom))`.
- Collapsed content needs a cue labelled with what is hidden ("Show 12 more results", not "More").

## Responsive structure

- Breakpoints from the content, not device presets. Keep the expanded layout while it genuinely fits; collapse late.
- Container queries for components that live in several contexts; viewport queries for page structure. Prefer `rem` breakpoints.
- Responsive changes are structural: reorder, collapse, reflow or reveal by importance, not just shrink.
- Test the smallest and largest sizes first; declare the narrow fallback in the same component as every multi-column layout.
- No fixed width or height on any text container; let rows wrap. Translations grow and short strings grow most, so a one-word button label is the riskiest thing on screen. Test with pseudo-localization.
- Viewport height: `min-height: 100svh` for anything that must fit the first viewport (the small viewport, with mobile browser chrome shown). `100vh` is the large viewport, so content hides under that chrome. Use `dvh` only where resizing as the chrome shows and hides is acceptable. Use `min-height`, never `height`.
- Never park a critical action where resizing or scrolling clips it.
- z-index from one fixed scale (0 / 10 / 20 / 40 / 100 / 1000), each step assigned to one layer role once. Never arbitrary values.

## Persuade pages

- Hero fits the first viewport (`min-height: 100svh`): headline at most 2 lines, subtext at most 20 words, at most 4 text elements (headline, subtext, CTAs with 1 primary and at most 1 secondary), top padding at most ~6rem.
- Logo walls and testimonials go in a section below the hero, never inside it, and only with real ones.
- Nav on one line at desktop, 64–72px tall, 80px max.
- Each layout family appears once per page; no more than 2 consecutive image-plus-text zigzag sections.
- A bento grid has exactly as many cells as content items, with real variation between cells.
- No eyebrow labels, no 01/02/03 section numbers unless the sequence is information.

## Interaction states

Every interactive surface ships each of these, built with realistic content:

| State | Requirement |
| --- | --- |
| Hover | Visible change; gated by `@media (hover: hover)` so it doesn't stick after a tap |
| Active | Press feedback (scale 0.97 or color shift) |
| Focus | `:focus-visible` ring, never bare `:focus` |
| Disabled | Visibly inert; explain why if not obvious |
| Loading | Skeleton matching the final layout's geometry, so nothing jumps |
| Empty | Explain the state and give exactly one clear next action |
| Error | Inline, next to where the action happened, naming the problem and the recovery |
| Success | Confirm the outcome; don't leave the user guessing |

- Destructive or irreversible actions: an alert dialog, or an undo window.
- Toasts with an action or error persist until dismissed; critical information never lives only in a timed element.
- Long text, missing images, zero items and 10,000 items must not break the layout.

## Forms

- Visible label above every control (`<label for>` or wrapping `<label>`); helper text below the label, error below the field. A placeholder shows an example format, never acts as the label.
- Keep submit enabled until the request starts; validate on submit; focus the first invalid field; disable only while the request is in flight.
- Errors: `aria-invalid="true"` plus `aria-describedby` pointing at the inline message; an icon or text, never a red border alone.
- Never block paste or filter characters while typing; trim values before validating.
- Correct `type` and `autocomplete` on every personal field (`email`, `tel`, `name`, `street-address`, `postal-code`, `cc-number`, `current-password`, `new-password`, `one-time-code`).
- Required fields: native `required` plus a visible marker explained once per form.

## Browser surfaces

The defaults that ship unless themed, and the cheapest sign that a page was built rather than assembled:
- `::selection` background and color from the palette.
- `caret-color` on inputs.
- Scrollbars (`scrollbar-color`, `scrollbar-width: thin` where it fits).
- Focus ring color token.
- `text-underline-offset` on links.
- `tabular-nums` in data.
- `-webkit-font-smoothing: antialiased` once on the root.

## Focus and keyboard

- Native elements first: `<button>`, `<a href>`, `<input>`, `<dialog>`, `<details>`. Never rebuild keyboard behavior by hand when a native element or an accessible primitive library exists.
- Prefer the browser focus indicator plus `outline-offset: 2px`. A custom one is `outline: 2px solid var(--focus-ring); outline-offset: 2px`, never bare `currentColor`, checked around its whole perimeter against every color it crosses and in `forced-colors: active` (use system colors such as `Highlight` there).
- Never `outline: none` without a verified replacement.
- `:focus-within` to light a wrapper whose inner input has focus.
- Skip link as the first focusable element, targeting `<main id="main">`; anchor targets get `scroll-margin-top` clearing any sticky header.
- `tabindex`: `0` only for custom controls that aren't natively focusable, `-1` for programmatic focus targets, never positive. Composite widgets (tabs, menus, toolbars, radio groups) use one tab stop with roving tabindex and arrow keys.
- Modals: background `inert`, focus moves in on open, Escape closes, focus returns to the trigger.

## Hit areas

| Standard | Size |
| --- | --- |
| WCAG 2.5.8 AA (hard floor) | 24x24px |
| Desktop target where density permits | 40px |
| Touch target for primary controls | 44px |

- A smaller target passes under the spacing exception when a 24px circle centered on it intersects no other target; in the simple case a 20px target needs a 4px gap.
- Extend a small visual with an absolutely positioned pseudo-element sized to the target (for example 44x44px centered on it) rather than enlarging the visual.
- Spacing clearances are on top of hit areas; expanded hit areas never overlap.

## Semantics and announcements

- Icon-only buttons get a descriptive `aria-label`; visible label text must appear in the accessible name.
- `aria-hidden="true"` on decoration only, never on a focusable element.
- Color is never the only carrier of meaning; add an icon, text or underline.
- Alt text by purpose: decorative `alt=""`, informative describes the meaning, functional describes the action (`alt="Search"`, not "magnifying glass").
- One `<h1>`, levels nested without skipping, one visible `<main>`.
- Live updates: field errors via `aria-describedby`; non-urgent updates via a polite `role="status"` region rendered empty before its text changes; `role="alert"` only for urgent errors not tied to a field.

## Zoom and reflow

- Works at 200% zoom and reflows at 320px width without horizontal scrolling.
- `min-height`, not `height`, on text containers; spacing in `rem`/`em` so it scales with the user's text size.
- Never set `maximum-scale` or `user-scalable=no` in the viewport meta.

## Severity on sight

Report as HIGH without further debate:
- A control with no accessible name.
- A keyboard-reachable control with no visible focus.
- Motion that ignores reduced motion.
- Content clipped at 320px or 200% zoom.
- An error message that names no recovery.
- A destructive action with no confirm or undo.
- Body text below its contrast threshold, or a color that misstates meaning (accent on non-interactive text, success hue on an error).
