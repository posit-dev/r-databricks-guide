# What Posit's Databricks documentation says

**Not yet written.** This file is a placeholder so the gap is visible rather than forgotten.

The site to read is `https://docs.posit.co/data-sources/user/databricks/`, Posit's own documentation for connecting to Databricks from Posit tooling. It is the third neighbour this guide sits between, alongside [sparklyr's](upstream-sparklyr.md) and [brickster's](upstream-brickster.md).

## Why it matters more than its size suggests

It is the only one of the three that addresses the environment this reader is actually in. Posit Workbench injects Databricks credentials ambiently on sign-in, which is the mechanism behind the guidance in `CLAUDE.md` that an unset `DATABRICKS_HOST` means the session is not signed in, and that `databricks auth login` is never the fix here. Both sparklyr's and brickster's documentation touch that story from the side: sparklyr's Databricks Connect page discusses Workbench at length as the recommended credential path, and brickster's auth article states that it detects Workbench-managed OAuth automatically. Neither owns it.

So this is the site most likely to already answer the connection and credential questions that `howdoi/connect.qmd` and `ref/when-it-breaks.qmd` would otherwise have to answer from scratch.

## What to establish when reading it

Follow the shape of the other two files: what each page covers, and whether this reader can safely be sent to it. Specific questions worth answering, because each one currently rests on this repo's own testing or on nothing:

- What it says about the ambient-credential model on Workbench, and whether the description matches what `CLAUDE.md` records.
- Whether it documents what an expired credential looks like. This guide's position is that it surfaces as an opaque ODBC driver error with nothing auth-shaped about it, which is exactly the kind of symptom a vendor troubleshooting page should carry, and which neither sparklyr's nor brickster's documentation covers.
- Which connection paths it covers, and whether it takes a position on `odbc` versus the alternatives. If it recommends ODBC without qualification, the `BINARY` finding here is a caveat worth raising with them.
- Whether it addresses the reader who cannot create compute. Both other sites assume otherwise, and that assumption is the largest single gap in the seam.
- Whether it says anything about R specifically, or only about Python and general connectivity.

## After reading it

Two follow-ups, neither of which should be skipped:

- Update [`README.md`](README.md) in this directory: the seam argument there is currently written from two neighbours, and a third will sharpen or complicate it.
- Check whether anything it states plainly is something this guide currently derives for itself. That is the cheapest win available from any of these audits, and it is how the sparklyr reading paid for itself.
