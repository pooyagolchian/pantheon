# Typography

## Contents
- Role scale
- Size floors
- Line-height
- Letter-spacing
- Measure
- Weights and families
- Choosing a face
- Wrapping, truncation, numerals
- Rendering details
- Copy and punctuation

## Role scale

Pair each size with its line-height and weight so a role is one decision, not three. Starting point for a product interface:

| Role | Size | Line-height | Weight |
| --- | --- | --- | --- |
| Display | 2.25rem (36px) | 1.1 | 600 |
| Title | 1.5rem (24px) | 1.2 | 600 |
| Heading | 1.125rem (18px) | 1.3 | 600 |
| Body | 1rem (16px) | 1.5 | 400 |
| Caption | 0.8125rem (13px) | 1.4 | 400 |

- This is a role scale, not a modular one: steps are chosen per role (16 to 18 is 1.125x, 24 to 36 is 1.5x), not derived from a fixed ratio. If you build a modular scale instead, use a 1.25–1.333 ratio. Either way keep 4–5 sizes in regular use; more is noise, not hierarchy.
- Emphasis inside a role is one weight step (400 to 500), never a size bump.
- Heading levels map to descending scale steps. A child heading never renders larger than its parent; deep levels may share a size if weight or tracking keeps them distinct. Pick the element from document structure, never for its default size.
- On a team, name sizes by use (`--text-body-sm`), not appearance (`--text-sm`).
- Persuade display text: cap at 6rem. Plan headline size together with the hero asset; a 4-line headline is a size error, not a copy error.

## Size floors

| Use | Size |
| --- | --- |
| Long-form body | 16px (move off it only for a nameable reason: small-running face, narrow measure, dense pro tool) |
| UI text (inputs, menus) | 14px |
| Captions | 13px |
| Absolute floor | 12px, rarely |
| Inputs on mobile | 16px, always |

iOS Safari zooms the page when an input's font-size is under 16px. Two fixes: size the input up on small screens (`font-size: 16px` then 14px from a breakpoint up; Tailwind `text-base sm:text-sm`), or keep 16px and render smaller with `transform: scale()` while compensating width and line-height. The first is simpler; use it unless the design must be pixel-identical across viewports. Never cap zoom in the viewport meta.

## Line-height

- Headings ~1.1; body 1.5–1.6. Use unitless values so line-height scales with size.
- Anything that wraps to 3+ lines needs at least 1.4, even in a height-constrained row (card descriptions are the usual casualty).
- Light text on dark surfaces: slightly more line-height, a touch more tracking, and one weight step more if the face looks thin.

## Letter-spacing

| Text | Tracking |
| --- | --- |
| Large display | -0.02em to -0.03em; floor -0.04em |
| Small uppercase labels | +0.05em |
| Body at reading sizes | 0 |

Tighten as size grows; never track body copy. Kerning is built into the font; leave `font-kerning` alone.

## Measure

Cap long-form text at 60–75 characters; target 65ch. Any unit works as long as the cap exists: at 16px body, 60–75 characters lands between roughly 560px and 680px (Tailwind `max-w-xl` 576px or `max-w-2xl` 672px). Recheck after changing the body size. Never `text-align: justify` in an interface.

## Weights and families

- Below 18px stay at 400 or heavier. Weights 100–300 are display-only, at 28px and up, and must still hold against their background.
- At most 3 families. Pair for contrast (serif display over sans body), never two near-identical sans faces, which read as a mistake.
- Use the optical variant matching the size: a font's `Display` cut for large sizes, `Text` cut for small. Set `font-optical-sizing: auto` on variable fonts.
- `font-synthesis: none` only after confirming every needed bold, italic and small-cap form exists in every fallback; otherwise emphasis silently disappears.

## Choosing a face

There is no whitelist and no blacklist. Derive the face from the brief and subject:
- Operate and Read: the system stack is a strong default (`system-ui, -apple-system, "Segoe UI", sans-serif`); it ships optical sizing and tracking tables.
- Persuade and Experience: a face with a point of view that matches the subject. Self-host it as `.woff2` with a metric-matched fallback stack.
- Never pick a face because it is the current default. Inter, Roboto, Geist, Space Grotesk, Plus Jakarta Sans, Fraunces, Instrument Serif and Recoleta are flagged as overused by impeccable's detector. They are not banned; they are a sign the choice was not made.
- An oversized italic serif hero headline is the current AI-startup cliché; use it only for a genuinely editorial brief.
- Monospace is for code, data and measurement, not a costume for "technical".
- Restyling or reviewing never requires a new typeface. Keep the product's family unless a type change is the task.

## Wrapping, truncation, numerals

| Declaration | Where |
| --- | --- |
| `text-wrap: balance` | Headings |
| `text-wrap: pretty` | Body text and descriptions (it avoids orphans at some layout cost; drop it only where very long or constantly re-laid-out text shows the cost) |
| `overflow-wrap: break-word` | Containers holding URLs, IDs, long words |
| `white-space: nowrap` | Labels, badges |
| `font-variant-numeric: tabular-nums` | Timers, counters, prices, table columns |

- Truncate one line with `overflow: hidden; white-space: nowrap; text-overflow: ellipsis`; several with `line-clamp`. If the hidden text matters, keep it reachable (tooltip or expanded view).
- `text-box: trim-both cap alphabetic` removes the font's built-in vertical padding so text centers in buttons and badges. Chromium 133+ and Safari 18.2+; treat as progressive enhancement.

## Rendering details

- `-webkit-font-smoothing: antialiased; -moz-osx-font-smoothing: grayscale` once on the root, never per component.
- Underlines: `text-underline-position: from-font; text-decoration-thickness: from-font`, then tune `text-underline-offset`. Only the color of a real underline animates reliably; build animated underlines as a separate element.

## Copy and punctuation

- Store copy in natural case; apply `text-transform` in CSS.
- Curly quotes in prose, straight in code; en dash for ranges (2010–2020); the single ellipsis character; `&nbsp;` to keep "16 px" together.
- Controls name their action ("Save changes", not "Submit"); errors name the problem and the recovery.
- Em dashes sparingly. A paragraph with three of them reads as generated.
