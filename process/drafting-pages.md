# Drafting several pages at once

Written after a session that took the nine `howdoi/` pages from scaffolding to published, on 2026-08-24. The order below is the finding, not a preference: three of these steps exist because skipping them cost that session real time, and one exists because skipping it published a leak.

## The three things that actually save time

In descending order of what they saved. The parallelism is last, and it only works because the first two came first.

**1. Read the upstream changelog batch before writing, not during.** This is the single highest-value step and it is a sequencing rule rather than a technique. The 2026-08-23 batch changed the content of three pages: it re-labelled the `ST_` coverage claim as warehouse-type-specific, it ruled out showing `dbWriteTable()` on an `sf` object, and it settled which parallel backend to recommend and why. Reading it first meant writing those pages once. Reading it after would have meant writing them, then revising them, then re-verifying them.

`CLAUDE.md` holds the consumed-through marker and a record of where each entry landed. Read the entries above the marker, decide what they change, then move the marker and say in the commit message what you declined.

**2. Reuse `R/setup.R`. Do not rebuild it.** It already has `wq_connect_odbc()`, `wq_connect_brickster()`, `wq_tbl()`, `wq_name()`, `wq_mask()` and `wq_mask_all()`. The 2026-08-24 review found seven of its ten helpers unused, and this session showed why: nothing pointed anyone at them, so it rebuilt most of them from scratch in a scratch directory and leaked a cluster id doing it. Source the file.

```r
source("R/setup.R")   # brings dbx-config.R with it
con  <- wq_connect_odbc()
acon <- wq_connect_brickster()
readings <- wq_tbl(con, "hydrology_readings")
```

**No page calls the connection helpers, and that is deliberate.** `CLAUDE.md` wants a reader to see the connection being opened, so the pages inline `dbConnect()` rather than hiding it behind `wq_connect_odbc()`. The helpers exist for verification scripts, which is where the saving is: use them there, and do not "fix" the pages to call them.

The same reasoning settles `example/connecting.qmd`, which defines its own profile guard rather than calling `dbx_cluster_id()`. That page is *teaching* the guard, and it demonstrates the failure with `#| error: true`. Replacing the definition with a call would hide the mechanism the section exists to explain. `dbx-config.R` was brought up to the page's standard instead, since the page used `cli_abort()` with structured bullets while the helper still used `stop()` and `sprintf()`.

One duplicate is knowingly left. `wq_cluster_notice()` has a verbatim twin inside `example/bootstrap.qmd`. Removing it is a one-line edit, but that page re-renders only with `WQ_RUN_CLUSTER=true` against the multi-node cluster, and rendering it without that flag drops its cluster output. The cost is out of proportion to a twelve-line duplicate the reader never sees, because it is `echo: false`.

**3. Batch by compute, then parallelise.** Sort the pages by what they need before dispatching anything.

Most pages need only the SQL warehouse, which is always available and answers in under a second. A few need an all-purpose cluster, which took between seven and eleven minutes to start from cold across several attempts in that session. Doing warehouse pages first, with no cluster running, then starting the cluster **once** for everything that needs it, turned four cold starts into one. Start the cluster before you need it and let it wake while the warehouse work proceeds.

Only then parallelise. Independent pages can be drafted concurrently by subagents, but five fresh agents without steps 1 and 2 will each rediscover the schema, invent their own connection idiom, and hit the same masking trap.

## Sorting the pages

Check what a page needs by reading its `This page rests on:` line, not by guessing from the title. In the session that produced this file the split was five warehouse-only, two cluster-backed, and two already written.

A page needs the cluster only if it rests on a claim about worker machines, distributed execution, forked workers on cluster compute, or cluster metadata. Everything about queries, pushdown, geometry transport, types and licences is warehouse work.

## Briefing a subagent

A fresh agent has none of this conversation. What it needs, in the brief itself rather than as a file to find:

- **Read order**, explicitly: `CLAUDE.md`, then `CODE-STYLE.md`, then its own page's scaffolding, then an already-finished page to match voice against. Naming a finished page is what keeps nine pages sounding like one author.
- **The factual budget.** Only claims on that page's own `rests on:` line. If it needs a fact that is not there, stop and report rather than invent. Running code does not enlarge the budget: code may demonstrate a claim already on the line, never establish a new one.
- **Schema facts up front**, so nobody rediscovers them. `hydrology_readings` has 32,540,721 rows and keys on `measure`, not `station_id`, which is the mistake to pre-empt. `wfd_catchments` has 4,080 rows with `geom_wkb` as `BINARY`.
- **Which compute it may use**, and an explicit instruction not to start a cluster if it is not its job.
- **Report disagreements, do not reconcile them.** This one earns its place. Four of the five subagents in that session hit a scaffolding claim their measurement did not support, and all four reported rather than quietly adjusting. One found the stated 2.5 GB was nearer 2.11 GB; another found a claim that is true in R and false server-side. Silently reconciling any of them would have produced a page that looked authoritative and was wrong, which is exactly the defect the 2026-08-24 review found in the worked example.

## Verification, in three layers

The third layer is the one that matters and the one that is easy to skip.

**The code ran.** A standalone script per page that executes top to bottom against real compute and produces every output the page shows, in page order. Keep it in the scratchpad, never commit it.

**The site builds and is publishable.**

```bash
quarto render
scripts/check-public.sh
scripts/check-freeze.sh    # if anything under example/ was touched
```

**Read the rendered output, not the source.** `quarto render` exits 0 on a page whose numbers are nonsense. That is precisely how the worked example shipped a table of eight identical rows and a figure of forty identical intervals: nothing in the source revealed it, and only the rendered page did. Open the HTML and check that tables vary where the prose implies they should, that a number in the prose matches the block above it, and that no output block contradicts its own introduction.

## Masking, and the leak that motivates it

Anything captured from compute must go through `wq_mask_all()` before it reaches a page.

`wq_mask()` handles the catalog and nothing else, which is correct for the worked example, whose chunks print little but table names. Output that came back from a cluster is a different problem: a worker's hostname embeds the cluster id, and a Workbench session name embeds a person's name. In that session both were pasted straight onto `howdoi/interactive.qmd`, and `scripts/check-public.sh` failed the build. It was caught by the check rather than by anyone reading the page, which is the argument for running the check before calling a page done rather than at push time.

## Where pages execute, and why `howdoi/` does not

`example/` pages execute and are published from a committed `_freeze/` cache. Editing one and pushing without re-rendering publishes the previous output with the edit missing, silently, at exit 0.

`howdoi/` pages do not execute. Their code blocks are plain fenced blocks with output pasted beneath, so no page there ever needs a credentialed re-render and work on them can never invalidate the example's frozen output.

**That trade was a mistake, and it is being unwound.** Nothing recomputes those numbers, so the code and the output beneath it drift apart silently: the block is edited, the output is not, and no check in `scripts/` can see the difference. `CLAUDE.md` now forbids pasted output outright. Treat every remaining static block as debt to be converted to an executing chunk, and never add another.

Do not put `#| eval: false` inside a plain fenced block. It is not consumed as a chunk option there and renders as visible text on the page.

## What this does not cover

Deciding what a page says. The scaffolding, the headings and the `rests on:` lines were settled separately and reviewed separately. A page that quietly grows a section has escaped that review, so a subagent that wants to add, merge or reorder one should stop and ask.
