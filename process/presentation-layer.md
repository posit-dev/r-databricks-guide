# The site's presentation layer

*Split out of `CLAUDE.md` to keep that file navigable. Read this before changing the theme, the type scale, or the width of anything.*

The theme lives in `assets/site.scss` (light, on `cosmo`) and `assets/site-dark.scss` (dark, on `darkly`), wired up in `_quarto.yml` under `format: html:`. **Both files must stay declared.** Quarto compiles one stylesheet per mode, so dropping the dark one silently leaves dark mode as unmodified `darkly` rather than erroring.

These came from the `quarto-website` skill, which names them after their author and calls those filenames load-bearing. **They are deliberately renamed here, and must stay renamed**: the blocklist in `scripts/check-public.sh` matches a personal name as a word, and a filename reaches `_quarto.yml` as tracked, published text. So do not restore the skill's names, and if you re-copy the files, rename them again and strip the attribution comments from the headers. Nothing is lost by it: the compiled CSS is byte-identical either way.

Verifying a theme change means reading the compiled CSS, not the source. A SASS error can fail silently into an unstyled page, so `Output created:` is not evidence:

```bash
rm -rf _site/site_libs/bootstrap && quarto render   # or you may read stale CSS
grep -hoE '\-\-bs-link-color: #[0-9A-Fa-f]{6}|\-\-bs-body-bg: #fbfaf8|\-\-bs-root-font-size: 17px' \
  _site/site_libs/bootstrap/bootstrap*.min.css | sort -u
```

Expect `#447099` (light links), `#7494B1` (dark links), `#fbfaf8` (paper) and a 17px root. Two traps: the filenames are content-hashed, so an unglobbed path finds nothing and reads exactly like a pass; and the root type appears as `--bs-root-font-size`, never as `html{font-size:17px}`.

The navbar has been checked at narrow widths and collapses cleanly, so five sections with four dropdowns is not too wide.

The two annotated code blocks on `index.qmd` are **stacked full-width**, not side by side, and the code is deliberately terse. Both constraints are load-bearing, so keep them if you edit the page.

The right-hand comments (`#   on Databricks`, `# <== how much crosses?`) are aligned into a column, and that alignment is the whole point of the examples: it is how the page shows that one line decides where the work happens. When a line exceeds the measure it wraps, the column breaks, and the meaning goes with it. `code-overflow: wrap` means that degrades silently rather than showing a scrollbar, so nothing warns you.

**Do the width arithmetic before lengthening a line**, because eyeballing it is what got this wrong once already. Code renders at `0.875em` on a 17px root, and Source Code Pro advances 0.6em, so a character is 8.9px.

The measure is set with `$grid-body-width`, which **must be `$grid-body-width` and must be in `px`**. Quarto has no `$content-max-width`: setting one compiles cleanly, changes nothing, and leaves the site at the 800px default while the SCSS reads as though the measure were set. This repo shipped that bug until it was measured. A `rem` value fails compilation outright, against `quarto-math.min(500px, $grid-body-column-max)`.

Quarto also subtracts a `3em` gutter, so the usable column is the variable less 51px at a 17px root, and then less about 16px of `pre` padding. At the 800px set here that is 733px:

- full-width: 733px, about **82 characters**
- one `.g-col-md-6` of a two-column `.grid`: 350px, about **39 characters**

Grep the compiled CSS for `800px` to confirm it applied: it lands inside the `calc()` in the grid definition, never on a `max-width` property, and zero hits means the variable name was wrong.

That 39 is why side by side was abandoned: it cannot hold an annotated pipeline. Terse also survives a phone better than the measure alone suggests, which is the second reason to keep it. The navbar is fine when narrow, already checked.
