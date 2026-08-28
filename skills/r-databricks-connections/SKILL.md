---
name: r-databricks-connections
description: Choosing and troubleshooting a connection from R to Databricks. Load this first for any R-to-Databricks work. Covers the five connection paths (odbc, brickster DBI, sparklyr, brickster REST, db_context), the ambient-credential model on Posit Workbench, and diagnosing an auth failure that surfaces as an opaque ODBC driver error.
---

# R-to-Databricks connections

*Load this first. It routes to the rest of the pack.*

There are five ways to connect R to Databricks, and picking the wrong one wastes time or loses data. This skill is the decision point.

## The five paths

| Goal | Path | Call |
|----|----|----|
| Query tables with `dbplyr` | ODBC | `DBI::dbConnect(odbc::databricks(), httpPath = ...)` |
| Read a `BINARY` column | brickster DBI | `DBI::dbConnect(brickster::DatabricksSQL(), ...)` |
| Spark DataFrames, distributed R | sparklyr | `sparklyr::spark_connect(method = "databricks_connect", cluster_id = ...)` |
| Clusters, jobs, catalogs, libraries | brickster REST | `brickster::db_cluster_list()` and siblings |
| Arbitrary R on a cluster | brickster contexts | `brickster::db_context_command_run_and_wait(..., parse_result = FALSE)` |

## Default to ODBC

For interactive querying, default to the ODBC path against a serverless SQL warehouse. Cold start to a warm serverless SQL warehouse is **0.70 s**, against **418-438 s** for an all-purpose cluster going TERMINATED to RUNNING: a gap of roughly 600×. `[verified: ran it on 2026-08-22]`

Both paths end in the same `dbplyr` idiom, so query logic is portable between them: start on the warehouse, and only move to a cluster connection when you need something a warehouse cannot do (a live cluster context, a Spark DataFrame, distributed R). This is a recorded measurement of one setup on one day, not a benchmark against which to judge every environment.

## The `BINARY` rule

This is a hard constraint, not a preference: **`odbc` silently loses most of a `BINARY` column.** It also truncates `STRING` silently, but that half is fixable; `BINARY` is not.

A dash means *not measured at that size*, not "no effect". The two halves were measured in separate runs (STRING 2026-08-18 and 2026-08-20, BINARY 2026-08-20) over different size ladders, so the rows do not line up.

| Bytes asked for | STRING, default | STRING, `DefaultStringColumnLength=65535` | BINARY, any setting tried |
|----|----|----|----|
| 512 | — | — | 512 ✓ |
| 1,000 | 1,000 ✓ | 1,000 ✓ | 1,000 ✓ |
| 1,023 | 1,023 ✓ | 1,023 ✓ | 1,023 ✓ |
| 1,024 | **1,023** ✗ | 1,024 ✓ | 1,024 ✓ |
| 1,025 | — | — | **1** ✗ |
| 1,500 | — | — | **476** ✗ |
| 2,000 | **1,023** ✗ | 2,000 ✓ | **976** ✗ |
| 2,048 | — | — | 1,024 ✗ |
| 5,000 | **1,023** ✗ | 5,000 ✓ | **904** ✗ |
| 20,000 | **1,023** ✗ | 20,000 ✓ | **544** ✗ |
| 42,000 | — | — | **16** ✗ |

`[verified: ran it on 2026-08-20]` There is no warning, no error and no truncation indicator in either case: the result is a valid-looking value that is simply wrong.

**The `BINARY` lengths follow an exact rule:**

```
bytes returned = n mod 1024        (with 0 -> 1024)
```

`[verified: ran it on 2026-08-20]` Confirmed against 17 payload sizes from 1,024 to 42,000 bytes with no deviation. Note what this means: a payload of exactly *k* × 1,024 bytes survives intact, and **1,025 bytes returns 1 byte**, losing 99.9% of the value. Worst case is not proportional to size, so a large-value spot check can pass while small values are destroyed.

`[verified: ran it on 2026-08-20]` **The returned bytes are a byte-exact prefix of the true value.** This is truncation, not corruption. It was tested with an all-distinct payload (5,120 bytes cycling `00..ff`), not just `repeat('x', n)`: a uniform payload makes any truncation look like a clean prefix, so it cannot settle the question. A byte-count check *is* therefore enough to detect it.

`[inference: not proven here]` The exact modulo, and `k` × 1,024 payloads surviving, is consistent with a length counter wrapping in a 1,024-byte buffer. Black-box evidence only; nothing here inspects driver internals.

The `STRING` half is fixable from R today: pass `DefaultStringColumnLength = 65535` to `dbConnect()`. The `BINARY` half is **not configurable** by any setting tried (`DefaultBinaryColumnLength` at 2000, 8000, 65535 and `"100000"` all return the identical wrong lengths). `brickster::DatabricksSQL()` is the only path that returns bytes exactly, because it decodes Arrow rather than the Thrift/ODBC wire format. If a table has a `BINARY` column and you need those bytes intact, use brickster DBI, not ODBC, full stop.

The upstream issue is `r-dbi/odbc#1024`, which is where to check whether this has since been fixed.

## The ambient-credential model

*This section describes Posit Workbench, where much of this pack was established. If you are not on Workbench, the fallbacks at the end of it are your route, and the expired-token signature below is worth reading either way: it is a property of the driver, not of the host.*

On Posit Workbench, credentials are ambient: `DATABRICKS_HOST`, `DATABRICKS_CONFIG_FILE` and `DATABRICKS_CONFIG_PROFILE` are injected into the session at sign-in. If they are unset, the session is simply not signed in, there is nothing else to configure.

Workbench renews the underlying token itself, on its own schedule. Nothing in R triggers that renewal. `odbc::databricks()` reads the host and token out of the Workbench-managed config file and hands them to the driver; it cannot prompt, refresh, or renew anything itself.

Fallbacks, for sessions without ambient credentials, are `DATABRICKS_TOKEN` or the `DATABRICKS_CLIENT_ID` / `DATABRICKS_CLIENT_SECRET` pair.

## The auth-failure signature

An auth failure does not surface as anything auth-shaped. It surfaces as this, verbatim:

```
ODBC failed with error 00000 from [RStudio][ThriftExtension].
(14) Unexpected response from server during a HTTP connection:
Unauthorized/Forbidden error response returned, but no token expired message received.
```

**Do not debug that as a warehouse, driver, or network fault.** It is an auth failure wearing a transport error's clothes.

**Confirm it by retrying the connection itself**, not by calling the REST API:

```r
con <- DBI::dbConnect(odbc::databricks(), httpPath = http_path)
DBI::dbGetQuery(con, "SELECT current_user() AS u")
```

If that returns your username, the credential is fine and the problem is elsewhere. This is the only check that tests the path you actually care about.

**A REST 401 does not prove the token is expired.** An earlier version of this section said to confirm with `/api/2.0/preview/scim/v2/Me` and expect `HTTP 401 "Token is expired"`. That test gives false positives and the guidance was **corrected on 2026-08-27**. Measured against an Azure Databricks workspace with OAuth (Entra ID) ambient credentials: every REST endpoint tried, `scim/v2/Me`, `clusters/list`, `sql/warehouses` and `unity-catalog/catalogs`, returned `HTTP 401` while `dbConnect()` authenticated successfully on the same credential seconds later. The token was a valid JWT with an hour left before `exp`. `[verified: ran it on 2026-08-27]`

Two reasons the REST check misleads:

- **The token may not carry REST authorisation at all.** A Workbench-injected OAuth JWT is audience-scoped, and the SQL/ODBC path and the REST API do not necessarily accept the same credential. A 401 can mean "not entitled to this API", not "expired".
- **The message text is not stable.** The documented `"Token is expired"` is one possibility. The observed message on a *valid* token was `"Credential was not sent or was of an unsupported type for this API"`, so matching on either string decides nothing.

If you do call REST, decode the JWT rather than trusting the status code. `exp` in the payload answers the expiry question directly:

```bash
python3 -c "import base64,json,sys; p=sys.argv[1].split('.')[1]; p+='='*(-len(p)%4); print(json.loads(base64.urlsafe_b64decode(p))['exp'])" "$TOKEN"
```

When the credential genuinely has expired, the fix is to wait for the platform to re-mint it, or to sign in again. Watch the config file's mtime to see the renewal happen; there is no other signal. Note that the mtime alone proves nothing about validity: a freshly written config and a failing connection can coexist, and a stale-looking mtime on a working credential is common. Test the connection, not the timestamp.

## Never do this

- **Do not use the `databricks` command-line tool to fix a login problem.** There may be no such CLI available at all, and even where there is one, its `auth login` step is not the fix for an ambient-credential failure: the credential is managed by Workbench, not by a CLI session.
  - **And do not justify that with `odbc:::is_hosted_session()`.** A tempting but wrong explanation is that `odbc` skips the CLI step inside a hosted session. That function returns `FALSE` in a Workbench session, so the reasoning does not hold. The conclusion is right for the simpler reason above: the credential is ambient, and a CLI login does not touch it.
- **Do not hard-code a warehouse ID or cluster ID in a document or script.** A cluster ID in particular is commonly per-user by construction (Dedicated access mode is one cluster per person), so a literal value is wrong for everyone but its author. Read both with `Sys.getenv()`, and degrade to a warning rather than a hard failure when the variable is empty, so shared code still runs for people without that resource.

## The `|>` rule

Use the base pipe `|>` in every example and script, never the magrittr pipe. `sparklyr`'s own documentation, and most Databricks vendor examples, use the magrittr pipe throughout: translate it as you read, do not copy it forward.
