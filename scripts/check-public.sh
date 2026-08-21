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
tracked() { git ls-files -z | xargs -0 -r "$@"; }

# Identifiers that must never appear in published material.
# \b word boundaries matter: without them "lois" matches inside unrelated words.
IDENT='\bdefra\b|\bliza\b|\blois\b|\bwood\b|\bbourne\b|\bpelikan\b'
IDENT="$IDENT"'|e985c33f1db7502f|0805-080135-14tsi328'
IDENT="$IDENT"'|\bandrie\b|\bagave\b|session-f[0-9a-f]|/tmp/andrie'

report "no customer, contact or personal identifier" \
  "$(tracked command grep -niE "$IDENT" 2>/dev/null)"

# A real warehouse, cluster or catalog name in a tracked file is a leak even
# when it is not customer-identifying: it points readers at someone's workspace.
report "no hard-coded warehouse or cluster id" \
  "$(tracked command grep -nE '/sql/1\.0/warehouses/[0-9a-f]{8,}|[0-9]{4}-[0-9]{6}-[a-z0-9]{8}' 2>/dev/null \
     | command grep -v '<your-')"

report "no hard-coded catalog name" \
  "$(tracked command grep -nE 'uk_water_quality' 2>/dev/null)"

# House style, per the guide's own conventions.
report "base pipe only, no magrittr pipe" \
  "$(tracked command grep -n '%>%' 2>/dev/null)"

report "no em-dashes" \
  "$(tracked command grep -n '—' 2>/dev/null)"

if [ "$fail" -eq 0 ]; then
  printf '\nAll checks passed.\n'
else
  printf '\nOne or more checks FAILED. Nothing should be pushed public until they pass.\n'
fi
exit "$fail"
