# Design: an isolated reviewer that reads the site as the reader, not as its author

## The problem this solves

The site is written by the people who established what it says, and the research shows through in the structure. Not in the facts, which are careful, and not obviously in the prose, which reads well sentence by sentence. It shows in the **order the material arrives in, and in what the headings are for**.

`howdoi/monte-carlo.qmd` is the clearest case, and it was the page that prompted this design. Its title and subtitle are good. Then the first paragraph opens:

> The expensive part of this work is not getting the data out. A large table shrinks server-side to a small one, and only then does the real cost start.

That answers a question she never asked, and it answers it by correcting an expectation she does not hold. The second paragraph is about the *previous* page. The second section, before she has seen a line of simulation code, is "Memory is not the constraint here", a negation of a worry she has not yet formed. Her actual task does not start until line 70 of 201.

That ordering is the order in which the findings were surprising **to the person who established them**: the crossing turned out to be cheap, memory turned out to go down rather than up, `spark_apply()` turned out to be slower than forking. Each is interesting if you held the opposite prior. She holds no prior. She has a simulation to run.

The mechanism has a visible tell: `sim_one()` is defined twice, at lines 42 and 84, with a comment at line 40 explaining why. That duplication exists only because the memory section was placed before the section that introduces the function. The structure is fighting itself.

**This is not a prose problem and the existing checks cannot see it.** `check-public.sh` looks for identifiers, `check-freeze.sh` for stale output, `check-facts.R` for drifted numbers, and the `writing-voice` skill for house style. All four pass on a page whose sections are in the author's order rather than the reader's.

## Why the author cannot review this

The defect is invisible from the inside, for a specific and unavoidable reason: **the author knows why the finding was surprising**, so the order feels like narrative rather than like autobiography. Re-reading your own page recovers the reasoning that put the sections where they are, and the reasoning is sound. Only the sequence is wrong.

An agent reviewing in this repository inherits the same problem by a different route. `CLAUDE.md` is a careful, persuasive account of the house style, and a reviewer that reads it will grade the pages against the author's stated standard and find them compliant. That is the agreeable-reviewer failure, and it is worse than no review, because it certifies the defect.

So the reviewer has to be **isolated from the author's reasoning**, and judged against a standard that comes from outside this repository.

## The external standard

Four books by four author teams, all well regarded in the R community, all writing technical documentation for a fluent R user. Chosen as comparators for **form, not content**: what a chapter looks like, not what it says.

| Book | Authors |
|----|----|
| [R for Data Science (2e)](https://r4ds.hadley.nz/) | Wickham, Çetinkaya-Rundel, Grolemund |
| [R Packages (2e)](https://r-pkgs.org/) | Wickham, Bryan |
| [Feature Engineering and Selection](https://feat.engineering/) | Kuhn, Johnson |
| [Supervised Machine Learning for Text Analysis in R](https://smltar.com/) | Hvitfeldt, Silge |
| [Text Mining with R](https://www.tidytextmining.com/) | Silge, Robinson |

Two further sites were read while establishing the problem, [Niehaus's Monte Carlo guide](https://jmniehaus.github.io/montes.html) and [Designing Simulations in R](https://jepusto.github.io/Designing-Simulations-in-R/). They are subject-matter comparators for one page and are **not** part of the standard: they teach simulation design to people learning it, and this reader already knows it. Holding the site to their coverage would produce exactly the condescension the guide forbids.

### Heading form, measured

245 H2 and H3 headings across the four form comparators, section numbers stripped, against 248 headings on this site.

| Source | n | mean | median | max | ≤5 words | >8 words |
|----|----|----|----|----|----|----|
| r4ds + r-pkgs (8 chapters) | 140 | 2.8 | 3 | 8 | 96% | 0% |
| feat.engineering (4 chapters) | 39 | 3.2 | 2 | 8 | 82% | 0% |
| smltar (3 chapters) | 45 | 3.6 | 4 | 6 | 91% | 0% |
| tidytextmining (3 chapters) | 21 | 3.3 | 3 | 6 | 86% | 0% |
| **this site (30 pages)** | **248** | **5.5** | **5** | **15** | **51%** | **18%** |

**Not one heading in 245 exceeds eight words.** Four independent author teams agree, so this is R-community documentation form rather than one author's habit. This site's headings are roughly twice as long, and 45 of them exceed the ceiling that none of the comparators reaches.

The longest comparator headings are still labels: "Creating Dummy Variables for Unordered Categories", "Most common positive and negative words", "Depending on the development version of a package". The longest on this site are arguments: "Spatial joins are affected too, and that is the one that will catch you", "You can start and stop what you have. You cannot change its shape".

That difference explains the length gap. A verdict needs a subject, a verb and a predicate, so a heading that carries a conclusion is *forced* to be long. Length and grammar are one defect, and fixing the grammar fixes the length.

Question headings are legitimate but rare: 0% in feat.engineering and tidytextmining, 2% in Wickham, 9% in smltar. The longest question in 245 headings is seven words.

### Openings, measured

The first draft of this design claimed a chapter must open by naming the reader's task. That is Wickham's habit, not the community's, and the other two books disprove it:

- r4ds databases: "A huge amount of data lives in databases, so it's essential that you know how to access it."
- smltar stemming: "When we deal with text, often documents contain different versions of one base word, often called a *stem*."
- feat.engineering missing data: "Missing data are **not** rare in real data sets."

The last two open with a **fact about the domain**, not a task. What all of them share is subtler, and it is the thing this site's openings violate: the opening fact is about **her world**, verifiable from her own data before she reads anything here. Word stems exist in text. Missing data is common. Databases hold a lot of data.

"The crossing is free, the repetition is not" is a fact about **our measurement of this platform**. Same grammatical shape, different provenance, and the difference is the whole defect.

Wickham additionally states scope as concrete items, which is worth adopting even though it is not universal: "we'll keep things concrete by focusing on three common tasks: modifying multiple columns, reading multiple files, and saving multiple objects."

## The seven rules

Each rule states its test and what it must not flag. Rules 1-3 are largely countable; 4-7 need judgement.

**1. Opening.** The opening establishes something about her world or her task, and pivots within two paragraphs to what the page does about it. A domain fact, a task statement or a problem she recognises all qualify.

*Test*: could she have known this before reading the site? If the only source is our testing, it fails. Also fails if the page opens by correcting an expectation it has not yet established she holds.

**2. Scope.** The opening says what the page covers, as concrete items. Not a requirement that the words "in this chapter" appear; a requirement that she can tell what she is about to get without reading the headings.

**3. Headings.** Two independent tests.

- *Length*: target 2-4 words, flag over 6, fail over 8. The ceiling is empirical, from 245 comparator headings. Questions may run to 7 and should be rare.
- *Grammar*: a heading is a noun phrase or an imperative. A heading whose main verb asserts something ("is", "does not", "was") is a verdict and fails.

A verdict heading is only navigable to someone who already knows the question, which is the author. She scans for "how do I use my cores" and finds "Memory is not the constraint here". Six of monte-carlo's twelve headings fail this test.

**4. Order.** Is the running order her path through the work? Specifically: does any reassurance, caveat or negation arrive before the thing it qualifies? Does the page tell her what it covers before its first code block?

Deliberately narrow. Order is a check on a permutation, so it is blind by construction to a section that is missing, and it will find a good position for a section that should not exist at all. Those are rules 5 and 6.

**5. Completeness.** Walk the page as a task rather than as a document. At each step, can she do the next thing with what she has been given, or must she leave?

*Reference*: the page's own title and subtitle, read as a contract, plus her task. **Not** comparator coverage. Report a gap only by naming the step she cannot take; "could say more about X" is not a finding.

**6. Necessity.** For each section, whose question does it answer?

*Test*: if she skipped this section entirely, what would go wrong? Nothing but missing an interesting fact means it is ours. An error, a bad choice or a wasted day means it is hers.

Three verdicts: keep, misplaced (hers, but later or on another page), removable (ours). The named-harm requirement is what stops the reviewer becoming a deletionist: it cannot remove a section for being long, only for being unnecessary.

**7. Register.** Flag sentences whose audience is someone **judging the guide** rather than someone using it. Three kinds:

- provenance about our own testing: "observed on a two-worker cluster", "single run in a Workbench session, not a benchmark"
- research vocabulary: "the memory finding", which refers to an earlier section as a research artefact
- author-facing notes: "that is the entire claim, and there is nothing else to teach here"

Not research register in general. "Missing data are not rare in real data sets" is fine, because it describes the world rather than what we did to find out about the world. The distinguishing question is which of those two a sentence is doing.

Rule 7 **counts and locates; it does not recommend deletion**. Some of this language is load-bearing honesty required by `CLAUDE.md`, and whether an instance stays is the author's call. The value is seeing where it clusters.

*Carve-out*: a page whose subject is verification or diagnosis (`howdoi/check-the-answer.qmd`, `ref/when-it-breaks.qmd`) will legitimately score high here. The reviewer must judge, not merely count.

### Out of scope, explicitly

- **Accuracy, code correctness, platform behaviour.** The reviewer has no cluster and cannot check. Structure and register only.
- **House style**: UK English, em-dashes, sentence case, base pipe. Covered by `scripts/`, `CODE-STYLE.md` and the `writing-voice` skill. Duplicating them buries the structural findings in spelling noise.

## Length: report it, do not rule on it

There is a real question about pages being too long or too short, and not yet enough evidence to answer it. The comparators cannot settle it, because a book chapter is read in sequence and teaches, while a `howdoi/` page is arrived at singly to solve one problem. Comparator chapters run to a median of about 3,900 words against this site's 1,066, and inventing a threshold from that gap would give the reviewer a number with nothing behind it.

Measured on 2026-09-02, prose words excluding YAML, code blocks, headings and the `rests on:` line:

| | median | range |
|----|----|----|
| site (30 pages) | 1,066 | 580-1,801 |
| `howdoi/` (10) | 1,242 | 944-1,801 |
| `example/` (9) | 920 | 649-1,585 |
| `ref/` (7) | 1,055 | 580-1,702 |

Two things the internal numbers show without any external reference. The spread within `howdoi/` is 3:1 for pages with the same job and the same reader. And **words per section** varies 4:1, from `ref/when-it-breaks.qmd` at 284 and `check-the-answer.qmd` at 255 down to `monte-carlo.qmd` at 76 and `ref/sending-things.qmd` at 73. That second number is the better proxy for scannability: 284 words under one heading means reading paragraphs to find out whether a section is the one she wants.

Note that `monte-carlo.qmd` is mid-pack on total length at 1,292 words. Its problem is 17 headings across those words, so it is fragmented rather than bloated. The reviewer must be able to tell those apart.

**So the rule is that there is no rule.** Report prose words, code lines, heading count and words per section, plus each page's position against the site's own median. Length never generates a finding on its own. It may only sharpen a finding that has already cleared the bar for another reason: *possibly too long* when it coincides with a rule 6 removable section, *possibly too thin* when it coincides with a rule 5 gap.

The numbers accumulate across runs. If a threshold emerges, it gets promoted to rule 8 with evidence behind it, exactly as heading length went from a hunch to "none of 245 exceeds eight".

## Design

### Two phases, and why

**Phase A, measurement, in the main session.** A script counts what is countable: heading lengths and grammar, opening shape, register sentences, the four length columns. Deterministic, cheap, and it cannot drift between runs because a model felt differently. This is what makes an eval tractable later.

**Phase B, judgement, in an isolated subagent.** Reads the pages against the persona, the comparator standard and the seven rules, and reports on order, completeness, necessity and register, which no script can count.

The main session merges both into one report.

### Isolation

Phase B runs in a temporary git worktree with the author's reasoning removed.

**Removed**: `CLAUDE.md`, `CODE-STYLE.md`, `process/`, `context/`, `skills/`, `.claude/`, `docs/`, `README.md`, `facts/`, `_freeze/`, `_site/`.

**Kept**: the `.qmd` sources, `_quarto.yml` (the reviewer needs the nav to know how she arrives at a page), and `R/` (hidden chunks affect what she sees).

Two details make this work rather than nominally work. The worktree gets a throwaway `CLAUDE.md` containing **only** the persona and the rules, because a subagent will look for one and finding nothing is worse than finding the right thing. And the brief states plainly that it is reading a site whose conventions it does not know, that it should judge against the reader and the comparators, and that there is no project documentation to consult.

`wq_fact()` calls render as literal `` `r wq_fact("key")` `` in the source. Harmless for structural review; the brief says so, so they are not reported as defects.

The reviewer reads `.qmd` source rather than rendered HTML, deliberately. The concern is the paragraphs, not the presentation, and source gives line numbers to cite.

### Report

Borrowed from `adv-cto-review` and `adv-data-science-review`, which solve the same problem of keeping a long review actionable.

```
# Reader review: [scope]

## Summary
3-4 sentences, worst thing first. If nothing clears the bar, say so and stop.

## Page scores                          [Phase A, deterministic]
page | prose | code | h | w/sec | head mean/max | >8 | verdict heads | opening | register
Sorted worst-first. This is the triage list.

## Findings                             [Phase B, judgement]
### Rule N: [name]: [Strong | Adequate | Needs improvement | Critical gap]
- **[high|medium|low]** page.qmd:LINE. The quote, the concrete reader failure, the fix.

## Assessed as sound
Pages and rules genuinely fine.

## Priority actions
Up to five, ordered by impact.

## Scope and limits
What it read, what it sampled, what it could not judge.
```

Capped at 250 lines.

### Discipline

Taken intact from `adv-cto-review/references/review-discipline.md`:

- Score each candidate finding 0-100 for confidence that it is a real problem worth attention. **Discard everything below 80.** Six findings acted on beat forty skimmed.
- Every finding needs a `page:line`, a verbatim quote, and a **concrete reader failure**: the moment she is confused, misled, or leaves. If that sentence cannot be written, the finding is not ready.
- "Assessed as sound" is a legitimate and expected outcome. A reader who sees only criticism discounts all of it, and much of this site is good: `ref/words.qmd` averages 1.9 words per heading and `ref/data.qmd` 3.2.
- Count, do not estimate.

**One rule from those skills is deliberately inverted.** Both say a documented reason wins unless there is evidence it is wrong. Here that would be fatal, because the documented reasoning is the thing under review. The reviewer does not read it, and writes as though the pages are all there is.

### Files

```
.claude/skills/reader-review/
  SKILL.md                    process, rules, report format, discipline bar
  references/reader.md        the persona, restated for someone who has never seen this repo
  references/comparators.md   the 245-heading evidence, the four books, the opening patterns
  scripts/measure.py          Phase A: scores table as markdown, and JSON alongside
```

Project-local, tracked, alongside the existing `.claude/skills/site-diagrams`. **Not** in `skills/`, which is symlinked to the research repo and forbidden from naming a repo, dataset or reader.

### Invocation

```
/reader-review                          all pages
/reader-review howdoi/monte-carlo.qmd   one page
/reader-review howdoi/                  one section
```

The single-page form is the one to use while fixing.

## Evaluation, deferred

The scores table is deterministic and emitted as JSON, so re-running after edits and diffing the numbers costs nothing. That gives **score movement** for free, and **stability** (run twice unedited, check the judgement findings match) for the price of a second run.

What it does not give is agreement with a human. A golden set, two or three pages hand-labelled and compared against the reviewer's findings, is the only way to establish that, and it is deliberately postponed until the skill has been run and its output judged useful. Building the measurement to be reproducible now is what keeps that option open at no cost.

## What this does not solve

Deciding what a page says. This reviews structure and register on the assumption that the facts are settled and correct, which is what `context/`, the upstream changelog and the honesty constraints in `CLAUDE.md` exist for. A page can pass all seven rules and be wrong.
