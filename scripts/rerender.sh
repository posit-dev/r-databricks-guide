#!/usr/bin/env bash
# Re-render a frozen page with credentials, refreshing its freeze cache.
#
#   scripts/rerender.sh example/spatial.qmd [more.qmd ...]
#   scripts/rerender.sh --stale              # every page whose cache is stale
#
# Why this exists. Every executable page sets `freeze: true`, which means
# *never re-execute*, not "re-execute when the source changes". So editing a
# page and pushing publishes the previous run's output with the edit missing:
# no error, nothing in the render log, exit 0.
#
# `quarto render <page>` alone does not fix that, because freeze still refuses
# to execute. The cache has to be dropped first. That is the whole job here,
# and doing it by hand means remembering which directory under _freeze/ maps
# to which source file, and remembering to commit the result.
#
# This deletes tracked files under _freeze/, which only a credentialed render
# can rebuild, so it refuses to run against a dirty _freeze/ rather than
# destroying output you have not committed.
set -uo pipefail

cd "$(dirname "$0")/.."

# assets/redact.lua reads identifiers from the *process* environment. This
# project keeps them in .Renviron, which only R reads, so they must be exported
# here or the filter silently redacts nothing. It warns in that case; exporting
# means it never has to.
export_identifiers() {
  local v
  for v in DATABRICKS_CATALOG DATABRICKS_HOST; do
    if [ -z "${!v:-}" ]; then
      export "$v"="$(Rscript -e "cat(Sys.getenv('$v'))" 2>/dev/null | grep -v '^WARNING')"
    fi
  done
}
export_identifiers

usage() {
  printf 'usage: scripts/rerender.sh <page.qmd> [page.qmd ...]\n'
  printf '       scripts/rerender.sh --stale\n'
  exit 2
}

[ "$#" -eq 0 ] && usage

# Pages whose committed cache no longer matches their source.
stale_pages() {
  while IFS= read -r frozen; do
    src="${frozen#_freeze/}"
    src="${src%/execute-results/html.json}.qmd"
    [ -f "$src" ] || continue
    stored=$(sed -n 's/.*"hash" *: *"\([0-9a-f]*\)".*/\1/p' "$frozen" | head -1)
    [ "$stored" != "$(md5sum "$src" | cut -d' ' -f1)" ] && printf '%s\n' "$src"
  done < <(find _freeze -name html.json 2>/dev/null | sort)
}

if [ "$1" = "--stale" ]; then
  mapfile -t pages < <(stale_pages)
  if [ "${#pages[@]}" -eq 0 ]; then
    printf 'ok:   every frozen page matches its source. Nothing to re-render.\n'
    exit 0
  fi
  printf 'Stale: %s\n\n' "${pages[*]}"
else
  pages=("$@")
fi

# Refuse to destroy uncommitted output.
if ! git diff --quiet -- _freeze || ! git diff --cached --quiet -- _freeze; then
  printf 'FAIL: _freeze/ has uncommitted changes.\n'
  printf '      This script deletes cache files that only a credentialed render\n'
  printf '      can rebuild. Commit or stash _freeze/ first.\n'
  exit 1
fi

fail=0
for page in "${pages[@]}"; do
  if [ ! -f "$page" ]; then
    printf 'FAIL: %s does not exist\n' "$page"
    fail=1
    continue
  fi

  if ! grep -q '^```{r' "$page"; then
    printf 'skip: %s has no R chunks, so it has no cache to refresh\n' "$page"
    continue
  fi

  # example/bootstrap.qmd holds cluster output that a plain render silently
  # drops: its cluster chunks are gated on WQ_RUN_CLUSTER and are shown but
  # not run without it. Rendering it unset would publish a page missing the
  # output it exists to show.
  if [ "$page" = "example/bootstrap.qmd" ] && [ "${WQ_RUN_CLUSTER:-}" = "" ]; then
    printf 'FAIL: %s needs a multi-node cluster.\n' "$page"
    printf '      Re-run as: WQ_RUN_CLUSTER=true scripts/rerender.sh %s\n' "$page"
    printf '      Rendering it without that flag drops its cluster output.\n'
    fail=1
    continue
  fi

  printf '\n== %s ==\n' "$page"
  rm -rf "_freeze/${page%.qmd}"
  if ! quarto render "$page"; then
    printf 'FAIL: %s did not render\n' "$page"
    fail=1
  fi
done

printf '\n'
if [ "$fail" -ne 0 ]; then
  printf 'Some pages failed. The freeze cache may now be incomplete: check\n'
  printf '`git status _freeze` before committing.\n'
  exit 1
fi

scripts/check-freeze.sh || exit 1

printf '\nCommit _freeze/ in the same commit as the edit, or the next push\n'
printf 'publishes the old output.\n'
printf 'Then read the rendered HTML: quarto render exits 0 on nonsense numbers.\n'
