
# CLAUDE.md

Guidance for Claude Code (claude.ai/code) when working in this repository.

## What this is

A Quarto **website**: a working guide for an R user whose data lives in Databricks. It is not an R package, has no test suite, and is **not** a research project. It publishes conclusions, not the work that established them.

**Public by default.** Anything committed here may be published. Run `scripts/check-public.sh` before any push.

## The reader, and what follows from her

One person, and every decision serves her.

An **environmental research scientist**. PhD, probably post-doc. Fluent and comfortable in R, and not a computer scientist. Her data is in Databricks because that is where IT put it, not because she chose it. She is overwhelmed by the Databricks documentation and cannot navigate it to the thing she needs. Her horizon is short: paper deadlines, no platform team, no budget authority.

- **Do not explain R, the tidyverse, `sf`, `tidymodels` or statistics.** She reads all of them fluently. Explaining a bootstrap to her is condescending.
- **Do explain** driver versus executor, partitions, serialisation, pushdown, Unity Catalog, access modes, cluster lifecycle. That is where the whole explaining budget goes.
- **Translate platform vocabulary into hers, never the reverse.** She knows CRS, EPSG, catchments, raster versus vector, Monte Carlo, bootstrap, resamples, tuning. She may not know executor, partition, UDF, DBFS, artifact, serialisation. Where she and the platform have different words for one thing, the page title carries **hers**.
- **She can use compute, and cannot create it.** She can start and stop what she has. A new cluster means asking someone and waiting. So never help her choose a cluster: help her read the one she has and design inside it.
- **Not the audience:** a platform engineer, a Databricks administrator, or a sceptic who needs persuading that R can do this. She is already doing it.

## The rule that this repo exists to enforce

**This is a user guide, not a research record.** The findings behind it were established elsewhere, and the apparatus of establishing them stays there.

So, by default, **a finding does not belong on the site**. It earns a place only if it changes what she *does*. Ask that question of every sentence.

Specifically, none of the following belongs here: evidence tags on prose, measurement records, package build times, version-pin archaeology, driver byte tables, anything describing how a test environment was configured, or any framing of the form "here is why that objection is wrong". Her IT has most likely already solved the environment problems, and showing her their scars makes the stack look forbidding for no reason.

Where something genuinely is unsettled and she would make a bad decision without knowing, say so plainly in the prose. That is a sentence, not a badge.

## Honesty constraints

These are not stylistic. Getting one wrong makes the guide untrustworthy to this reader.

- **`spark_apply()` does distribute across worker machines**, observed on a two-worker cluster by counting distinct machine names. That answers "does it distribute at all" and nothing more: **never claim anything about how it scales**, about shuffle cost, or about behaviour at many nodes. Note also that the grouped path (`group_by =`) does not run on a current runtime.
- **Never assert anything about Standard access mode** in either direction. Never write "Standard access mode refuses R" unqualified: it refuses R *notebooks*, and a client connection to one works.
- **No timing presented as a benchmark or a comparison.** State the session size with any number you do give.
- **Sometimes she should just use her laptop.** If the data fits and nobody dictates where it lives, local R is faster to set up and better for her science. Naming this earns the credibility for everything else.
- **Do not sell the platform.** The goal is to get her work running, not to advocate.

## Never in this repository

- **No organisation name, customer name, contact, ticket reference or commercial term.** Say "a research scientist" or "a public-sector environmental body". Upstream open-source issue numbers are fine and useful.
- **No hard-coded warehouse id, cluster id or catalog name.** Read them with `Sys.getenv()`. `DATABRICKS_CLUSTER_ID` is per-user by construction, so a literal is wrong for everyone but its author.
- **No personal annotation.** Working notes go in `docs/`, which is gitignored.
- **Two data licences must survive** wherever the data is described: environmental agency data is OGL v3.0, and storm overflow locations are **CC BY 4.0, not OGL**.

## Commands

```bash
Rscript check-databricks-access.R    # smoke test: run this FIRST, and before blaming a document
scripts/check-public.sh              # publication safety. Run before any push, and after adding any file
quarto render                        # whole site -> _site/
quarto preview                       # live preview
R -e 'renv::restore()'               # restore the package environment
```

### Setup

`.Renviron` is gitignored and required. Copy `.Renviron.example`, fill in your own values, restart R. Without it `DATABRICKS_PATH` is unset and anything touching Databricks fails at `dbConnect()`.

Credentials are **ambient** on Posit Workbench, injected on sign-in. If `DATABRICKS_HOST` and `DATABRICKS_CONFIG_FILE` are unset, the session is not signed in. There is no `databricks` CLI here, so `databricks auth login` is never the fix. An expired token surfaces as an opaque ODBC driver error rather than anything auth-shaped: do not debug it as a warehouse, driver or network fault.

Packages come from **P3M** (`https://p3m.dev/cran/latest`), set in `.Rprofile`. Keep the generic URL: renv rewrites it per-distribution to the binary path.

## The site's five sections

- `concepts/`: one page, labelled "Get started" in the nav, building the mental model the rest of the site assumes. Read once, referred back to rather than repeated. `spark_apply()` is explained here, as a mechanism like `collect()`, because it spans several tasks and belongs to none of them.
- `howdoi/`: the task pages, one per thing she is trying to do. Titles are phrased as her question. The nav label is "Guides", following sparklyr and quarto.org rather than inventing a fresher word: in a signpost, familiarity beats distinctiveness for this reader.
- `example/`: one analysis in six stages, using the public water quality data, with the awkward parts left in. It exists to show continuity, which the task pages structurally cannot.
- `ref/`: lookups: words, licences, packages, symptoms, evidence tags.
- `admin/`: the only material addressed to someone other than the reader. `index.qmd` is for her (what to ask for, and how); `geospatial-setup.qmd` is for the administrator and is meant to be forwarded.

**Name things in her words, not the vendor's and not a framework's.** "Jobs" was rejected because it comes from jobs-to-be-done, and "Demo" because it is what a vendor calls it. The rule in "The reader, and what follows from her" about platform vocabulary applies equally to vocabulary from any other discipline she does not share.

**Nav labels are the exception, and convention beats freshness there.** This reader already reads quarto.org, sparklyr and pkgdown, so the navbar borrows their words: "Get started", "Guides", "Reference". There is no home entry, because the site title is the home link on all three. Page titles behind those labels still use her language, which is where the distinctiveness belongs.

The five sections map onto Diátaxis (explanation, how-to, tutorial, reference) with an audience-based fifth. That is a useful check when deciding where a new page goes, and not a source of labels.

**Every page except `index.qmd` is scaffolding.** Each carries settled headings, a few paragraphs stating the facts the finished page must contain, and no code. The site is deliberately sparse, and review happens at each stage: structure, then stated facts, then prose, then code. Do not write finished prose or add examples to a page unless asked for them.

## The site's presentation layer

The theme lives in `assets/site.scss` (light, on `cosmo`) and `assets/site-dark.scss` (dark, on `darkly`), wired up in `_quarto.yml` under `format: html:`. **Both files must stay declared.** Quarto compiles one stylesheet per mode, so dropping the dark one silently leaves dark mode as unmodified `darkly` rather than erroring.

These came from the `quarto-website` skill, which names them after their author and calls those filenames load-bearing. **They are deliberately renamed here, and must stay renamed**: the blocklist in `scripts/check-public.sh` matches a personal name as a word, and a filename reaches `_quarto.yml` as tracked, published text. So do not restore the skill's names, and if you re-copy the files, rename them again and strip the attribution comments from the headers. Nothing is lost by it: the compiled CSS is byte-identical either way.

Verifying a theme change means reading the compiled CSS, not the source. A SASS error can fail silently into an unstyled page, so `Output created:` is not evidence:

```bash
rm -rf _site/site_libs/bootstrap && quarto render   # or you may read stale CSS
grep -hoE '\-\-bs-link-color: #[0-9A-Fa-f]{6}|\-\-bs-body-bg: #fbfaf8|\-\-bs-root-font-size: 20px' \
  _site/site_libs/bootstrap/bootstrap*.min.css | sort -u
```

Expect `#447099` (light links), `#7494B1` (dark links), `#fbfaf8` (paper) and a 20px root. Two traps: the filenames are content-hashed, so an unglobbed path finds nothing and reads exactly like a pass; and the root type appears as `--bs-root-font-size`, never as `html{font-size:20px}`.

The navbar has been checked at narrow widths and collapses cleanly, so five sections with four dropdowns is not too wide.

One thing still unchecked: the theme caps the measure at `42rem` on a 20px root, and `index.qmd` leans on code blocks with aligned right-hand comments (`#   runs on Databricks`). If those wrap, the alignment stops carrying meaning. Look at it in `quarto preview`, in both modes, before trusting it.

## Two connection paths

- `odbc::databricks()` is the default for queries via `dbplyr`.
- `brickster::DatabricksSQL()` is **required** for `BINARY` columns, which is how geometry is stored. `odbc` silently returns only part of a `BINARY` value, so geometry cannot travel over the ODBC path. This is not a preference (`r-dbi/odbc#1024`).

## `skills/`

Five portable skills covering connections, `brickster`, Unity Catalog, compute lifecycle and parallel methods. Start at `skills/README.md`; `r-databricks-connections` routes to the rest.

**They are shared with the research repo by symlink**, which points here. This is the canonical copy, so an edit here changes both. Nothing in `skills/` may name a repo, a dataset, a customer or any identifier.

Note that the skills keep evidence tags in their own text. That is correct: they are reference material for an agent deciding what to trust. The site's prose does not.

## House style

- **UK English.** `-ise` not `-ize`. Code identifiers keep their real spelling.
- **Avoid em-dashes.** Use a comma, a colon, parentheses, or two sentences.
- **Sentence case in headings.**
- **Bold inside a line, never as a paragraph lead-in.** A bolded lead-in wants to be a real heading.
- **Write as if to one person**, second person, active voice.
- **Lead with the answer.** State the conclusion, then support it.
- **Do not hard-wrap.** One line per paragraph in every `.md` and `.qmd` file, soft-wrapped by the editor. Code blocks keep their own line structure and are formatted for code readability. Pipe tables and hard line breaks keep theirs too.
- **Base pipe `|>` only, never `%>%`.** Most Spark-related R documentation uses `%>%`, so translate anything borrowed.
- **Prefer saying where the code runs** to saying "pushdown". At most once per page, as a parenthetical gloss, so the term still connects to vendor documentation.

## Where the findings come from

The research that established what this guide says lives in a separate, private repository. It notifies this one through a downstream changelog rather than by sharing files.

Each page here should carry a short note naming the claims it rests on, phrased as claims rather than file references, so a changelog entry can be matched to the pages it affects without either repo knowing the other's internals.

### What has been taken from the changelog

Entries are dated and newest-first upstream, so a date and a heading is enough to say where the guide has read up to. The marker below is the only state this side keeps about the other repo, and it deliberately records no path, no commit and no file name.

**Consumed through: 2026-08-22, "Standard access mode does not support R" is wrong as usually written.**

To bring the guide up to date, read the entries above that marker, match each `Bears on:` line against the `rests on:` lines here, change what needs changing, then move the marker. Matching is a judgement, not a string comparison: an entry can leave a claim standing but incomplete, which reads as agreement until you look at what it adds. Move the marker only for entries you have actually acted on or actively declined, and note a declined one in the commit message, or the next reader will re-litigate it.

Three entries above the current marker are known not to be spent. Two of them, the river network reading as basins and the silent `config` profile fallback, bear on no page yet. The third, moving a cluster to DBR 18, contradicts version pins that `admin/geospatial-setup.qmd` still rests on, and settling it means deciding which runtime the guide addresses.
