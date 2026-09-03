---
name: reader-review
description: 'Reviews whether this site''s pages are structured for the reader rather than for the people who researched them: opening, scope, heading form, running order, enumeration, completeness, necessity and register. Judged against five R-community books and an isolated reading of the pages. Use when asked to review the reading experience, page structure, or whether a page is fit for its audience. Not for facts, code correctness or house style.'
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Agent
---

# Reader review

You are checking whether these pages are **built for the reader or for their authors**.

The facts on this site are careful and the prose reads well sentence by sentence. The defect this review exists to find is structural: material ordered by what surprised the people who established it, headings that state a conclusion rather than name a topic, and openings that answer a question the reader has not asked.

Read these two before anything else:

1. `references/reader.md`: who she is, what she already knows, and how she arrives at a page.
2. `references/comparators.md`: the measured external standard, 245 headings across five R-community books.

`process/DESIGN-reader-review.md` in the repository records the evidence behind every threshold here, and why the review is built this way.

## Scope

`$ARGUMENTS` may name a page, a directory, or nothing.

```
/reader-review                          every page
/reader-review howdoi/simulate-locally.qmd   one page
/reader-review howdoi/                  one section
```

Default to the whole site. The single-page form is the one to use while fixing.

### What counts as unreviewed

A page that has been **split, renamed, merged, or had its sections reordered is unreviewed**, whatever the site's last review said. Its score in an old run describes a page that no longer exists.

This is not a formality. Both times a defect escaped this skill, it escaped this way: `howdoi/monte-carlo.qmd` was split into two pages after a review, and the halves inherited a clean bill of health they had never earned. Check `git log --oneline -15` for a rename or a split before trusting a previous run.

## This runs before `writing-voice`, not after

The two skills have an order, and it only runs one way.

**Structure first.** Every heading this review renames orphans the prose beneath it: a pronoun whose antecedent was in the old heading, or a first sentence that only parsed as a continuation of it. Measured on 2026-09-03, a pass over 85 renames left nine sections defective that way. Fixing sentences before the structure moves means fixing them twice.

**Then prose.** `writing-voice` catches what is left: fragments, stripped bold lead-ins, passives, sixty words doing twenty words' work.

The reverse dependency does not exist, because fixing a fragment never invalidates a heading.

So after acting on any finding here that **moves, renames, splits or merges a section**, run `writing-voice` over the sections you touched. Not the whole site: the sections you touched.

## Two phases

**Phase A is deterministic.** A script counts what is countable. Run it yourself, in this repository.

**Phase B is judgement.** An isolated subagent reads the pages without access to this project's own documentation, because that documentation argues for the style under review and a reviewer that reads it will find the pages compliant.

Then merge both into one report.

### Phase A: measure

```bash
python3 .claude/skills/reader-review/scripts/measure.py [targets] --detail \
  --json /tmp/reader-review.json
```

The table it prints goes into the report unchanged. Do not recompute or round its numbers.

Columns: prose words, code lines, heading count, words per section, heading mean and max, headings over eight words, verdict headings, whether the opening is corrective, whether it states scope, register hits, and a composite triage rank.

The script decides nothing. A register hit is a candidate, not a finding, and Phase B judges whether it is legitimate for its page.

### Phase B: judge, in isolation

Build a scrubbed worktree, then dispatch one subagent per section (or a single agent for one page).

```bash
SKILL=.claude/skills/reader-review               # from the repository root
git worktree add /tmp/reader-review-wt HEAD
cp "$SKILL/references/reader.md" /tmp/reader-review-wt/CLAUDE.md
cd /tmp/reader-review-wt
rm -rf CODE-STYLE.md README.md process context skills .claude docs facts \
       scripts _freeze _site *.rds *.R
```

Note the order: `reader.md` is copied in **before** `CLAUDE.md` is removed by the same command, so copy first and let the `rm` list omit it.

**Removed** because it is the author's reasoning: `CLAUDE.md`, `CODE-STYLE.md`, `README.md`, `process/`, `context/`, `skills/`, `.claude/`, `docs/`, `facts/`, and `scripts/`, which reveals the method through `check-facts.R` and `rerender.sh`. The `.rds` files and root-level `.R` scripts go too, as noise.

**Kept** because the reader is affected by it: the `.qmd` sources, `_quarto.yml` (how she arrives at a page), and `R/` (hidden chunks change what she sees).

A subagent will look for a `CLAUDE.md` and finding none is worse than finding the right one, so the worktree gets `reader.md` under that name and nothing else.

Tell each subagent, in the brief itself:

- It is reading a documentation site whose conventions it does not know, and there is **no project documentation to consult**. The pages are all there is.
- The persona and the comparator standard, in full.
- The eight rules below, and the two exclusions.
- The confidence bar, in full.
- That `` `r wq_fact("key")` `` in the source is a value inserted at render time, not a defect.
- Which pages are its own, and that it must not report on any other.

Remove the worktree when the review is written: `git worktree remove /tmp/reader-review-wt`.

## The eight rules

Rules 1 to 3 are largely countable and Phase A pre-computes them. Rules 4 to 8 are the reason Phase B exists.

**1. Opening.** The opening establishes something about her world or her task, and pivots within two paragraphs to what the page does about it. A domain fact, a task statement, or a problem she recognises all qualify.

*Test*: could she have known this before reading the site? If the only source is our own testing of the platform, it fails. It also fails if the page opens by correcting an expectation it has not yet established she holds.

**2. Scope.** The opening says what the page covers, as concrete items. Not a requirement that any particular phrase appears; a requirement that she can tell what she is about to get without reading the headings.

**3. Headings.** Three tests, two of form and one of fit.

- *Length*: target 2 to 4 words, flag over 6, fail over 8. Questions may run to 7 and should be rare.
- *Grammar*: a heading is a noun phrase or an imperative. A heading whose own main verb asserts something is a **verdict** and fails.

A verdict heading is only navigable to someone who already knows the question, which is the author. She scans for "how do I use my cores" and finds "Memory is not the constraint here".

*Exception*: on a symptom-shaped page, the heading is the symptom she is matching against what she saw, so it has to carry enough to be recognised. `ref/when-it-breaks.qmd` is the one such page here, and "A spatial join or point-in-polygon count is off by a handful of rows" is right at thirteen words. Do not shorten a symptom into a label.

**A third test, and it is not about form.** Does the section deliver what its heading names?

*Test*: read the heading, then the section, and ask whether she got what she was promised. Both directions are findings. A heading that oversells sends her to the wrong section; one that undersells means she skips the section she needed.

The tell for the first is a section that opens by taking the heading back. `## Whether it spread across machines` opening "Not answered here, and worth being straight about." is the case that prompted this test, and the section went on to answer it: `distinct_machines` counts the machines. What was genuinely unanswered was how it *scales*, which is a caveat in the last paragraph rather than the section's subject. The heading was describing the caveat.

This is invisible to both tests above. That heading was five words and a clean noun phrase, so it passed on length and on grammar, and it was still pointing at the wrong thing.

**4. Order.** Is the running order her path through the work? Specifically: does any reassurance, caveat or negation arrive **before** the thing it qualifies? Does the page say what it covers before its first code block?

Deliberately narrow. Order is a check on a permutation, so it cannot see a missing section and it will find a good position for a section that should not exist. Those are rules 6 and 7.

**5. Enumeration.** A section that enumerates should show the enumeration.

Where prose names N things and then treats each in turn, the N belong in a list or in subheadings, not in a sentence she has to hold in her head while she reads four paragraphs. She is scanning for her item, and a sentence gives her nothing to scan.

*Test*: count the treatments. If a paragraph exists per item, or the paragraphs open with "It uses... It returns... And the seed is...", the list is already there and only the markup is missing.

Also check that **the treatment order matches the naming order.** Where it does not, the prose ends up reconciling two sequences by hand, and every paragraph pays for it: "Floating point is the smallest", "Aggregation order is the next", "The fourth is the largest" is a severity ranking running across a list order, so a reader tracking either one is tripped by the other. One of the two orderings is wrong; usually the naming order should be changed to match the treatment.

Two items is not an enumeration, and a list whose items get a sentence each is fine as prose. This is for three or more, each with its own paragraph.

**6. Completeness.** Walk the page as a task, not as a document. At each step, can she do the next thing with what she has been given, or must she leave?

*Reference*: the page's own title and subtitle, read as a contract, plus her task. **Not** comparator coverage.

Report a gap only by naming the step she cannot take. "Could say more about X" is not a finding.

**7. Necessity.** For each section, whose question does it answer?

*Test*: if she skipped this section entirely, what would go wrong? Nothing but missing an interesting fact means it is the author's. An error, a bad choice, or a wasted day means it is hers.

Three verdicts: **keep**, **misplaced** (hers, but later or on another page), **removable** (the author's). A removable finding must name the harm of skipping, which is what stops this rule turning into deletion for its own sake.

**8. Register.** Flag sentences whose audience is someone **judging the guide** rather than someone using it:

- provenance about our own testing: "observed on a two-worker cluster", "single run in a Workbench session, not a benchmark"
- research vocabulary: "the memory finding", which refers to an earlier section as a research artefact
- author-facing notes: "that is the entire claim, and there is nothing else to teach here"

Not research register in general. "Missing data are not rare in real data sets" is fine: it describes the world, not what we did to find out about the world. That distinction is the whole test.

**Count and locate; do not recommend deletion.** Some of this language is deliberate honesty the site has chosen. The value is seeing where it clusters.

*Carve-out*: a page whose subject is verification or diagnosis will legitimately score high here, because provenance is its topic. Judge, do not merely count.

## Never flag

- **Accuracy, code correctness, or platform behaviour.** You have no cluster and cannot check. Structure and register only.
- **House style**: UK English, em-dashes, sentence case, base pipe versus magrittr. Other checks own these, and duplicating them buries the structural findings in spelling noise.
- **Sentence-level prose quality**: a clumsy sentence, a passive, a paragraph that takes sixty words to say twenty. The `writing-voice` skill owns those, including the stripped bold lead-in, which is a paragraph opening that labels rather than says. Rule 5 is the one place the two meet, and it is here because a hidden enumeration is a *structural* failure: she cannot scan for her item. If the fix is rewording rather than adding a list or subheadings, it belongs to `writing-voice`.

## Confidence bar

Score every candidate finding 0 to 100 for your confidence that it is a real problem worth the reader's attention.

- **0** false positive, or outside scope.
- **25** might be real, could not verify.
- **50** verified but minor.
- **75** verified, she will hit it, and the page is insufficient as written.
- **100** confirmed by direct evidence, happens on every reading.

**Discard everything below 80.** Six findings acted on beat forty skimmed. If a page has nothing at or above 80, say the page looks sound and move on.

Every finding needs:

- a `page.qmd:LINE` reference,
- the **verbatim quote**, and
- a **concrete reader failure**: the moment she is confused, misled, or leaves. If you cannot write that sentence, the finding is not ready.

**Count, do not estimate.** If you say six headings are verdicts, you have counted six.

**One rule is deliberately inverted from other review skills in this environment.** They defer to a documented reason. Here the documented reasoning is the thing under review, so it earns no deference and Phase B never reads it.

## Length

Reported, never ruled on. There is not yet evidence for a threshold: a book chapter is read in sequence and teaches, while a task page is arrived at singly, so the comparators cannot settle it.

Length may only **sharpen a finding that already cleared the bar**: mark a page *possibly too long* when its length coincides with a rule 6 removable section, and *possibly too thin* when it coincides with a rule 5 gap. Length alone is never a finding.

Watch words-per-section rather than total words. A page can be fragmented (many short sections) or dense (few long ones), and those are opposite failures.

## Report

Under 250 lines.

```
# Reader review: [scope]

## Summary
Three or four sentences, worst thing first. If nothing clears the bar, say so and stop.

## Page scores
[Phase A table, unchanged]

## Findings

### Rule N: [name]: [Strong | Adequate | Needs improvement | Critical gap]

What works here, briefly. Genuine strengths, not consolation.

- **[high|medium|low]** `page.qmd:LINE`. Quote, the concrete reader failure, the fix.

[Only rules with findings at or above the bar. Most severe first.]

## Assessed as sound
One line each, for pages and rules checked and found in good shape. A short findings
list and a long section here is a legitimate outcome.

## Priority actions
Up to five, ordered by impact, each with the reason it ranks there. Fewer is normal.

## Scope and limits
What was read, what was sampled, what could not be judged.
```

## Guidelines

- **Lead with the answer.** The summary and the priority actions are what get acted on.
- **Name real strengths.** A reader who sees only criticism discounts all of it. Several pages here are exemplary on heading form and should be named as the standard the others should meet.
- **Rank by consequence to her**, not by how many rules a page breaks. An opening that sends her to the wrong page outranks four long headings.
- **No manufactured findings.** The rules are a prompt for attention, not a quota.
- **Suggest, do not rewrite.** A finding names the defect and the shape of the fix. Rewriting a page is a separate request.
