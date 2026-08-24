# What a Databricks reading found missing, 2026-08-24

**What this is.** The neutral half of an external review of this guide by someone who works at Databricks. It records what the review found the site does not say, and what was verified in response. Nothing here identifies the reviewer, quotes them, or carries anything about the relationship: that stays in `docs/`, which is gitignored.

**How much weight to give it.** The review had two parts with different standing. The reviewer's own reading is an informed external judgement. Four further suggestions were relayed rather than endorsed, having been produced by running an internal Databricks agent over the site, and they are hypotheses to check rather than findings. That distinction turned out to matter: one of the four reproduces the exact error this guide exists in part to correct.

Sorted below by what survived checking.

## Accepted: serverless is missing as a compute decision

The site never names the choice a reader actually faces. The connection pages frame it as a **driver** decision, `odbc` versus `brickster`, and never as a **compute** decision, SQL warehouse versus all-purpose cluster. "The warehouse" appears throughout as a bare noun for "the server side" with no compute type attached.

The distinction worth drawing, and it is the reviewer's own clarification rather than the agent's: R cannot execute *on* serverless compute, because notebooks and jobs there are Python and SQL only. But an R client pushing SQL *to* a serverless SQL warehouse over ODBC works well. The natural shape is a serverless warehouse for connect-and-reduce, and a classic cluster for the distributed-R stages. That is exactly the shape of the worked example, and the site never says so.

There is an asymmetry between what this project knows and what it publishes:

- The published site mentions serverless **once**, at `howdoi/polygons.qmd`, and only to scope an `ST_` function count to a Pro serverless warehouse.
- `skills/r-databricks-connections` and `skills/r-databricks-compute` both carry a verified measurement: **0.70 s** to reach a warm serverless SQL warehouse, against **244 s** for an all-purpose cluster going from terminated to running. Both state the rule outright, that a warehouse is the default and a cluster is for what a warehouse cannot do.
- **No published page carries that claim.** The closest is `howdoi/interactive.qmd`, which quotes only the cluster side, at seven to eleven minutes cold.

So the reader currently gets the discouraging half of the comparison without the reassuring half. `context/upstream-brickster.md` had already identified the same fix and named the page: say once on `howdoi/connect.qmd` that the DBI path needs a warehouse and the remote-execution path needs a cluster.

Constraint on acting: any number promoted from `skills/` is a recorded measurement of one setup on one day, never a benchmark, per the honesty constraints in `CLAUDE.md`.

## Rejected: the claim that R needs Dedicated access mode

The agent suggested flagging that R requires Dedicated (single-user) access mode and that Standard will not accept it. This is the unqualified sentence that `CLAUDE.md` names as false, and adopting it would damage the guide.

Standard access mode refuses R **notebooks**. A client connection to a Standard cluster works. The evidence is in `skills/r-databricks-compute`: `spark_connect()` reached a Standard cluster on DBR 14.3 and `spark_apply()` shipped a UDF to a Databricks Python worker there. It then failed on an `rpy2`/R-version fault, which is not an access-mode refusal.

This is worth recording precisely because the suggestion came from a Databricks-internal source. The unqualified claim is in circulation inside the vendor as well as outside it, which is the strongest argument for the guide keeping its qualifier rather than softening it.

## Partly accepted: Unity Catalog governance

Half of this is already covered and half is a real gap.

Volumes need nothing: they are covered as the durable home for library trees, as the staging route for ingest, as the answer for anything file-shaped, and as readable from inside a worker as an ordinary path.

What is genuinely absent is a short statement of how a client R session inherits governance: grants, masking and row filters apply to the session, and a reader in a regulated environment will ask about that first. The site says three-part names are how permission is granted, and stops there.

## Right to look, wrong reason: the 50,000-row `dbWriteTable()` limit

The agent suggested re-verifying the limit against a recent runtime on the grounds that it may have moved. The premise is wrong: the limit is not a runtime property, so a newer runtime would not move it.

Checking anyway surfaced a real internal inconsistency in how the guide states it, which is worth settling regardless of the agent's reasoning. `ref/sending-things.qmd` qualifies the failure as happening **without a staging volume**, and that qualifier is load-bearing.

## Accepted, low value: SparkR deprecation

SparkR is deprecated from DBR 16.0 onward. This guide builds on `sparklyr` throughout and never mentions SparkR, so it is already on the right side of the change and there is nothing for a reader to do.

## One piece of praise that names something not on the site

The review credited a "Verified / Documented / Open" tagging scheme as part of the site's intellectual honesty. That scheme is deliberately **not** on the site: `CLAUDE.md` forbids evidence tags in the guide's prose, and `ref/evidence.qmd` was removed during the internal review of the same date. The tags survive only in `skills/`, which is reference material for an agent rather than for the reader.

Either the reviewer read `skills/` as part of the site, or their agent surfaced the tags from the repository and attributed them to the guide. Either way it is praise for something the reader will never see, and it should not be read as validation for putting tags back on pages.

## Status

**Nothing here has been acted on.** The serverless gap is the one with real consequences for a reader, and it is scheduled as its own piece of work rather than folded into something else.
