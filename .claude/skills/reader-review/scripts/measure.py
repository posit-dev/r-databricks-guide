#!/usr/bin/env python3
"""Phase A of /reader-review: count what is countable on a set of .qmd pages.

Emits a markdown scores table on stdout and, with --json, a machine-readable
file alongside it so runs can be diffed after edits.

Deliberately deterministic. Nothing here is a judgement: the judgement rules
(order, completeness, necessity, and whether a flagged register sentence is
legitimate for its page) belong to the isolated reviewer in Phase B.

Thresholds come from 245 H2/H3 headings measured across five R-community
books. See process/DESIGN-reader-review.md for the evidence.
"""

from __future__ import annotations

import argparse
import json
import re
import statistics
import sys
from dataclasses import dataclass, asdict
from pathlib import Path

# Heading length, from the comparator distribution: mean 2.8 to 3.6, and no
# heading over 8 words in any of the five books.
HEAD_TARGET_MAX = 4
HEAD_FLAG = 6
HEAD_FAIL = 8
HEAD_QUESTION_MAX = 7

# A heading whose MAIN verb asserts something is a verdict rather than a
# label. The verb has to be the heading's own assertion, so a verb inside a
# relative or subordinate clause does not count: "Running them across the
# cores you have" is a gerund label, not a claim, and "you have" is a
# relative clause modifying "cores".
VERDICT_VERB = re.compile(
    r"\b(is|are|was|were|does|do|did|has|have|will|can|cannot|"
    r"isn't|aren't|doesn't|don't|won't|can't)\b",
    re.I,
)

# Clause openers after which a verb belongs to a subordinate clause rather
# than to the heading's own assertion.
SUBORDINATOR = re.compile(
    r"\b(you|that|which|who|whom|whose|where|when|what|how|why|if|unless|"
    r"whether|because|since|while|after|before|though|although)\b",
    re.I,
)

# A heading starting with a gerund or an imperative is a label whatever
# verbs appear later in it: "Getting the worker count wrong is cheap" is
# still a verdict, so this only applies when no main-clause copula follows.
GERUND_START = re.compile(r"^\s*(X\s+)?\w+ing\b", re.I)

# Register: sentences addressed to someone judging the guide rather than
# using it. Provenance about our own testing, research vocabulary, and
# author-facing notes. Reported with the sentence so Phase B can judge
# whether it is legitimate for that page.
REGISTER_PATTERNS = [
    (r"\bobserved (on|by|in)\b", "provenance"),
    (r"\bnot a benchmark\b", "provenance"),
    (r"\bmeasured (on|at|across)\b", "provenance"),
    (r"\bsingle run\b", "provenance"),
    (r"\bin (a|one) Workbench session\b", "provenance"),
    (r"\bat every setting tried\b", "provenance"),
    (r"\bconfirmed by\b", "provenance"),
    (r"\bhas been observed\b", "provenance"),
    (r"\bthe \w+ finding\b", "research-vocabulary"),
    (r"\b(untested|unverified|unresolved|unexplained)\b", "research-vocabulary"),
    (r"\bestablished by test\b", "research-vocabulary"),
    (r"\bthis page rests on\b", "research-vocabulary"),
    (r"\bthat is the entire claim\b", "author-facing"),
    (r"\bnothing else to teach\b", "author-facing"),
    (r"\bthe page must\b", "author-facing"),
    (r"\bthis (page|section) (exists|is here) to\b", "author-facing"),
    (r"\bnot a (rhetorical device|preference)\b", "author-facing"),
]
# "it is worth saying so plainly" reads as an author's note but is ordinary
# reader-facing emphasis, so it is deliberately not matched.

# Openings that correct an expectation rather than establishing a situation.
CORRECTIVE_OPENING = re.compile(
    r"^\s*(the \w+ part (of|is)|it is not|this is not|that is not|"
    r"\w+ is not the|contrary to|despite what|you might (expect|think|assume))",
    re.I,
)

# Scope signals: the opening telling her what the page covers.
SCOPE_SIGNAL = re.compile(
    r"\b(this page|this chapter|below|what follows|three|two|four|"
    r"first .{0,30}then|covers|walks through|shows you how)\b",
    re.I,
)


@dataclass
class Heading:
    line: int
    level: int
    text: str
    words: int
    question: bool
    verdict: bool


@dataclass
class RegisterHit:
    line: int
    kind: str
    sentence: str


@dataclass
class PageScore:
    page: str
    prose_words: int
    code_lines: int
    headings: int
    words_per_section: int
    head_mean: float
    head_max: int
    head_over_fail: int
    head_over_flag: int
    verdict_headings: int
    opening_corrective: bool
    opening_has_scope: bool
    first_code_line: int | None
    first_heading_line: int | None
    register_hits: int
    worst: list[Heading]
    register: list[RegisterHit]


def strip_yaml(text: str) -> tuple[str, int]:
    """Remove front matter, returning the body and the line it starts on."""
    m = re.match(r"\A---\n.*?\n---\n", text, re.S)
    if not m:
        return text, 0
    return text[m.end():], text[: m.end()].count("\n")


def split_fences(body: str) -> tuple[list[tuple[int, str]], list[str]]:
    """Split body into (line_no, prose_line) and raw code-chunk lines."""
    prose: list[tuple[int, str]] = []
    code: list[str] = []
    in_fence = False
    for i, line in enumerate(body.split("\n"), start=1):
        if re.match(r"^\s*```", line):
            in_fence = not in_fence
            continue
        if in_fence:
            if line.strip() and not line.strip().startswith("#|"):
                code.append(line)
        else:
            prose.append((i, line))
    return prose, code


def count_prose_words(prose: list[tuple[int, str]]) -> int:
    """Body prose only: no headings, callout fences, or the rests-on line."""
    words = 0
    for _, line in prose:
        s = line.strip()
        if not s or s.startswith("#") or s.startswith(":::"):
            continue
        if s.lower().startswith("this page rests on:"):
            continue
        s = re.sub(r"`[^`]*`", "X", s)
        words += len(s.split())
    return words


def find_headings(prose: list[tuple[int, str]], offset: int) -> list[Heading]:
    out = []
    for i, line in prose:
        m = re.match(r"^(#{2,4})\s+(.*)", line)
        if not m:
            continue
        text = m.group(2).strip()
        # Inline code counts as one word: `spark_apply()` is one idea.
        counted = re.sub(r"`[^`]*`", "X", text)
        n = len([w for w in counted.split() if w])
        question = text.rstrip().endswith("?")
        out.append(Heading(i + offset, len(m.group(1)), text, n, question,
                           is_verdict(counted, question)))
    return out


def is_verdict(counted: str, question: bool) -> bool:
    """True when the heading's own main verb asserts something.

    A question is her question, not our answer, so it is never a verdict.
    A verb inside a subordinate clause belongs to that clause: in "Running
    them across the cores you have", the "have" follows "you" and modifies
    "cores", so the heading stays a label.
    """
    if question:
        return False
    m = VERDICT_VERB.search(counted)
    if not m:
        return False
    before = counted[: m.start()]
    # The verb sits inside a subordinate clause opened earlier in the heading.
    if SUBORDINATOR.search(before):
        # Unless a further verb follows the clause and carries the assertion,
        # as in "If your replicates do polygon work, sf has to load ...".
        rest = counted[m.end():]
        return bool(VERDICT_VERB.search(rest))
    # A gerund opening with no preceding subject is a label: "Naming the
    # output columns is context-dependent" still asserts, so require that
    # the copula not be the heading's own predicate.
    if GERUND_START.match(counted) and not re.search(
        r"\b(is|are|was|were)\b", counted, re.I
    ):
        return False
    return True


def find_register(prose: list[tuple[int, str]], offset: int) -> list[RegisterHit]:
    hits = []
    for i, line in prose:
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        if s.lower().startswith("this page rests on:"):
            hits.append(RegisterHit(i + offset, "research-vocabulary",
                                    "This page rests on: ..."))
            continue
        for sentence in re.split(r"(?<=[.!?])\s+", s):
            for pattern, kind in REGISTER_PATTERNS:
                if re.search(pattern, sentence, re.I):
                    hits.append(RegisterHit(i + offset, kind, sentence.strip()[:120]))
                    break
    return hits


def opening_paragraphs(prose: list[tuple[int, str]], n: int = 2) -> str:
    """The first n prose paragraphs after any callout block."""
    paras: list[str] = []
    buf: list[str] = []
    in_callout = False
    for _, line in prose:
        s = line.strip()
        if s.startswith(":::"):
            in_callout = not in_callout if s != ":::" else False
            continue
        if in_callout or s.startswith("#"):
            continue
        if not s:
            if buf:
                paras.append(" ".join(buf))
                buf = []
                if len(paras) >= n:
                    break
            continue
        buf.append(s)
    if buf and len(paras) < n:
        paras.append(" ".join(buf))
    return " ".join(paras)


def score_page(path: Path, root: Path) -> PageScore:
    text = path.read_text()
    body, offset = strip_yaml(text)
    prose, code = split_fences(body)

    heads = find_headings(prose, offset)
    words = count_prose_words(prose)
    reg = find_register(prose, offset)
    opening = opening_paragraphs(prose)

    ns = [h.words for h in heads]
    first_code = next(
        (i + offset for i, l in enumerate(body.split("\n"), 1)
         if re.match(r"^\s*```\{r", l)), None
    )

    return PageScore(
        page=str(path.relative_to(root)),
        prose_words=words,
        code_lines=len(code),
        headings=len(heads),
        words_per_section=round(words / len(heads)) if heads else words,
        head_mean=round(statistics.mean(ns), 1) if ns else 0.0,
        head_max=max(ns) if ns else 0,
        head_over_fail=sum(1 for h in heads if h.words > HEAD_FAIL),
        head_over_flag=sum(
            1 for h in heads
            if h.words > (HEAD_QUESTION_MAX if h.question else HEAD_FLAG)
        ),
        verdict_headings=sum(1 for h in heads if h.verdict),
        opening_corrective=bool(CORRECTIVE_OPENING.search(opening)),
        opening_has_scope=bool(SCOPE_SIGNAL.search(opening)),
        first_code_line=first_code,
        first_heading_line=heads[0].line if heads else None,
        register_hits=len(reg),
        worst=sorted(heads, key=lambda h: -h.words)[:3],
        register=reg,
    )


def composite(s: PageScore, median_wps: float) -> float:
    """Triage rank. Higher is worse. Weighted by how load-bearing each rule is."""
    return (
        3.0 * s.verdict_headings
        + 2.0 * s.head_over_fail
        + 1.0 * s.head_over_flag
        + 2.0 * (1 if s.opening_corrective else 0)
        + 1.5 * (0 if s.opening_has_scope else 1)
        + 0.3 * s.register_hits
        + 1.0 * (1 if s.words_per_section > 2 * median_wps else 0)
    )


def markdown_table(scores: list[PageScore], median_wps: float) -> str:
    rows = sorted(scores, key=lambda s: -composite(s, median_wps))
    out = [
        "| page | prose | code | h | w/sec | head mean | max | >8 | verdict | open | scope | reg | rank |",
        "|---|--:|--:|--:|--:|--:|--:|--:|--:|:-:|:-:|--:|--:|",
    ]
    for s in rows:
        out.append(
            f"| `{s.page}` | {s.prose_words} | {s.code_lines} | {s.headings} | "
            f"{s.words_per_section} | {s.head_mean} | {s.head_max} | "
            f"{s.head_over_fail} | {s.verdict_headings} | "
            f"{'BAD' if s.opening_corrective else 'ok'} | "
            f"{'ok' if s.opening_has_scope else 'no'} | "
            f"{s.register_hits} | {composite(s, median_wps):.1f} |"
        )
    return "\n".join(out)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("targets", nargs="*", default=None,
                    help="pages, directories, or nothing for the whole site")
    ap.add_argument("--json", metavar="PATH", help="also write JSON here")
    ap.add_argument("--root", default=".", help="repository root")
    ap.add_argument("--detail", action="store_true",
                    help="list the worst headings and register hits per page")
    args = ap.parse_args()

    root = Path(args.root).resolve()
    sections = ["concepts", "howdoi", "example", "ref", "admin"]

    paths: list[Path] = []
    if args.targets:
        for t in args.targets:
            p = (root / t) if not Path(t).is_absolute() else Path(t)
            paths.extend(sorted(p.glob("*.qmd")) if p.is_dir() else [p])
    else:
        for sec in sections:
            paths.extend(sorted((root / sec).glob("*.qmd")))
        if (root / "index.qmd").exists():
            paths.append(root / "index.qmd")

    paths = [p for p in paths if p.exists() and p.suffix == ".qmd"]
    if not paths:
        print("no .qmd pages found", file=sys.stderr)
        return 1

    scores = [score_page(p, root) for p in paths]
    wps = [s.words_per_section for s in scores]
    median_wps = statistics.median(wps) if wps else 0
    prose = [s.prose_words for s in scores]

    print(f"## Page scores\n")
    print(markdown_table(scores, median_wps))
    print()
    print(f"Site: {len(scores)} pages, prose median {statistics.median(prose):.0f} words "
          f"(range {min(prose)}-{max(prose)}), words-per-section median {median_wps:.0f}.")
    print(f"Heading thresholds: target <={HEAD_TARGET_MAX}, flag >{HEAD_FLAG}, "
          f"fail >{HEAD_FAIL} words. Comparator mean is 2.8 to 3.6 with no heading over 8.")

    if args.detail:
        for s in sorted(scores, key=lambda s: -composite(s, median_wps)):
            if not (s.worst or s.register):
                continue
            print(f"\n### `{s.page}`")
            for h in s.worst:
                tags = []
                if h.words > HEAD_FAIL:
                    tags.append("FAIL")
                elif h.words > (HEAD_QUESTION_MAX if h.question else HEAD_FLAG):
                    tags.append("flag")
                if h.verdict:
                    tags.append("verdict")
                if tags:
                    print(f"- L{h.line} heading ({h.words}w, {'+'.join(tags)}): {h.text}")
            for r in s.register[:5]:
                print(f"- L{r.line} register ({r.kind}): {r.sentence}")

    if args.json:
        Path(args.json).write_text(json.dumps(
            {"pages": [asdict(s) for s in scores],
             "median_words_per_section": median_wps,
             "median_prose_words": statistics.median(prose)},
            indent=2,
        ))
    return 0


if __name__ == "__main__":
    sys.exit(main())
