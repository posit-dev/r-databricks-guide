---
name: r-databricks-parallel
description: Choosing a parallel method for R work on Databricks, then running distributed R with sparklyr::spark_apply(). Covers the six candidate methods and when each fits, spark_apply mechanics and its hard prerequisites, and the limits of Databricks Connect. Load when a workload is too slow for one core or when considering spark_apply.
---

# Choosing a parallel method, then running distributed R

*Load this when a workload is too slow for one core, or before reaching for
`spark_apply()` specifically. Method selection comes first: `spark_apply()` is one row
in the table below, not the default answer.*

## Choose the method before reaching for Spark

Simulation is usually embarrassingly parallel: independent draws, independent
replicates, no shared state between iterations. When that is true, the variable that
matters is setup cost and ergonomics, not raw throughput, because the work would finish
quickly on almost anything with enough cores. **Try `future`/`furrr` on one machine
first, and escalate only on evidence** that one machine is genuinely not enough.

| Method | Where it runs | Fits when |
|---|---|---|
| `future` / `furrr` | Workbench VM, many cores | The default to try first. Simplest thing that works; no cluster, no serialisation surprises |
| `mirai` / `parallel` | one machine | The baseline to beat. Lowest ceremony |
| `future` on the cluster driver via `brickster` | one cluster node, many cores | A bigger machine is enough, and you want no Spark UDF machinery |
| Databricks Jobs, parameterised fan-out | many nodes, no Spark UDF | Embarrassingly-parallel simulation, especially long runs that should survive a session ending |
| `sparklyr::spark_apply()` | Spark executors, across machines `[verified: ran it on 2026-08-21]` | The only mechanism that distributes R itself. Reach for it when the data is already a Spark DataFrame and one machine genuinely is not enough |
| Push the computation into SQL | Databricks, no R | Only if it is expressible that way, which for simulation it usually is not |

The "`future` on the cluster driver via `brickster`" row means running R on a single,
bigger cluster node reached through `brickster`'s remote-execution path (see
`r-databricks-brickster` for the `db_context_*` calls that do this), and then using
`future`/`furrr` on that one node's cores. It buys a bigger machine without any Spark
serialisation machinery, but it is still one node: it does not distribute across a
cluster the way `spark_apply()` does.

Work down that table in order. Each row costs more to set up and debug than the one
above it, so a row only earns its keep when the row above it has been tried and shown
to be insufficient, not merely assumed to be.

## What `spark_apply()` actually does

It applies an R function to each partition of a Spark DataFrame on the executors, and
reassembles the results into one Spark DataFrame. The function receives a data frame
and must return one. `group_by` changes the unit of work from "one partition" to "one
group"; `packages` controls which libraries are distributed to the workers; `names`
sets the output column names. `[documented: read it on 2026-08-19]`

```r
library(sparklyr)

sc <- spark_connect(method = "databricks_connect", cluster_id = Sys.getenv("DATABRICKS_CLUSTER_ID"))

sdf <- sdf_sql(sc, "SELECT id, id * 2 AS y FROM range(0, 1000)")

out <- sdf |>
  spark_apply(function(df) data.frame(z = nrow(df)))
```

See `r-databricks-connections` for why `spark_connect(method = "databricks_connect", ...)`
is the sparklyr path among the five connection choices, and cite it rather than
re-deriving the decision here.

## Prerequisites: hard gates, checked before writing any `spark_apply()` code

- **R must be installed cluster-wide**, on the executors and not merely the driver. A
  missing R gives "Cannot run program", an error that reads like a `PATH` problem and is
  actually a missing installation.
- **Not serverless.** `spark_apply()` is unsupported on serverless compute, because there
  is no R installation there to run the function.
- **More than one node, or there is nothing to distribute to.** Personal Compute is
  typically single-node; it is a cluster *policy* rather than an access mode, and it
  pins Dedicated access mode, which is why R works on it but also why it may have no
  second node to spread work across.
- **Driver and workers need matching architecture and system libraries.** A function
  that only the driver can run is not a distributed function.

See `r-databricks-compute` for the access-mode table itself (Dedicated, Standard, Auto)
and the notebook-versus-client-connection distinction for Standard; it is not repeated
here.

## A working recipe, measured on a Dedicated cluster, 2026-08-19

The prerequisites above come from vendor documentation. A working end-to-end recipe now
also exists, `[verified: ran it on 2026-08-19]`, measured on a Dedicated cluster, DBR 15.4:

1. Install `sparklyr` and `pysparklyr` locally, and nothing else. Do not hand-build a
   Python environment for this: `pysparklyr` ignores a hand-built one and provisions its
   own `uv` environment matching the cluster's DBR version, including its own CPython
   build. Hand-pinning a venv first is wasted effort.
2. Install `rpy2` as a **cluster library**, pinned to the version that matches the
   *cluster's* R, not the newest release. A `rpy2` built against a newer R C API than the
   cluster ships will fail; the failure surfaces as a serialization error from the
   worker, not as an obvious version mismatch, because the real fault is in the innermost
   frame of that traceback, underneath the serializer's own frames. Read past the
   serializer frames before concluding the problem is serialisation.
3. Restart the cluster after any library change before reconnecting.
4. Budget for a cold start of roughly five minutes, and a first-connection `uv`
   environment build of roughly ninety seconds; later connections took roughly three
   seconds. **Not a benchmark**: one workspace, one day, single node, results cached.

The cluster measured had no worker nodes: the parallelism observed was across cores on
that single node, not across multiple machines. **That run was not evidence that
`spark_apply()` distributes across multiple Spark nodes.**

**It has since been measured on a two-worker cluster, and it does.**
`[verified: ran it on 2026-08-21]` Counting distinct `Sys.info()[["nodename"]]` values
rather than PIDs, tasks landed on **two worker machines, neither of them the driver**,
across eight R processes, holding at 8, 16 and 64 tasks. `sf` loaded and did real
point-in-polygon work in the same runs. Details: DBR 18.3, two `Standard_DS3_v2`
workers, Dedicated access mode.

**Two workers answers "does it distribute at all" and nothing more.** It says nothing
about scaling, shuffle cost, or behaviour at twenty nodes.

**Count machines, not processes.** Two machines can report the same PID, and N distinct
PIDs is consistent with N processes on one host, so a PID count cannot tell a
single-node cluster from a distributed one. Note also that `SPARK_EXECUTOR_ID` came back
**empty** in the worker on this stack, so it is not a usable corroborating identifier;
nodename is the one that worked. `[verified: ran it on 2026-08-21]`

## Costs and traps that surprise people

- **The first call is slow by design, not hung.** On first use, sparklyr copies **all**
  of `.libPaths()` to the workers via `SparkConf.addFile()`, once per connection.
  Libraries are commonly gigabytes in aggregate. Budget for this rather than
  interrupting it. `[documented: read it on 2026-08-19]` That is the vendor-documented
  model; it is not what was observed for the `rpy2` path above, where the workers instead
  used their own `pysparklyr`-provisioned `uv` environment rather than a copy of the local
  `.libPaths()`. Treat the two as describing different mechanisms, not one measured fact.
- **Closures do not serialise references to the enclosing environment.** Pass everything
  the function needs as an argument; do not rely on it finding a variable defined
  outside itself.
- **Adding a package after connecting requires disconnect and reconnect.** There is no
  way to extend the set of libraries already shipped to the workers on a live
  connection.
- **Each group or partition must fit in one worker's memory.** `spark_apply()`
  distributes across workers, but does not shrink the unit of work below what a single
  worker must hold.
- **`group_by` does not by itself buy parallelism, and usually costs it.** Measured twice,
  on different workloads, with the same outcome:
  - `[verified: ran it on 2026-08-19]` The `group_by =` path used **1** R process where the
    plain partition path used **4**, same cluster, same session.
  - `[verified: ran it on 2026-08-20]` Reproduced independently on a different workload
    (703 groups, one simulation per group): partition path **4 processes in 15.6 s**,
    `group_by =` **1 process in 33.0 s**, **2.1× slower for an identical, correct result**.

  Two runs on different work is a pattern rather than a one-off, so treat this as a rule:
  **do not reach for `group_by =` because the unit of work is naturally a group.** Partition
  instead, and let each worker loop over the rows in its slice. Mapping one group per unit of
  work is the intuitive expression and it serialises the job.

  The mechanism remains unexplained `[unresolved]`, and the failure is **silent**: the answer
  is correct either way, so nothing surfaces except wall-clock time. **Return the nodename and
  `Sys.getpid()` from the worker function and count distinct values** before believing work was
  distributed. It is two columns and it is the only cheap way to see this.

  **Whether this persists across machines is still `[unresolved]`**, because on a multi-node
  cluster the `group_by` path could not be run at all: on **`rpy2` 3.6.x it fails outright**,
  raising `DeprecationWarning` from `pandas2ri.activate()` inside `pysparklyr`'s
  `udf/udf-apply.py`, which is the template used only when `group_by` is supplied. Ungrouped
  calls are unaffected. `[verified: ran it on 2026-08-21]` So on a current runtime the practical
  rule is stronger than the performance argument: **the grouped path does not run.**
- **`columns =` must be a Spark DDL string under `databricks_connect`, not the documented
  named list.** `[verified: ran it on 2026-08-20]` `columns = list(id = "character", m =
  "double")`, the form `?spark_apply` documents, fails with a bare
  `Error: non-character argument`. A named character vector fails with
  `PySparkTypeError: [NOT_DATATYPE_OR_STR] Argument 'returnType' should be a DataType or str`.
  **The working form is `columns = "id string, m double"`.** Omitting `columns` entirely also
  works. Neither error names the argument at fault, so this reads as a fault in the worker
  function or the data, and it is neither. Seen on `sparklyr` 1.9.5 against DBR 15.4; whether
  other connection methods are affected is **untested**.

## Databricks Connect is a reduced Spark API

Most `sdf_` functions need a `SparkSession` that Spark Connect does not provide;
`tidyr` verbs are unsupported; ML is limited to logistic regression and two scalers
(Standard, Max Abs) on DBR 14.1+; caching and memory persistence are limited on
serverless. `[documented: read it on 2026-08-19]` The connection stack is `sparklyr` →
`reticulate` → `databricks-connect` (Python) → gRPC → Spark, so a resolvable Python
environment is a precondition for any of this working, not an optional detail.

## The access-mode question: genuinely unresolved

**The working recipe above does not answer this.** It was measured on a Dedicated
(`SINGLE_USER`) cluster. Whether `spark_apply()` works on **Standard** access mode is a
different, untested case, and the successful run is **not evidence in either direction**
for it.

Whether `spark_apply()` works on Standard access mode is **`[unresolved]`, and must not
be asserted in either direction.** Two inferences point opposite ways:

- Standard access mode exists specifically to prevent non-isolated execution, and from
  DBR 19 it rejects cluster configs that set `spark.r.command`, `spark.r.driver.command`
  or `spark.r.shell.command`, which reads like a "no" for anything that looks like
  classic `SparkR`/`sparklyr` UDF execution.
- But with `pysparklyr`/`rpy2`, the UDF that actually reaches the cluster arrives as a
  *Python* UDF, not an R one, and Python UDFs are supported on Standard, which reads
  like a "yes" by a different mechanism.

Nothing in Databricks' documentation states directly which access modes `sparklyr`
requires or supports. `[documented: read it on 2026-08-18]` Do not resolve this tension
by picking the inference that sounds more convenient; state it as open.

The experiment that would settle it: install `rpy2` as a **cluster library** (not a
notebook-scoped install) on a Standard-access cluster, then make one `spark_apply()`
call and observe whether it runs. Nobody has run this experiment yet. Cite
`r-databricks-compute` for access-mode detail generally; this skill only states the
open question as it bears on `spark_apply()`.

## Timings are never benchmarks

Any latency or runtime number attached to `spark_apply()`, cluster start, or a
comparison between methods describes one run on one workspace on one day. It is not a
guarantee for a different cluster size, a different workload, or a different day.

## The `|>` rule, with a specific warning here

Use the base pipe `|>` in every example, never the magrittr pipe. This matters more in
this skill than any other: sparklyr's own guides and nearly every `spark_apply()`
example found online use the magrittr pipe throughout, not the base pipe. Translate as
you read; do not paste vendor-style examples forward unchanged.
