# Unfinished: convert the remaining `tbl(con, I(...))` to `in_catalog()`

*Started 2026-08-26, reverted unfinished because the Databricks token expired mid-task and the edited pages could not be re-rendered. Nothing is broken; the site is exactly as it was. This is the note so the work is not rediscovered from scratch.*

## What is inconsistent today

`CODE-STYLE.md` and `skills/r-databricks-unity-catalog` both say to build a three-part name with `dbplyr::in_catalog()` rather than `tbl(con, I(glue(...)))`. Two pages follow that (`howdoi/big-table.qmd`, `example/connecting.qmd`) and the rest do not, so the guidance currently contradicts most of the code.

This is a style inconsistency, not a defect. `I()` works: it marks a name as already-qualified so `dbplyr` does not re-quote it. `in_catalog()` is better because it quotes each part separately, so a catalog, schema or table whose name needs escaping still works, and because it is `dbplyr`'s own idiom rather than a workaround.

## What to change

15 occurrences across six pages, all of the form `tbl(<con>, I(tbl_name("<table>")))` or `tbl(con, I(glue("{catalog}.{schema}.<table>")))`:

| Page | Occurrences |
|----|----|
| `example/spatial.qmd` | 5 |
| `howdoi/polygons.qmd` | 5 |
| `howdoi/connect.qmd` | 2 |
| `example/reducing.qmd` | 1, inside the `wq_tbl()` helper |
| `example/ingest.qmd` | 1 |
| `howdoi/check-the-answer.qmd` | 1 |

Each becomes `tbl(<con>, in_catalog(catalog, schema, "<table>"))`. It works on both the `odbc` and the `brickster` connection, so `tbl(acon, ...)` converts the same way.

**`in_catalog()` needs `dbplyr` attached**, verified rather than assumed: with only `dplyr` loaded the call fails. Three of the six pages do not currently attach it and need `library(dbplyr)` adding next to `library(dplyr)`: `example/spatial.qmd`, `example/ingest.qmd`, `howdoi/check-the-answer.qmd`.

## Deliberately out of scope

Two further occurrences sit on **sparklyr** connections, and are left alone until someone tests them:

- `howdoi/interactive.qmd:51`
- `ref/packages.qmd:51`

`in_catalog()` has not been tried against a `spark_connect()` handle, and testing it needs the multi-node cluster rather than the warehouse. Do not convert these on the assumption that a `tbl()` is a `tbl()`; check first, on a cluster, and if it does not work say so here rather than leaving the question open.

## Cost, and the reason this stalled

All six pages are frozen, so this is six credentialed re-renders. None needs the cluster: every one runs against the warehouse, so `scripts/rerender.sh --stale` covers the lot once the caches are invalidated.

The first attempt died because the Workbench token expired partway through, surfacing as the opaque ODBC error `r-databricks-connections` documents (`[RStudio][ThriftExtension] (14) Unexpected response ... Unauthorized/Forbidden`). Nothing in R renews it. The edits were reverted rather than committed, because committing an edit to a frozen page without re-rendering publishes the previous output with the edit missing, silently, at exit 0.

**So do this only with a live session**, and check first:

```bash
Rscript check-databricks-access.R
```

## Verifying it worked

The output of every affected page must be unchanged, since this alters only how the name is built. Worth checking two specifically, because they are the ones where a quoting change would show:

- `example/spatial.qmd`: 4,080 catchments, 14,190 overflows, 9,536 stations, and the cross-check at 2,638 / 2,609 / 28 / 13,076 / 13,080.
- `howdoi/polygons.qmd`: 4,080 catchments and 130,229 km², the six-class aggregation at 74,367 km², and the join at 8,491 overflows.

Compare with `scripts/page-md.sh <page>` rather than reading the HTML.
