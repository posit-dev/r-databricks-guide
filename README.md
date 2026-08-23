
# R on Databricks

A working guide for R users whose data lives in Databricks.

It is written for one person: a research scientist who is fluent in R, was not consulted about the move to Databricks, and wants to finish an analysis rather than administer a platform. Most Databricks documentation is written for the other reader.

## Reading it

The rendered site is the guide. Build it with:

```bash
quarto render     # -> _site/
quarto preview    # live preview
```

## Running the code

You need your own Databricks workspace. Nothing here points at one.

1.  Copy `.Renviron.example` to `.Renviron` and fill in your warehouse path, catalog and schema. `.Renviron` is gitignored and must stay that way.
2.  Restart R so the values are read.
3.  Check the connection works:

```bash
Rscript check-databricks-access.R
```

That script is the first thing to run, and the first thing to re-run before concluding a document is broken.

Packages come from [P3M](https://p3m.dev/cran/latest), which serves pre-built binaries on Linux. Restore the environment with `R -e 'renv::restore()'`.

### Credentials

On Posit Workbench, Databricks credentials are ambient: they are injected when you sign in, and Workbench renews them on its own schedule. If `DATABRICKS_HOST` and `DATABRICKS_CONFIG_FILE` are unset, you are not signed in. An expired token shows up as an opaque ODBC driver error rather than anything that looks like an auth failure.

## Skills

`skills/` holds five agent skills for working with Databricks from R, covering connections, `brickster`, Unity Catalog, compute lifecycle and parallel methods. They assume no `databricks` CLI. Start at `skills/README.md`.

## Contributing

This repository is public by default: anything committed may be published. Run the publication check before pushing.

```bash
scripts/check-public.sh
```

It refuses any hard-coded warehouse id, cluster id or catalog name, along with personal and customer identifiers. Read `CLAUDE.md` for the editorial rules, in particular the one this repository exists to enforce: this is a user guide, not a research record, and a finding earns a place only if it changes what the reader does.

## Licences

The code in this repository is available under the MIT licence.

Where the guide describes data, two licences apply and both must be preserved: environmental agency data is **OGL v3.0**, and storm overflow locations are **CC BY 4.0**, not OGL. They are different, and the difference has to survive into any page that describes the data.
