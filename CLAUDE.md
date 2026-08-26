
# CLAUDE.md

Guidance for Claude Code (claude.ai/code) when working in this repository.

## What this is

A Quarto **website**: a working guide for an R user whose data lives in Databricks. It is not an R package, has no test suite, and is **not** a research project. It publishes conclusions, not the work that established them.

**Public by default.** Anything committed here may be published. Run `scripts/check-public.sh` before any push.

## Start here

Read this file, then go to whichever of these your task touches. Everything else in this file is detail you can come back for.

| Doing what | Read |
|----|----|
| Writing or editing R on a page | `CODE-STYLE.md`, then `skills/r-databricks-unity-catalog` |
| Connecting to Databricks at all | `skills/r-databricks-connections`, which routes to the rest of `skills/` |
| Editing anything under `example/` | "Editing `example/` means re-rendering it" below, before you touch the page |
| Writing prose on a page | "House style" below, and the `writing-voice` skill |
| Drafting more than one page | `process/drafting-pages.md` |
| Anything touching sparklyr or brickster prose | `context/README.md` first |
| Theme, CSS, or the width of a code line | `process/presentation-layer.md` |
| Acting on an upstream changelog entry | `process/upstream-changelog.md` |

Four rules that are not stylistic, and that cost real time when missed:

1. **A page's output is executed, never typed.** See "Never paste code output".
2. **`freeze: true` means never re-execute.** Editing an executable page and pushing publishes the *old* output at exit 0. Use `scripts/rerender.sh`, not `quarto render <page>`.
3. **Never stop a cluster** unless asked. Start freely; `scripts/start-cluster.R` is idempotent.
4. **Prefer `dplyr` to SQL strings.** Neither the spatial functions nor the `odbc` `BINARY` bug is a reason to reach for `dbGetQuery()`.

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

Three scripts do the repeated work, so the sequences below are not retyped:

```bash
scripts/start-cluster.R              # idempotent start; --status reports and starts nothing
scripts/rerender.sh <page.qmd>       # refresh one frozen page; --stale does every stale one
scripts/rebuild-site.sh              # drop every cache and rebuild from source; --dry-run first
scripts/page-md.sh <page.qmd>        # print a page's executed output; --list shows what is cached
```

**Read the markdown for content, the HTML only for rendering.** `page-md.sh` prints what a page actually produced, from the freeze cache: numbers, output, a leaked string. Reaching for `_site/*.html` to check a number means grepping past the whole template for something that was sitting in plain text all along. Keep the HTML for things pandoc decides, such as whether a cross-reference resolved or a callout rendered.

`rerender.sh` is the one to reach for after editing anything under `example/`: `quarto render <page>` alone will **not** refresh a frozen page, because freeze means never re-execute, so the cache has to be dropped first and that is what the script does. `rebuild-site.sh` is the whole-site version, for testing that the site still builds from nothing.

`rerender.sh` deletes a page's cache before rebuilding it, which is what forces re-execution and also what makes it unsafe to interrupt: killed in between, a page is left with no cache at all. Recover with `git checkout -- _freeze`. Do not run it under a timeout shorter than the render, because a cluster-backed page takes minutes.

Both refuse to run against a dirty tree. They delete tracked files under `_freeze/` that only a credentialed render can rebuild, so the refusal is the guard that keeps a bad rebuild one `git checkout` away. Both also stop before rendering `example/bootstrap.qmd` without `WQ_RUN_CLUSTER=true`, since that render silently drops the page's cluster output.

### Editing `example/` means re-rendering it

The site publishes from a committed `_freeze/` cache, and every executable page sets `freeze: true`. That means **never re-execute**, not "re-execute when the source changes". So editing one of those pages and pushing publishes the *previous* output with the edit missing: no error, nothing in the render log, exit 0. Established by test on 2026-08-24, not inferred.

The freeze hash is a plain md5 of the `.qmd`, so any edit invalidates it, prose included. After changing anything under `example/`, re-render that page with credentials and commit `_freeze/` with the edit. `scripts/check-freeze.sh` catches it either way, in the pre-push hook and again in CI, but the fix always requires a credentialed local render because CI has no R.

The hash is necessary and not sufficient, because a project-level `quarto render` refreshes it without re-executing: new source, new hash, old output. `check-freeze.sh` therefore also runs `scripts/check-freeze-code.py`, which compares the code echoed into the cached output against the code in the source. That is why re-rendering goes through `scripts/rerender.sh`, which drops the cache first. See `process/PROBLEM-freeze-cache-staleness.md`.

Corollary worth knowing before reaching for it: `cache: true` does nothing for this. Under `freeze: true` a prose edit re-executes nothing locally either, so there is no loop for a chunk cache to speed up.

### Never terminate a cluster

**Start clusters when the work needs them; never stop them.** Stopping is the user's call alone, and no agent should call `db_cluster_terminate()` or `db_sql_warehouse_stop()` here, including after finishing a task and including on a cluster it started itself.

The reason is that VM provisioning is the gating cost and nothing on this side reduces it. A cold start is roughly seven minutes, measured at 438 s single-node and 418 s multi-node with the init script already attached. Tidying up after a task therefore does not save a wait, it schedules one for whoever works next. Both clusters auto-terminate at 90 minutes, so an idle one stops by itself without help.

Note that the init script is a cost *added* to that start, not a way to shorten it: it runs on every node during boot. Getting binaries rather than source keeps it near a minute instead of about fifteen, which is worth doing and still leaves the seven minutes untouched.

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

**The site is drafted, and a page that is still scaffolding says so on its face.** A scaffolding page carries settled headings, a few paragraphs stating the facts the finished page must contain, no code, and a `Not yet written` callout at the top. That callout is the marker: trust it rather than inferring from length or from this file, because the boundary moves as pages get written and a stale list here is worse than none.

Review happens in stages, structure, then stated facts, then prose, then code, so on a page still carrying that callout, do not write finished prose or add examples unless asked. On a drafted page the constraint reverses: match the voice that is there.

Two habits keep this honest. Drop the callout in the same commit that drafts the page, and keep the author-facing register out of drafted prose: a sentence like "the page must not imply otherwise" is a note to a writer, not a sentence for the reader, and it reads as a lapse once the page around it is finished.

## The site's presentation layer

Theme, type scale, and the width arithmetic behind the home page's code blocks are in **`process/presentation-layer.md`**. Read it before touching `assets/*.scss`, the `format:` block in `_quarto.yml`, or the length of a line in a home-page example: several constraints there are silent, and one shipped as a bug until it was measured.

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

## Identifiers are masked in three layers, and all three are load-bearing

The site is public and the pages query a real workspace, so a catalog name, cluster id, session name or cluster *display* name can reach a published page through ordinary output. Three layers stop that, at three different moments:

| Layer | Runs | Protects |
|----|----|----|
| `wq_mask_output()` in `R/setup.R` | during chunk execution | `_freeze/` **and** `_site/` |
| `assets/redact.lua`, declared in `_quarto.yml` | at pandoc time | `_site/` and `search.json` |
| `scripts/check-public.sh` | before any push | everything tracked |

**Call `wq_mask_output()` in a hidden chunk on any page that connects to Databricks.** One line, right after sourcing `R/setup.R`. `check-public.sh` fails the build if a page opens a connection without it, so this is enforced rather than remembered.

The layers are not redundant. The Lua filter cannot replace the R hook, because it runs *after* the freeze cache is written and `_freeze/` is tracked and published. The hook cannot replace the filter, because it has to be added per page. And neither replaces the check, because both redact only strings someone has already named: the one leak that reached a page here was a cluster's display name, dangerous precisely because nothing knew that string was sensitive until it appeared.

Two traps worth knowing before touching any of this:

- **Masking hooks output, not objects, and that is deliberate.** Three routes leak a catalog and they have nothing in common except ending up as printed text: a `dbplyr::in_catalog()` object stores it, `show_query()` builds it into SQL, and a server error quotes the fully qualified name. Wrapping a function catches one and looks like it caught all three.
- **`redact.lua` reads the *process* environment.** Identifiers live in `.Renviron`, which only R reads, so `os.getenv()` sees nothing unless the variable is exported to the shell running `quarto`. It warns on stderr in that case rather than silently redacting nothing. `rerender.sh` and `rebuild-site.sh` export them for you.

## Never paste code output

**No output on a page may be typed, pasted or copied by hand. Output is produced by executing the code, or it does not appear.**

This is absolute, and it outranks convenience. A pasted block is a claim that some code once printed something, with nothing checking it: the code changes, the output does not, and the page then lies at exit 0 with no warning in any log. That failure is silent, permanent, and invisible to every check in `scripts/`.

It applies to all of it: printed results, `show_query()` SQL, error messages, `cli` alerts, timings, row counts, version strings. Editing a number inside a fenced block is the same offence as inventing one.

Two consequences follow, and neither is optional:

- **A page that shows output must execute.** Use ```` ```{r} ```` and let `freeze: true` cache it. A page that cannot execute must not show output.
- **Where output genuinely cannot be executed** (it needs an administrator's permissions, a volume that is not provisioned, a cluster the reader has no equivalent of), do not paste it. Say in prose what happens, or gate the chunk and let it render as code alone. Describing a result in a sentence is honest; a fenced block that was never produced is not.

If output needs reshaping before it is fit to show, that is a job for a chunk option or a knitr hook, applied to real output. It is never a reason to hand-write the result.

The site currently violates this: 54 code blocks across `concepts/`, `howdoi/`, `ref/`, `admin/` and `index.qmd` are plain ```` ```r ```` blocks with output pasted beneath. Converting them is tracked work, not a licence to add more. Do not add a static block with pasted output to any page, for any reason.

## House style

- **UK English.** `-ise` not `-ize`. Code identifiers keep their real spelling.
- **Avoid em-dashes.** Use a comma, a colon, parentheses, or two sentences.
- **Sentence case in headings.**
- **Bold inside a line, never as a paragraph lead-in.** A bolded lead-in wants to be a real heading.
- **Write as if to one person**, second person, active voice.
- **Lead with the answer.** State the conclusion, then support it.
- **Do not hard-wrap.** One line per paragraph in every `.md` and `.qmd` file, soft-wrapped by the editor. Code blocks keep their own line structure and are formatted for code readability. Pipe tables and hard line breaks keep theirs too.
- **Base pipe `|>` only, never `%>%`.** Most Spark-related R documentation uses `%>%`, so translate anything borrowed.
- **Method is in `process/`, and drafting more than one page starts there.** `process/drafting-pages.md` records the order that works: read the changelog batch before writing rather than during, reuse `R/setup.R` rather than rebuilding its helpers, batch the work by which compute it needs, and verify by reading rendered output rather than trusting exit 0. It exists because each of those was learned by paying for the alternative.
- **Code style is in `CODE-STYLE.md`, and it is not advisory.** The tidyverse is the default idiom because the reader is fluent in it: `glue()` rather than `paste()` or `sprintf()`, `cli` rather than `message()` or `stop()`, `dplyr` and `purrr` rather than `[` and `lapply()`. `example/reducing.qmd` carries the reference preamble. Read that file before writing R for this repo.
- **Prefer saying where the code runs** to saying "pushdown". At most once per page, as a parenthetical gloss, so the term still connects to vendor documentation.

## Where the findings come from

The research behind this guide lives in a separate private repository and reaches this one two ways: **facts as a downstream changelog**, prose to read and act on, and **code in `skills/`**, as runnable examples upstream has executed. Nothing else crosses; the site's own pages are written here.

**`process/upstream-changelog.md`** holds the protocol, the marker recording how far the changelog has been consumed, and what each entry changed. Read it before acting on an entry, and before widening a page's `rests on:` line.
