#!/usr/bin/env bash
# Acceptance checks for this repo, which is public by default.
#
#   scripts/check-public.sh
#
# The inversion that matters: in a private repo a leak has to reach a specific
# directory to be dangerous. Here, anything committed is published, so this
# scans everything git tracks rather than a named subdirectory.
#
# `command grep` is deliberate: this shell's grep may be a ugrep wrapper with
# --ignore-files, which silently skips gitignored files.
set -uo pipefail

fail=0
report() { # name, matches
  if [ -n "$2" ]; then
    printf 'FAIL: %s\n%s\n\n' "$1" "$2"
    fail=1
  else
    printf 'ok:   %s\n' "$1"
  fi
}

# Only ever scan tracked files. Untracked working material (docs/, .Renviron)
# is gitignored on purpose and is not what this check is about.
#
# GREP is resolved to a real binary rather than left as the shell's `grep`,
# which on this machine is a ugrep wrapper with --ignore-files that silently
# skips gitignored files. xargs cannot run a shell builtin, so `command grep`
# would exit 127 here and every check would report a false pass.
GREP="$(command -v grep)"
# Two tracked paths are excluded from every scan below.
#
# This script necessarily contains the patterns it searches for, so it is
# excluded from its own scan rather than contorting every pattern to avoid
# self-matching.
#
# renv.lock is generated, never hand-edited, and is ~2000 lines of CRAN
# metadata copied verbatim from each package's DESCRIPTION. That metadata
# trips two checks with nothing this repo wrote: `config` names its own CRAN
# maintainer, who is also this repo's author, and magrittr's Description
# explains that the package provides `%>%`. Both are third-party facts about
# published packages, so there is nothing to fix in the file. Excluded here
# rather than per-check because every future pattern will hit it the same way.
#
# This exclusion is deliberately confined to the tracked-file checks. The
# rendered-output checks below scan _site/ and _freeze/ directly and are
# unaffected, which is what still catches an identifier that reaches the web.
EXCLUDE='^(scripts/check-public\.sh|renv\.lock)$'
tracked() {
  git ls-files -z | "$GREP" -zvE "$EXCLUDE" | xargs -0 -r "$GREP" "$@"
}

# Identifiers that must never appear in published material.
# \b word boundaries matter: without them "lois" matches inside unrelated words.
IDENT='\bdefra\b|\bliza\b|\blois\b|\bwood\b|\bbourne\b|\bpelikan\b'
IDENT="$IDENT"'|e985c33f1db7502f|0805-080135-14tsi328'
IDENT="$IDENT"'|\bandrie\b|\bagave\b|session-f[0-9a-f]|/tmp/andrie'

report "no customer, contact or personal identifier" \
  "$(tracked -niE "$IDENT" 2>/dev/null)"

# A real warehouse, cluster or catalog name in a tracked file is a leak even
# when it is not customer-identifying: it points readers at someone's workspace.
report "no hard-coded warehouse or cluster id" \
  "$(tracked -nE '/sql/1\.0/warehouses/[0-9a-f]{8,}|[0-9]{4}-[0-9]{6}-[a-z0-9]{8}' 2>/dev/null \
     | "$GREP" -v '<your-')"

report "no hard-coded catalog name" \
  "$(tracked -nE 'uk_water_quality' 2>/dev/null)"

# House style, per the guide's own conventions.
# The style rules in CLAUDE.md, CODE-STYLE.md and README.md have to quote what
# they forbid, so they are exempt from these two prose checks.
PROSE_EXEMPT='^(CLAUDE|CODE-STYLE|README)\.md:'

report "base pipe only, no magrittr pipe" \
  "$(tracked -n '%>%' 2>/dev/null | "$GREP" -vE "$PROSE_EXEMPT")"

# A lone em-dash in a table cell is an empty-cell marker, not prose.
report "no em-dashes in prose" \
  "$(tracked -n '—' 2>/dev/null \
     | "$GREP" -vE "$PROSE_EXEMPT" \
     | "$GREP" -vE '\|[[:space:]]*—[[:space:]]*\|')"

# --- rendered output -------------------------------------------------------
#
# The checks above scan only what git tracks, which is a real blind spot: an
# identifier can reach the web without ever appearing in a tracked file. A
# chunk that queries the environment and prints the result puts the catalog
# name into _site/*.html and into the _freeze/ cache, and both are gitignored,
# so nothing above would see it. That is how a real cluster id and the catalog
# name once reached rendered pages.
#
# Every page that queries Databricks must install the output mask, and this
# checks the guard rather than the leak. The other checks here fire only after
# something has already escaped into a tracked file; this one fires while the
# page is still being written.
#
# The trigger is a connection, not a chunk. A page that opens `con`, `acon` or
# a Spark connection will print something that came back from the workspace
# sooner or later, and the identifiers travel by more routes than any one of
# them is obvious about: an in_catalog() object stores the catalog, show_query()
# builds it into SQL, and a server error quotes the fully qualified name.
missing_mask=""
while IFS= read -r qmd; do
  grep -q '^```{r' "$qmd" || continue
  "$GREP" -qE 'dbConnect|spark_connect' "$qmd" || continue
  grep -q 'wq_mask_output()' "$qmd" || missing_mask="$missing_mask$qmd: connects to Databricks with no wq_mask_output()"$'\n'
done < <(git ls-files '*.qmd')

report "every connecting page masks its output" "$missing_mask"

# _site/ is what gets published, so it is scanned when it exists. It is build
# output, so its absence is not a failure: a clean clone has not rendered yet.
BUILT=""
for d in _site _freeze; do
  [ -d "$d" ] && BUILT="$BUILT $d"
done

if [ -n "$BUILT" ]; then
  # shellcheck disable=SC2086
  built() { "$GREP" -rIl "$@" $BUILT 2>/dev/null; }

  report "rendered output carries no personal identifier" \
    "$(built -iE "$IDENT")"

  report "rendered output carries no warehouse or cluster id" \
    "$(built -E '/sql/1\.0/warehouses/[0-9a-f]{8,}|[0-9]{4}-[0-9]{6}-[a-z0-9]{8}')"

  report "rendered output carries no catalog name" \
    "$(built -E 'uk_water_quality')"
else
  printf 'skip: rendered output not scanned (_site/ absent; run quarto render)\n'
fi

if [ "$fail" -eq 0 ]; then
  printf '\nAll checks passed.\n'
else
  printf '\nOne or more checks FAILED. Nothing should be pushed public until they pass.\n'
fi
exit "$fail"
