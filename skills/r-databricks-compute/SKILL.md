---
name: r-databricks-compute
description: Starting, stopping and inspecting Databricks clusters and SQL warehouses from R with brickster, without surprise billing. Covers the check-before-start rule, access modes and which ones permit R, cluster library installation, getting binary rather than source packages onto a cluster, and why a colleague's dedicated cluster returns HTTP 403. Load before any operation that could start compute.
---

# Compute lifecycle: clusters and warehouses

*Load this before any call that could start a cluster or warehouse. For argument-level detail on the functions named here, see `r-databricks-brickster`; for choosing a connection path in the first place, see `r-databricks-connections`.*

## The rule, first and unmissable

**Check state before starting. Ask before a cold start.** A cold start is several minutes, and the cluster bills for the whole time it is running, not just the time it is doing useful work, until it auto-terminates. When you report a start, report the auto-termination window alongside it, so whoever reads the report knows how long the bill keeps running.

Check state like this, before anything else:

```r
info <- brickster::db_cluster_get(cluster_id = Sys.getenv("DATABRICKS_CLUSTER_ID"))
info$state                      # RUNNING, TERMINATED, PENDING...
info$autotermination_minutes    # report this when you report a start
```

Only once you have looked at `info$state` and decided a start is genuinely needed, and only after asking, move on to actually starting something.

## Prefer the idempotent helper

Once the decision to start has been taken, do not hand-roll `db_cluster_get()` followed by `db_cluster_start()`: that sequence can start something already running, or race a `PENDING` state. Use the helper instead:

```r
cluster <- brickster::get_and_start_cluster(cluster_id = Sys.getenv("DATABRICKS_CLUSTER_ID"))
```

`get_and_start_cluster()` returns the cluster if it is already running and starts it only if needed, so it is safe to call at the top of a script every time. The warehouse equivalent is `get_and_start_warehouse()`. Both are described in `r-databricks-brickster`; this skill only covers when and whether to call them.

## Warehouses before clusters, where there is a choice

A warm serverless SQL warehouse answers in **0.70 s**. An all-purpose cluster takes minutes to go from `TERMINATED` to `RUNNING`: **438 s** single-node and **418 s** with two workers, both with an init script attached. `[verified: ran it on 2026-08-22]` Recorded measurements, not benchmarks: they describe one setup on one day, not a guarantee for every workspace. Where the task can be done with a warehouse, prefer it; reach for a cluster only when the task needs something a warehouse cannot do, such as a live cluster context or distributed R.

## Access modes and R

State the current API values, since a colleague's older documentation, or the API's own legacy field, may still show the old name:

| Mode | API value | Legacy alias | R |
|----|----|----|----|
| Dedicated | `DATA_SECURITY_MODE_DEDICATED` | `SINGLE_USER` | Works |
| Standard | `DATA_SECURITY_MODE_STANDARD` | `USER_ISOLATION` | **Notebooks refused; client connection works** |
| Auto | `DATA_SECURITY_MODE_AUTO` | — | Resolves to Standard unless ML runtime, GPU, or DBR below 14.3 |

Standard access mode refuses R **notebooks** outright, `[documented: read it on 2026-08-18]`. Do not generalise that to "Standard refuses R": a client connection to a Standard cluster is a different path and works. `[verified: ran it on 2026-08-19]` `spark_connect()` reached a Standard cluster (DBR 14.3) and `spark_apply()` shipped a UDF to a Databricks Python worker there; it then failed on an `rpy2`/R-version fault, **not** on an access-mode refusal. That result is "access mode not implicated", nothing stronger: the run never got far enough to test whether `spark_apply()` fully works on Standard, which remains `[unresolved]` (see `r-databricks-parallel`).

- **Dedicated means one cluster per person.** Workspace admin does not override the single-user check: the check tests `single_user_name` on the cluster, not workspace permissions on the caller. Borrowing a colleague's Dedicated cluster returns `HTTP 403 PERMISSION_DENIED`, not a slower path. N R users therefore needs N clusters, which is a cost and administration story as much as a tooling one. `[verified: ran it on 2026-08-05]`
- **Dedicated group access mode (DBR 15.4+) is documented to support R**, and is the likely route if cluster-side R is needed for a team rather than an individual. It is **Public Preview, not GA**. It is not a separate access mode: it is Dedicated with a group, rather than a single user, in the "single user or group" field, and it also requires Unity Catalog plus `CAN MANAGE` on a workspace folder for that group. The R support claim is a single documented sentence with no language table and no worked example, so treat it as a lead to verify, not a settled fact. `[documented: read it, re-confirmed 2026-08-18]`

## Cluster images lag behind your workstation

Do not assume a package installed locally is present on the cluster, and check the R version too: cluster images commonly run an older R than a current workstation.

```r
Sys.getenv("DATABRICKS_CLUSTER_ID") |> brickster::db_libs_cluster_status()
```

Install what is missing and block until it finishes, rather than polling by hand:

```r
brickster::db_libs_install(
  cluster_id = Sys.getenv("DATABRICKS_CLUSTER_ID"),
  libraries = list(brickster::lib_cran("some_package"))
)
brickster::wait_for_lib_installs(cluster_id = Sys.getenv("DATABRICKS_CLUSTER_ID"))
```

## Getting binary packages, not a fifteen-minute compile

A package with compiled code will build from source on the cluster unless the binary repository is addressed in the one way it recognises, and the fallback is **silent**: the same command against the same mirror either takes seconds or spends a quarter of an hour per node. Two conditions must both hold. `[verified: ran it on 2026-08-21]`

1.  **Use the distribution-specific repository URL**, `https://p3m.dev/cran/__linux__/<codename>/latest`. The generic `https://p3m.dev/cran/latest` is correct in a project using `renv`, which rewrites it per distribution; `install.packages` does no such rewriting, so the generic URL serves sources.
2.  **Set `HTTPUserAgent` so it keeps the leading `R/<version>` token.** The repository reads that token to decide whether a client may have binaries. An interactive R session sends `R/4.5.1 R (4.5.1 ...)`, but a **child `Rscript` process sends only `R (4.5.1 ...)`** on at least some runtime images. Anything scripted, an init script above all, is that child process.

```r
codename <- system(". /etc/os-release && echo $VERSION_CODENAME", intern = TRUE)
options(
  repos = c(P3M = sprintf("https://p3m.dev/cran/__linux__/%s/latest", codename)),
  HTTPUserAgent = sprintf(
    "R/%s R (%s)", getRversion(),
    paste(getRversion(), R.version$platform, R.version$arch, R.version$os)
  )
)
```

**Getting condition 1 right and condition 2 wrong is indistinguishable from getting both wrong**, which is what makes this expensive to diagnose. Measured on one runtime: with the correct URL but the default child-process user agent, an init script installing `sf` and `terra` logged `installing *source* package` and took **873 s then 843 s** across two boots; with the user agent set, **63 s**.

Check what arrived rather than trusting the wall clock. `packageDescription(p)$Built` naming the runtime's own R version means it compiled locally; a binary names the version and date it was built under.

Binaries are keyed to distribution **and** R minor version, so a runtime with no matching build legitimately falls back to source. That is worth confirming before assuming the user agent is at fault.

## Never hard-code a cluster or warehouse ID

Dedicated access mode is one cluster per person by construction, so a literal cluster ID in a document is wrong for everyone but its author, and a warehouse ID hard-codes an environment that will eventually change. Read both with `Sys.getenv()`, and degrade to a warning rather than a hard failure when the variable is empty, so shared documents still build for someone without that resource configured:

```r
cluster_id <- Sys.getenv("DATABRICKS_CLUSTER_ID")
running <- nzchar(cluster_id)
if (!running) warning("DATABRICKS_CLUSTER_ID is unset; skipping live chunks")
```

## Stopping

**Stopping is a decision for whoever owns the compute, not a tidy-up step.** Do not terminate as the closing move of a task, and do not terminate something because you started it: a cold start is several minutes of VM provisioning that nothing on the client side shortens, so stopping between two pieces of work schedules that wait rather than saving it. Autotermination already handles the forgotten case. Terminate when asked to, or when a session is genuinely over and the owner has said so.

`db_cluster_terminate()` stops a cluster without deleting its configuration. `db_cluster_delete()` and `db_cluster_perm_delete()` are a different action entirely, and the latter is irreversible, so do not reach for it when what you mean is `db_cluster_terminate()`. For a warehouse, the equivalent stop call is `db_sql_warehouse_stop()`.

```r
brickster::db_cluster_terminate(cluster_id = Sys.getenv("DATABRICKS_CLUSTER_ID"))

# db_sql_warehouse_stop() takes a bare warehouse id, not a connection path such as
# DATABRICKS_PATH. There is no established env var for it here: get the id from a
# listing call, or substitute your own, such as "<warehouse-id>".
warehouse_id <- brickster::db_sql_warehouse_list()$id[[1]]
brickster::db_sql_warehouse_stop(id = warehouse_id)
```

## The `|>` rule

Use the base pipe `|>` in every example, never the magrittr pipe.
