# dbx-config.R --------------------------------------------------------------
# One place that answers "which warehouse, which cluster?".
#
#   source("dbx-config.R")
#   dbx_http_path()                  # /sql/1.0/warehouses/<id>  for odbc
#   dbx_warehouse_id()               # bare <id>                 for brickster
#   dbx_cluster_id()                 # single-node cluster
#   dbx_cluster_id("multinode")      # driver + 2 workers
#
# Two sources. `config.yml` is committed, so it holds the project's defaults;
# `.Renviron` is per-machine and gitignored, so it holds anything personal. That
# fixes the precedence between them:
#
#   - The WAREHOUSE comes from config.yml first. It is shared infrastructure,
#     and everyone reading these tables uses the same one.
#   - The CLUSTER comes from DATABRICKS_CLUSTER_ID first, falling back to
#     config.yml. Dedicated access mode is one cluster per person, so the
#     committed value is only ever right for its owner. Anyone else sets the
#     env var and needs no edit to a tracked file.
#
# Named profiles exist because some jobs need the single-node cluster and some
# need workers, so that choice is per-job and cannot live in a per-machine
# variable at all.
#
# What this does NOT do is default to a real warehouse or a real cluster: a
# misconfigured clone must fail, not quietly query someone else's workspace.
# Every accessor below errors when neither source supplies a value, except
# dbx_cluster_id(), which returns "" so a cluster-backed page can degrade to a
# callout instead of breaking the site render.

`%||%` <- function(x, y) if (is.null(x) || !nzchar(x)) y else x

# Resolved from the project root, not the working directory. Quarto renders a
# page with the cwd set to that page's own directory, so a bare "config.yml"
# is invisible to anything under example/ or howdoi/. The symptom is not a
# missing-file error but an empty cluster id, which surfaces much later as
# "Cluster id cannot be empty" from the Databricks SDK.
DBX_CONFIG_FILE <- if (requireNamespace("here", quietly = TRUE)) {
  here::here("config.yml")
} else {
  "config.yml"
}

# config::get() has three sharp edges this wraps:
#   - a missing file is an *error*, not a NULL, so file.exists() has to gate it;
#   - a missing key returns NULL silently;
#   - an unknown profile name silently falls back to `default`, so a typo in
#     "multinode" yields the single-node cluster and a render that looks fine.
#     Hence the explicit check against the file's own top-level names.
dbx_profiles <- function(file = DBX_CONFIG_FILE) {
  if (!file.exists(file)) return(character())
  names(yaml::yaml.load_file(file))
}

dbx_config_value <- function(key, profile = "default", file = DBX_CONFIG_FILE) {
  if (!file.exists(file)) return(NULL)
  known <- dbx_profiles(file)
  if (!profile %in% known) {
    cli::cli_abort(c(
      "Unknown config profile {.val {profile}}.",
      i = "{.file {file}} defines: {.val {known}}.",
      x = "config::get() would have fallen back to {.val default}
           and given you the wrong compute."
    ))
  }
  config::get(key, config = profile, file = file)
}

# The warehouse. Stored as a bare id, because both consumers want a different
# shape of it: odbc wants the HTTP path, brickster wants the id. Storing the
# path and calling basename() back off it, as this repo used to, meant the two
# forms drifted apart at six call sites.
dbx_warehouse_id <- function(profile = "default") {
  id <- dbx_config_value("warehouse_id", profile) %||%
        sub(".*/", "", Sys.getenv("DATABRICKS_PATH"))
  if (!nzchar(id)) {
    cli::cli_abort(c(
      "No warehouse configured.",
      i = "Set {.field warehouse_id} in {.file config.yml},
           or {.envvar DATABRICKS_PATH} in {.file .Renviron}.",
      i = "See {.file README.md}."
    ))
  }
  id
}

dbx_http_path <- function(profile = "default") {
  # Prefer a literal http_path if one is given: a workspace that does not use
  # the /sql/1.0/warehouses/<id> shape can override rather than fight it.
  literal <- dbx_config_value("http_path", profile) %||% Sys.getenv("DATABRICKS_PATH")
  if (nzchar(literal) && grepl("/", literal)) return(literal)
  paste0("/sql/1.0/warehouses/", dbx_warehouse_id(profile))
}

# The cluster. Unset is NOT fatal: the cluster-backed example pages gate on
# wq_cluster_enabled() and emit a callout instead, so the site builds for a
# reader with no cluster of her own.
# Env var first, but ONLY for `default`: see the precedence note at the top.
#
# The profile restriction is the important half. DATABRICKS_CLUSTER_ID names one
# cluster, and a named profile is a request for a *particular* topology, so
# letting a single env var answer both means dbx_cluster_id("multinode") quietly
# returns a single-node cluster. That is the same silent-wrong-compute failure
# this file exists to prevent, so a non-default profile ignores the env var and
# reads config.yml.
dbx_cluster_id <- function(profile = "default") {
  from_env <- if (identical(profile, "default")) Sys.getenv("DATABRICKS_CLUSTER_ID") else ""
  from_env %||% dbx_config_value("cluster_id", profile) %||% ""
}

# Which source won, for the smoke test to report. Diagnosing "why is it hitting
# the wrong cluster?" is otherwise guesswork.
dbx_config_source <- function() {
  if (file.exists(DBX_CONFIG_FILE)) sprintf("%s (profiles: %s)",
    DBX_CONFIG_FILE, paste(dbx_profiles(), collapse = ", ")) else ".Renviron"
}
