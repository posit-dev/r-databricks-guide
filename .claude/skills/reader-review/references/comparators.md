# The external standard

The site under review must be judged against documentation written for the same kind of reader by authors this community already trusts. This file records what those books actually do, measured rather than remembered.

Five books, five author teams, all writing technical documentation for a fluent R user:

| Book | Authors |
|----|----|
| [R for Data Science (2e)](https://r4ds.hadley.nz/) | Wickham, Çetinkaya-Rundel, Grolemund |
| [R Packages (2e)](https://r-pkgs.org/) | Wickham, Bryan |
| [Feature Engineering and Selection](https://feat.engineering/) | Kuhn, Johnson |
| [Supervised Machine Learning for Text Analysis in R](https://smltar.com/) | Hvitfeldt, Silge |
| [Text Mining with R](https://www.tidytextmining.com/) | Silge, Robinson |

They are comparators for **form, not content**: what a chapter looks like, not what it says. Never fault a page for lacking a topic one of these books covers.

## Heading form

245 H2 and H3 headings, section numbers stripped, measured 2026-09-02.

| Source | n | mean | median | max | ≤5 words | >8 words |
|----|----|----|----|----|----|----|
| r4ds + r-pkgs (8 chapters) | 140 | 2.8 | 3 | 8 | 96% | 0% |
| feat.engineering (4 chapters) | 39 | 3.2 | 2 | 8 | 82% | 0% |
| smltar (3 chapters) | 45 | 3.6 | 4 | 6 | 91% | 0% |
| tidytextmining (3 chapters) | 21 | 3.3 | 3 | 6 | 86% | 0% |

**Not one heading in 245 exceeds eight words.** Four independent author teams agree, so this is R-community documentation form rather than one author's habit.

Even the longest are **labels for a thing**, never claims about it:

- "Creating Dummy Variables for Unordered Categories"
- "Models that are Resistant to Missing Values"
- "Most common positive and negative words"
- "Depending on the development version of a package"
- "Discretize Predictors as a Last Resort" (an opinion, but carried as a six-word imperative)

Question headings are legitimate and rare: 0% in feat.engineering and tidytextmining, 2% in Wickham, 9% in smltar. The longest question in 245 headings is seven words ("Why is formal testing worth the trouble?").

## Openings

Two patterns, both acceptable.

**Naming her task**, which is Wickham's habit:

> "In this chapter, you'll learn tools for iteration, repeatedly performing the same action on different objects." (r4ds, iteration)

> "A huge amount of data lives in databases, so it's essential that you know how to access it." (r4ds, databases)

**Stating a fact about the domain**, which the others prefer:

> "When we deal with text, often documents contain different versions of one base word, often called a *stem*." (smltar)

> "Missing data are **not** rare in real data sets." (feat.engineering)

What every one of them shares: **the opening fact is about her world**, verifiable from her own data before she reads anything. Word stems exist in text. Missing data is common. Databases hold a lot of data.

None of them opens with a finding whose only source is the authors' own testing of a product, and none opens by correcting an expectation the reader has not been shown to hold. That is the distinction the review turns on.

## Scope

Wickham states it as concrete items, and it is worth adopting even though the other books do not always:

> "Learning functional programming can easily veer into the abstract, but in this chapter we'll keep things concrete by focusing on three common tasks: modifying multiple columns, reading multiple files, and saving multiple objects."

r4ds also carries an explicit **Prerequisites** section at the start of a chapter, stating what the reader needs before beginning.

## Running order

Ordered by the reader's path through the work, not by what surprised the author.

- Pusto's parallel-processing chapter: your computer, then a virtual machine, then a cluster. Ascending scale, which is the order she will try them in.
- Niehaus's Monte Carlo guide: review, serial versus parallel, seeds, thread competition, parameter grids, functions, do's and don'ts, examples. The order you hit the problems as you build one.
- r4ds databases: database basics, connecting, dbplyr basics, SQL, function translations. Each step needs the one before it.

## Chapter length, for reference only

Comparator chapters run to a median of about 3,900 words (range 2,000 to 12,400). **Do not hold the site to this.** A book chapter is read in sequence and teaches; a task page is arrived at singly to solve one problem. The right comparator for a task page would be a vignette or a how-to article, which has not been measured. Length is reported in the scores table and is not a rule.

## The two subject-matter comparators, and why they are excluded

[Niehaus's Monte Carlo guide](https://jmniehaus.github.io/montes.html) and [Designing Simulations in R](https://jepusto.github.io/Designing-Simulations-in-R/) were read while establishing the problem, and their running order is quoted above because it illustrates the pattern well.

They are **not** a coverage standard. Both teach simulation design to people learning it, and this reader already knows it. Faulting the site for lacking their "Parameter Grids" or "Performance Measures" would produce exactly the condescension the site is right to avoid.
