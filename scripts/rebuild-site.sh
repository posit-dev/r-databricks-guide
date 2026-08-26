#!/usr/bin/env bash
# Throw away every cache and rebuild the whole site from source, for testing.
#
#   scripts/rebuild-site.sh              # rebuild, leaving bootstrap's cluster output
#   WQ_RUN_CLUSTER=true scripts/rebuild-site.sh   # rebuild everything, cluster included
#   scripts/rebuild-site.sh --dry-run    # list what would be deleted and rebuilt
#
# Why this exists. `quarto render` on its own proves very little here. Every
# executable page sets `freeze: true`, so a project render replays _freeze/ as
# text without starting R: it will happily rebuild a site whose cached output
# no longer matches its source, and exit 0. Reading stale compiled CSS has the
# same shape, which is why _site/site_libs/bootstrap is dropped too.
#
# This is the expensive, honest check: delete both caches, re-execute every
# page against real credentials, and see whether the site still builds. Expect
# it to take a while and to bill for the compute it touches.
#
# It rewrites tracked files under _freeze/. Everything it deletes is
# reconstructible only by a credentialed render, so it refuses to start from a
# dirty tree rather than destroying work you have not committed.
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

dry_run=0
[ "${1:-}" = "--dry-run" ] && dry_run=1

cluster_note() {
  if [ "${WQ_RUN_CLUSTER:-}" = "" ]; then
    printf '      example/bootstrap.qmd will render WITHOUT its cluster output.\n'
    printf '      Its cluster chunks are gated on WQ_RUN_CLUSTER, so they are shown\n'
    printf '      and not run, and the committed cache will lose that output.\n'
    printf '      To keep it, re-run as: WQ_RUN_CLUSTER=true scripts/rebuild-site.sh\n'
  else
    printf '      example/bootstrap.qmd WILL run against the multi-node cluster.\n'
    printf '      Start it first: scripts/start-cluster.R\n'
  fi
}

if [ "$dry_run" -eq 1 ]; then
  printf 'Would delete:\n'
  printf '  _freeze/    (%s tracked files; only a credentialed render rebuilds these)\n' \
    "$(git ls-files _freeze | wc -l | tr -d ' ')"
  printf '  _site/\n\n'
  printf 'Would re-execute:\n'
  find . -name '*.qmd' -not -path './_freeze/*' -not -path './_site/*' \
    | sed 's|^\./||' | sort | while IFS= read -r q; do
      grep -q '^```{r' "$q" && printf '  %s\n' "$q"
    done
  printf '\nNote:\n'
  cluster_note
  exit 0
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  printf 'FAIL: the working tree is dirty.\n'
  printf '      This deletes every freeze cache and rebuilds it from a live render.\n'
  printf '      Commit or stash first, so a bad rebuild is one `git checkout` away.\n'
  exit 1
fi

printf 'This deletes _freeze/ and _site/ and re-executes every page against\n'
printf 'real credentials and real compute.\n'
cluster_note
printf '\nContinue? [y/N] '
read -r reply
case "$reply" in
  y|Y|yes|YES) ;;
  *) printf 'Aborted. Nothing deleted.\n'; exit 0 ;;
esac

printf '\n== dropping caches ==\n'
rm -rf _freeze _site
printf 'Deleted _freeze/ and _site/.\n'

printf '\n== rendering ==\n'
if ! quarto render; then
  printf '\nFAIL: the render did not complete.\n'
  printf '      _freeze/ is now partial. Restore it with:\n'
  printf '        git checkout -- _freeze\n'
  exit 1
fi

printf '\n== checks ==\n'
scripts/check-freeze.sh || exit 1
scripts/check-public.sh || exit 1

printf '\n== what changed ==\n'
git status --short _freeze | head -20
printf '\nA rebuilt cache differs from the committed one whenever a number moved.\n'
printf 'Read the diff before committing: that is the point of the exercise.\n'
printf 'Then read the rendered HTML, because quarto exits 0 on nonsense numbers.\n'
