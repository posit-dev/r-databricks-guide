# One source of truth for measured numbers quoted in prose.
#
#   source("R/facts.R")
#   wq_fact("readings_rows")            # 32,540,721
#   wq_fact("readings_rows", "round")   # 32.5 million
#
# A number typed into prose has no owner and no expiry: nothing links it to the
# measurement that produced it, and nothing knows which other pages would be
# wrong if it changed. facts/measurements.yml owns them instead, and this file
# is how a page quotes one. See process/DESIGN-fact-table.md.
#
# Reads a local file and touches no network, so a page using it needs R at
# render time but not credentials.

# Cached because a page can call wq_fact() a dozen times in one render, and
# re-reading the file each time would be pointless work. Set to NULL to force a
# re-read after editing the YAML in a live session.
.wq_facts <- NULL

#' Every fact, as a named list. Reads the file once per session.
wq_facts <- function(path = NULL) {
  default <- is.null(path)
  if (!is.null(.wq_facts) && default) {
    return(.wq_facts)
  }
  path <- path %||% wq_facts_path()
  if (!file.exists(path)) {
    cli::cli_abort(c(
      "No fact table at {.path {path}}.",
      i = "Expected {.path facts/measurements.yml} at the repository root."
    ))
  }
  facts <- yaml::read_yaml(path)
  if (default) .wq_facts <<- facts
  facts
}

# here::here() so a page renders the same from the project root or its own
# directory, which Quarto does not guarantee.
wq_facts_path <- function() {
  if (requireNamespace("here", quietly = TRUE)) {
    here::here("facts", "measurements.yml")
  } else {
    "facts/measurements.yml"
  }
}

`%||%` <- function(x, y) if (is.null(x)) y else x

#' A measured number, formatted for the sentence it sits in.
#'
#' @param key    a key in facts/measurements.yml
#' @param format "digits" gives 32,540,721; "words" gives Ninety-seven,
#'   capitalised to open a sentence; "round" gives the entry's own rounded
#'   spelling; "value" gives the bare number, for arithmetic.
wq_fact <- function(key, format = c("digits", "words", "round", "value")) {
  format <- match.arg(format)
  facts <- wq_facts()

  # A typo in a key must never reach a published page as an NA, so this is the
  # one thing in the file that aborts rather than degrades.
  if (!key %in% names(facts)) {
    near <- names(facts)[utils::adist(key, names(facts)) <= 5]
    cli::cli_abort(c(
      "No fact named {.val {key}} in the fact table.",
      i = if (length(near)) "Did you mean {.val {near}}?" else
        "Known keys: {.val {names(facts)}}."
    ))
  }

  entry <- facts[[key]]
  value <- entry$value

  switch(format,
    value = value,
    digits = format(value, big.mark = ",", scientific = FALSE, trim = TRUE),
    round = {
      if (is.null(entry$round)) {
        cli::cli_abort(c(
          "{.val {key}} has no {.field round} spelling.",
          i = "Add a {.field round:} field to the entry, or use another format.",
          i = "Where to round is an editorial choice, so it is not computed."
        ))
      }
      entry$round
    },
    words = wq_number_words(value)
  )
}

# Capitalised, because the only reason to spell a number is that it opens a
# sentence. Beyond a hundred, digits are what prose uses anyway, so this
# deliberately covers only the range where the question arises.
wq_number_words <- function(n) {
  if (n != round(n) || n < 0 || n > 100) {
    cli::cli_abort(c(
      "Cannot spell {.val {n}} as words.",
      i = "Only whole numbers from zero to one hundred are spelled out.",
      i = "Use {.code format = \"digits\"} instead."
    ))
  }

  ones <- c(
    "Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight",
    "Nine", "Ten", "Eleven", "Twelve", "Thirteen", "Fourteen", "Fifteen",
    "Sixteen", "Seventeen", "Eighteen", "Nineteen"
  )
  tens <- c(
    "Twenty", "Thirty", "Forty", "Fifty", "Sixty", "Seventy", "Eighty", "Ninety"
  )

  if (n == 100) return("One hundred")
  if (n < 20) return(ones[[n + 1]])

  unit <- n %% 10
  ten <- tens[[n %/% 10 - 1]]
  if (unit == 0) ten else glue::glue("{ten}-{tolower(ones[[unit + 1]])}")
}

#' Every page that quotes a given key, from the entry's used_by list.
wq_fact_pages <- function(key) {
  facts <- wq_facts()
  if (!key %in% names(facts)) {
    cli::cli_abort("No fact named {.val {key}} in the fact table.")
  }
  facts[[key]]$used_by %||% character(0)
}
