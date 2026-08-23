---
name: r-databricks-brickster
description: The brickster R package as a reference: authentication, the db_* function families, the builder DSL for clusters and jobs, the DatabricksSQL DBI backend for BINARY columns, and remote R execution via contexts. Load when you need brickster API detail; load r-databricks-connections first if you are choosing a connection path.
---

# The brickster package

*Reference detail for `brickster`. If you have not yet chosen a connection path, load `r-databricks-connections` first: it names the five paths and routes to this skill for the one built on `brickster`.*

## What it is

`brickster` is an R client for the Databricks REST API, plus a DBI backend. It is the substitute for the `databricks` command-line tool when that CLI is absent: everything the CLI would do from a terminal, `brickster` does from an R session instead. As of version 0.2.14 it exports 304 functions. `[verified: ran it on 2026-08-19]`

## The function families

Most exports follow a `db_<family>_<verb>` naming convention. The eleven `db_*` families, by export count:

| Family | Count | Covers |
|----|----|----|
| `db_cluster_*` | 16 | create, start, terminate, resize, restart, events, list, pin |
| `db_jobs_*` | 15 | create, run_now, runs_submit, runs_get_output |
| `db_sql_*` | 14 | exec_query, warehouse start/stop/list, query_history |
| `db_uc_*` | 14 | catalogs, schemas, tables, volumes |
| `db_vs_*` | 14 | vector search |
| `db_mlflow_*` | 10 | MLflow model registry |
| `db_secrets_*` | 10 | secret scopes |
| `db_volume_*` | 10 | volume file operations |
| `db_context_*` | 8 | remote R execution on a cluster |
| `db_workspace_*` | 6 | notebooks and folders |
| `db_libs_*` | 4 | install, uninstall, cluster status |

Counts `[verified: ran it on 2026-08-19]` against the installed 0.2.14. If your installed version reports different counts, that version has moved on from this reference; trust what you observe over this table.

## Prefer the convenience helpers

Do not hand-roll the "is it running, if not start it, then wait" sequence: `brickster` already has it, and it is the billing-aware pattern:

- `get_and_start_cluster()` returns the cluster if it is already running and starts it otherwise. Idempotent: safe to call at the top of a script every time.
- `get_and_start_warehouse()` is the same idea for a SQL warehouse.
- `wait_for_lib_installs()` blocks until library installation on a cluster completes, rather than polling `db_libs_*` status calls by hand.
- `open_workspace()` / `close_workspace()` manage the underlying connection to a workspace, so calls elsewhere do not each need their own host and token.

Reusing these means the busy-wait and idempotency logic lives in one tested place instead of being reinvented per script.

## The builder DSL

Cluster and job specifications are R objects built with constructor functions, not hand-written JSON strings. The constructors compose:

```r
spec <- new_cluster(
  spark_version = "15.4.x-scala2.12",
  node_type_id = "m5.xlarge",
  autoscale = cluster_autoscale(min_workers = 1, max_workers = 4),
  aws_attributes = aws_attributes()
)
```

The catalogue of builders:

- `new_cluster()`, `cluster_autoscale()`: cluster shape.
- `job_task()`, `job_tasks()`, `notebook_task()`, `spark_python_task()`, `for_each_task()`, `condition_task()`: job task graphs.
- `cron_schedule()`, `email_notifications()`: job scheduling and alerting.
- `libraries()`, `lib_cran()`, `lib_pypi()`, `lib_maven()`, `lib_whl()`: library specifications, passed to `db_libs_*` or attached to a cluster spec.
- `aws_attributes()`, `azure_attributes()`, `gcp_attributes()`: cloud-specific cluster attributes, matched to the workspace's cloud.

Each builder has a matching `is.*()` predicate (for example `is.cluster_autoscale()`) so a spec can be validated before it is sent, rather than discovering a malformed field only after the API call fails.

## `DatabricksSQL()`: the DBI backend

`brickster::DatabricksSQL()` is a full DBI backend, usable anywhere `DBI::dbConnect()` and the usual `dbGetQuery()` / `dbReadTable()` / `dbplyr` machinery are used with any other DBI driver:

```r
con <- DBI::dbConnect(
  brickster::DatabricksSQL(),
  server_hostname = Sys.getenv("DATABRICKS_HOST"),
  http_path = Sys.getenv("DATABRICKS_PATH")
)
```

Choose it over `odbc::databricks()` whenever a `BINARY` column is in play: `DatabricksSQL()` decodes Arrow directly and returns bytes exactly, where the ODBC path silently drops most of them. See `r-databricks-connections` for the measured byte table; it is not repeated here.

## Native `GEOMETRY` and `GEOGRAPHY`: what actually arrives

`[verified: ran it on 2026-08-23]` against a **Pro** SQL warehouse (serverless, `DBSQL 2026.20`).

**A native geometry value arrives as an EWKT string with the SRID prefixed onto the value**, and the R column class is `character`:

```
SELECT st_geomfromtext('POINT(1 2)', 4326)   ->  "SRID=4326;POINT(1 2)"
```

This is a **different path** from geometry stored as WKB in a `BINARY` column, which is what the `DatabricksSQL()`-over-`odbc` argument above is about. Native geometry is text and needs no byte-exactness; binary-stored geometry still does.

- **The SRID does not need a separate `st_srid()` call.** It is on the value, and it is *also* in the result manifest as `type_text = "GEOMETRY(4326)"`, alongside `type_name = "GEOMETRY"`.
- **`INLINE` and `EXTERNAL_LINKS` return identical manifest schemas** for this type.
- **The text form is not lossy**, round-tripping `POINT(1.2345678901234567 2.9876543210987654)` character-for-character.
- **`GEOGRAPHY` behaves identically**, reporting `type_name = "GEOGRAPHY"`. Its constructor takes **one** argument: `st_geogfromtext('POINT(1 2)')`. Passing an SRID raises `WRONG_NUM_ARGS`.

**Converting to `sf` is two steps**, because `sf::st_as_sfc()` does not accept the `SRID=` prefix:

```r
srid <- as.integer(sub("^SRID=([0-9]+);.*$", "\\1", x))
sfc  <- sf::st_as_sfc(sub("^SRID=[0-9]+;", "", x), crs = srid)
```

**`brickster` 0.2.14 does not recognise either type.** `db_sql_type_to_empty_vector()` has no `GEOMETRY` or `GEOGRAPHY` case, so both fall through to the character default alongside `ARRAY`, `STRUCT` and `MAP`. The returned column is usable, since the wire form really is text, but it is indistinguishable from an unhandled type and the SRID in the manifest is discarded.

**Check the warehouse type before blaming the query.** Spatial functions are documented as unavailable on **SQL Classic** warehouses, and the failure is an unknown-function error that reads like a typo. `db_sql_warehouse_get(id = ...)$warehouse_type` answers it in one call. A current Pro warehouse reports **97** `ST_` functions from `SHOW FUNCTIONS LIKE 'st_*'`, against vendor documentation's "80+".

**`dbDataType()` mistypes an `sf` geometry column.** `[verified: ran it on 2026-08-23]` It returns `"STRING"` for an `sfc` column, so `dbWriteTable()` on an `sf` object writes geometry into a string column without warning. `raw` and `blob` correctly give `BINARY`. Separately, `dbDataType()` is not scalar over a `raw` vector: `as.raw(1:3)` returns three values where DBI expects one.

## Runnable script

`scripts/geometry-to-sf.R` demonstrates the whole path: warehouse-type check, function count, what arrives, the two-step `sf` conversion, and the precision round trip. Run on a Pro serverless warehouse on 2026-08-23. It needs `DATABRICKS_WAREHOUSE_ID`.

## Two recorded gotchas

- **Call `db_context_command_run_and_wait(..., parse_result = FALSE)`.** The default parsing path pulls in `huxtable` and `magick` to format the result, a heavy and usually unwanted dependency chain for what is otherwise a lightweight remote-execution call.
- **`db_repl()` opens with an `interactive()` guard, by design.** It will not run inside a non-interactive document or script, and that is not a defect to work around: it is an interactive REPL, not a batch-execution entry point. Use `db_context_command_run_and_wait()` for non-interactive remote execution instead.

## The `|>` rule

Use the base pipe `|>` in every example, never the magrittr pipe.
