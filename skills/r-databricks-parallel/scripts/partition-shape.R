#!/usr/bin/env Rscript
# How many R processes does a spark_apply() job actually get, and where do they run?
#
#   Rscript partition-shape.R
#
# Answers three things you cannot see from a job's output:
#   1. how many distinct R processes ran, and on how many machines
#   2. how many cores each worker believes it has
#   3. whether work reached machines other than the driver
#
# Run this before tuning anything. A job that looks parallel and is not looks
# exactly like a job that is.
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

# Count MACHINES, not processes. Two machines can report the same PID, so a PID
# count cannot tell a single-node cluster from a distributed one.
probe <- function(n_partitions) {
  sdf_len(sc, n_partitions, repartition = n_partitions) |>
    spark_apply(function(df) {
      data.frame(
        host  = Sys.info()[["nodename"]],
        pid   = Sys.getpid(),
        cores = parallel::detectCores(),
        stringsAsFactors = FALSE
      )
    }) |>
    collect()
}

driver_host <- Sys.info()[["nodename"]]

for (n in c(2, 8)) {
  res <- probe(n)
  cat("\n--", n, "partitions --\n")
  cat("  distinct R processes :", length(unique(res$pid)), "\n")
  cat("  distinct machines    :", length(unique(res$host)), "\n")
  cat("  cores seen by worker :", paste(unique(res$cores), collapse = ", "), "\n")
  cat("  reached a non-driver :", any(res$host != driver_host), "\n")
}

cat("\nOne R process per task, and a task gets one core.\n")
cat("If distinct machines is 1, this is a single-node cluster: it cannot show distribution.\n")
