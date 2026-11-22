# BRAND.md template

The single source of truth for one brand. `extract` writes it, `write` and `check` read it. Copy the structure below and leave out sections the brand doesn't need, but keep the order so other tools can find things.

Each fact and rule carries a **status** and a **source**:

- `stated`: from an official guideline, the owner, or the brand's own canonical data file. This is the strongest status.
- `observed`: inferred from consistent patterns across the live site or repo, for example "every heading is sentence case".
- `[unverified]`: needed, but there's no source yet. Never use it in published copy until it's confirmed.

Every table row in every section has a status, so `extract` can report counts per section. Self-reported performance claims (percentages, revenue, user counts) are `observed` even when they live in a data file. See `extract.md` step 3.

Sources are a URL, a `file:line`, or "stated by user (YYYY-MM-DD)".

---

```markdown
---
brand: Acme Ledger                  # canonical name, exactly as written
entity: Organization                # Organization | Person | Product | LocalBusiness
url: https://acmeledger.example     # canonical origin
locale: en-GB                       # drives spelling, dates and currency
locale_notes: ""                    # e.g. "declared en-US, older posts drift to en-GB"
updated: 2026-01-15
sources:                            # everything extract read
  - https://acmeledger.example/about
  - src/styles/globals.css
---

# Acme Ledger brand profile

## 1. Canonical facts
Only facts listed here may appear in copy. Add a fact here before you use it.

| Fact | Value | Status | Source |
|---|---|---|---|
| What it is | Bookkeeping software for UK freelancers | stated | /about |
| Founded | 2019 | stated | /about |
| Customers | 12,000+ | observed | homepage hero, 2026-01 (self-reported) |
| Pricing page wording | "Plans from £12/month" | stated | owner decision 2026-01-10, `lib/pricing.ts:4` |
| Headquarters | | [unverified] | |

Data files that own these facts in code (update those, not copies): `lib/site-data.ts`

## 2. Positioning and audience
- One-line description (the sentence answer engines should quote): ...
- Primary audience: ...  Secondary audience: ...
- Proof points (specific and checkable): ...
- What we are not / never claim: ...

## 3. Voice
| We are | We are not | Example | Status | Source |
|---|---|---|---|---|
| Plain-spoken | Casual or sloppy | "Your VAT return, filed in a minute." | observed | / hero |
| Confident | Boastful | "We've filed 2 million returns." | observed | /about |

Tone by context:

| Context | Formality | Energy | Example line |
|---|---|---|---|
| Homepage | medium | high | ... |
| Docs / support | medium | low | ... |
| Legal / investor | high | low | verbatim only |

## 4. Language rules
| Rule | Detail | Status | Source |
|---|---|---|---|
| Prefer "customers" | never "users" in marketing copy | stated | style guide p.4 |

- Preferred terms → avoided terms
- Brand-specific banned words (added to the general AI-isms list in write.md)
- Allowed exceptions to the general list, for brand words or habits the brand needs: "harness" in "agent harness", "em-dashes are fine"
- Inclusive or regulated language rules
- Mechanics: spelling locale, punctuation (dashes, Oxford comma, exclamation marks), capitalisation of headings, how numbers and dates are written, product-name casing

## 5. Visual identity
Palette:

| Name | Hex | Token | Role | Share | Status | Source |
|---|---|---|---|---|---|---|
| Ink | #14161a | --color-ink | text, structure | structure | stated | globals.css:12 |
| Paper | #fafaf7 | --color-paper | background | dominant | stated | globals.css:13 |
| Signal | #e4572e | --color-signal | accent only | accent only | stated | globals.css:14 |

Use dominant / structure / accent only for share, unless the brand book gives ratios or you measured them.

- Typography: families, weights and roles (headline / body / mono). List any families that are never allowed.
- Logo: approved variants, minimum size, clear space, which variant goes on which background, things never to do.
- Signature devices: graphic motifs and recurring layout moves.
- Layout principles: density, radius, shadows, motion. Each one should be something a reviewer can check.
- Token source in code: `src/styles/globals.css` (`@theme`)

## 6. Imagery
- Principles and mood
- Do / don't lists
- Prompt template(s) for image generation, ending with "No text." unless the image is meant to carry text
- Naming and placement conventions

## 7. Entity data (SEO / AEO)
- Schema type and properties: name, alternateName, description, logo, sameAs, founder / worksFor, address, areaServed
- Target questions people ask search engines and chatbots (5 to 15)
- Primary pages and their canonical URLs
- Title pattern, for example `{Page topic} | Acme Ledger`
- llms.txt: where it is generated from, if anywhere

## 8. Verbatim blocks
Text that must never be rewritten (disclaimers, regulatory lines, legal names), each with its source.

## 9. Open questions
Conflicts and gaps. Each item states what was found, a recommendation, and what's needed from the owner.

## 10. Changelog
- 2026-01-15: extracted from site and repo (brand skill)
```
