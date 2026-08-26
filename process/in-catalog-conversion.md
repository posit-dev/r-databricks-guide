# Done: three-part names are built with `in_catalog()`

*Completed 2026-08-26. Kept as a record because the conversion stalled once, and because two of the things it turned up are worth knowing before writing new code.*

## What changed

Every `tbl()` call that took a hand-built three-part name now uses `dbplyr::in_catalog()`:

```r
# before
tbl(con, I(glue("{catalog}.{schema}.{table}")))

# after
tbl(con, in_catalog(catalog, schema, table))
```

17 occurrences across eight pages, plus the `wq_tbl()` helper in `example/reducing.qmd`. `in_catalog()` quotes each part of the name separately, so a catalog, schema or table whose name needs escaping still works. The `I()` it replaces existed only to stop `dbplyr` re-quoting a name that already had dots in it, which is a workaround rather than an idiom.

It works identically on all three connection types, each tested rather than assumed: `odbc`, `brickster::DatabricksSQL()`, and a `sparklyr::spark_connect()` handle. The sparklyr case was the doubtful one and returned the same 9,536 stations as the form it replaced.

## Two things that came out of it

**`in_catalog()` needs `dbplyr` attached.** With only `dplyr` loaded, or only `sparklyr` and `dplyr`, the call is not found. Five pages gained a `library(dbplyr)` line. This is easy to miss because most of these pages were already using `dbplyr` machinery through `dplyr` verbs without ever attaching it.

**Several pages then had no use for `glue` at all**, because pasting a name together was the only thing it did there. `library(glue)` was removed from eight pages, and `ref/packages.qmd` lost a `tbl_name()` helper that existed only to span a line continuation. `cli` interpolates its own messages, so removing `glue` does not affect `cli_alert_info()`; that was checked with `glue` detached rather than reasoned about.

`renv.lock` is unchanged: `glue` remains a genuine dependency of the pages that still call it.

## Why it stalled the first time, which is the part worth remembering

The first attempt was reverted unfinished. The Workbench token expired partway through, surfacing as the opaque ODBC error `r-databricks-connections` documents (`[RStudio][ThriftExtension] (14) Unexpected response ... Unauthorized/Forbidden`), and nothing in R renews it.

Reverting was right rather than cautious. Every affected page is frozen, and committing an edit to a frozen page without re-rendering publishes the *previous* output with the edit missing, silently, at exit 0. Committing would have left the repository in a state that needed credentials to leave.

So for any change of this shape: confirm the session is live before starting, with `Rscript check-databricks-access.R`, and treat a half-finished conversion as something to revert rather than to commit.

## How it was verified

Output must be unchanged, since this alters only how a name is built. Every figure recorded before the change came back identical afterwards:

- `example/spatial.qmd`: 4,080 catchments, 14,190 overflows, 9,536 stations, cross-check 2,638 / 2,609 / 28 / 13,076 / 13,080
- `howdoi/polygons.qmd`: 4,080 catchments and 130,229 km², the six-class aggregation at 74,367 km², the join at 8,491
- `howdoi/big-table.qmd`: 32,540,721 rows, 1,103 measures, 1,029 rows at 138 KB

Compared with `scripts/page-md.sh <page>` against the freeze cache, not by reading the HTML.
