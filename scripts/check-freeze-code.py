#!/usr/bin/env python3
"""Verify that each freeze cache's stored output came from executing its source.

    scripts/check-freeze-code.py

Why this exists. `check-freeze.sh` compares an md5 of the .qmd against the hash
Quarto recorded in the cache. That answers "which source did Quarto last
*process*", not "did the stored output come from *executing* that source". A
project-level `quarto render` refreshes the hash and re-runs pandoc over the
source without re-executing the R chunks, because `freeze: true` means never
re-execute. The cache is then internally inconsistent: new source, new hash,
old executed output, and the hash check passes.

This check reads the code that Quarto echoed into the cached markdown and asks
whether every line of it still exists in the source. Deleted or renamed code
that lingers in the stored output is the signature of that bug, and it is
invisible to the hash.

The test is deliberately one-directional. Code in the source but absent from
the cache is normal and expected: `include: false` and `echo: false` chunks
never appear in the cached markdown. Code in the *cache* but absent from the
*source* is not explainable that way, because Quarto only ever echoes code it
was given. Checking only that direction is what keeps the false-positive rate
at zero across the current site.

Runs on the JSON as text. No R, so CI can run it.
"""

import json
import pathlib
import re
import sys

# Quarto echoes each executed chunk into the cached markdown as a fenced block
# carrying the `.cell-code` class. One source chunk can produce several of
# these, because knitr splits a chunk wherever output is interleaved, so the
# blocks are pooled rather than matched up one-to-one with chunks.
CACHE_CODE = re.compile(r"^```\{\.r[^}]*\.cell-code[^}]*\}\n(.*?)^```", re.M | re.S)
SRC_CHUNK = re.compile(r"^```\{r[^}]*\}\n(.*?)^```", re.M | re.S)


def significant(lines):
    """Drop blank lines and chunk options, which are not comparable code."""
    out = []
    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("#|"):
            continue
        out.append(stripped)
    return out


def cache_code(path):
    data = json.loads(path.read_text())
    markdown = data.get("result", {}).get("markdown", "")
    lines = []
    for match in CACHE_CODE.finditer(markdown):
        lines.extend(match.group(1).rstrip("\n").split("\n"))
    return significant(lines)


def source_code(path):
    lines = []
    for match in SRC_CHUNK.finditer(path.read_text()):
        lines.extend(match.group(1).rstrip("\n").split("\n"))
    return significant(lines)


def main():
    root = pathlib.Path(".")
    caches = sorted(root.glob("_freeze/**/execute-results/html.json"))
    if not caches:
        print("FAIL: no freeze caches found; run this from the repository root")
        return 1

    fail = 0
    checked = 0

    for cache in caches:
        rel = cache.relative_to("_freeze").parent.parent
        src = root / f"{rel}.qmd"
        if not src.is_file():
            # check-freeze.sh already reports a cache with no source.
            continue

        stored = cache_code(cache)
        current = set(source_code(src))
        checked += 1

        # Multiset difference: a line the cache shows more often than the
        # source does is still evidence, so count rather than set-subtract.
        orphans = [line for line in stored if line not in current]
        if orphans:
            fail = 1
            print(f"FAIL: {src} cache holds code its source no longer contains")
            for line in dict.fromkeys(orphans[:5]):
                print(f"      cached: {line[:78]}")
            remaining = len(dict.fromkeys(orphans)) - len(dict.fromkeys(orphans[:5]))
            if remaining > 0:
                print(f"      ... and {remaining} more distinct line(s)")

    if fail == 0:
        print(f"ok:   {checked} freeze caches echo only code their source still has")
    else:
        print("\nThe cached output was not produced by the source now on disk.")
        print("A project-level `quarto render` refreshes the hash without")
        print("re-executing, so the hash comparison above cannot see this.")
        print("Use scripts/rerender.sh, which drops the cache first; a plain")
        print("`quarto render <page>` will leave the stale output in place.")

    return fail


if __name__ == "__main__":
    sys.exit(main())
