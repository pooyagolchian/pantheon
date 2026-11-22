# Write: on-brand copy that people trust and answer engines cite

Copy has two readers. One is a person deciding whether to believe it. The other is a search or answer engine (Google, AI Overviews, ChatGPT, Perplexity, Claude) deciding whether to rank or quote it. Both reward the same things: a direct answer, specific checkable facts, and no filler.

Load `BRAND.md` first. Its facts, voice and language rules override the general rules below.

## Workflow

Follow this order whenever you revise text. For short surfaces, use the shortcuts at the end.

1. **Identify the surface**: homepage, About, service or product page, blog post, case study, FAQ, meta tags, Open Graph, `llms.txt`, email, social post.
2. **Name the implied question.** Ask what a person or a model is trying to find out from this text. Write it down. It drives the lead, the headings and the FAQ.
3. **Strip filler.** Remove the general AI-isms below plus the brand's own banned words. Delete openers that only clear the throat.
4. **Rewrite the lead** so the first sentence answers the question and names the subject, for example: "Acme Ledger is bookkeeping software for UK freelancers that files VAT returns directly to HMRC."
5. **Atomise.** Each paragraph must still make sense if a model quotes it alone. Repeat the subject's name ("Acme Ledger", not "it" or "the platform") at the start of a paragraph.
6. **Swap claims for specifics** taken from `BRAND.md`, such as numbers, names, dates and tools. If the right specific isn't in the profile, mark the spot `[unverified]`. Never fill it with a plausible-sounding figure.
7. **Apply the brand's voice and mechanics**: register for this context, preferred terms, spelling locale, punctuation and heading case.
8. **Add structure for the surface**: question-shaped headings, FAQ, a JSON-LD recommendation, meta tags, internal links (see below).
9. **Read it as the skeptical reader.** Cut any sentence that a competitor could publish unchanged.
10. **Report**:
    - what you cut
    - which specifics you added, with sources
    - `[unverified]` items for the owner
    - brand rules you applied, or deliberately bent and why

## General AI-isms to remove

The brand profile can allow any of these back. If it doesn't, remove them.

- **Words**: delve, leverage, tapestry, seamless, robust, comprehensive, unlock, empower, harness, pave the way, game-changer, cutting-edge, revolutionary, transformative, elevate, supercharge, synergy, holistic, paradigm, world-class, best-in-class, foster, realm, ever-evolving.
- **Metaphors**: journey, navigate, landscape.
- **Openers**: "in today's fast-paced world", "In this article", "Let's explore", "When it comes to", "It's important to note".
- **Patterns**:
  - triplets used to fill space where one specific fact would do
  - "not just X, but Y"
  - closing summaries that repeat the paragraph
  - stacked hedges ("may potentially help")
  - passive voice that hides who did what
- **Punctuation**: em-dashes and colons used as the default way to explain something. Write the sentence instead, unless the brand allows them.

Prefer active voice and strong verbs. Mix short declarative sentences with one longer sentence per paragraph so the rhythm doesn't go flat.

## Answer-engine rules (AEO)

1. **Lead with the answer.** The first sentence of the page and of each section answers its question directly.
2. **Question-shaped headings.** H2 and H3 headings are phrased the way people ask, taken from the target questions in `BRAND.md` section 7, for example "How much does Acme Ledger cost?".
3. **Stand-alone blocks.** Keep one idea per paragraph, name the subject, and avoid "as mentioned above".
4. **Checkable specifics.** "Files VAT returns to HMRC in under a minute" beats "fast and easy".
5. **FAQ** on long pages: 3 to 6 questions from the target list. Answers are 40 to 80 words, self-contained, and lead with the answer.
6. **Consistent entity.** Use the canonical name, description and facts identically everywhere. Answer engines cross-check them.
7. **llms.txt / llms-full.txt**: plain factual sentences, one per line, no marketing language, the canonical URL first, and links to the main pages. If the site generates the file from a data file (noted in `BRAND.md`), edit that file instead.

## Search rules (SEO)

- **Title**: 50 to 60 characters, main topic first, brand last, following the pattern in `BRAND.md`.
- **Meta description**: 140 to 160 characters. Give the answer plus a reason to click. No keyword stuffing.
- **Headings**: one H1 per page, matching the search intent.
- **Internal links**: use descriptive anchor text pointing at the main pages, never "click here".
- **Image alt text**: describe the image. For a portrait, name the person and their role as `BRAND.md` gives it.
- **Canonical URL, Open Graph and Twitter Card**: on every page. The OG image is 1200×630.

## Structured data by surface

Recommend or generate JSON-LD that uses only facts from `BRAND.md`:

| Surface | Schema |
|---|---|
| About / home | `Organization` or `Person` (name, description, logo/image, url, sameAs, founder or worksFor, address) |
| Blog post | `Article` / `BlogPosting` with an `author` (Person) and a `publisher` |
| Service / product page | `Service` / `Product` (and `Offer` only if the price is in the profile) |
| FAQ block | `FAQPage` |
| Nested route | `BreadcrumbList` |

## Shortcuts

- **Meta description or OG text only**: give 2 or 3 options of 140 to 160 characters that lead with the answer, name the brand where natural and use no banned words. Skip the full workflow.
- **One paragraph**: do steps 3 to 7 and report in one line.
- **llms.txt block**: list the facts from the profile, one per line, in order: what it is, who it's for, proof points, main pages, contact.
