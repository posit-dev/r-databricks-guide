#!/usr/bin/env Rscript
# Stage the sample files that howdoi/volume-files.qmd executes against.
#
#   scripts/stage-sample-files.R           # create anything missing
#   scripts/stage-sample-files.R --status  # report what is there, write nothing
#   scripts/stage-sample-files.R --force   # rewrite even if it is already there
#
# Why this exists. That page shows a CSV and a four-part shapefile being read
# out of a volume, and CLAUDE.md forbids pasted output, so the files have to be
# really there or the page cannot re-render. They are derived rather than
# downloaded: the first 200 rows of hydrology_stations, which the volume already
# holds, so this needs no network beyond the workspace and no second licence.
#
# It is idempotent, like scripts/start-cluster.R, so it is safe to run before a
# render without checking first.
#
# It deliberately never creates a volume. CREATE VOLUME is commonly held by IT
# alone, which is a constraint the guide is built around, so this script writes
# only inside a volume that already exists and says so plainly if it does not.

suppressPackageStartupMessages({
  library(DBI)
  library(dplyr)
  library(dbplyr)
  library(readr)
  library(sf)
  library(brickster)
  library(purrr)
  library(glue)
  library(cli)
})

args <- commandArgs(trailingOnly = TRUE)
status_only <- "--status" %in% args
force <- "--force" %in% args

catalog <- Sys.getenv("DATABRICKS_CATALOG")
schema <- Sys.getenv("DATABRICKS_SCHEMA")

if (!nzchar(catalog) || !nzchar(schema)) {
  cli_abort(c(
    "{.envvar DATABRICKS_CATALOG} and {.envvar DATABRICKS_SCHEMA} must both
     be set.",
    i = "Copy {.file .Renviron.example} to {.file .Renviron}, fill in your own
         values, and restart R so they are read.",
    x = "There is deliberately no default: a literal catalog name must never
         reach this repository."
  ))
}

# The volume and the directory the page reads from. `sample` is the page's
# staging area; everything else under `raw` belongs to the worked example.
volume <- "raw"
volume_root <- glue("/Volumes/{catalog}/{schema}/{volume}")
sample_dir <- glue("{volume_root}/sample")
shape_dir <- glue("{sample_dir}/stations_shp")

# What the page reads. The Parquet example reuses the worked example's own
# hydrology_stations/data.parquet, so it is checked but never written here.
shape_parts <- c("shp", "shx", "dbf", "prj")

listing <- function(path) {
  found <- tryCatch(
    db_volume_list(path)$contents,
    error = function(e) NULL
  )
  if (is.null(found)) character() else map_chr(found, \(item) basename(item$path))
}

report <- function() {
  top <- listing(sample_dir)
  parts <- listing(shape_dir)

  cli_alert_info("Volume {.path {volume}}, directory {.path {basename(sample_dir)}}:")

  if ("stations.csv" %in% top) {
    cli_alert_success("stations.csv")
  } else {
    cli_alert_danger("stations.csv is missing")
  }

  missing_parts <- setdiff(glue("stations.{shape_parts}"), parts)
  if (length(missing_parts) == 0) {
    cli_alert_success("stations_shp/ has all four parts")
  } else {
    cli_alert_danger("stations_shp/ is missing {.file {missing_parts}}")
  }

  invisible(list(csv = "stations.csv" %in% top, parts = missing_parts))
}

# A missing volume is not something this script can fix, so say so rather than
# failing later inside a write.
if (!volume %in% map_chr(db_uc_volumes_list(catalog, schema)$volumes, \(v) v$name)) {
  cli_abort(c(
    "Volume {.path {volume}} does not exist in this schema.",
    i = "Create it, or ask whoever administers the workspace to.",
    x = "This script will not create a volume: {.code CREATE VOLUME} is
         commonly held by IT alone, which is the constraint the guide is
         written around."
  ))
}

state <- report()

if (status_only) {
  quit(status = 0)
}

if (state$csv && length(state$parts) == 0 && !force) {
  cli_alert_success("Everything the page needs is already staged. Nothing to do.")
  cli_alert_info("Re-stage anyway with {.code --force}.")
  quit(status = 0)
}

# Source rows. Taken from the table rather than a local .rds so the staged files
# always match what the site's own tables hold, and kept small because the page
# is demonstrating transport rather than volume.
cli_alert_info("Reading source rows from {.path hydrology_stations}.")

con <- dbConnect(
  odbc::databricks(),
  httpPath = Sys.getenv("DATABRICKS_PATH"),
  DefaultStringColumnLength = 65535
)
on.exit(dbDisconnect(con), add = TRUE)

stations <- tbl(con, in_catalog(catalog, schema, "hydrology_stations")) |>
  select(
    station_id, station_name, easting, northing, river_name,
    catchment_area_km2, date_opened, status
  ) |>
  filter(!is.na(easting), !is.na(northing)) |>
  head(200) |>
  collect()

cli_alert_success("{nrow(stations)} stations.")

invisible(db_volume_dir_create(sample_dir))

# The CSV. Written with readr so the file the page reads is the file readr
# writes, which is what the page's read_csv() call then has to parse.
local_csv <- file.path(tempdir(), "stations.csv")
write_csv(stations, local_csv)
invisible(
  db_volume_write(glue("{sample_dir}/stations.csv"), file = local_csv, overwrite = TRUE)
)
cli_alert_success("stations.csv")

# The shapefile. EPSG:27700 is the reader's own grid and the CRS the site's
# hydrology data arrives in, and it is what the page's .prj demonstration turns
# on: without the .prj, st_read() succeeds and st_crs() is NA.
local_shape <- file.path(tempdir(), "stations_shp")
if (dir.exists(local_shape)) unlink(local_shape, recursive = TRUE)
dir.create(local_shape)

# st_write() abbreviates any field name over ten characters, which is a
# shapefile format limit rather than a fault, so the warning is suppressed
# deliberately. The page reads geometry and feature count, not these names.
withCallingHandlers(
  stations |>
    st_as_sf(coords = c("easting", "northing"), crs = 27700) |>
    select(station_id, station_name, river_name) |>
    st_write(file.path(local_shape, "stations.shp"), quiet = TRUE),
  warning = function(w) {
    if (grepl("abbreviated", conditionMessage(w))) invokeRestart("muffleWarning")
  }
)

written <- list.files(local_shape)
if (!all(glue("stations.{shape_parts}") %in% written)) {
  cli_abort(c(
    "{.fn st_write} produced {.file {written}}.",
    x = "The page needs all four of {.file {glue('stations.{shape_parts}')}}:
         a missing {.file .prj} is the trap it demonstrates, so it has to be
         there to be left out on purpose."
  ))
}

invisible(db_volume_upload_dir(local_shape, shape_dir))
cli_alert_success("stations_shp/ with {length(written)} parts.")

# The Parquet the page reads belongs to the worked example, so it is verified
# rather than written. If ingest has never run, the page's Parquet chunk fails.
parquet_path <- glue("{volume_root}/hydrology_stations/data.parquet")
if (length(listing(glue("{volume_root}/hydrology_stations"))) == 0) {
  cli_alert_warning(
    "{.path {basename(parquet_path)}} is absent, and the page's Parquet chunk
     reads it. It comes from the worked example's load, not from here."
  )
}

report()
cli_alert_info("Now re-render the page: {.code scripts/rerender.sh howdoi/volume-files.qmd}")
