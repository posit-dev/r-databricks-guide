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

# The compute targets. Sourced rather than assumed: wq_connect_odbc() below
# calls dbx_http_path(), and a page that sources only this file would otherwise
# fail with "object not found" at connection time rather than here.
if (!exists("dbx_http_path")) source("dbx-config.R")

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
wq_name <- function(table) glue::glue("{wq_catalog()}.{wq_schema()}.{table}")

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

#' Mask everything that identifies this workspace, not just the catalog.
#'
#' wq_mask() handles the catalog and nothing else, which is right for the
#' worked example: its chunks print table names and little else. Output that
#' came back from *compute* is a different problem. A worker's hostname embeds
#' the cluster id, and a Workbench session name embeds a person's name, so
#' pasting a raw `Sys.info()[["nodename"]]` into a page fails
#' scripts/check-public.sh. That has happened, on howdoi/interactive.qmd,
#' and it was caught by the check rather than by review.
#'
#' Use this on anything captured from a cluster, a REST call or a session,
#' before it goes anywhere near a page.
wq_mask_all <- function(x) {
  x <- wq_mask(x)
  x <- gsub("[0-9]{4}-[0-9]{6}-[a-z0-9]{8,}", "<cluster-id>", x)
  x <- gsub("session-[a-z0-9]+-[a-z0-9-]+", "<my-session>", x)
  # A cluster's *display name* is not its id and is not caught by the pattern
  # above. sparklyr prints it on connect ("Connecting to '<name>'"), and these
  # are conventionally named after their owner, so it is a personal identifier
  # reaching a public page. Read the real name from the API rather than
  # hard-coding it: this file is published too.
  cluster_name <- tryCatch(
    brickster::db_cluster_get(
      cluster_id = Sys.getenv("DATABRICKS_CLUSTER_ID")
    )$cluster_name,
    error = function(e) ""
  )
  if (nzchar(cluster_name)) {
    x <- gsub(cluster_name, "<cluster-name>", x, fixed = TRUE)
  }
  host <- Sys.getenv("DATABRICKS_HOST")
  if (nzchar(host)) x <- gsub(host, "<host>", x, fixed = TRUE)
  x
}

#' Mask every identifier out of a page's printed output.
#'
#' Call once, in a hidden chunk, near the top of any page whose chunks print
#' anything that came back from Databricks:
#'
#'     wq_mask_output()
#'
#' Why a hook on output rather than a safer version of some function. The
#' catalog escapes by more than one route, and they have nothing in common
#' except that they all end up as printed text:
#'
#'   - printing a `dbplyr::in_catalog()` object, which stores the catalog
#'   - `show_query()`, which builds it into the SQL
#'   - any server error that names the table it could not find
#'
#' Wrapping a function catches the first and misses the other two, while
#' looking like it handled the category. Masking the output catches all three,
#' because that is where they converge.
#'
#' All four streams are hooked, not just stdout: an ODBC error quotes the fully
#' qualified name, so an unmasked error block leaks exactly what the page was
#' careful not to print.
#'
#' assets/redact.lua does the same job at pandoc time. It is a second layer
#' rather than a replacement, because it runs after the freeze cache is
#' written and `_freeze/` is tracked and published. This hook is what keeps
#' the committed cache clean.
wq_mask_output <- function() {
  mask_hook <- function(x, options) paste0("```\n", wq_mask_all(x), "```\n")
  knitr::knit_hooks$set(
    output = mask_hook,
    error = mask_hook,
    warning = mask_hook,
    message = mask_hook
  )
  invisible(TRUE)
}

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
  cli::cli_alert_info(
    "{label}: {format(nrow(x), big.mark = ',')} rows x {ncol(x)} cols, \\
     {round(as.numeric(utils::object.size(x)) / 2^20, 1)} MB"
  )
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

# --- how many cores you may actually use ------------------------------------

# detectCores() reads the MACHINE, not your share of it. Under a container it
# reports the host's cores while cgroup quota caps what you may actually run,
# and forking past the quota is how you get an OOM kill rather than a slowdown:
# each worker is a real process, and anything it allocates itself (an sf
# spatial index, say) is not shared by copy-on-write.
#
# This matters on the driver too. A Databricks driver is a container with a
# quota, so the same overcommit happens there, and the symptom is a session
# that dies rather than an error a reader can act on.
#
# cgroup v2 states the quota in cpu.max as "<quota> <period>"; v1 splits it
# across two files. "max" means unlimited, in which case detectCores() is the
# honest answer.
wq_cpu_quota <- function() {
  v2 <- "/sys/fs/cgroup/cpu.max"
  if (file.exists(v2)) {
    parts <- strsplit(readLines(v2, warn = FALSE)[1], "\\s+")[[1]]
    if (identical(parts[1], "max")) return(NA_integer_)
    return(as.integer(floor(as.numeric(parts[1]) / as.numeric(parts[2]))))
  }
  q <- "/sys/fs/cgroup/cpu/cpu.cfs_quota_us"
  p <- "/sys/fs/cgroup/cpu/cpu.cfs_period_us"
  if (file.exists(q) && file.exists(p)) {
    quota <- as.numeric(readLines(q, warn = FALSE)[1])
    if (quota <= 0) return(NA_integer_)
    return(as.integer(floor(quota / as.numeric(readLines(p, warn = FALSE)[1]))))
  }
  NA_integer_
}

#' Cores it is safe to fork onto: the quota if there is one, else the machine.
#'
#' `reserve` leaves a core for the parent process. Pass reserve = 0 when the
#' parent only waits, and note that on a 2-core quota reserving one leaves one,
#' which is serial and correct rather than a failure.
wq_cores <- function(reserve = 1L) {
  quota <- wq_cpu_quota()
  n <- if (is.na(quota)) parallel::detectCores() else min(quota, parallel::detectCores())
  max(1L, as.integer(n) - reserve)
}
