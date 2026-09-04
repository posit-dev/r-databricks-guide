#!/usr/bin/env python3
"""Verify that every internal link and anchor on the site resolves.

    scripts/check-links.py           # every rendered page
    scripts/check-links.py --nav     # also check _quarto.yml's render and nav lists
    scripts/check-links.py page.qmd  # one page

Why this exists. Nothing else catches a broken anchor. `quarto render` exits 0
on a link to a heading that no longer exists, so renaming a heading silently
breaks every cross-reference to it. That happened on 2026-09-02: a heading pass
renamed about forty headings and left one link in ref/spatial-functions.qmd
pointing at `#spatial-joins-are-affected-too-and-that-is-the-one-that-will-
catch-you`, which no longer existed. It was found by an ad-hoc script, which is
the reason this one is tracked.

Checks four things, all of them internal. External URLs are not fetched: that
needs the network, is slow, and fails for reasons that have nothing to do with
this repository.

  1. a linked .qmd file exists
  2. an #anchor exists on the page it points at
  3. a bare #anchor exists on the page carrying the link
  4. with --nav, every path in _quarto.yml resolves

Anchors are derived the way Pandoc derives them, which is not the same as
lowercasing the heading: punctuation is dropped, inline code keeps its text,
and a leading digit is prefixed. Where a heading carries an explicit
{#custom-id}, that wins.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

SECTIONS = ("concepts", "howdoi", "example", "ref", "admin")


def pandoc_anchor(heading: str) -> str:
    """Pandoc's auto_identifier, close enough for a link check.

    Strip formatting, drop everything that is not alphanumeric, hyphen,
    underscore, space or full stop, then lowercase and hyphenate.
    """
    s = re.sub(r"`([^`]*)`", r"\1", heading)          # inline code keeps its text
    s = re.sub(r"\*\*?([^*]*)\*\*?", r"\1", s)        # bold and italic
    s = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", s)    # links keep their text
    s = re.sub(r"[^\w\s.-]", "", s, flags=re.UNICODE)
    s = s.strip().lower().replace(" ", "-")
    s = re.sub(r"-+", "-", s).strip("-")
    # Pandoc drops leading digits; a heading that is only digits gets "section".
    s = re.sub(r"^[0-9.]+", "", s)
    return s or "section"


def headings_of(path: Path) -> set[str]:
    """Every anchor a page offers, including explicit {#ids}."""
    out: set[str] = set()
    fence = False
    for line in path.read_text().split("\n"):
        if re.match(r"^\s*```", line):
            fence = not fence
            continue
        if fence:
            continue
        m = re.match(r"^#{1,6}\s+(.*)", line)
        if not m:
            continue
        text = m.group(1).strip()
        explicit = re.search(r"\{#([\w-]+)\}", text)
        if explicit:
            out.add(explicit.group(1))
            text = re.sub(r"\{#[\w-]+\}", "", text)
        out.add(pandoc_anchor(text))
    return out


def links_of(path: Path) -> list[tuple[int, str, str]]:
    """(line, text, target) for every markdown link, code excluded."""
    out = []
    fence = False
    for i, line in enumerate(path.read_text().split("\n"), 1):
        if re.match(r"^\s*```", line):
            fence = not fence
            continue
        if fence:
            continue
        masked = re.sub(r"`[^`]*`", lambda m: "\x00" * len(m.group(0)), line)
        for m in re.finditer(r"\[([^\]]+)\]\(([^)\s]+)\)", masked):
            start = m.start(2)
            out.append((i, m.group(1), line[start:start + len(m.group(2))]))
    return out


def check(paths: list[Path], root: Path, nav: bool) -> int:
    known = {p: headings_of(p) for p in
             sorted(root.glob("*.qmd")) + [q for s in SECTIONS for q in sorted((root / s).glob("*.qmd"))]}
    problems: list[str] = []
    checked = 0

    for p in paths:
        for line, text, target in links_of(p):
            if target.startswith(("http://", "https://", "mailto:")):
                continue
            checked += 1
            file_part, _, anchor = target.partition("#")

            if not file_part:                      # bare #anchor, same page
                if anchor and anchor not in known.get(p, headings_of(p)):
                    problems.append(
                        f"{p.relative_to(root)}:{line}  #{anchor} is not a heading on this page"
                        f"\n      link text: [{text}]")
                continue

            tgt = (p.parent / file_part).resolve()
            if not tgt.exists():
                problems.append(
                    f"{p.relative_to(root)}:{line}  {file_part} does not exist"
                    f"\n      link text: [{text}]")
                continue

            if anchor:
                have = known.get(tgt) or headings_of(tgt)
                if anchor not in have:
                    problems.append(
                        f"{p.relative_to(root)}:{line}  #{anchor} is not a heading in {file_part}"
                        f"\n      link text: [{text}]")

    if nav:
        import yaml
        cfg = yaml.safe_load((root / "_quarto.yml").read_text())

        def walk(node):
            if isinstance(node, dict):
                for k, v in node.items():
                    if k == "href" and isinstance(v, str):
                        yield v
                    else:
                        yield from walk(v)
            elif isinstance(node, list):
                for v in node:
                    yield from walk(v)
            elif isinstance(node, str) and node.endswith(".qmd"):
                yield node

        for ref in sorted(set(walk(cfg))):
            if ref.startswith(("http://", "https://")) or "*" in ref:
                continue
            checked += 1
            if not (root / ref.split("#")[0]).exists():
                problems.append(f"_quarto.yml  {ref} does not exist")

    if problems:
        print(f"FAIL: {len(problems)} broken link{'s' if len(problems) > 1 else ''} "
              f"of {checked} checked\n", file=sys.stderr)
        for pr in problems:
            print(f"  {pr}", file=sys.stderr)
        print("\nA renamed heading breaks every anchor pointing at it, and quarto\n"
              "render exits 0 either way. Fix the link, or restore the heading.",
              file=sys.stderr)
        return 1

    print(f"ok:   {checked} internal links and anchors all resolve")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("targets", nargs="*", help="pages; default is every rendered page")
    ap.add_argument("--nav", action="store_true", help="also check _quarto.yml paths")
    ap.add_argument("--root", default=Path(__file__).resolve().parent.parent)
    args = ap.parse_args()

    root = Path(args.root).resolve()
    if args.targets:
        paths = [Path(t) if Path(t).is_absolute() else root / t for t in args.targets]
    else:
        paths = sorted(root.glob("*.qmd"))
        for s in SECTIONS:
            paths += sorted((root / s).glob("*.qmd"))

    paths = [p for p in paths if p.exists() and p.suffix == ".qmd"]
    if not paths:
        print("no .qmd pages found", file=sys.stderr)
        return 1
    return check(paths, root, args.nav)


if __name__ == "__main__":
    sys.exit(main())
