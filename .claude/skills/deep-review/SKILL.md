---
name: deep-review
description: Full quality pass over the site: structure via reader-review, then prose via writing-voice, then broken links and anchors, then a rebuild and the three checks. Fixes what is mechanical and reports what needs judgement. Needs credentials and takes 15 to 30 minutes, so run it deliberately rather than at the end of a session; use wrap-up for that.
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Edit, Write, Agent, Skill
---

# Deep review

A full quality pass, run deliberately. It needs a live Workbench session, it may start the cluster, and it takes 15 to 30 minutes. **If you are closing a session, you want `wrap-up` instead**, which needs nothing and takes under a minute.

## What it fixes and what it reports

The line is the one `reader-review` already draws between its two phases.

**Fixed without asking**, because the standard is measured and the fix is mechanical:

- heading length and grammar, against the 245-heading comparator standard
- broken internal links and anchors
- stripped and surviving bold lead-ins
- freeze caches left stale by an edit

**Reported for you to decide**, because each needs taste or removes something:

- running order, completeness, necessity, register, enumeration
- anything that deletes a section
- anything that changes what a page claims

When in doubt, report. A fix you had to think about is a fix the human should see.

## Order, and why it is not negotiable

Structure moves prose. Renaming a heading orphans the sentence beneath it: a pronoun whose antecedent was in the heading, or an opening that only parsed as a continuation of it. A pass over 85 renames on 2026-09-02 left nine sections defective that way, because the prose pass was never re-run.

So the order is **structure, prose, links, render, check**, and each step assumes the one before it has finished.

Rendering last matters for a second reason: it is the only expensive step, and doing it once at the end costs one pass instead of five.

## Steps

### 1. Confirm the session is live

```bash
Rscript check-databricks-access.R
```

Stop if this fails. Everything below either needs credentials or produces work that cannot be committed without them, and a half-finished pass on frozen pages is worse than none. `wrap-up` still works, so use it to record where you stopped.

### 2. Structure: `reader-review`

Invoke the `reader-review` skill. It measures every page, then judges them from a scrubbed worktree.

Act on its **rule 3** findings, which are the mechanical ones: headings over eight words, verdict grammar, headings that do not match their section. Leave the rest.

**Every heading you rename re-opens the prose beneath it.** Note which sections you touched; step 3 needs the list.

Two exceptions the skill records and this pass must respect: `ref/when-it-breaks.qmd`'s symptom headings stay long, and a page that was split or renamed since the last run is unreviewed whatever its old score said.

### 3. Prose: `writing-voice`

Invoke the `writing-voice` skill in check mode, over **the sections step 2 touched** plus any page it reports as changed. Not the whole site unless nothing was touched.

Act on: stripped bold lead-ins, surviving `**Bold.**` lead-ins, fragments left by a rename. Report the rest.

### 4. Links

```bash
python3 scripts/check-links.py --nav
```

Fix every break. A dangling anchor is almost always a heading step 2 renamed, so the fix is the new anchor rather than restoring the old heading.

### 5. Render

Only what is stale:

```bash
scripts/check-freeze.sh 2>&1 | grep '^FAIL' | cut -d' ' -f2
```

For each page, decide from what you changed:

- **prose only**: `quarto render <page>`. Executes nothing **if the page declares `freeze: true` in its own front matter**. Every `example/` page does; most `howdoi/` pages rely on the project setting, and a single-document render overrides that, so they will execute and need the session.
- **code changed**: `scripts/rerender.sh <page>`, which drops the cache so the chunk runs.

Start the cluster only if a stale page needs it, which means it rests on worker machines, distributed execution, or cluster metadata. `example/bootstrap.qmd` and `howdoi/simulate-on-the-cluster.qmd` are the two, and `bootstrap` also needs `WQ_RUN_CLUSTER=true` or it silently drops its cluster output.

```bash
scripts/start-cluster.R --status     # reports and starts nothing
scripts/start-cluster.R              # idempotent start; ~7 minutes cold
```

**Never stop a cluster.** Both auto-terminate at 90 idle minutes.

### 6. Check

```bash
scripts/check-freeze.sh
python3 scripts/check-links.py --nav
scripts/check-public.sh
Rscript scripts/check-facts.R
```

All four must pass. Then **read the rendered output**, because `quarto render` exits 0 on nonsense: `scripts/page-md.sh <page>` prints what a page actually produced. Check that a number in the prose still matches the block above it, and that no output contradicts its own introduction.

That last check is not ceremony. On 2026-09-03 a re-render produced a timing table showing forking *slower* than serial, contradicting the page's own argument, and only reading the output caught it.

## Report

Under 40 lines.

```
# Deep review: [scope], [date]

## Fixed
Grouped by kind, with counts. One line each, not a list of every edit.

## For you to decide
Each with page:line, the quote, and the concrete reader failure. Most severe first.
This is the section that matters; the one above is bookkeeping.

## Checks
Each check and its result.

## Not done
Anything skipped, and why. A page that could not be rendered, a finding left
because it needed a decision, a section deliberately left alone.
```

## Guidelines

- **Do not commit or push.** Leave the tree for the human to review, however clean it looks.
- **Do not act on a judgement finding** because it seems obvious. That is what the report is for.
- **Count, do not estimate.** "Nine headings" means you counted nine.
- **A short report is a good outcome.** If structure and prose are sound, say so in three lines rather than manufacturing findings.
