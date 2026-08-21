# check-databricks-access.R --------------------------------------------------
# Minimal smoke test: can this session reach Databricks and read your tables?
# Run it before anything else, and before blaming a document that will not render.
#
#   Rscript check-databricks-access.R
#
# Needs only odbc + DBI. There is no token in this file: on Posit Workbench the
# Databricks credentials are ambient, injected when you sign in.

HTTP_PATH <- Sys.getenv("DATABRICKS_PATH")
CATALOG   <- Sys.getenv("DATABRICKS_CATALOG")
SCHEMA    <- Sys.getenv("DATABRICKS_SCHEMA", "default")

# Both are required. There is deliberately no fallback: a default warehouse ID
# would point every reader at whichever workspace happened to write this file.
missing <- c(
  if (!nzchar(HTTP_PATH)) "DATABRICKS_PATH",
  if (!nzchar(CATALOG))   "DATABRICKS_CATALOG"
)
if (length(missing)) {
  stop(
    "Unset: ", paste(missing, collapse = ", "), ".\n",
    "  Copy .Renviron.example to .Renviron, fill in your own values, and\n",
    "  restart R so they are read.",
    call. = FALSE
  )
}

mask <- function(x) if (nzchar(x)) paste0(substr(x, 1, 24), if (nchar(x) > 24) "…" else "") else "<unset>"

cat("== 1. environment ==\n")
for (v in c("DATABRICKS_HOST", "DATABRICKS_CONFIG_FILE", "DATABRICKS_CONFIG_PROFILE",
            "DATABRICKS_PATH", "DATABRICKS_CATALOG", "DATABRICKS_SCHEMA")) {
  cat(sprintf("  %-26s %s\n", v, mask(Sys.getenv(v))))
}
cat(sprintf("  %-26s %s\n", "odbc", as.character(packageVersion("odbc"))))

drv <- unique(odbc::odbcListDrivers()$name)
cat("  ODBC drivers:              ", paste(drv, collapse = ", "), "\n")
if (!any(grepl("databricks|spark", drv, ignore.case = TRUE))) {
  cat("  !! No Databricks/Spark ODBC driver visible - install the Simba driver.\n")
}

# All three unset usually means "not signed in yet" rather than "broken". Inside
# Workbench the CLI OAuth path is skipped, so `databricks auth login` will not
# rescue it: sign in to the session instead.
if (!nzchar(Sys.getenv("DATABRICKS_HOST"))) {
  cat("  !! DATABRICKS_HOST unset. Sign in to Databricks in this session,\n",
      "     or set DATABRICKS_HOST and DATABRICKS_TOKEN manually.\n", sep = "")
}

cat("\n== 2. connect to the SQL warehouse ==\n")
cat("  httpPath:", HTTP_PATH, "\n")
t0 <- Sys.time()
con <- DBI::dbConnect(odbc::databricks(), httpPath = HTTP_PATH)
cat(sprintf("  connected in %.2f s\n", as.numeric(difftime(Sys.time(), t0, units = "secs"))))

cat("\n== 3. who am I ==\n")
print(DBI::dbGetQuery(con, "SELECT current_user() AS user"))

cat("\n== 4. tables visible in your schema ==\n")
print(DBI::dbGetQuery(con, sprintf("SHOW TABLES IN %s.%s", CATALOG, SCHEMA)))

cat("\n== 5. dbplyr round trip ==\n")
# Reads whichever table SHOW TABLES listed first, so this works against any
# schema rather than assuming a particular set of tables exists.
tables <- DBI::dbGetQuery(con, sprintf("SHOW TABLES IN %s.%s", CATALOG, SCHEMA))
if (nrow(tables)) {
  suppressPackageStartupMessages({library(dplyr); library(dbplyr)})
  first <- tables$tableName[1]
  cat("  counting rows in", first, "\n")
  tbl(con, in_catalog(CATALOG, SCHEMA, first)) |>
    count() |>
    collect() |>
    print()
} else {
  cat("  no tables in", paste(CATALOG, SCHEMA, sep = "."), "- nothing to round-trip\n")
}

DBI::dbDisconnect(con)
cat("\nAll checks passed.\n")
