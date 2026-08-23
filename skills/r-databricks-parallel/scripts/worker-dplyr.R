#!/usr/bin/env Rscript
# dplyr inside a spark_apply() worker: the shape that works, and the one that cannot.
#
#   Rscript worker-dplyr.R
#
# Inside the worker, R is R. The function receives a local data frame and returns
# one, so mutate() there is ordinary dplyr with nothing translated. The reverse --
# spark_apply() inside a mutate() on a lazy table -- fails at translation, before
# any cluster is involved, and no argument spelling fixes it.
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

sdf <- sdf_len(sc, 6)

# WORKS. Namespace-qualify dplyr:: rather than relying on attach order in the
# worker. Omitting `columns` is the portable form: the correct spelling of
# `columns` differs between a client connection and the cluster's own R session,
# and neither rejects the other's.
cat("-- mutate() inside the worker --\n")
out <- sdf |>
  spark_apply(function(df) dplyr::mutate(df, doubled = id * 2)) |>
  collect()
print(as.data.frame(out))

# Columns the worker adds are typed correctly on return without being declared.
cat("\n-- the worker adding two columns --\n")
out2 <- sdf |>
  spark_apply(function(df) {
    dplyr::mutate(df, doubled = id * 2, label = paste0("r", id))
  }) |>
  collect()
print(as.data.frame(out2))
cat("classes:", paste(vapply(out2, function(x) class(x)[1], ""), collapse = ", "), "\n")

# CANNOT WORK. dbplyr walks the expression to build SQL and reaches the
# function's formals, a pairlist, which has no SQL form. This is general: ANY R
# closure written inline inside a mutate() on a remote table fails the same way.
# spark_apply() is a pipeline stage, not an expression.
cat("\n-- spark_apply() inside mutate(): expected to fail --\n")
failed <- tryCatch({
  sdf |> mutate(z = spark_apply(id, function(e) e * 2)) |> collect()
  FALSE
}, error = function(e) {
  cat("errored as expected:\n  ", conditionMessage(e), "\n")
  TRUE
})

if (!failed) {
  cat("UNEXPECTED: this succeeded. The translation behaviour has changed.\n")
}
