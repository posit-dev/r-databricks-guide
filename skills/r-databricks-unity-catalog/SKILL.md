---
name: r-databricks-unity-catalog
description: Finding and querying Unity Catalog data from R. Covers browsing catalogs, schemas and tables with brickster, querying with dbplyr, deciding where the collect() line goes, and using dplyr::sql() for expressions dbplyr cannot translate or tbl(con, sql()) to start from a whole hand-written query. Load when locating a table or writing a query; load r-databricks-connections first to choose a connection path.
---

# Finding and querying Unity Catalog data from R

*Load `r-databricks-connections` first if you have not yet chosen a connection path. This skill assumes a DBI connection is already open, and cites `r-databricks-brickster` for the exact signature of any `db_*` call it names rather than restating it.*

## Browse, then query

These are two different operations, with two different costs. Browsing asks Unity Catalog for metadata: `db_uc_catalogs_list()`, `db_uc_schemas_list()`, `db_uc_tables_list()`, `db_uc_tables_summaries()` and `db_uc_tables_exists()`. None of these move a single row of data, so calling them freely to locate a table costs nothing worth worrying about.

Querying is different: it is `dbplyr` over a DBI connection, and it moves data. Find the table first with the browsing calls, confirm it is the one you want, then query it. See `r-databricks-brickster` for the full `db_uc_*` family and its argument list.

## The `collect()` line, as the governing idea

Every `dbplyr` pipeline has one line that decides where the work happens: above it, the work runs on Databricks; below it, the work runs in R. The only real question for any pipeline is how big the data is when it crosses that line.

```r
library(dplyr)

result <- tbl(con, I("catalog.schema.measurements")) |>
  filter(sample_year >= 2020) |>
  group_by(site_id) |>
  summarise(n = n(), mean_value = mean(value, na.rm = TRUE)) |>
  collect()          # <- the line. Everything above ran on Databricks.
```

Vendor documentation calls this "pushdown" (the term you will see if you go looking), but the useful mental model is the line itself, not the label, so this skill uses "the `collect()` line" as the primary vocabulary from here on.

## Measure what crosses, before you pull it

Two habits catch a pipeline that would otherwise land an unexpectedly large result in R's memory. Use `dplyr::show_query()` to see what SQL is actually being sent, and check a row count before collecting rather than finding out after:

```r
pipeline <- tbl(con, I("catalog.schema.measurements")) |> filter(sample_year >= 2020)
pipeline |> show_query()
pipeline |> summarise(n = n()) |> collect()   # how big is it before you pull it
```

If the count is small, `collect()` the real pipeline with confidence. If it is not, narrow the filter, aggregate further on the server side, or reconsider whether the whole result belongs in R at all.

## The escape hatch: `dplyr::sql()`

`dbplyr` cannot translate every expression to Spark SQL, and its coverage is not the real ceiling. `dplyr::sql()` embeds arbitrary Spark SQL inside an otherwise ordinary `dbplyr` pipeline, including functions `dbplyr` has no translation for and Databricks' native spatial functions. So the actual ceiling is "what Spark SQL can express", a vastly larger set than "what `dbplyr` happens to translate". `[verified: ran it on 2026-08-04]`

```r
tbl(con, I("catalog.schema.sites")) |>
  mutate(code = sql("regexp_extract(site_name, '([A-Z]{2}[0-9]+)', 1)")) |>
  collect()
```

The same escape hatch has a second, larger form: pass a `sql()` object to `tbl()` in place of a table name and a whole hand-written query becomes a lazy table. Use it when the query already exists (a colleague's, or one tuned in the Databricks SQL editor) rather than translating it into verbs. `[verified: ran it on 2026-08-24]`

```r
q <- tbl(con, sql("SELECT id, site_name FROM catalog.schema.sites WHERE region = 'NW'"))
q |> count(site_name) |> collect()
```

`dbplyr` does not reparse the query: it wraps it as a subquery and writes around it, so verbs piped on afterwards still push down. Confirm with `show_query()`. Works on both the `odbc` and `brickster` connection paths. `[verified: ran it on 2026-08-24]`

The wrapper is load-bearing. A bare character string is read as a table *name*, and fails with `TABLE_OR_VIEW_NOT_FOUND` quoting the whole SELECT back as an identifier, which reads as a server fault rather than a missing `sql()`. `[verified: ran it on 2026-08-24]`

## A known backend gap, attributed correctly

`dbplyr` refuses most `stringr` regex verbs on the Spark backend: `str_detect(x, 'a')` fails with "Only fixed patterns are supported on this backend", even though the same warehouse runs `regexp_extract()`, `regexp_replace()` and `rlike` without complaint. That is a `dbplyr` backend-translation gap, not a Databricks limitation, and `sql()` is the workaround. `[verified: ran it on 2026-08-04]`

## After `collect()`, `duckdb` raises the tabular ceiling

Once data is local, a disk-backed `duckdb` file raises what R can handle next: pulling through the warehouse in chunks and landing in `duckdb` aggregates 5M rows × 10 columns in 0.16 s under a 512 MB memory limit, spilling a full-table sort to disk rather than failing. `[verified: ran it on 2026-08-05]` The benefit comes from `duckdb` running *after* `collect()`, not from Arrow transport, and it does not help when what overflows is a spatial object in R's own heap, because `duckdb` has no geometry type to hold it.

## Scope note

Governance, `GRANT`/`REVOKE`, the privilege model, row filters, column masks and external locations are out of scope here. Where a `databricks` command-line tool is available, the official `databricks-unity-catalog` skill covers that ground; treat this paragraph as a pointer to that material, not as an instruction to install or run anything.

## The `|>` rule

Use the base pipe `|>` in every example, never the magrittr pipe.
