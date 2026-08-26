#!/usr/bin/env bash
# Verify that every frozen page's cache matches its source.
#
#   scripts/check-freeze.sh
#
# Why this exists. The site renders in CI with no R installed, replaying
# _freeze/ as text. That works because every executable page sets
# `freeze: true`, which means *never re-execute*, not "re-execute when the
# source changes".
#
# The consequence is a silent failure mode that no exit code reports: edit a
# page, and Quarto happily publishes the previous run's output with the edit
# missing. There is no warning in the log, and the render exits 0. (Only
# `freeze: auto` re-executes on an edit, and in CI that would fail loudly
# instead, which is the opposite problem.)
#
# Quarto stores in each html.json the md5 of the .qmd it executed, so a stale
# cache is detectable exactly, and without running anything.
set -uo pipefail

fail=0
checked=0

while IFS= read -r frozen; do
  # _freeze/<path>/execute-results/html.json  ->  <path>.qmd
  src="${frozen#_freeze/}"
  src="${src%/execute-results/html.json}.qmd"

  if [ ! -f "$src" ]; then
    printf 'FAIL: %s has a freeze cache but no source\n' "$src"
    fail=1
    continue
  fi

  stored=$(sed -n 's/.*"hash" *: *"\([0-9a-f]*\)".*/\1/p' "$frozen" | head -1)
  actual=$(md5sum "$src" | cut -d' ' -f1)
  checked=$((checked + 1))

  if [ "$stored" != "$actual" ]; then
    printf 'FAIL: %s has changed since its freeze cache was written\n' "$src"
    printf '      cache built from %s, source is now %s\n' "$stored" "$actual"
    fail=1
  fi
done < <(find _freeze -name html.json 2>/dev/null | sort)

# A source that executes but has no cache at all would try to run R in CI.
while IFS= read -r qmd; do
  grep -q '^```{r' "$qmd" || continue
  cache="_freeze/${qmd%.qmd}/execute-results/html.json"
  if [ ! -f "$cache" ]; then
    printf 'FAIL: %s has R chunks but no freeze cache\n' "$qmd"
    fail=1
  fi
done < <(find . -name '*.qmd' -not -path './_freeze/*' -not -path './_site/*' \
           | sed 's|^\./||' | sort)

# The hash above answers "which source did Quarto last process", not "did the
# stored output come from executing it". A project-level render refreshes the
# hash without re-executing, which leaves new source against old output and
# passes every test so far. check-freeze-code.py reads the code echoed into the
# cached markdown and catches that; the two are complementary, so run it here
# rather than wiring it separately into the hook, CI and the render scripts.
if [ "$fail" -eq 0 ]; then
  printf 'ok:   %d frozen pages match their source\n' "$checked"
  if command -v python3 >/dev/null 2>&1; then
    python3 "$(dirname "$0")/check-freeze-code.py" || fail=1
  else
    printf 'FAIL: python3 not found, so the cached code could not be checked\n'
    printf '      against its source. Install python3; this check must not be\n'
    printf '      skipped silently, because the staleness it catches is silent.\n'
    fail=1
  fi
fi

if [ "$fail" -eq 0 ]; then
  printf '\nFreeze cache is current.\n'
else
  printf '\nRe-render the affected pages locally, with credentials, and commit\n'
  printf '_freeze/ alongside the edit. CI cannot refill the cache itself.\n'
fi

exit "$fail"
