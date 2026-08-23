#!/usr/bin/env Rscript
# Reading native GEOMETRY / GEOGRAPHY out of Databricks and into sf.
#
#   Rscript geometry-to-sf.R
#
# Native geometry arrives as an EWKT *string* with the SRID prefixed onto the
# value: "SRID=4326;POINT(1 2)". That is not what sf::st_as_sfc() accepts, so the
# conversion is two steps: split the prefix off, then supply it as the CRS.
#
# This is a different path from geometry stored as WKB in a BINARY column, which
# needs the brickster DBI backend to survive the trip intact. Use this one where
# the table uses the native type.
#
# Verified 2026-08-23 on a Pro SQL warehouse (serverless, DBSQL 2026.20).
# WARNING: built-in spatial functions are documented as unavailable on SQL
# Classic warehouses. The script checks, because the failure is otherwise an
# unknown-function error that looks like a typo.
#
# Requires DATABRICKS_WAREHOUSE_ID. Credentials are ambient on Posit Workbench.

library(brickster)
library(DBI)

warehouse_id <- Sys.getenv("DATABRICKS_WAREHOUSE_ID")
if (!nzchar(warehouse_id)) {
  stop("Set DATABRICKS_WAREHOUSE_ID to the warehouse you want to query.", call. = FALSE)
}

# Check the warehouse type first. On Classic, everything below fails with an
# unknown-function error that says nothing about the warehouse.
wh <- db_sql_warehouse_get(id = warehouse_id)
cat("warehouse type :", wh$warehouse_type, "\n")
cat("serverless     :", isTRUE(wh$enable_serverless_compute), "\n")
if (!identical(wh$warehouse_type, "PRO")) {
  warning(
    "Spatial functions are documented as unavailable on SQL Classic warehouses. ",
    "If the queries below fail with an unknown function, this is why.",
    call. = FALSE
  )
}

con <- dbConnect(DatabricksSQL(), warehouse_id = warehouse_id)
on.exit(dbDisconnect(con), add = TRUE)

# How many spatial functions does this warehouse actually have? Counted rather
# than taken from documentation, which understates it.
fns <- dbGetQuery(con, "SHOW FUNCTIONS LIKE 'st_*'")
cat("ST_ functions  :", nrow(fns), "\n\n")

# What a native GEOMETRY column looks like on arrival.
geo <- dbGetQuery(con, "
  SELECT st_geomfromtext('POLYGON((0 0,1 0,1 1,0 1,0 0))', 27700) AS g
")
cat("R class        :", class(geo$g), "\n")
cat("value          :", geo$g, "\n\n")

# The two-step conversion. The SRID is a prefix on the value, so it does not need
# a separate st_srid() call, though the result metadata carries it too.
ewkt_to_sfc <- function(x) {
  srid <- as.integer(sub("^SRID=([0-9]+);.*$", "\\1", x))
  bare <- sub("^SRID=[0-9]+;", "", x)
  sf::st_as_sfc(bare, crs = unique(srid))
}

sfc <- ewkt_to_sfc(geo$g)
cat("parsed to sf   :", class(sfc)[1], "\n")
cat("crs            :", sf::st_crs(sfc)$epsg, "\n")
cat("area           :", as.numeric(sf::st_area(sfc)), "\n\n")

# The text form is not lossy: it round-trips at full double precision.
prec <- dbGetQuery(con, "
  SELECT st_geomfromtext('POINT(1.2345678901234567 2.9876543210987654)', 4326) AS g
")
cat("precision check:", prec$g, "\n")

cat("\nGEOGRAPHY behaves identically, but st_geogfromtext() takes ONE argument,\n")
cat("not two: passing an SRID raises WRONG_NUM_ARGS.\n")
