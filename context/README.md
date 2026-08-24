# The seam this guide sits in

This guide is not the first thing written about R and Databricks. Three documentation sets already exist, they are each good at what they cover, and none of them covers what this reader needs. The guide exists in the seam between them.

The files here record what each of those sets says, so that a page written here can link to them instead of repeating them, avoid contradicting them, and be clear about which gap it is filling. Read the relevant one before writing prose on any page that touches sparklyr, brickster, or connecting from Posit tooling.

One file points the other way. `databricks-review-2026-08-24.md` records an external reading of *this* guide from someone at Databricks, kept here for the same reason: it is a neutral account of what the site does not say, and a page can be written against it. It is the published half of a review whose private half stays in `docs/`.

The three divide more cleanly than expected, and the division is by *layer* rather than by product: Posit's documentation covers getting authenticated, brickster's covers the API calls you then make, and sparklyr's covers the distributed computation. Each stops where the next begins, and none of them looks down at the data.

| File | Covers | State |
|----|----|----|
| [`upstream-sparklyr.md`](upstream-sparklyr.md) | `spark.posit.co`: 17 pages under `guides/`, plus the deployment pages | Read 2026-08-23 |
| [`upstream-brickster.md`](upstream-brickster.md) | `databrickslabs.github.io/brickster`: 6 articles and the DBI backend | Read 2026-08-23 |
| [`upstream-posit-docs.md`](upstream-posit-docs.md) | `docs.posit.co/data-sources/user/databricks/`: 8 Databricks pages, plus Getting started and the admin pages | Read 2026-08-24 |
| [`databricks-review-2026-08-24.md`](databricks-review-2026-08-24.md) | An external Databricks reading of *this* guide: what it found the site does not say | Read 2026-08-24, unacted |

## What the seam actually is

Each of the three neighbours addresses a different person, and the gaps fall in predictable places.

**sparklyr's guides address someone with a Spark of their own.** Every one of the seventeen connects with `spark_connect(master = "local")`, or YARN, or a standalone URL, and not one mentions Databricks or Spark Connect in its body. Everything platform-specific sits on a single page outside that section, at `deployment/databricks-connect.html`, which the guides do not link to. So a reader who searches for "sparklyr distributed R" lands in a section written for compute she does not have, and never learns the page for her platform exists.

**brickster's articles address the API surface.** They are accurate and current, and they document what each function does. What they say almost nothing about is data types, which is where the hardest-won findings on this site sit: nothing in brickster's documentation states that its DBI path returns `BINARY` intact, even though that is the reason this guide depends on it.

**Posit's own documentation addresses the credential and nothing past it.** It is the only one of the three written for the environment this reader is actually in, a Workbench session with ambient credentials, and within that scope it is complete, current and correct for both R and Python. But its axis is the seam between two Posit products, development on Workbench and deployment on Connect, and that is not her axis: she is in one session and is not deploying anything. Half the site is about a transition she will not make, and the half that is hers ends at the moment `dbConnect()` returns.

**No geospatial story anywhere, and no data types anywhere.** sparklyr has no geospatial guide, and the community extensions that once filled the gap (`geospark`, `sparkgeo`) are Spark 2.x/3.x-era and predate native `ST_` functions. brickster's backend has no geospatial case in either direction. Posit's pages never mention a data type at all. That is the clearest gap of the three, and not coincidentally the part of this guide with the least competition.

**And a fourth reader is missing everywhere: the one who cannot change her compute.** All three assume, in different ways, that the reader configures the thing she runs on, or say nothing about the question. sparklyr's connections guide is about setting executor memory and cores. brickster's cluster-management article is written throughout for someone who can create clusters. Neither covers reading an existing cluster's configuration and designing within it, which is the situation this guide's reader is actually in. Posit's documentation comes closest without ever naming it: every example reads a cluster id or an HTTP path out of the environment rather than provisioning anything, so its framing fits her even though it never says how to find those values or what to do when there is nothing to find.

**And with three read rather than two, one absence is now conspicuous: none of them can tell her why it broke.** sparklyr's troubleshooting page names no symptom and no cause. brickster's auth article says nothing about diagnosing a bad credential. Posit's only troubleshooting page is about ODBC driver installation, so an expired token, which surfaces as an opaque driver error, sends a reader following it to inspect an `odbcinst.ini` that is fine. Three neighbours, three misses, and the third actively misdirects. `ref/when-it-breaks.qmd` therefore has no competition at all, and that is the strongest single conclusion from reading all three.

## How to use these files

Three things they are for, in the order they save the most work.

**Link rather than write.** Every upstream page that is safe to send her to is prose this guide does not have to produce. Each file marks which pages those are.

**Do not send her somewhere that will break her.** Several upstream pages will fail if followed correctly on managed compute, and the failure does not look like a platform mismatch. Those are marked too, and they are good candidates for `ref/when-it-breaks.qmd`, which is symptom-shaped.

**Cite upstream where upstream already says it.** Some facts this guide derives for itself are stated plainly on a page nobody here had read. Resting a claim on an upstream statement is stronger and cheaper than resting it on our own testing alone.

One caution that applies to all three files. Where an upstream claim and a measurement here disagree, the honesty constraints in `CLAUDE.md` win: they are deliberately stricter than upstream is. The clearest case is `spark_apply()`, where upstream's claim about distribution is architectural and asserted rather than demonstrated, so it cannot be used to widen what this guide says.

## Keeping these current

Each file records the date its site was read. Documentation moves, so treat anything here as a claim about that date rather than about now, and re-check a page before building something load-bearing on it.

Three specific things known to be unsettled, each of which would change what these files say:

- Whether `compute()` and `memory = TRUE` fail on non-serverless Databricks Connect or only on serverless. Upstream's statement is scoped to serverless and it is not clear whether that scope is deliberate.
- Which runtime this guide addresses. The `ST_` functions need DBR 17.1 or above, so the open DBR-18 question in `CLAUDE.md` decides how much of the geospatial material applies.
- Whether Posit's documentation grows an authentication troubleshooting page. It is the site most likely to add one, and if it does, the argument above that `ref/when-it-breaks.qmd` has no competition needs revisiting.
