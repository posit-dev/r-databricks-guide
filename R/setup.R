# Shared plumbing for the worked example.
#
#   source("R/setup.R")
#
# Holds only what every stage needs and no reader needs to look at: where the
# tables live, how to open each of the two connections, and how to report a
# size. Anything the example is trying to TEACH stays visible in the page that
# teaches it.
#
# Nothing here hard-codes an identifier. The catalog, schema and compute
# targets are read from the environment and from config.yml, so a clone with
# different values needs no edit to a tracked file.

# --- where the tables live -------------------------------------------------

# Three-part names are built here rather than pasted into each query, so a
# reader pointing the example at her own tables changes two environment
# variables and nothing else.
wq_catalog <- function() {
  x <- Sys.getenv("DATABRICKS_CATALOG")
  if (!nzchar(x)) stop("DATABRICKS_CATALOG is unset. See .Renviron.example.", call. = FALSE)
  x
}

wq_schema <- function() {
  x <- Sys.getenv("DATABRICKS_SCHEMA")
  if (!nzchar(x)) stop("DATABRICKS_SCHEMA is unset. See .Renviron.example.", call. = FALSE)
  x
}

#' A fully qualified table name, for dbGetQuery() and friends.
wq_name <- function(table) sprintf("%s.%s.%s", wq_catalog(), wq_schema(), table)

#' The same thing for dbplyr, which needs I() so it does not quote the dots.
wq_tbl <- function(con, table) dplyr::tbl(con, I(wq_name(table)))

# --- masking, for published output -----------------------------------------

# This site is public, so a rendered page must not carry the catalog this
# example happens to run against. The chunks still query the real tables: only
# what gets *printed* is masked, and the shape of the name is what the page is
# teaching anyway.
#
# scripts/check-public.sh scans _site/ as well as tracked source, so a chunk
# that prints an unmasked name fails the check rather than reaching the web.
WQ_MASK_CATALOG <- "your_catalog"

#' Replace the real catalog with a neutral stand-in for display.
#'
#' The catalog only, deliberately. The schema here is `water`, which is a
#' substring of real table names, so masking it turns
#' bathing_water_classifications into nonsense and quietly falsifies the
#' output the page is teaching from. Only the catalog is on the blocklist, and
#' only the catalog is distinctive enough to substitute safely.
wq_mask <- function(x) gsub(wq_catalog(), WQ_MASK_CATALOG, x, fixed = TRUE)

#' A fully qualified name as a reader should see it, not as this workspace
#' spells it. Use in any chunk whose output is published.
wq_name_shown <- function(table) wq_mask(wq_name(table))

# --- the two connections ---------------------------------------------------

# Why there are two, and when each is required, is the subject of
# example/connecting.qmd. This file only opens them.

#' ODBC, for ordinary dbplyr work against the SQL warehouse.
#'
#' DefaultStringColumnLength is load-bearing rather than defensive: without it
#' a base64-encoded geometry is silently clipped at 1,023 characters and most
#' of every polygon is discarded with no error. 65535 deliberately is not a
#' round number, because a round value renders as 1e+05 and is dropped.
wq_connect_odbc <- function() {
  DBI::dbConnect(
    odbc::databricks(),
    httpPath = dbx_http_path(),
    DefaultStringColumnLength = 65535
  )
}

#' brickster, required whenever a BINARY column has to arrive intact.
wq_connect_brickster <- function() {
  DBI::dbConnect(brickster::DatabricksSQL(), warehouse_id = dbx_warehouse_id())
}

# --- reporting -------------------------------------------------------------

#' Report what an object cost, so a page can show a reduction rather than
#' claim one.
wq_size <- function(x, label) {
  cat(sprintf(
    "%-34s %12s rows x %2d cols  %7.1f MB\n",
    label, format(nrow(x), big.mark = ","), ncol(x),
    as.numeric(utils::object.size(x)) / 2^20
  ))
  invisible(x)
}

#' Decode a base64 WKB column into an sf geometry column.
#'
#' The two-step shape is forced by the transport route: geometry is encoded
#' server-side to survive the trip, so it arrives as text and has to be decoded
#' before sf will look at it. crs must be supplied, because WKB carries no SRID.
wq_decode_wkb <- function(b64, crs = 27700) {
  sf::st_as_sfc(
    structure(lapply(b64, jsonlite::base64_dec), class = "WKB"),
    EWKB = FALSE, crs = crs
  )
}

# --- the cluster gate ------------------------------------------------------

# Cluster-backed chunks are gated on an environment variable rather than left
# to freeze alone. Freeze re-executes a document whose source has changed, so
# editing a sentence on a cluster page would otherwise start a cluster and
# bill until it auto-terminates. Running those sections has to be deliberate:
#
#   WQ_RUN_CLUSTER=true quarto render example/bootstrap.qmd
#
# With the variable unset those chunks are shown and not run, and the page says
# so, which is also what happens for a reader who has no cluster of her own.
#
# The gate belongs part-way down a page, not in its header. Setting it at the
# top switches off the page's local chunks too, and the local run is the part
# the example most wants to show working. Only the sections that genuinely need
# workers sit below it.
wq_cluster_enabled <- function() {
  isTRUE(tolower(Sys.getenv("WQ_RUN_CLUSTER")) %in% c("true", "1", "yes"))
}

#' A callout explaining why the cluster chunks below did not run.
wq_cluster_notice <- function() {
  if (wq_cluster_enabled()) return(invisible(NULL))
  cat(":::: {.callout-note appearance=\"simple\"}\n",
      "**The code from here on is shown but was not run.** It needs a ",
      "multi-node cluster, which costs time to start and bills while it runs, ",
      "so it is not executed as part of an ordinary render. Everything above ",
      "this point ran normally. The outputs quoted in the prose below come ",
      "from a deliberate run, recorded on the date given.\n",
      "::::\n", sep = "")
}
