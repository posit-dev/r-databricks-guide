# Design: one table of measured facts, inserted into prose rather than typed

## The problem this solves

A number that was measured once and typed into prose has no owner and no expiry. Nothing recomputes it, nothing links it to the measurement that produced it, and nothing knows which pages would be wrong if it changed.

The scale is worth stating before designing anything. `97`, the count of built-in `ST_` functions, appears **four times across two pages**: twice in body prose and twice inside a `rests on:` line. `32.5 million`, the readings row count, appears on **six pages**. Each occurrence is an independent chance to drift, and a fact check that updates one and misses another leaves the site contradicting itself, which is worse than being uniformly stale.

Three registers make a plain find-and-replace unsafe:

- digits: `93 on an all-purpose cluster`
- words: `Ninety-seven distinct functions`
- deliberate vagueness: `about twenty other `sf` staples`, `roughly seven minutes`

The third is not sloppiness to be tidied away. `about twenty` is honest where the exact count is unstable, and the mechanism must preserve the ability to say it.

## What is in scope

Facts that were **measured against a real system** and could change if measured again: function counts, row counts, byte lengths, timings, version numbers, and the dates on which each was established.

Explicitly out of scope:

- Numbers that are definitional rather than measured: `EPSG:27700`, `1,024` bytes as the ODBC truncation modulus, `65535` as a driver setting. These are properties of a standard or an API, not observations, and freezing them in a data file adds indirection for nothing.
- Anything already produced by execution. An executing chunk is a better mechanism than this one, because the number and the code that made it are adjacent and cannot disagree. **Prefer converting a page to executing chunks over adding its numbers here.** This design is for facts that cannot be recomputed at render time, typically because they need compute the render must not assume.

## Storage: YAML, one file, `facts/measurements.yml`

YAML rather than CSV, because each fact needs more than a value: a unit, a date, the compute it was measured on, and the pages that depend on it. That is a record, not a row, and CSV would force either a wide sparse table or a second lookup.

One file rather than one per topic, because the questions asked of it are cross-cutting ("what is stale?", "what does this page depend on?") and a single file makes them one read.

```yaml
# facts/measurements.yml
#
# Every number in this file was measured. Nothing definitional belongs here:
# EPSG codes, the 1024-byte ODBC modulus and driver settings are properties of
# a standard, not observations, and they stay written into the prose.
#
# Prefer executing chunks to entries here. A fact belongs in this file only
# when the render cannot recompute it, which usually means it needs compute
# the render must not assume.

spatial_functions_warehouse:
  value: 97
  unit: functions
  measured: 2026-08-24
  compute: Pro warehouse, serverless
  method: SHOW FUNCTIONS LIKE 'st_*', distinct names
  volatile: true          # vendor may add functions at any time
  note: >
    Distinct names, no aliases, geography not counted twice. Two are
    aggregates and five are geography constructors.
  used_by:
    - ref/spatial-functions.qmd
    - howdoi/polygons.qmd

spatial_functions_cluster:
  value: 93
  unit: functions
  measured: 2026-08-24
  compute: all-purpose cluster, DBR 18.1
  volatile: true
  used_by:
    - ref/spatial-functions.qmd
    - howdoi/polygons.qmd

readings_rows:
  value: 32540721
  unit: rows
  measured: 2026-08-24
  compute: Pro warehouse, serverless
  volatile: false         # a static published dataset
  used_by:
    - ref/data.qmd
    - howdoi/big-table.qmd
    - example/reducing.qmd
```

`volatile` is the field that earns its place. It separates "this will change and we should expect to re-measure" from "this is stable and a stale reading is nearly harmless", which is what makes a staleness report actionable rather than noise.

## Insertion: an inline R call, not a templating language

Quarto already has inline R. Adding a second templating syntax would mean a second thing to learn and a second thing to break.

```r
# R/facts.R
fact <- function(key, format = c("digits", "words", "value")) { ... }
```

Usage in prose:

```markdown
There were `r fact("spatial_functions_warehouse")` on a Pro warehouse and
`r fact("spatial_functions_cluster")` on an all-purpose cluster.

`r fact("spatial_functions_warehouse", "words")` is a lot, and it is still
not all of `sf`.
```

The `format` argument is what handles the three registers. `"digits"` gives `97`, `"words"` gives `Ninety-seven` (capitalised when it opens a sentence), and `"value"` returns the bare number for arithmetic. Deliberate vagueness stays as literal prose: `about twenty` is not a fact lookup, and pretending otherwise would encode a false precision the guide has chosen not to claim.

`fact()` must **fail loudly on an unknown key**, with `cli_abort()`, naming the near matches. A silent `NA` in published prose is precisely the failure this design exists to prevent, and a typo in a key is the likeliest way to introduce one.

## The catch, and why it is acceptable

Inline R makes a page executable, so it needs a freeze cache and a credentialed render. On a page that already executes this costs nothing. On a page that does not, it converts a page needing no compute into one needing a render.

Two mitigations, and the choice between them is worth making deliberately rather than by default:

1. **Accept it** where the page is already executable, which covers most of the affected pages.
2. **Pre-render to a partial** for pages that must stay compute-free, writing the resolved prose into a `_facts/` include. This adds a build step, and should only be reached for if option 1 proves genuinely blocking.

Note that `fact()` itself reads a local YAML file and touches no network, so a page using it needs R at render time but **not** credentials. That is a meaningfully weaker requirement than the pages that query Databricks, and it means CI still cannot run it (CI has no R) but a contributor without workspace access can.

## Fact-checking loop

```bash
scripts/check-facts.sh              # report only: what is stale, what is unused
scripts/check-facts.sh --measure    # re-measure what can be measured, show a diff
```

The report is the important half, and it should answer three questions:

- **Stale**: `volatile: true` entries whose `measured` date is older than a threshold, say 90 days.
- **Orphaned**: keys no page references, which are usually a fact that was removed from prose without being removed here.
- **Undeclared**: a page listed in `used_by` that no longer calls `fact()` for that key, which is the same drift in the other direction.

`--measure` should print a diff and change nothing on its own. Updating a value is a deliberate act, because it means re-dating the entry and re-rendering every page in `used_by`, and that is a decision with a cost attached rather than a formality.

The `used_by` list is what makes the loop tractable: change a number, and the list tells you exactly which pages need re-rendering. Keeping it accurate is the price of the design, which is why the report checks it in both directions rather than trusting it.

## Migration order

Do not convert everything. Start where the pain is measurable:

1. `spatial_functions_warehouse` and `spatial_functions_cluster`, four occurrences across two pages, both `volatile: true`, and the most perishable facts on the site.
2. `readings_rows`, six occurrences, stable but the most duplicated.
3. Stop and review. If the mechanism has not paid for itself on those two, it will not on the tail.

## What this does not fix

A fact table records what was measured; it cannot know whether the measurement is still true. `scripts/check-facts.sh` can report that a number is 90 days old and `volatile`, and no more than that. Someone still has to run the measurement. This design shortens the distance between deciding to re-check and having the site reflect it; it does not remove the need to decide.
