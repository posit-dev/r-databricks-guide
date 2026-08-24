
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
scripts/check-freeze.sh              # freeze cache matches source. Run after editing anything in example/
scripts/install-hooks.sh             # once per clone: pre-push runs both checks
quarto render                        # whole site -> _site/
quarto preview                       # live preview
R -e 'renv::restore()'               # restore the package environment
```

### Editing `example/` means re-rendering it

The site publishes from a committed `_freeze/` cache, and every executable page sets `freeze: true`. That means **never re-execute**, not "re-execute when the source changes". So editing one of those pages and pushing publishes the *previous* output with the edit missing: no error, nothing in the render log, exit 0. Established by test on 2026-08-24, not inferred.

The freeze hash is a plain md5 of the `.qmd`, so any edit invalidates it, prose included. After changing anything under `example/`, re-render that page with credentials and commit `_freeze/` with the edit. `scripts/check-freeze.sh` catches it either way, in the pre-push hook and again in CI, but the fix always requires a credentialed local render because CI has no R.

Corollary worth knowing before reaching for it: `cache: true` does nothing for this. Under `freeze: true` a prose edit re-executes nothing locally either, so there is no loop for a chunk cache to speed up.

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
grep -hoE '\-\-bs-link-color: #[0-9A-Fa-f]{6}|\-\-bs-body-bg: #fbfaf8|\-\-bs-root-font-size: 17px' \
  _site/site_libs/bootstrap/bootstrap*.min.css | sort -u
```

Expect `#447099` (light links), `#7494B1` (dark links), `#fbfaf8` (paper) and a 17px root. Two traps: the filenames are content-hashed, so an unglobbed path finds nothing and reads exactly like a pass; and the root type appears as `--bs-root-font-size`, never as `html{font-size:17px}`.

The navbar has been checked at narrow widths and collapses cleanly, so five sections with four dropdowns is not too wide.

The two annotated code blocks on `index.qmd` are **stacked full-width**, not side by side, and the code is deliberately terse. Both constraints are load-bearing, so keep them if you edit the page.

The right-hand comments (`#   on Databricks`, `# <== how much crosses?`) are aligned into a column, and that alignment is the whole point of the examples: it is how the page shows that one line decides where the work happens. When a line exceeds the measure it wraps, the column breaks, and the meaning goes with it. `code-overflow: wrap` means that degrades silently rather than showing a scrollbar, so nothing warns you.

**Do the width arithmetic before lengthening a line**, because eyeballing it is what got this wrong once already. Code renders at `0.875em` on a 17px root, and Source Code Pro advances 0.6em, so a character is 8.9px.

The measure is set with `$grid-body-width`, which **must be `$grid-body-width` and must be in `px`**. Quarto has no `$content-max-width`: setting one compiles cleanly, changes nothing, and leaves the site at the 800px default while the SCSS reads as though the measure were set. This repo shipped that bug until it was measured. A `rem` value fails compilation outright, against `quarto-math.min(500px, $grid-body-column-max)`.

Quarto also subtracts a `3em` gutter, so the usable column is the variable less 51px at a 17px root, and then less about 16px of `pre` padding. At the 800px set here that is 733px:

- full-width: 733px, about **82 characters**
- one `.g-col-md-6` of a two-column `.grid`: 350px, about **39 characters**

Grep the compiled CSS for `800px` to confirm it applied: it lands inside the `calc()` in the grid definition, never on a `max-width` property, and zero hits means the variable name was wrong.

That 39 is why side by side was abandoned: it cannot hold an annotated pipeline. Terse also survives a phone better than the measure alone suggests, which is the second reason to keep it. The navbar is fine when narrow, already checked.

## Two connection paths

- `odbc::databricks()` is the default for queries via `dbplyr`.
- `brickster::DatabricksSQL()` is **required** for `BINARY` columns, which is how geometry is stored. `odbc` silently returns only part of a `BINARY` value, so geometry cannot travel over the ODBC path. This is not a preference (`r-dbi/odbc#1024`).

## `context/`

**What the three neighbouring documentation sites already say.** This guide sits in a seam: sparklyr's documentation at `spark.posit.co`, brickster's at `databrickslabs.github.io/brickster`, and Posit's own at `docs.posit.co/data-sources/user/databricks/`. Each is good at what it covers and none covers this reader. `context/` records what each says, so a page here can link instead of repeating, avoid contradicting, and be clear about which gap it fills.

**Read the relevant file before writing prose on any page that touches sparklyr or brickster.** Start at `context/README.md`, which states the seam argument. The sparklyr and brickster files were written from a reading on 2026-08-23; the Posit one is a placeholder naming what to establish.

Three things they change, in the order they save the most work:

- **Several upstream pages will break her if she follows them correctly**, notably `memory = TRUE` and `compute()` from sparklyr's caching guide. Each file marks which pages to link, which to link with a warning, and which not to link at all. The dangerous ones are good `ref/when-it-breaks.qmd` entries, because that page is symptom-shaped.
- **Some facts this guide derives for itself are stated plainly upstream**, including the broad `sdf_*` exclusion over Spark Connect and the serverless `spark_apply()` prohibition. Citing upstream is stronger and cheaper than resting on our own testing alone.
- **Neither site has any geospatial story**, and brickster's backend silently writes an `sfc` column as `STRING`. That is the clearest gap, and the part of this guide with the least competition.

Where an upstream claim and a measurement here disagree, the honesty constraints above win: they are deliberately stricter than upstream. The clearest case is `spark_apply()`, where upstream's distribution claim is architectural and asserted rather than demonstrated, so it cannot be used to widen what this guide says.

These files are tracked and therefore published, so they are subject to `scripts/check-public.sh` like anything else. They are not part of the site: `_quarto.yml` has an explicit render list and `context/` is not on it. Do not add it, and do not link to these files from a page.

## `skills/`

Five portable skills covering connections, `brickster`, Unity Catalog, compute lifecycle and parallel methods. Start at `skills/README.md`; `r-databricks-connections` routes to the rest.

**They are shared with the research repo by symlink**, which points here. This is the canonical copy, so an edit here changes both. Nothing in `skills/` may name a repo, a dataset, a customer or any identifier.

Note that the skills keep evidence tags in their own text. That is correct: they are reference material for an agent deciding what to trust. The site's prose does not.

### The research repo writes skill code; this repo decides what is published

Upstream contributes to `skills/` directly, and specifically contributes **runnable code examples**: scripts it has actually run on a cluster, alongside the findings they establish. That is the right division, because it can run things this repo cannot, and an example nobody has executed is worth less than none.

**Publication authority stays here.** Because the symlink makes this the copy that gets committed, and this repo is public by default, nothing reaches the outside world without passing through it. So treat an upstream contribution as a submission, not as a merge already made:

- **Run `scripts/check-public.sh` before committing it.** The check scans only what git tracks, so new untracked files are invisible to it until added. Add them first, or run the patterns against the new paths by hand. It also skips `renv.lock`, whose CRAN metadata quotes both a maintainer name and `%>%`: that file is generated, so read a real identifier in it as a reason to regenerate rather than to edit.
- **Read every script for identifiers.** A cluster id, warehouse id, catalog or host name must be read with `Sys.getenv()`. `DATABRICKS_CLUSTER_ID` is per-user by construction.
- **Hold it to this repo's conventions**, which upstream has no reason to share: base pipe, no em-dashes, UK English, and no repo, dataset or customer name.
- **Rewrite freely.** Upstream's wording is a draft here. Keeping the measurement and changing the prose around it is normal and needs no negotiation.

Editing a contributed script is fine and expected, but the measurements in it are upstream's evidence: change what a script *says* without re-running it, never what it *found*.

## House style

- **UK English.** `-ise` not `-ize`. Code identifiers keep their real spelling.
- **Avoid em-dashes.** Use a comma, a colon, parentheses, or two sentences.
- **Sentence case in headings.**
- **Bold inside a line, never as a paragraph lead-in.** A bolded lead-in wants to be a real heading.
- **Write as if to one person**, second person, active voice.
- **Lead with the answer.** State the conclusion, then support it.
- **Do not hard-wrap.** One line per paragraph in every `.md` and `.qmd` file, soft-wrapped by the editor. Code blocks keep their own line structure and are formatted for code readability. Pipe tables and hard line breaks keep theirs too.
- **Base pipe `|>` only, never `%>%`.** Most Spark-related R documentation uses `%>%`, so translate anything borrowed.
- **Code style is in `CODE-STYLE.md`, and it is not advisory.** The tidyverse is the default idiom because the reader is fluent in it: `glue()` rather than `paste()` or `sprintf()`, `cli` rather than `message()` or `stop()`, `dplyr` and `purrr` rather than `[` and `lapply()`. `example/reducing.qmd` carries the reference preamble. Read that file before writing R for this repo.
- **Prefer saying where the code runs** to saying "pushdown". At most once per page, as a parenthetical gloss, so the term still connects to vendor documentation.

## Where the findings come from

The research that established what this guide says lives in a separate, private repository. It reaches this one two ways, and they carry different things. **Facts arrive as a downstream changelog**, prose to be read and acted on, never files to be copied. **Code arrives in `skills/`**, as runnable examples upstream has executed, written into the shared copy directly. Nothing else crosses: the site's own pages are written here.

So a finding that changes what the guide says comes through the changelog even when the script demonstrating it lands in `skills/`. If a skill gains an example whose claim is not in the changelog, that is a gap upstream needs to close, not a fact to promote onto a page.

Each page here should carry a short note naming the claims it rests on, phrased as claims rather than file references, so a changelog entry can be matched to the pages it affects without either repo knowing the other's internals.

### What has been taken from the changelog

Entries are dated and newest-first upstream, so a date and a heading is enough to say where the guide has read up to. The marker below is the only state this side keeps about the other repo, and it deliberately records no path, no commit and no file name.

**Consumed through: 2026-08-22, "Standard access mode does not support R" is wrong as usually written.**

To bring the guide up to date, read the entries above that marker, match each `Bears on:` line against the `rests on:` lines here, change what needs changing, then move the marker. Matching is a judgement, not a string comparison: an entry can leave a claim standing but incomplete, which reads as agreement until you look at what it adds. Move the marker only for entries you have actually acted on or actively declined, and note a declined one in the commit message, or the next reader will re-litigate it.

Three entries above the current marker are known not to be spent. Two of them, the river network reading as basins and the silent `config` profile fallback, bear on no page yet. The third, moving a cluster to DBR 18, contradicts version pins that `admin/geospatial-setup.qmd` still rests on, and settling it means deciding which runtime the guide addresses.
