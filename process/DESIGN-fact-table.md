# Design: one table of measured facts, inserted into prose rather than typed

## The problem this solves

A number that was measured once and typed into prose has no owner and no expiry. Nothing recomputes it, nothing links it to the measurement that produced it, and nothing knows which pages would be wrong if it changed.

The scale is worth stating before designing anything, and it is larger than it looks. Counted on 2026-08-26:

| Fact | Occurrences | Pages |
|----|----|----|
| `97`, built-in `ST_` functions on a warehouse | 6 | `ref/spatial-functions.qmd`, `howdoi/polygons.qmd` |
| `93`, the same count on a cluster | 4 | the same two |
| `32,540,721` / `32.5 million` readings rows | 9 | 6 pages |
| `4,080` catchment polygons | 5 | 5 pages |
| `9,536` stations, `14,190` overflows | 3 each | 3 pages each |
| the other five row counts in `ref/data.qmd` | 1 each | `ref/data.qmd` only |

Each occurrence is an independent chance to drift, and a fact check that updates one and misses another leaves the site contradicting itself, which is worse than being uniformly stale.

Two of those rows deserve attention because they break the obvious plan. The readings count appears in **two spellings**, exact (`32,540,721`) and rounded (`32.5 million`), on pages that sit next to each other, so a mechanism that can only emit one of them cannot replace the prose. And `ref/data.qmd` carries a nine-row table of counts that exists for no other purpose than to state them, which is the single densest concentration of this problem on the site.

Four registers make a plain find-and-replace unsafe, all four taken from prose currently on the site:

- digits: `93 on an all-purpose cluster`
- words: `Ninety-seven distinct functions`
- rounded: `32.5 million rows`, where the exact value is `32,540,721`
- deliberate vagueness: ``about twenty other `sf` staples``, `roughly seven minutes`

The rounded register is the one the first draft of this design missed, and it is not a nicety. `32.5 million` and `32,540,721` are the same fact in two spellings, chosen per sentence: the reference table wants the exact figure and a sentence about what will not fit in memory wants the round one. A mechanism that emits only one of them would force a rewrite of prose that is currently correct, so `round` is a format rather than a separate key.

Deliberate vagueness is not sloppiness to be tidied away either. `about twenty` is honest where the exact count is unstable, and the mechanism must preserve the ability to say it. It stays literal prose and is never a fact lookup.

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
  round: 32.5 million     # the rounded spelling the prose also uses
  used_by:
    - ref/data.qmd
    - howdoi/big-table.qmd
    - example/index.qmd
    - example/ingest.qmd
    - example/reducing.qmd
```

`volatile` is the field that earns its place. It separates "this will change and we should expect to re-measure" from "this is stable and a stale reading is nearly harmless", which is what makes a staleness report actionable rather than noise.

## Insertion: an inline R call, not a templating language

Quarto already has inline R. Adding a second templating syntax would mean a second thing to learn and a second thing to break.

```r
# R/facts.R
wq_fact <- function(key, format = c("digits", "words", "round", "value")) { ... }
```

Named `wq_fact()` to match the `wq_*` helpers already in `R/setup.R`, and defined in its own file because it is the one helper a page might want without the connection plumbing.

Usage in prose:

```markdown
There were `r wq_fact("spatial_functions_warehouse")` on a Pro warehouse and
`r wq_fact("spatial_functions_cluster")` on an all-purpose cluster.

`r wq_fact("spatial_functions_warehouse", "words")` is a lot, and it is still
not all of `sf`.
```

The `format` argument is what handles the registers. `"digits"` gives `97` (comma-grouped, so `32,540,721`), `"words"` gives `Ninety-seven` capitalised for the start of a sentence, `"round"` gives the `round:` field verbatim (`32.5 million`), and `"value"` returns the bare number for arithmetic.

`"round"` reads from the YAML rather than computing the rounding, because where to round is an editorial choice, not an arithmetic one: `32.5 million` is a judgement about what the sentence needs, and a formatter guessing significant figures would eventually produce something nobody chose. A key with no `round:` field errors when asked for one, rather than silently falling back to digits.

Deliberate vagueness stays as literal prose: `about twenty` is not a fact lookup, and pretending otherwise would encode a false precision the guide has chosen not to claim.

An entry may still record those spellings in an `approx:` list, which `scripts/check-facts.R` reports without failing on. Five exist on the site, including "Thirty-two million rows go in and about a thousand come back" and "Four thousand catchment polygons". They are sentences about scale rather than citations, so the mechanism must not rewrite them; but re-measuring a value means someone has to read them and decide whether they still hold, and listing them is the only thing that would say so.

`wq_fact()` must **fail loudly on an unknown key**, with `cli_abort()`, naming the near matches. A silent `NA` in published prose is precisely the failure this design exists to prevent, and a typo in a key is the likeliest way to introduce one.

## The catch, and how it is resolved

Inline R makes a page executable, so it needs a freeze cache. On a page that already executes this costs nothing. On a page that does not, it converts a page needing no render into one needing one.

The first draft of this design assumed that mattered little, because "most of the affected pages already execute". That is false, and it is false in the worst possible place:

| Page | Executes today? | Facts it carries |
|----|----|----|
| `howdoi/polygons.qmd` | yes | `97`, `93`, `4,080` |
| `howdoi/big-table.qmd` | yes | readings count, `9,536` |
| `example/ingest.qmd`, `reducing.qmd`, `connecting.qmd` | yes | readings count, `4,080` |
| **`ref/spatial-functions.qmd`** | **no** | `97`, `93`, the definition of the count |
| **`ref/data.qmd`** | **no** | **all nine row counts** |
| `example/index.qmd` | no | `9,536`, `32,443`, `14,190`, `4,080` |

The three static pages hold the densest and most perishable facts on the site, so the mitigation that was written as a fallback is in fact the main case. Converting them is the point of the exercise rather than an unfortunate side effect.

**The resolution: `wq_fact()` needs R but not credentials.** It reads a local YAML file and touches no network. So making `ref/data.qmd` executable does not make it a page that queries Databricks; it makes it a page that reads a file. That is a much weaker requirement, and it is the reason the cost is acceptable:

- A contributor without workspace access can still render it.
- The freeze cache it gains is cheap to rebuild and cannot go stale against the workspace, only against the YAML.
- CI still cannot render it, because CI has no R, which is already true of every other executable page and is what `_freeze/` exists to handle.

The one genuine cost is that three pages gain a freeze cache and therefore join the set that `scripts/check-freeze.sh` governs. Edit one and you must re-render it. That is the same discipline the rest of the site already lives under, and `process/PROBLEM-freeze-cache-staleness.md` covers the trap in it.

## Fact-checking loop

```bash
scripts/check-facts.sh              # report only: what is stale, what is unused
scripts/check-facts.sh --measure    # re-measure what can be measured, show a diff
```

The report is the important half, and it should answer three questions:

- **Stale**: `volatile: true` entries whose `measured` date is older than a threshold, say 90 days.
- **Orphaned**: keys no page references, which are usually a fact that was removed from prose without being removed here.
- **Undeclared**: a page listed in `used_by` that no longer calls `wq_fact()` for that key, which is the same drift in the other direction.
- **Literal**: a migrated number still typed into prose. This is the one that earns its keep day to day, and it justified itself on the first run by finding a `4,080` on `howdoi/polygons.qmd` that a manual sweep had missed.
- **Approximate**: the `approx:` spellings above, reported and never failed.

`--measure` should print a diff and change nothing on its own. Updating a value is a deliberate act, because it means re-dating the entry and re-rendering every page in `used_by`, and that is a decision with a cost attached rather than a formality.

The `used_by` list is what makes the loop tractable: change a number, and the list tells you exactly which pages need re-rendering. Keeping it accurate is the price of the design, which is why the report checks it in both directions rather than trusting it.

## Migration order

Do not convert everything at once, but do convert whole facts rather than whole pages. A fact half-converted is worse than one not converted, because the site then states it two ways with only one of them owned.

1. **The spatial function counts**, `97` and `93`, ten occurrences across two pages. The most perishable facts on the site, both `volatile: true`, and the vendor has already moved the published figure once. This step converts `ref/spatial-functions.qmd` from static to executing, which is the design's hardest case, so doing it first is deliberate: if the cost is unacceptable it is better to learn that here than after three more pages.
2. **The nine row counts in `ref/data.qmd`**, plus their duplicates elsewhere. Nineteen occurrences in total and the densest concentration on the site. Lower risk than step 1 because the values are stable, and the biggest single reduction in duplication.
3. **Stop and review.** If the mechanism has not paid for itself across those two, it will not on the tail.

The readings count spans both steps, appearing in `ref/data.qmd` and on five other pages, so it is converted with step 2 rather than split.

## What this does not fix

A fact table records what was measured; it cannot know whether the measurement is still true. `scripts/check-facts.sh` can report that a number is 90 days old and `volatile`, and no more than that. Someone still has to run the measurement. This design shortens the distance between deciding to re-check and having the site reflect it; it does not remove the need to decide.
