# The seam this guide sits in

This guide is not the first thing written about R and Databricks. Three documentation sets already exist, they are each good at what they cover, and none of them covers what this reader needs. The guide exists in the seam between them.

The files here record what each of those sets says, so that a page written here can link to them instead of repeating them, avoid contradicting them, and be clear about which gap it is filling. Read the relevant one before writing prose on any page that touches sparklyr, brickster, or connecting from Posit tooling.

| File | Covers | State |
|----|----|----|
| [`upstream-sparklyr.md`](upstream-sparklyr.md) | `spark.posit.co`: 17 pages under `guides/`, plus the deployment pages | Read 2026-08-23 |
| [`upstream-brickster.md`](upstream-brickster.md) | `databrickslabs.github.io/brickster`: 6 articles and the DBI backend | Read 2026-08-23 |
| [`upstream-posit-docs.md`](upstream-posit-docs.md) | `docs.posit.co/data-sources/user/databricks/` | **Not yet written** |

## What the seam actually is

Each of the three neighbours addresses a different person, and the gaps fall in predictable places.

**sparklyr's guides address someone with a Spark of their own.** Every one of the seventeen connects with `spark_connect(master = "local")`, or YARN, or a standalone URL, and not one mentions Databricks or Spark Connect in its body. Everything platform-specific sits on a single page outside that section, at `deployment/databricks-connect.html`, which the guides do not link to. So a reader who searches for "sparklyr distributed R" lands in a section written for compute she does not have, and never learns the page for her platform exists.

**brickster's articles address the API surface.** They are accurate and current, and they document what each function does. What they say almost nothing about is data types, which is where the hardest-won findings on this site sit: nothing in brickster's documentation states that its DBI path returns `BINARY` intact, even though that is the reason this guide depends on it.

**Neither has any geospatial story at all.** sparklyr has no geospatial guide, and the community extensions that once filled the gap (`geospark`, `sparkgeo`) are Spark 2.x/3.x-era and predate native `ST_` functions. brickster's backend has no geospatial case in either direction. That is the clearest gap of the three, and not coincidentally the part of this guide with the least competition.

**And a fourth reader is missing everywhere: the one who cannot change her compute.** Both sites assume, in different ways, that the reader configures the thing she runs on. sparklyr's connections guide is about setting executor memory and cores. brickster's cluster-management article is written throughout for someone who can create clusters. Neither covers reading an existing cluster's configuration and designing within it, which is the situation this guide's reader is actually in.

## How to use these files

Three things they are for, in the order they save the most work.

**Link rather than write.** Every upstream page that is safe to send her to is prose this guide does not have to produce. Each file marks which pages those are.

**Do not send her somewhere that will break her.** Several upstream pages will fail if followed correctly on managed compute, and the failure does not look like a platform mismatch. Those are marked too, and they are good candidates for `ref/when-it-breaks.qmd`, which is symptom-shaped.

**Cite upstream where upstream already says it.** Some facts this guide derives for itself are stated plainly on a page nobody here had read. Resting a claim on an upstream statement is stronger and cheaper than resting it on our own testing alone.

One caution that applies to all three files. Where an upstream claim and a measurement here disagree, the honesty constraints in `CLAUDE.md` win: they are deliberately stricter than upstream is. The clearest case is `spark_apply()`, where upstream's claim about distribution is architectural and asserted rather than demonstrated, so it cannot be used to widen what this guide says.

## Keeping these current

Each file records the date its site was read. Documentation moves, so treat anything here as a claim about that date rather than about now, and re-check a page before building something load-bearing on it.

Two specific things known to be unsettled, both of which would change what these files say:

- Whether `compute()` and `memory = TRUE` fail on non-serverless Databricks Connect or only on serverless. Upstream's statement is scoped to serverless and it is not clear whether that scope is deliberate.
- Which runtime this guide addresses. The `ST_` functions need DBR 17.1 or above, so the open DBR-18 question in `CLAUDE.md` decides how much of the geospatial material applies.
