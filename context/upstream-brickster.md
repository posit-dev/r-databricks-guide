# What brickster's documentation says

An account of `databrickslabs.github.io/brickster`, read on 2026-08-23: six articles plus the reference index. Accurate, current, and thin on exactly the axis this guide cares about.

The short version: brickster documents its API surface well and says **nothing whatever about data types**. That is where this guide's hardest-won findings sit, so the duplication risk is near zero and the gap is the whole opportunity.

## The articles

| Page | What it covers | Verdict |
|----|----|----|
| [Connect to a Databricks Workspace](https://databrickslabs.github.io/brickster/articles/setup-auth.html) | OAuth U2M, OAuth M2M and PAT. `DATABRICKS_HOST`, `DATABRICKS_TOKEN`, `DATABRICKS_WSID`; suffixed variables and `.databrickscfg` profiles; `db_host()`, `db_token()`, `db_cluster_list()` as a smoke test | **Link from `howdoi/connect.qmd`.** It states that brickster detects Workbench-managed OAuth automatically, corroborating the ambient-credentials note in `CLAUDE.md`. Says nothing about diagnosing an expired credential |
| [`{DBI}`/`{dbplyr}` backend](https://databrickslabs.github.io/brickster/articles/sql-backend.html) | The DBI and dbplyr backends. See below | Central. Link, and cover only the type behaviour it omits |
| [Cluster Management](https://databrickslabs.github.io/brickster/articles/cluster-management.html) | Create, edit, resize, pin, start, restart, terminate; library install and status; `db_cluster_events()` | **Link with care.** Written entirely for someone who can create clusters. Never covers reading an existing cluster's configuration to design within it, never discusses access modes, never says what a user without create rights can do. That is `howdoi/compute.qmd`, with no upstream page to defer to |
| [Job Management](https://databrickslabs.github.io/brickster/articles/managing-jobs.html) | Jobs CRUD, `db_jobs_run_now()`, `db_jobs_runs_submit()` with idempotency tokens, task builders, `cron_schedule()` | Moderate, for `howdoi/results.qmd`. Only notebook tasks are demonstrated, and there is no R task type in the API, so running R non-interactively means an R notebook task. The page does not say so |
| [Databricks REPL](https://databrickslabs.github.io/brickster/articles/remote-repl.html) | `db_repl()`, language switching with `:py`, `:sql`, `:scala`, `:sh` | Moderate. Two load-bearing limits: compute must be a cluster, and **R support is restricted to single-user clusters**. Not compatible with serverless. Does not say how to find a cluster id, nor what failure looks like on an access mode that refuses R |
| [Working with Unity Catalog Volumes](https://databrickslabs.github.io/brickster/articles/working-with-volumes.html) | `db_uc_volumes_*` for the object, `db_volume_*` for files: `db_volume_write()`/`_read()`, `_list()`, `_dir_create()`, `db_volume_upload_dir()`/`_download_dir()` | **Link from `ref/sending-things.qmd`.** States no size limit, which is where our figure adds something, and does not connect volumes to the `staging_volume` argument of the DBI backend even though it is the same mechanism |

## The DBI backend in detail

The article argues for a native-R alternative to ODBC, JDBC and the Python connector, and documents both backends. It is built on the Statement Execution API, plus the Files API for large uploads.

`DatabricksSQL()` **takes no arguments**; all configuration is on the `dbConnect()` method:

```r
dbConnect(
  drv,
  warehouse_id = NULL,
  http_path = NULL,
  catalog = NULL,
  schema = NULL,
  staging_volume = NULL,
  disposition = c("EXTERNAL_LINKS", "INLINE"),
  max_active_connections = 30,
  fetch_timeout = 300,
  show_progress = TRUE,
  token = db_token(),
  host = db_host(),
  ...
)
```

Give either `warehouse_id` or `http_path`; from a path, the id is taken from the `/warehouses/<id>` segment. Authentication is implicit through `db_token()` and `db_host()`, so it inherits whatever brickster's normal resolution finds, Workbench OAuth included.

Facts worth carrying onto our pages:

- **Warehouse only.** There is no `cluster_id` argument. Meanwhile `db_repl()` is cluster-only and R-only-on-single-user. That is a clean division to state once on `howdoi/connect.qmd`: the DBI path needs a warehouse, the remote-execution path needs a cluster.
- **Writing is supported**, which is unusual for this class of backend. Two paths: inline `INSERT` for small data, or staged parquet to a volume then `COPY INTO`. Above 50,000 rows only the staged path is allowed, and it needs `staging_volume`. This is the upstream statement of the limit `ref/sending-things.qmd` records.
- **No temporary tables.** `temporary = TRUE` errors, so `copy_to()` needs `temporary = FALSE`.
- **No persistent session.** Every call is an API call, so `dbDisconnect()` frees nothing on the warehouse. Transactions are documented as not supported.
- **arrow is only Suggested**, with `nanoarrow` as fallback, and the article recommends having `arrow` installed for performance. The stack is stated to be WebR-compatible.
- The article says **nothing about data types**: not `BINARY`, not `DECIMAL`, `ARRAY`, `MAP`, `STRUCT`, `TIMESTAMP`, nor anything nested.

That last point is the gap this guide fills. It also means the `BINARY` finding here has no upstream counterpart to align with or contradict: nothing in brickster's documentation says whether its path returns `BINARY` intact. Ours says it does, byte-exact, and that is the entire reason this guide depends on brickster rather than ODBC for geometry.

## Where the backend falls short on geospatial

The documentation covers none of this, so what follows was read from source (`R/databricks-dbi.R`, `R/sql-query-execution.R`, `R/databricks-dbplyr.R`, at `main`, 2026-08-23) and checked against measurement where noted. Re-verify against the version in play before building on it.

### What the platform now offers

Databricks has native `GEOMETRY` and `GEOGRAPHY` types and 97 `ST_` functions counted on a current Pro warehouse, published as "80+", on Databricks SQL and **DBR 17.1 and above**. `GEOMETRY` carries an SRID, with about 11,000 supported; `GEOMETRY(ANY)` can mix SRIDs per row but cannot be persisted. Conversion exists in both directions: `st_geomfromwkb()`, `st_geomfromtext()`, `st_geomfromgeojson()`, `to_geometry()` in; `st_asbinary()`, `st_asewkb()`, `st_astext()`, `st_asewkt()`, `st_asgeojson()` out. The `ST_` functions are **not available on SQL Classic warehouses**, and `st_geomfromwkb()` is documented as Public Preview requiring 17.1+ even though `GEOMETRY` support itself is GA.

Two consequences. First, `st_asbinary()` returns WKB as `BINARY`, exactly the column type this guide has established that ODBC truncates and `DatabricksSQL()` returns intact, so the transport problem for geometry is already solved on the brickster path and only the R-side typing is missing. Second, this collides with the open DBR-18 question in `CLAUDE.md`: the `ST_` functions need 17.1+, so deciding which runtime the guide addresses has a second reason to be settled, not just the version pins in `admin/geospatial-setup.qmd`.

### Three gaps in the backend

**1. The write path silently mistypes geometry.** `dbDataType()` maps `blob` and `raw` columns to `BINARY` via an internal `db_is_binary_column()` helper, then switches on `class(x)[1]` with a fallback of `"STRING"` for anything unrecognised. An `sfc` column is unrecognised, so it reaches the fallback.

Reproduced against brickster 0.2.14 on a live warehouse connection: `dbDataType(con, sf::st_sfc(sf::st_point(c(1, 2)), crs = 4326))` returns `"STRING"`. So `dbWriteTable()` on an `sf` object writes geometry into a `STRING` column with no warning. That is the sharpest single finding here: a silent wrong-type write, on the overwhelmingly common way R users hold geometry.

A smaller bug sits in the same function: `dbDataType()` is not scalar over a `raw` vector, returning one `"BINARY"` per element rather than a single value, so anything building a DDL fragment from it produces malformed SQL.

**2. The read path has no geospatial case.** `db_sql_type_to_empty_vector()` maps SQL types to empty R vectors and handles `BYTE`/`SHORT`/`INT`/`LONG`, `FLOAT`/`DOUBLE`/`DECIMAL`, `BOOLEAN`, `DATE`, `TIMESTAMP`, `STRING`/`BINARY`/`CHAR`, then falls through to `character(0)` with a comment naming `ARRAY`, `STRUCT`, `MAP`, `INTERVAL`, `NULL` and `USER_DEFINED_TYPE`. `GEOMETRY` and `GEOGRAPHY` are absent, so both land in the character fallback.

Measured since: for a `GEOMETRY` column the result manifest carries `type_name = "GEOMETRY"` and `type_text = "GEOMETRY(4326)"`, and the values arrive as EWKT strings such as `"SRID=4326;POINT(1 2)"`, carrying the SRID inline. `GEOGRAPHY` behaves identically. So `character(0)` is arguably the correct empty vector as things stand, because the wire form really is text. The defect is narrower than it first looked: the two types are indistinguishable from an unhandled type, and the SRID available in the manifest is discarded.

**3. The two dispositions were suspected of typing results differently, and do not.** `db_sql_process_inline()` transposes the `JSON_ARRAY` payload straight into a tibble without consulting the schema, where `EXTERNAL_LINKS` goes through `arrow::read_ipc_stream()` (or `nanoarrow::read_nanoarrow()`) and gets Arrow's native typing. That reads like a second silent trap, since `disposition` is a connection-level default documented purely in terms of result size.

Measured since: **`INLINE` and `EXTERNAL_LINKS` return identical manifest schemas** for `GEOMETRY`. So the suspicion is not confirmed for this type. Treat it as open for `BINARY` specifically until someone runs the same comparison there.

### What could be built

The dbplyr side is more encouraging than expected. `sql_translation.DatabricksConnection()` delegates to an internal `spark_sql_translation()`, described in a source comment as a slightly modified version of sparklyr's own translation, built on `dbplyr::base_scalar`. Because the `ST_` functions are ordinary SQL scalar functions, `st_*` translations could be added there so that `sf`-shaped verbs in a `dplyr` chain push down.

Three separable pieces, smallest first:

1. Add `GEOMETRY`/`GEOGRAPHY` to `db_sql_type_to_empty_vector()`, and teach `dbDataType()` to map an `sfc` column to `BINARY` rather than falling through to `STRING`. A bug fix rather than a feature, and it needs no `sf` dependency if the write path errors instead of converting.
2. On read, wrap a `GEOMETRY` column with `st_asbinary()` and return `sf::st_as_sfc()` of the WKB, carrying the SRID into a CRS. Needs a decision about whether `sf` becomes a `Suggests` dependency, for which `arrow` being `Suggests`-only is the natural precedent.
3. Add `st_*` translations to the dbplyr backend so spatial predicates and transforms run server-side. This is the one that matters most to this reader, because it decides whether a spatial join runs on the cluster or drags every geometry into R first.

Note that sparklyr has no geospatial guide either, so the geospatial story is missing from both upstream sites. See [`upstream-sparklyr.md`](upstream-sparklyr.md).

## What this changes on this site

1. **Link the auth article from `howdoi/connect.qmd`**, and the volumes article from `ref/sending-things.qmd`. Both are accurate and save prose.
2. **State the compute split once**: the DBI path needs a warehouse, `db_repl()` needs a cluster and R only on single-user. "Can I use this package" is usually really "which kind of compute do I have", which is `howdoi/compute.qmd`'s question.
3. **Say that brickster returns `BINARY` intact**, because nothing upstream says it and it is the reason this guide uses it for geometry.
4. **Note that the cluster-management article assumes create rights**, if it is linked at all. This reader can start and stop what she has.
5. **The type-mapping gap is ours to fill.** No upstream page documents the mapping in either direction, so anything this guide says about types stands alone rather than duplicating.
