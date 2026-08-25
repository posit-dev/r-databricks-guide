#!/usr/bin/env Rscript
# Start the cluster named by DATABRICKS_CLUSTER_ID, and wait for it.
#
#   scripts/start-cluster.R            # start and wait
#   scripts/start-cluster.R --status   # report state and exit, starting nothing
#
# Why this exists. The check-then-start sequence is easy to get subtly wrong:
# calling db_cluster_start() on something already RUNNING is an error, and on
# something PENDING it races. brickster::get_and_start_cluster() is idempotent
# and handles both, so the only thing left to get wrong is forgetting to use it.
#
# This script never stops a cluster. Stopping is the owner's call, and a cold
# start is roughly seven minutes of VM provisioning that nothing here shortens,
# so terminating between two pieces of work schedules that wait rather than
# saving it. Both clusters auto-terminate when idle anyway.

suppressPackageStartupMessages({
  library(brickster)
  library(cli)
})

cluster_id <- Sys.getenv("DATABRICKS_CLUSTER_ID")

if (!nzchar(cluster_id)) {
  cli_abort(c(
    "{.envvar DATABRICKS_CLUSTER_ID} is unset.",
    i = "Copy {.file .Renviron.example} to {.file .Renviron}, fill in your own
         cluster id, and restart R so it is read.",
    x = "There is deliberately no default: a cluster id is per-user under
         dedicated access mode, so a literal would be wrong for everyone
         but its author."
  ))
}

status_only <- "--status" %in% commandArgs(trailingOnly = TRUE)

info <- db_cluster_get(cluster_id = cluster_id)
cli_alert_info("Cluster is {.strong {info$state}}.")

if (status_only) {
  cli_alert_info("Auto-terminates after {info$autotermination_minutes} idle minutes.")
  quit(status = 0)
}

if (identical(info$state, "RUNNING")) {
  cli_alert_success("Already running. Nothing to do.")
  cli_alert_info("Auto-terminates after {info$autotermination_minutes} idle minutes.")
  quit(status = 0)
}

cli_alert_info("Starting. A cold start is around seven minutes, and it bills
                until it auto-terminates.")

started <- Sys.time()
cluster <- get_and_start_cluster(cluster_id = cluster_id)
elapsed <- round(as.numeric(difftime(Sys.time(), started, units = "secs")))

cli_alert_success("Cluster is {.strong {cluster$state}} after {elapsed}s.")
cli_alert_info("Auto-terminates after {cluster$autotermination_minutes} idle minutes.")
