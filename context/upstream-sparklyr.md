# What sparklyr's documentation says

An account of `spark.posit.co`, read on 2026-08-23: all seventeen pages under `guides/`, plus the deployment pages the guides do not link to. Recorded so this guide can link rather than repeat, avoid contradicting it, and be clear about which gaps it fills.

Link only to `spark.posit.co`. `spark.rstudio.com` 301-redirects there, and `sparklyr.ai` is a single-page site for the project under the Linux Foundation with no `/guides/` tree, so every `sparklyr.ai/guides/*.html` path returns 404.

## The structural finding

**None of the seventeen `guides/` pages mentions Databricks or Spark Connect in its body.** Every code example connects with `spark_connect(master = "local")`, or YARN, or a standalone URL. Everything Databricks-specific lives on one page outside that section, `deployment/databricks-connect.html`, and the guides do not link to it.

That shapes how this guide should use the site. A reader searching for "sparklyr dplyr" or "sparklyr distributed R" lands in `guides/`, reads material written for a Spark she does not have, and never learns the page addressing her platform exists. So a link into `guides/` usually needs a sentence of framing around it, and several pages need a warning or should not be linked at all.

## The page that matters most, and is not in `guides/`

`deployment/databricks-connect.html` is the single most relevant upstream page to this whole guide, and it states plainly several things this site currently derives for itself. Read it before writing another page.

What it gives us:

- The connection form: `spark_connect(cluster_id = ..., method = "databricks_connect")`, and for serverless the same call plus `serverless = TRUE, version = ...`.
- `pysparklyr` is the Python integration, isolated into its own package, installed with `pysparklyr::install_databricks()`, optionally matched to a runtime version or read from a cluster id.
- Supported: most of the `dplyr` and `DBI` APIs, `invoke()`, the Connections Pane, PAT authentication, most read and write commands.
- Not supported: most `sdf_*` functions, because they require a `SparkSession`, which Spark Connect does not provide. `tidyr` is described as ongoing work.
- On serverless: `spark_apply()` is not supported, because there is no R installation in the serverless environment. No data can be persisted in memory, so `memory = TRUE` does not work and `compute()` will not work.
- Machine learning from DBR 14.1, and deliberately narrow: logistic regression, standard scaler, max abs scaler. ML needs an opt-in install, `install_databricks(install_ml = TRUE)`.
- Posit Workbench is discussed at length as the recommended credential path, with a Databricks pane and an ordered preference for Python environments.
- It does not mention R version requirements, and it does not mention geospatial or `sf` anywhere.

Three of these bear directly on pages here. The `sdf_*` exclusion is broad and this guide nowhere states it. The serverless `spark_apply()` prohibition matches what `skills/r-databricks-parallel` says, so that claim can cite upstream rather than resting on our own testing alone. And the Workbench credential discussion corroborates the ambient-credentials note in `CLAUDE.md`.

## The guides, and what each is worth

The verdict column is the one that matters: it records whether this reader can safely be sent to the page.

### Interacting with Spark

| Page | What it covers | Verdict |
|----|----|----|
| [Manipulating Data with `dplyr`](https://spark.posit.co/guides/dplyr.html) | The five verbs against a Spark table, `group_by()`, `collect()`, `copy_to()`, `sample_n()`, window functions, joins | **Link, do not repeat.** The closest thing to directly reusable: verb translation behaves the same over a Connect session. Connects with `master = "local"`, so the preamble is wrong but the body is fine. Nothing about reading the generated SQL |
| [Understanding Spark Caching](https://spark.posit.co/guides/caching.html) | Lazy evaluation and the cache lifecycle: `memory =`, `sdf_register()`, `tbl_cache()` | **Do not link without a warning.** Teaches `memory = TRUE` and `compute()`, both of which the Databricks Connect page says do not work on serverless. A reader following it correctly will fail |
| [Configuring Spark Connections](https://spark.posit.co/guides/connections.html) | `spark_config()` across local, YARN client and standalone. Executor memory and cores. Spark UI on port 4040 | **Do not link.** Wrong in framing rather than detail: she cannot set executor memory or cores, and `localhost:4040` is not her Spark UI. What its title promises, attaching to compute she already has and reading its size, is absent. That is `howdoi/compute.qmd`'s territory, with no upstream page to defer to |
| [Using Spark with AWS S3 buckets](https://spark.posit.co/guides/aws-s3.html) | Adds `hadoop-aws` via `sparklyr.defaultPackages`, credentials in config, `spark_read_csv()` on `s3a://` | **Do not link.** Wrong mechanism on Databricks, where storage is reached through Unity Catalog external locations and volumes, and where a client cannot add a Hadoop jar to a managed cluster's classpath. The failure looks like a jar problem rather than a platform mismatch |

### Machine learning, and the wall behind it

All six are classic-Spark pages and none mentions Spark Connect. The important cross-page finding: **two upstream pages disagree on how much of MLlib survives Connect.** `deployment/spark-connect.html` carries an appendix of 21 `ml_*` and 34 `ft_*` functions supported via Spark Connect, requiring Spark 4.0+. `deployment/databricks-connect.html` is much narrower: logistic regression, standard scaler, max abs scaler. Both may be correct within their own scope, but neither states its scope, and the gap is large enough to change what she builds.

**A reader on Databricks should assume the narrow list.** Nothing on any of the six pages warns her.

| Page | What it covers | Verdict |
|----|----|----|
| [Spark MLlib](https://spark.posit.co/guides/mlib.html) | Catalogue of `ml_*`, `ft_*`, `sdf_*` | Low value. Roughly half of what it demonstrates is not on the Connect list, `ml_pca()` and `ml_random_forest()` included |
| [Spark ML Pipelines](https://spark.posit.co/guides/pipelines.html) | `ml_pipeline()`, `ft_dplyr_transformer()`, `ml_fit()`, `ml_save()`/`ml_load()` | Low value. `ml_load()` and `ft_dplyr_transformer()` are not on the Connect list, and saving without loading is not a workflow |
| [Text modeling](https://spark.posit.co/guides/textmodeling.html) | Text classification pipeline into logistic regression, `ml_metrics_binary()` | Moderate, and the most portable of the classic pages: everything it uses is on the Connect list |
| [Intro to Model Tuning](https://spark.posit.co/guides/model_tuning.html) | `ml_cross_validator()` over a random forest, `ml_validation_metrics()` | Moderate. This is the MLlib-native alternative to `tune_grid_spark()`, and the choice between them is a real decision no upstream page frames |
| [Grid Search Tuning](https://spark.posit.co/guides/model_tuning_text.html) | The text pipeline under a parameter grid | Low value |
| [Sparkling Water (H2O)](https://spark.posit.co/guides/h2o.html) | `rsparkling`, `as_h2o_frame()`, the `h2o.*` algorithms | **Do not link at all.** Pins Sparkling Water versions for Spark 1.6 and 2.x. `rsparkling` is off CRAN, the approach needs a JVM-side assembly on the cluster, and none of it works over Connect. No deprecation notice anywhere on the page |

### tidymodels, which is where this reader lives

The two most important pages in `guides/` for her, and very different from each other.

[**`tidymodels` and Spark**](https://spark.posit.co/guides/tidymodels.html) is an inventory of four integration points: parsnip via `set_engine("spark")`, broom's `tidy()`/`glance()`/`augment()`, the `ml_metrics_*` family, and corrr. The thing to state plainly on our side: **this is a thin translation layer over MLlib, not tidymodels running on Spark.** `translate()` shows it, with `linear_reg() |> set_engine("spark")` resolving to `sparklyr::ml_linear_regression()`. Six parsnip models are supported.

Two consequences the page does not draw. Every Spark Connect restriction applies invisibly, and its headline `rand_forest()` example translates to `ml_random_forest()`, which is not on the Connect supported list, so the page's own example may fail on her cluster without saying so. And there is no preprocessing integration at all: the word "recipes" never appears, so no `recipe()`, no `step_*`, no `workflow()`. A tidymodels user arrives expecting these.

[**Tune `tidymodels` remotely in Spark Connect**](https://spark.posit.co/guides/tune_tidymodels_spark.html) is a genuinely different mechanism and the only page in `guides/` written for Spark Connect. `sparklyr::tune_grid_spark()` takes the same arguments as `tune::tune_grid()` plus `sc`, and accepts a workflow. Full recipes work, because the recipe and resamples are built locally in R and serialised up. The fitting then runs as R code in Spark tasks on the executors, and **not** through `spark_apply()`. Parallelism is by Spark task, one per available core, with `parallel_over = "resamples"` by default. The returned object is indistinguishable from one produced by tidymodels locally.

Its framing is worth borrowing: "we are not speaking of 'big data', but rather 'big processing'." That describes this reader's situation exactly.

Its stated requirement is the part that matters here, and it is stated once and never revisited: every node needs an R runtime, `tidymodels`, `reticulate`, `rpy2`, and any model-specific package (`xgboost` for the `boost_tree()` default). On Databricks that is an init script or a cluster library policy, which is precisely what this reader cannot do for herself. The page gives no Databricks recipe, no way to check from R whether the workers are ready, and no description of the failure mode when they are not. By implication from the serverless "no R installation" statement, `tune_grid_spark()` cannot work on serverless, but nobody says so.

### The rest

| Page | What it covers | Verdict |
|----|----|----|
| [Distributing R Computations](https://spark.posit.co/guides/distributed-r.html) | `spark_apply()`, `repartition`, `group_by =`, `columns =`, per-group `lm()` with broom | Important, and to be cited carefully. See below |
| [Text mining](https://spark.posit.co/guides/textmining.html) | `spark_read_text()`, Hive functions through dplyr, tokenising, `compute()` | Low value, and carries two traps: `compute()` does not work on Databricks Connect, and `spark_read_text()` on a local path is meaningless against a remote cluster |
| [Intro to Spark Streaming](https://spark.posit.co/guides/streaming.html) | `stream_read_csv()`, `stream_write_*`, watermarks, a Shiny dashboard | None. Links to Spark 2.1.3 documentation. No Kafka, Delta or Auto Loader, and no word on Connect |
| [Creating Extensions](https://spark.posit.co/guides/extensions.html) | `invoke()`, `invoke_new()`, `invoke_static()`, `spark_dependency()`, compiling jars | None for her, though the Databricks page confirms `invoke()` survives Connect. Names the Scala 2.10 and 2.11 compilers |
| [Troubleshooting](https://spark.posit.co/guides/troubleshooting.html) | Three signposts: Stack Overflow, the NEWS file, the connections guide. No code, no diagnostic functions | **Do not link as a destination.** It names no symptom and no cause. This page is an argument that `ref/when-it-breaks.qmd` needs to exist |

## `spark_apply()`: what upstream actually claims

This needs care, because the honesty constraints in `CLAUDE.md` are stricter than the upstream page and must stay that way.

**The upstream claim is architectural and asserted, not demonstrated.** The page says Spark objects are partitioned "so they can be distributed across a cluster" and that `spark_apply()` will run your R function on each partition. The modal verb is *can be* throughout, and every worked example runs on `master = "local"`, so nothing on the page evidences cross-machine execution. It counts no machines.

So our two-worker observation is stronger evidence than the upstream page is. That is worth knowing and changes nothing about what this guide may claim: the constraint in `CLAUDE.md` still holds, and nothing here licenses a statement about how `spark_apply()` scales.

It makes no timing, throughput or node-count claims anywhere. The only cost it discusses is the one-time library copy, described as a tax to be prepared for because R libraries are often several gigabytes. That is compatible with the no-benchmarks rule.

Two facts on the page are genuinely useful and change what she does, so they belong on `ref/packages.qmd` or `ref/sending-things.qmd`:

- The first `spark_apply()` call copies the whole of the local `.libPaths()` to each worker via `SparkConf.addFile()`, once per connection, persisting as long as the connection is open. `packages = FALSE` disables it, and packages are not copied in local mode. **Installing more packages is not supported while the connection is active**: you must disconnect, change them, and reconnect. That last point is a real operational constraint this guide does not state anywhere.
- Closures are serialised with `serialize` and do not capture objects referenced outside their environment, so a closure over a free variable errors. That is `ref/sending-things.qmd`'s territory and supports it from upstream.

Two things not to carry across. The page discusses `group_by =` at length and does not know that the grouped path fails on a current runtime, which is our finding and an absence rather than a contradiction. And its advice for groups too large for one node is `dplyr::do()`, which is superseded.

## Behaviours we believe are bugs

Recorded here because they affect what pages can safely demonstrate.

- **`spark_apply(columns = list(...))`, the documented form, fails on the `databricks_connect` backend**, where a Spark DDL string works. Filed as [`sparklyr/sparklyr#3529`](https://github.com/sparklyr/sparklyr/issues/3529). The correct form appears to differ by context: a Spark type string works from a client connection, a plain character vector works when running in the cluster's own R session, and neither form is rejected by the other path. The error never names `columns`: it surfaces as a complaint that a column does not exist, which reads like the worker function returned the wrong shape. Omitting the argument works in both contexts.
- **`spark_apply(group_by = ...)` fails on `rpy2` 3.6.x.** The grouped path is prominent in `guides/distributed-r.html`, so a reader following that page on a current runtime hits it.
- **`spark_apply(context = )` does not work on the `databricks_connect` backend.** Whether that is a known limitation or a bug is unresolved.

## The gap: geospatial

There is no geospatial guide anywhere in `guides/`, and the extensions that historically filled the gap are not viable: `geospark` and `sparkgeo` are Spark 2.x/3.x-era, not installable from CRAN in a current setup, and predate native platform geospatial support entirely.

The gap is larger than it used to be, because the platform moved. Databricks has native `GEOMETRY` and `GEOGRAPHY` types and 97 `ST_` functions counted on a current Pro warehouse, published as "80+", on DBR 17.1 and above. These are ordinary scalar SQL functions, so much of the work can push down through `dbplyr` without any R-side geometry at all, which is a better story than shipping `sf` objects to executors.

So an R user doing spatial work on Spark has no documented path, and the good path that now exists is undocumented. See [`upstream-brickster.md`](upstream-brickster.md) for the transport half of the same problem.

## What this changes on this site

Ordered by how much they reduce risk or work.

1. **Nothing here links to `spark.posit.co` yet.** Every link added is prose this guide does not have to write, so this is the cheapest improvement available and should happen when the pages get their prose.
2. **State the `sdf_*` exclusion somewhere.** Broad, upstream-stated, never mentioned here, and it will bite anyone following older sparklyr material. `concepts/index.qmd` or `ref/when-it-breaks.qmd`.
3. **Two upstream pages will break her if followed correctly**, which makes them good `ref/when-it-breaks.qmd` entries: `memory = TRUE`/`compute()` from the caching guide, and adding a Hadoop jar from the S3 guide. Symptom-shaped, cause upstream.
4. **Add the two `spark_apply()` operational facts**: packages cannot be added while the connection is open, and closures do not capture free variables.
5. **Cite upstream for the serverless `spark_apply()` prohibition** rather than resting it on our own testing.
6. **Say once that the tidymodels/parsnip integration is MLlib underneath**, and that `tune_grid_spark()` is the different thing that runs actual R on the executors. Then say that its every-node requirement is an ask-and-wait for her. That framing exists nowhere upstream and is squarely in this guide's remit.
7. **Do not link** the H2O guide, the connections guide, the S3 guide, or the troubleshooting page.
