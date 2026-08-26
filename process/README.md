# How work gets done here

**What this directory is.** Tracked, neutral notes on the *method* of building this site: the order to do things in, what to reuse rather than rebuild, and how to verify. It holds no finding, no engagement detail, no personal annotation, and nothing about what the site says.

That last part is the boundary. `context/` records what the neighbouring documentation sites say. `CODE-STYLE.md` records what the R should look like. `CLAUDE.md` records what the site is and who it is for. This directory records only how to work on it.

**Why it is separate from `docs/`.** `docs/` is gitignored on purpose, because it carries private material: contribution planning, judgements about upstream projects phrased for a maintainer, offers of work that may not be honoured. The repo has already made this separation once. The upstream documentation audit began in `docs/` and moved to `context/` when the neutral findings were split from the private ones, and `docs/README.md` records that move. This directory follows the same precedent: the publishable method here, the private material there.

So the test for anything added: could a stranger read it without learning who the client is or what was promised to whom? If not, it belongs in `docs/`.

**These files are tracked and therefore published**, and are subject to `scripts/check-public.sh` like anything else. They are not part of the site: `_quarto.yml` has an explicit render list and `process/` is not on it. Do not add it, and do not link to these files from a page.

| File | What it covers | Read it when |
|----|----|----|
| [`drafting-pages.md`](drafting-pages.md) | Sequencing, batching by compute, briefing subagents, verification | Writing or revising more than one page |
| [`presentation-layer.md`](presentation-layer.md) | Theme files, the type scale, the width arithmetic for code blocks | Touching `assets/*.scss`, the `format:` block, or a home-page code line |
| [`upstream-changelog.md`](upstream-changelog.md) | How findings arrive, the consumed-through marker, what each entry changed | Acting on a changelog entry, or widening a `rests on:` line |
| [`PROBLEM-freeze-cache-staleness.md`](PROBLEM-freeze-cache-staleness.md) | An open bug: the freeze check can pass while the cache is stale | Working on `scripts/check-freeze.sh`, or if a page publishes output you did not expect |
| [`DESIGN-fact-table.md`](DESIGN-fact-table.md) | A proposal, not built: measured numbers in a data file rather than typed into prose | Deciding what to do about a number that keeps going stale |
| [`TODO-in-catalog.md`](TODO-in-catalog.md) | Unfinished: 15 `tbl(con, I(...))` still to become `in_catalog()` | You have live credentials and want a small, well-specified job |

## The short version

If you are about to write or revise more than one page, read `drafting-pages.md` first. It exists because a session that drafted nine pages found the expensive part was never the writing or the fact-checking. It was rediscovering the same setup nine times, and revising pages that were written before the relevant upstream findings had been read.
