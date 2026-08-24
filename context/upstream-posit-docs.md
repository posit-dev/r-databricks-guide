# What Posit's Databricks documentation says

An account of `docs.posit.co/data-sources/user/databricks/`, read on 2026-08-24: the section index, all six credential-pattern pages, the three Getting started pages, the source-agnostic recipe page, and the admin pages the user pages defer to. Twenty-eight pages in the site's sitemap, of which eight are the Databricks section.

The short version: **it is a credential-selection guide, and only a credential-selection guide.** It answers "which authentication method should I use, and what does the connection call look like" completely, for both R and Python, across Workbench and Connect. It answers nothing else. There is no troubleshooting, no data types, no diagnosis, and no page about the compute itself. So the duplication risk with this guide is smaller than the placeholder assumed, and the corroboration value is larger.

Two things to know before using it. First, its scope is the *seam between two Posit products*, development on Workbench and deployment on Connect, and that axis is not this reader's axis at all: she is in one Workbench session and is not deploying anything. Roughly half the site is about a transition she will not make. Second, unlike the other two neighbours, this site is **actively maintained and current in tone**: no Spark 1.6 pins, no dead packages, base pipe throughout, `Sys.getenv()` in the code examples. Nothing here needs a warning for being stale.

## The pages, and what each is worth

The verdict column is the one that matters: it records whether this reader can safely be sent to the page.

### The Databricks section

| Page | What it covers | Verdict |
|----|----|----|
| [Choose a connection for Databricks](https://docs.posit.co/data-sources/user/databricks/index.html) | The two connection types, Spark versus ODBC/SQL, and four tables mapping credential scope to a code example, for Workbench and Connect | **Link from `howdoi/connect.qmd`.** The Spark-versus-ODBC framing is clean and matches this guide's. Send her past the Connect tables, which are not her situation |
| [Workbench managed credentials](https://docs.posit.co/data-sources/user/databricks/dbx-workbench-managedcred.html) | The one page written for her environment. `spark_connect(cluster_id =, method = "databricks_connect")` and `dbConnect(odbc::databricks(), httpPath = )`, both with `Sys.getenv()` | **Link, and it is the single most relevant page on the site.** See below |
| [Workbench OAuth M2M](https://docs.posit.co/data-sources/user/databricks/dbx-workbench-m2m.html) | Service-principal client id and secret, set as `DATABRICKS_HOST`, `DATABRICKS_CLIENT_ID`, `DATABRICKS_CLIENT_SECRET` | **Do not link.** A service-principal credential is an ask-and-wait for her, and the page states plainly that the Spark half is Python only: "This connection method will be supported in a future release of `sparklyr`" |
| `dbx-connect-viewer-oauth`, `dbx-connect-sa-oauth`, `dbx-connect-workload-identity`, `dbx-connect-m2m` | Four Connect deployment patterns, using `connectcreds` in R and `posit-sdk` in Python | **Do not link.** All four are about publishing content to Connect. Correct, current, and about a different problem. Two of the four are Python-only for Spark |

### Getting started, and the recipe

| Page | What it covers | Verdict |
|----|----|----|
| [Credential types](https://docs.posit.co/data-sources/user/getting-started/credentials.html) | Scope (user versus one-to-many) crossed with lifetime (long-lived versus ephemeral), and how Workbench and Connect supply the ephemeral case | Moderate. The scope/lifetime grid is a genuinely good two-axis model, but she has exactly one credential and no decision to make. Worth one sentence of borrowing, not a link |
| [Data sources and connection methods](https://docs.posit.co/data-sources/user/getting-started/sources-and-methods.html) | SDKs, language-specific libraries, HTTP clients, ODBC/JDBC, and a preference order between them | Low value here. Generic across all data sources, and its recommendation, prefer a library over a driver, points somewhere useful by accident. See the ODBC note below |
| [Managing data access from development to deployment](https://docs.posit.co/data-sources/user/getting-started/dev-to-deploy.html) | Branching on the `POSIT_PRODUCT` environment variable, which is `WORKBENCH` in a session and `CONNECT` in deployed content | Low value, one fact worth keeping: `POSIT_PRODUCT` is a reliable way to detect which environment R is running in. Relevant only if a page here ever discusses deployment |
| [Connect to any data source](https://docs.posit.co/data-sources/user/connecting-to-a-source.html) | A three-step recipe: connection method, then credential scope and lifetime, then portability | **Do not link.** Explicitly says that for Databricks the recipe has already been worked through, and points at the section index. Send her to the index directly |

### Admin pages, which are forwardable

Two of these are the same shape as `admin/geospatial-setup.qmd`: written for someone else and meant to be handed on.

| Page | What it covers | Verdict |
|----|----|----|
| [Databricks configuration for Workbench and Connect](https://docs.posit.co/data-sources/admin/databricks.html) | What an administrator must set up. States that `sparklyr` needs no system-level admin configuration, while the ODBC path needs the Professional Driver installed and a DSN configured | **Forwardable from `admin/index.qmd`.** It answers "what do I ask for" precisely: the ODBC path has an administrator prerequisite and the Spark path does not |
| [Install Pro Drivers](https://docs.posit.co/data-sources/admin/pro-drivers/installation.html) | Driver installation by distribution | Forwardable, and only if her ODBC driver is missing. Not her page |
| [Troubleshoot database connections](https://docs.posit.co/data-sources/admin/pro-drivers/troubleshooting.html) | `isql`, `odbcinst -j`, `ldd`, driver logging, and opening a support ticket | **Do not link as a destination**, for the same reason as sparklyr's troubleshooting page. Everything on it is admin-side and system-level, it names no symptom she would recognise, and it never mentions authentication at all. See below |

## The page written for her environment

`dbx-workbench-managedcred.html` is the only upstream page anywhere, on any of the three neighbouring sites, addressed to a reader in a Workbench session with ambient Databricks credentials. What it gives us:

- **Both connection forms, in R, with `Sys.getenv()`.** `spark_connect(cluster_id = Sys.getenv("DATABRICKS_CLUSTER_ID"), method = "databricks_connect")` for a cluster, and `DBI::dbConnect(odbc::databricks(), httpPath = Sys.getenv("DATABRICKS_HTTP_PATH"))` for a warehouse. It states the convention this repo already follows, that these are per-user values belonging in the environment rather than in code, and it names the two variables.
- **The compute split stated in the reader's terms.** Spark needs a cluster id; ODBC/SQL needs an HTTP path, which it tells her to find under Advanced Options > JDBC/ODBC in the Databricks UI and describes as looking like `/sql/1.0/warehouses/<id>`. That is the missing half of the split recorded in [`upstream-brickster.md`](upstream-brickster.md): brickster's DBI path needs a warehouse and `db_repl()` needs a cluster, and now there is an upstream page saying where each identifier comes from.
- **The mechanism, named.** Credentials arrive as a `workbench` profile in a Databricks config file that Workbench creates and manages. That is what `odbc::databricks()` and `sparklyr` pick up without being told.
- **A version floor for `pysparklyr`**, stated in a comment as 0.1.8 or above.

What it does not give us: any mention of `brickster`, of data types, of what happens when it stops working, or of a reader who cannot create compute. And note the small conflict of framing: it tells her to store the cluster id in a `.env`-style variable, while the Workbench user guide (below) warns that hand-written credential files can interfere with managed credentials. The two are compatible, since a cluster id is not a credential, but a reader following both could reasonably be confused.

## The two claims this repo was checking, and how they come out

Both were the point of the exercise, and they come out differently.

**The ambient-credential model: corroborated, and better stated upstream than here.** The site is unambiguous that Workbench injects the credential on sign-in and that no code-level configuration is needed. The clearest single sentence is on the Workbench user guide page it defers to, `ide/server-pro/user/posit-workbench/managed-credentials/databricks.html`: "Any tool that implements the Databricks client unified authentication standard can use the ambient credentials supplied by Workbench." That page also states which R packages were validated against managed credentials, `sparklyr`, `odbc` with the Professional Driver, and the Databricks R SDK, and that `sparklyr` 1.8.4 or above is required. So the ambient-credentials note in `CLAUDE.md` can cite upstream rather than rest on local testing.

Two refinements upstream adds that this repo does not record. The credential **refreshes automatically while the session remains active**, which is stated on both the Workbench user page and the admin page. And a user can **opt out** at session start, by leaving the Databricks credential toggle disabled, in which case her own `.databrickscfg` or `.Renviron` applies instead. Upstream warns that supplying host variables or a PAT by hand *while* managed credentials are enabled "may interfere with Workbench-managed credentials and lead to inconsistent behavior". That is a real trap worth carrying, and it is not the same trap as the config-profile fallback already noted on `howdoi/connect.qmd`.

Strictly, upstream corroborates the mechanism rather than the diagnostic. Nothing on any of these pages says that an unset `DATABRICKS_HOST` means the session is not signed in. What it does say is that Workbench sets the environment variables and config file automatically when the integration is on, which makes the inference sound but leaves it an inference. Keep the rule; cite upstream for the mechanism and not for the test.

**The expired-credential symptom: not documented anywhere, and upstream arguably points the other way.** This was the sharper of the two questions and the answer is clean. No page on this site describes what an expired or failed credential looks like from R. Neither does the Workbench managed-credentials guide. The only troubleshooting page on the whole site is the Pro Drivers one, and it is entirely about driver installation, `odbcinst.ini`, `ldd` and driver logging, with no mention of tokens, OAuth or authentication in any form. So a reader whose credential has lapsed, following the one page named "Troubleshoot", is sent to check her ODBC configuration for a fault that is not there. That is precisely the wrong direction, and it is the same failure this guide already warns against: do not debug an expired token as a warehouse, driver or network fault.

It is slightly worse than an absence. The admin page states that "Workbench handles token refreshes in the background, preventing session timeouts", which a reader can fairly take to mean this cannot happen to her. The refresh claim is scoped to an active session and is presumably accurate within that scope, so treat this as under-stated upstream rather than contradicted. The honesty constraints in `CLAUDE.md` win regardless: the symptom observed here stands, and it is now known to have no upstream counterpart on any of the three neighbouring sites.

**This makes `ref/when-it-breaks.qmd` the clearest un-contested page on the site.** Three neighbours, three troubleshooting stories, and all three are absent or misdirecting: sparklyr's page names no symptom, brickster's auth article says nothing about diagnosing a bad credential, and this one sends an auth failure to the driver documentation. A symptom-shaped page has no competition at all.

## Where it takes a position this guide must qualify

**It recommends `odbc` for SQL warehouses without qualification, and does not mention `brickster`.** The exact wording, repeated on both Workbench pages: "The best method for creating a database connection to a Databricks SQL warehouse is to use the `odbc` package and the `odbc::databricks()` function."

That is fine for the reader it has in mind and wrong for this one the moment geometry is involved, because `odbc` silently truncates `BINARY` (`r-dbi/odbc#1024`), which is how geometry travels. Nothing on the site mentions data types at all, so this is an absence rather than a contradiction, and the qualification belongs on `howdoi/connect.qmd` where it already is. Worth noting that the site's own Getting started page prefers a language-specific library over a driver where one exists, which is an argument for `brickster` that the Databricks pages do not follow through.

This is the clearest case on any of the three sites for raising something upstream: a caveat on the `odbc` recommendation costs one sentence, and the finding is already filed against the driver package.

**It does not address the reader who cannot create compute, but it comes closest of the three.** It never says how to find a cluster id, what to do when there is no cluster, or what access modes are. What it does do, unlike the other two, is treat the compute as a given: every code example reads an identifier out of the environment rather than provisioning anything. The Databricks pane in RStudio Pro, which it mentions twice, is for viewing, starting, stopping and connecting to clusters, which is exactly the set of verbs available to her. So the framing is compatible with her situation even though nothing on the site names it.

**On R specifically it is even-handed, with a caveat.** Every connection-pattern page gives R and Python side by side. But R is second in ordering everywhere, and two of the six patterns are Python-only for Spark, each carrying the same note that R support awaits a future `sparklyr` release. Both are service-principal patterns she will not use, so the gap does not bite her, and it is worth knowing that the R and Python surfaces are not equal here.

## What this changes on this site

Ordered by how much they reduce risk or work.

1. **Link `dbx-workbench-managedcred.html` from `howdoi/connect.qmd`.** It gives both R connection calls, with `Sys.getenv()`, for the exact environment she is in. It is the highest-value single link available from any of the three neighbours, and it saves this guide from writing the ambient-credential setup at all.
2. **Cite upstream for the ambient-credential model** in `CLAUDE.md` and wherever `howdoi/connect.qmd` covers it, rather than resting it on local observation. Add the two things upstream knows and this repo does not: the credential refreshes automatically while the session is active, and hand-written credential files can interfere with the managed one.
3. **Say that the expired-credential symptom is undocumented upstream**, on `ref/when-it-breaks.qmd`. The entry gets sharper, not weaker: the one page called "Troubleshoot" is about ODBC driver installation and sends her the wrong way.
4. **State the identifier split once, with upstream's own words for it.** Spark wants a cluster id; ODBC wants an HTTP path, found under Advanced Options > JDBC/ODBC and shaped like `/sql/1.0/warehouses/<id>`. That belongs on `howdoi/connect.qmd` or `howdoi/compute.qmd` and pairs with the brickster warehouse-versus-cluster note.
5. **Forward `admin/databricks.html` from `admin/index.qmd`.** It answers "what do I ask my administrator for" cleanly: the ODBC path needs a driver installed and a DSN configured, the `sparklyr` path needs nothing system-level. That is a concrete ask she can hand on, in someone else's words.
6. **Do not link** the four Connect pages, the Workbench M2M page, the source-agnostic recipe page, or the Pro Drivers troubleshooting page.

## What to re-check when this is next read

The site is current and moving, so the two answers most likely to change:

- **Whether an authentication troubleshooting page appears**, on this site or in the Workbench guide. If one does, the `ref/when-it-breaks.qmd` framing above needs revisiting, and it would be the single most useful thing upstream could add for this reader.
- **Whether the M2M Spark note ("supported in a future release of `sparklyr`") is still there.** It dates the reading, and its disappearance would mean the R and Python surfaces have converged.
