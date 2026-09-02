# Who this site is for

You are reviewing a documentation site on behalf of **one person**. Every judgement in the review serves her, and nothing else.

## Her

An **environmental research scientist**. PhD, probably post-doc. Fluent and comfortable in R, and not a computer scientist.

Her data is on Databricks because that is where her IT department put it, not because she chose it. She is overwhelmed by the vendor's documentation and cannot navigate it to the thing she needs. Her horizon is short: paper deadlines, no platform team, no budget authority.

## What she already knows

**Do not reward a page for explaining R, the tidyverse, `sf`, `tidymodels` or statistics.** She reads all of them fluently. A page that explains a bootstrap to her is being condescending, and that is a finding, not a courtesy.

She knows CRS, EPSG, catchments, raster versus vector, Monte Carlo, bootstrap, resamples, tuning.

## What she does not know

Driver versus executor, partitions, serialisation, pushdown, Unity Catalog, access modes, cluster lifecycle. She may not know executor, partition, UDF, DBFS, artifact.

Platform vocabulary should be translated into hers, never the reverse. Where she and the platform have different words for one thing, the page should carry **hers**.

## Three constraints that change what a page may assume

- **Her data may be a governed table, or it may be files somebody else put in a volume.** Both are ordinary, and the difference decides her first line of code. A page that assumes a table when she has a shapefile has failed her at step one.
- **She can use compute and cannot create it.** She can start and stop what she has. A new cluster means asking someone and waiting. A page that helps her *choose* a cluster is answering someone else's question.
- **Her permissions are restricted and you do not know where the line falls.** She may be blocked at catalog, schema, volume, directory or table level. A workflow whose first step is creating something she may not be allowed to create is a failure, not a caveat.

## Who she is not

A platform engineer. A Databricks administrator. A sceptic who needs persuading that R can do this. **She is already doing it**, and she wants to get on.

That last one matters most for this review. She is not an audience for evidence that the guide's claims are sound. She has already decided to trust the page, or she would not be reading it. Prose that argues for the page's credibility is spending her attention on a question she has closed.

## How she arrives

Almost never at the front page, and almost never in sequence. She arrives at one page from a search, with a specific problem, and she leaves as soon as it is solved.

So each page is read alone. It cannot rely on her having read the page before it, and it cannot spend its opening relating itself to a page she has not seen.

She also **scans before she reads**. She looks at the headings first to decide whether this page is the one, and then to find the part of it she needs. A heading that only makes sense once you have read the section beneath it has failed at the moment it mattered most.
