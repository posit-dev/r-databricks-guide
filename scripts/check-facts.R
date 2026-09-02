#!/usr/bin/env Rscript
# Report on the fact table: what is stale, what is orphaned, what has drifted.
#
#   scripts/check-facts.R
#
# Reports only. Updating a value is a deliberate act, because it means
# re-dating the entry and re-rendering every page in its used_by list, and that
# is a decision with a cost attached rather than a formality.
#
# What it reports, from process/DESIGN-fact-table.md:
#
#   stale       volatile entries older than the threshold
#   orphaned    keys no page quotes
#   undeclared  a page quoting a key that its used_by does not list, or a
#               used_by naming a page that no longer quotes it
#   literal     a migrated number still typed into prose somewhere
#   approx      deliberately vague spellings, reported and never failed
#
# "undeclared" is what keeps used_by trustworthy, and it is checked in both
# directions rather than believed. "literal" is the one that earns its keep
# day to day: it found a 4,080 a manual sweep had missed.

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
  declared <- wq_or_else(facts[[key]]$used_by, character(0))
  actual <- wq_or_else(quoted_by[[key]], character(0))

  missing <- setdiff(actual, declared)
  for (page in missing) {
    drift <- c(drift, glue("{key}: quoted by {page}, not in used_by"))
  }
}

# The other direction is only checkable once a key is in use anywhere. Before
# migration a used_by list is a plan rather than a claim, so an unquoted page
# on an entirely unquoted key is not drift.
for (key in names(quoted_by)) {
  declared <- wq_or_else(facts[[key]]$used_by, character(0))
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

  for (page in union(quoted_by[[key]], wq_or_else(entry$used_by, character(0)))) {
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

# --- approximations, reported rather than enforced -------------------------

# A deliberately vague spelling stays literal prose, so this is not a failure.
# It is reported because re-measuring a value means someone has to read these
# sentences and decide whether they still hold, and nothing else would say so.
approx <- character(0)
for (key in names(facts)) {
  for (spelling in wq_or_else(facts[[key]]$approx, character(0))) {
    for (page in qmd) {
      lines <- readLines(page, warn = FALSE)
      for (i in grep(spelling, lines, fixed = TRUE)) {
        approx <- c(approx, glue("{page}:{i} says {spelling} for {key}"))
      }
    }
  }
}

if (length(approx)) {
  cli_text()
  cli_alert_info("Deliberate approximations, which stay prose and need a human eye if re-measured:")
  cli_ul(approx)
}

# --- nobody else may define %||% -------------------------------------------

# dbx-config.R owns `%||%` and gives it non-standard semantics: "" counts as
# absent, and dbx_cluster_id() relies on that to fall through to config.yml.
# A second definition anywhere silently replaces it, wherever it is sourced
# later. The damage is asymmetric and therefore easy to miss: `default` keeps
# working while DATABRICKS_CLUSTER_ID is set, and only the "multinode" profile
# breaks, surfacing far away as "Cluster id cannot be empty" from the SDK.
#
# This repo hit exactly that when R/facts.R was added, and the guard is here
# rather than in a comment because of how narrow the reachable failure is.
# "multinode" has one call site, example/bootstrap.qmd, inside a section gated
# on WQ_RUN_CLUSTER, on a page that is freeze: true and so does not re-execute
# on an ordinary render. The only way to reach it is a credentialed cluster
# re-render, which needs a roughly seven-minute cold start. Nothing cheaper
# fails, so a comment would be read only after paying that cost twice.
# One definition is the invariant; anything else is the bug.
r_files <- c(
  list.files(".", pattern = "[.](R|qmd)$", recursive = TRUE)
)
r_files <- r_files[!grepl("^(_freeze|_site|renv)/", r_files)]

definers <- character(0)
for (f in r_files) {
  lines <- readLines(f, warn = FALSE)
  hits <- grep("^\\s*`%\\|\\|%`\\s*<-", lines)
  for (i in hits) definers <- c(definers, glue("{f}:{i}"))
}

if (length(definers) > 1) {
  cli_text()
  cli_alert_danger("More than one file defines {.code `%||%`}:")
  cli_ul(definers)
  cli_alert_info("dbx-config.R must be the only one; see the note in R/facts.R.")
  fail <- TRUE
} else {
  cli_alert_success("Only {.file dbx-config.R} defines {.code `%||%`}.")
}

# --- rests-on.yml matches the pages that exist -----------------------------
#
# The claims moved out of the pages on 2026-09-02, so nothing on a page points
# at its own entry any more. Two ways that drifts: a page is added and never
# gets an entry, or a page is renamed and its entry is orphaned. Neither is
# visible when reading either file alone.

rests_path <- here::here("facts", "rests-on.yml")
if (file.exists(rests_path)) {
  rests <- yaml::read_yaml(rests_path)
  # The render list is globs ("howdoi/*.qmd"), so expand rather than match.
  patterns <- yaml::read_yaml(here::here("_quarto.yml"))$project$render
  rendered <- unlist(lapply(patterns, \(g) {
    hits <- Sys.glob(here::here(g))
    sub(paste0("^", here::here(), "/"), "", hits)
  }))
  rendered <- rendered[grepl("\\.qmd$", rendered)]

  orphans <- setdiff(names(rests), rendered)
  if (length(orphans)) {
    cli_text()
    cli_alert_danger("{.file facts/rests-on.yml} names {length(orphans)} page{?s} that {?is/are} not rendered:")
    cli_ul(orphans)
    fail <- TRUE
  } else {
    cli_alert_success("Every {.file facts/rests-on.yml} entry names a rendered page.")
  }

  empty <- names(rests)[vapply(rests, \(x) length(x$claims) == 0, logical(1))]
  if (length(empty)) {
    cli_text()
    cli_alert_danger("Entries with no claims (delete them rather than leaving them empty):")
    cli_ul(empty)
    fail <- TRUE
  }

  leaked <- character()
  for (page in rendered) {
    if (!file.exists(here::here(page))) next
    # Anchored: the footer always began a line. "It rests on one worked
    # comparison" mid-sentence is ordinary prose and must not trip this.
    if (any(grepl("^This page rests on", readLines(here::here(page), warn = FALSE)))) {
      leaked <- c(leaked, page)
    }
  }
  if (length(leaked)) {
    cli_text()
    cli_alert_danger("{length(leaked)} page{?s} still carr{?ies/y} a {.code rests on} line in prose:")
    cli_ul(leaked)
    cli_alert_info("Claims belong in facts/rests-on.yml, not on the page.")
    fail <- TRUE
  } else {
    cli_alert_success("No page carries a {.code rests on} line.")
  }
}

# --- summary ---------------------------------------------------------------

cli_text()
cli_alert_info(
  "{length(facts)} fact{?s} in the table, {length(quoted_by)} quoted by {length(calls)} page{?s}."
)

if (fail) {
  cli_alert_danger("Fix the above. Where a fact has genuinely changed, update
                    facts/measurements.yml and re-render its used_by pages.")
  quit(status = 1)
}
quit(status = 0)
