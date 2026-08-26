
# R on Databricks: a skills pack

Five skills for working with Databricks from R. They assume no `databricks` CLI: everything routes through `brickster` (workspace and control plane) and `sparklyr` (Spark and distributed R).

Start with `r-databricks-connections`. It routes to the rest.

| Skill | Answers |
|----|----|
| `r-databricks-connections` | Which connection path, and why the credential just failed |
| `r-databricks-brickster` | How the `brickster` package works |
| `r-databricks-unity-catalog` | How do I find and query a table |
| `r-databricks-compute` | Should I start this cluster, and what does it cost |
| `r-databricks-parallel` | Which parallel method, and how do I distribute R |

## Conventions

- **Base pipe `|>` only.** sparklyr's documentation uses the magrittr pipe throughout; translate it.
- **`dbplyr` pipelines, not SQL strings.** Default to `tbl()` and verbs. Neither spatial `ST_` functions nor the `odbc` `BINARY` bug is a reason to drop to `dbGetQuery()`: unknown function names pass through to the server verbatim, and the `BINARY` bug constrains the connection rather than the idiom. `r-databricks-unity-catalog` has the detail and the short list of things that genuinely need SQL.
- **Evidence tags.** `[verified: ran it on DATE]` means someone ran it. `[documented: read it on DATE]` means someone read the vendor documentation. `[unresolved]` means nobody knows. A documented claim is never presented as a measured one.
- **Timings are not benchmarks.** Warehouse submit latency varies by up to 6.5× and results cache. Figures carry a date and a tag.
- **No customer or project detail.** These skills are portable by construction. Anything naming a specific catalog, warehouse, cluster or dataset belongs in a project-local skill.
- **Runnable scripts sit in a `scripts/` directory beside the skill.** Each is self-contained, reads every identifier from the environment with `Sys.getenv()`, and says in its header what was run, where, and when. A script that has not been executed does not belong here.
- **This copy is published.** It is symlinked into a public repository, so anything committed may go out. Assume no private context survives.

## Prior art

Databricks publishes an official pack at `databricks/databricks-agent-skills`, roughly 30 skills covering the CLI, Unity Catalog governance, jobs, pipelines and serverless migration. It is worth using **if you have the `databricks` CLI**, which every skill there requires. It contains no R and no `sparklyr` content, which is why this pack exists.
