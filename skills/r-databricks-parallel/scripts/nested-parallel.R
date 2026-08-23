#!/usr/bin/env Rscript
# Does forking inside a spark_apply() worker reclaim the node's idle cores?
#
#   Rscript nested-parallel.R
#
# Use when partition count is bounded below the cores available: a few large
# groups, or one expensive task per row of a small frame. Where the data
# partitions naturally, add partitions instead -- simpler, and Spark schedules it.
#
# The timing is taken INSIDE the worker on purpose. Timing the whole job instead
# measures submission, library serialisation and collection, which dominate a
# sub-second compute difference and make nesting look useless when it is not.
#
#
# Connection path: this uses method = "databricks_connect", the client-side path.
# The logic was verified on the cluster's own R session (method = "databricks"),
# where the same code produces the results quoted in SKILL.md. If you run this
# from a notebook, change the spark_connect() line accordingly; note that the
# correct spelling of `columns` differs between the two paths, which is why
# these scripts omit it.
# Requires DATABRICKS_CLUSTER_ID. Credentials are ambient on Posit Workbench.

library(sparklyr)
library(dplyr)

cluster_id <- Sys.getenv("DATABRICKS_CLUSTER_ID")
if (!nzchar(cluster_id)) {
  stop("Set DATABRICKS_CLUSTER_ID to the cluster you want to inspect.", call. = FALSE)
}

sc <- spark_connect(method = "databricks_connect", cluster_id = cluster_id)
on.exit(spark_disconnect(sc), add = TRUE)

# One partition, so the task gets one core and the rest of the node sits idle.
# That is the situation nesting is for.
res <- sdf_len(sc, 1, repartition = 1) |>
  spark_apply(function(df) {
    burn <- function(k) { s <- 0; for (i in 1:3e6) s <- s + sqrt(i); s }

    n_cores <- parallel::detectCores()

    t_serial <- system.time(lapply(1:n_cores, burn))[["elapsed"]]
    t_forked <- system.time(
      parallel::mclapply(1:n_cores, burn, mc.cores = n_cores)
    )[["elapsed"]]

    data.frame(
      cores   = n_cores,
      serial  = round(t_serial, 3),
      forked  = round(t_forked, 3),
      speedup = round(t_serial / t_forked, 2),
      stringsAsFactors = FALSE
    )
  }) |>
  collect()

print(as.data.frame(res))

cat("\nA speedup near 1 means forking bought nothing: check whether the executor\n")
cat("is really allocated the cores that detectCores() reports.\n\n")
cat("CAUTION: mc.cores here is detectCores(), which reports the MACHINE. With\n")
cat("several partitions running at once, nested forks multiply -- 8 partitions\n")
cat("forking 4 ways is 32 processes on a 4-core node. Choose mc.cores against\n")
cat("cores per executor, not against what the machine reports.\n")
