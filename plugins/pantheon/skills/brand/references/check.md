# Check: is this on-brand?

Review copy, UI code, or images against `BRAND.md` and report violations someone can act on. This mode **reports**. It edits only when the user asks for fixes.

## What to check

### Copy (pages, components, content files, emails)
- Facts: every name, number, client and claim appears in `BRAND.md` section 1. Anything else is a finding of type **unverified claim**.
- Language: brand-banned words, general AI-isms (see `write.md`, unless the profile allows them), preferred vs avoided terms, inclusive and regulated language rules.
- Mechanics: spelling locale, punctuation rules (search for `—`, `–`, `&mdash;`, `&#8212;` if dashes are banned), heading case, how numbers and dates are written, product-name casing.
- Verbatim blocks: compare them character for character with section 8.
- Entity consistency: the name, description and title pattern match section 7 everywhere.

### UI code (CSS, Tailwind, components, email templates)
- **Colour**: search for hard-coded hex, rgb or hsl values and arbitrary Tailwind colours (`text-[#...]`). Each one should map to a palette token. Flag accent colours used on large surfaces or for body text, and any off-palette colour.
- **Type**: check font families against the type lock. Flag a third family, banned fonts and weights outside the allowed range.
- **Logo**: check variant, background pairing, minimum size and clear space. Flag stretched or recoloured files.
- **Layout rules** from section 5: radius, shadows, borders, density, motion. Search for the classes and properties that would break them, such as `shadow-`, `rounded-` and `gradient`.
- **Contrast**: text against background must meet WCAG AA (4.5:1 for body text, 3:1 for large text). Compute it from the token hex values.
- **Hard-coded copy** in components, if the project keeps copy in content files.

### Images and image prompts
- Does the image match the do / don't lists and the mood in section 6?
- Do generation prompts follow the profile's template, including "No text." where it applies?
- Do filenames and placement follow the naming convention?

## How to run it

1. Load `BRAND.md`. If it's missing, stop and offer to extract first.
2. Scope the check to the files, page or diff the user named. For a whole repo, start with global styles, layout components and the main content files.
3. Use search for mechanical rules (hex values, dashes, banned words, font names) and reading for judgment rules (voice, imagery mood).
4. Rate each finding:
   - **blocker**: wrong fact, altered verbatim text, off-palette brand colour, broken logo rule, failed contrast
   - **major**: banned word, a third font, an accent colour used as a large fill, voice clearly off
   - **minor**: mechanics such as dashes, heading case or spelling locale

## Report format

| Severity | Location | Rule (BRAND.md §) | Found | Fix |
|---|---|---|---|---|
| blocker | `app/about/page.tsx:42` | §1 facts | "serving 50,000 users" | Profile says 12,000+. Use that, or confirm the new number and add it to §1 |
| minor | `content/home.ts:8` | §4 mechanics | em-dash in subtitle | Replace with a full stop |

End with:
- counts by severity
- the rules you couldn't check, and why
- any findings that suggest `BRAND.md` itself is out of date. Propose an update rather than "fixing" the site to match a stale profile.
