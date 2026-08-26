#!/usr/bin/env Rscript
# Report on the fact table: what is stale, what is orphaned, what has drifted.
#
#   scripts/check-facts.R
#
# Reports only. Updating a value is a deliberate act, because it means
# re-dating the entry and re-rendering every page in its used_by list, and that
# is a decision with a cost attached rather than a formality.
#
# Three questions, from process/DESIGN-fact-table.md:
#
#   stale       volatile entries older than the threshold
#   orphaned    keys no page quotes
#   undeclared  a page quoting a key that its used_by does not list, or a
#               used_by naming a page that no longer quotes it
#
# The last is the one that keeps used_by trustworthy, and it is checked in both
# directions rather than believed.

suppressPackageStartupMessages({
  library(cli)
  library(glue)
})

# Run from anywhere: walk up until the fact table is in sight.
root <- getwd()
while (!file.exists(file.path(root, "facts", "measurements.yml")) &&
       dirname(root) != root) {
  root <- dirname(root)
}
if (!file.exists(file.path(root, "facts", "measurements.yml"))) {
  stop("Cannot find facts/measurements.yml above ", getwd(), call. = FALSE)
}
setwd(root)

source("R/facts.R")

STALE_DAYS <- 90

facts <- wq_facts()
fail <- FALSE

# --- every page that calls wq_fact(), and the keys it asks for --------------

qmd <- list.files(".", pattern = "[.]qmd$", recursive = TRUE)
qmd <- qmd[!grepl("^(_freeze|_site|renv)/", qmd)]

calls <- list()
for (page in qmd) {
  text <- paste(readLines(page, warn = FALSE), collapse = "\n")
  keys <- regmatches(text, gregexpr('wq_fact\\(\\s*"[^"]+"', text))[[1]]
  keys <- unique(sub('.*"([^"]+)"', "\\1", keys))
  if (length(keys)) calls[[page]] <- keys
}

quoted_by <- list()
for (page in names(calls)) {
  for (key in calls[[page]]) {
    quoted_by[[key]] <- c(quoted_by[[key]], page)
  }
}

# --- stale -----------------------------------------------------------------

today <- Sys.Date()
stale <- character(0)
for (key in names(facts)) {
  entry <- facts[[key]]
  if (!isTRUE(entry$volatile)) next
  age <- as.numeric(today - as.Date(entry$measured))
  if (age > STALE_DAYS) {
    stale <- c(stale, glue("{key}: measured {entry$measured}, {round(age)} days ago"))
  }
}

if (length(stale)) {
  cli_alert_warning("Volatile facts older than {STALE_DAYS} days:")
  cli_ul(stale)
  cli_text()
} else {
  cli_alert_success("No volatile fact is older than {STALE_DAYS} days.")
}

# --- orphaned --------------------------------------------------------------

orphans <- setdiff(names(facts), names(quoted_by))
# A key with an empty used_by is a deliberate placeholder, not an orphan.
orphans <- orphans[vapply(orphans, function(k) length(facts[[k]]$used_by) > 0, logical(1))]

if (length(orphans)) {
  cli_alert_warning("Facts no page quotes, though {.field used_by} says otherwise:")
  cli_ul(orphans)
  cli_text()
} else {
  cli_alert_success("Every fact with a {.field used_by} list is quoted somewhere.")
}

# --- undeclared, in both directions ----------------------------------------

drift <- character(0)
for (key in names(facts)) {
  declared <- facts[[key]]$used_by %||% character(0)
  actual <- quoted_by[[key]] %||% character(0)

  missing <- setdiff(actual, declared)
  for (page in missing) {
    drift <- c(drift, glue("{key}: quoted by {page}, not in used_by"))
  }
}

# The other direction is only checkable once a key is in use anywhere. Before
# migration a used_by list is a plan rather than a claim, so an unquoted page
# on an entirely unquoted key is not drift.
for (key in names(quoted_by)) {
  declared <- facts[[key]]$used_by %||% character(0)
  actual <- quoted_by[[key]]
  for (page in setdiff(declared, actual)) {
    drift <- c(drift, glue("{key}: used_by lists {page}, which does not quote it"))
  }
}

if (length(drift)) {
  cli_alert_danger("The {.field used_by} lists have drifted from the pages:")
  cli_ul(drift)
  cli_text()
  fail <- TRUE
} else {
  cli_alert_success("Every {.field used_by} list matches the pages that quote it.")
}

# --- prose still carrying a migrated number literally ----------------------

# Once a key is quoted with wq_fact(), the same number typed literally into
# prose is the drift this whole mechanism exists to prevent: two spellings of
# one fact with only one of them owned.
literal <- character(0)
for (key in names(quoted_by)) {
  entry <- facts[[key]]
  spellings <- c(
    format(entry$value, big.mark = ",", scientific = FALSE, trim = TRUE),
    entry$round
  )
  spellings <- spellings[!is.na(spellings) & nzchar(spellings)]

  for (page in union(quoted_by[[key]], entry$used_by %||% character(0))) {
    if (!file.exists(page)) next
    lines <- readLines(page, warn = FALSE)
    # Strip the inline calls themselves before looking for literals.
    lines <- gsub('`r wq_fact\\([^`]*\\)`', "", lines)
    for (spelling in spellings) {
      hit <- grep(spelling, lines, fixed = TRUE)
      for (i in hit) {
        literal <- c(literal, glue("{page}:{i} still types {spelling} for {key}"))
      }
    }
  }
}

if (length(literal)) {
  cli_alert_danger("A migrated fact is still typed literally:")
  cli_ul(literal)
  cli_text()
  fail <- TRUE
} else if (length(quoted_by)) {
  cli_alert_success("No migrated fact is still typed literally.")
}

# --- summary ---------------------------------------------------------------

cli_text()
cli_alert_info(
  "{length(facts)} fact{?s} in the table, {length(quoted_by)} quoted by {length(calls)} page{?s}."
)

if (fail) {
  cli_alert_danger("Fix the above, or update facts/measurements.yml to match.")
  quit(status = 1)
}
quit(status = 0)
