#!/usr/bin/env bash
# Print a page's executed markdown: the code, and the output it produced.
#
#   scripts/page-md.sh howdoi/polygons.qmd
#   scripts/page-md.sh howdoi/polygons.qmd | grep -n 'A tibble'
#   scripts/page-md.sh --list
#
# Why this exists. Checking what a page actually produced does not need the
# rendered HTML. Quarto already stores the post-execution, pre-pandoc markdown
# in _freeze/<path>/execute-results/html.json, and that is the artefact worth
# reading: it holds every chunk's output as text, with no tags to strip and no
# navigation, search index or theme wrapped around it.
#
# So the rule this script exists to make convenient:
#
#   read the markdown for CONTENT   - numbers, output, a leaked string
#   read the HTML for RENDERING     - a cross-reference resolving, a callout
#                                     appearing, anything pandoc decides
#
# Reaching for HTML to check a number means grepping past the whole template
# for something that was sitting in plain text all along.
#
# Note this reads the committed cache, not the source. It tells you what the
# site will publish, which is the question that matters, and it is silent about
# whether that cache is current: scripts/check-freeze.sh answers that.
set -uo pipefail

cd "$(dirname "$0")/.."

if [ "${1:-}" = "--list" ]; then
  find _freeze -name html.json 2>/dev/null \
    | sed 's|^_freeze/||; s|/execute-results/html.json$|.qmd|' \
    | sort
  exit 0
fi

if [ "$#" -ne 1 ]; then
  printf 'usage: scripts/page-md.sh <page.qmd>\n'
  printf '       scripts/page-md.sh --list\n'
  exit 2
fi

page="${1%.qmd}"
cache="_freeze/${page}/execute-results/html.json"

if [ ! -f "$cache" ]; then
  printf 'No executed markdown for %s.qmd\n\n' "$page" >&2
  if [ -f "${page}.qmd" ] && ! grep -q '^```{r' "${page}.qmd"; then
    printf 'That page has no R chunks, so it never executes and has no cache.\n' >&2
    printf 'Read the source directly.\n' >&2
  else
    printf 'Render it first, or run --list to see what is cached.\n' >&2
  fi
  exit 1
fi

python3 -c "
import json, sys
d = json.load(open('$cache'))
r = d.get('result', d)
sys.stdout.write(r['markdown'])
"
