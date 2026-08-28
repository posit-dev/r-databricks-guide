# Code style

The R idiom every code example on this site uses. Prose style is in `CLAUDE.md`; this file covers only code.

The rule underneath all of it: **the reader is fluent in the tidyverse, so code on this site looks like code she would write.** Base R where the tidyverse has an answer reads as translated-from-somewhere-else, and it costs her a moment of parsing on every line. That moment is the entire budget, and it should be spent on driver versus executor, not on `[[`.

Derived from the code under `example/`, which is the reference implementation. When in doubt, open `example/reducing.qmd` and copy its shape.

## The preamble

Every page that touches the data opens the same way. Copy it rather than inventing a variant:

```r
library(DBI)
library(dplyr)
library(dbplyr)
library(tibble)
library(glue)
library(cli)

catalog <- Sys.getenv("DATABRICKS_CATALOG")
schema <- Sys.getenv("DATABRICKS_SCHEMA")

con <- dbConnect(
  odbc::databricks(),
  httpPath = Sys.getenv("DATABRICKS_PATH"),
  DefaultStringColumnLength = 65535
)

tbl_name <- function(table) {
  glue("{catalog}.{schema}.{table}")
}
```

Three things in it are load-bearing.

**Connection details come from the environment, never from a helper and never hard-coded.** `Sys.getenv("DATABRICKS_PATH")` is what the reader must actually do. `dbx-config.R` exists for this repo's internals, solving a problem she does not have, and must not appear in any published page. `brickster` takes the same variable: `warehouse_id = basename(Sys.getenv("DATABRICKS_PATH"))`.

**`DefaultStringColumnLength = 65535` is load-bearing, not defensive.** Left at its default, an encoded geometry is silently clipped at 1,023 characters. The number is deliberately not round, because a round one can be silently dropped. Keep it and do not tidy it.

**No id, catalog or host is ever written literally.** `DATABRICKS_CLUSTER_ID` is per-user by construction, so a literal is wrong for everyone but its author.

## String construction: `glue()`

`glue()`, not `paste()`, `paste0()` or `sprintf()`. The site uses `glue()` 44 times; the only two `sprintf()` calls left are in `R/setup.R`, which is mostly unused and not a model.

```r
# yes
fq <- glue("`{catalog}`.`{schema}`.`{table}`")
dbExecute(con, glue("DROP TABLE IF EXISTS {fq}"))

# no
fq <- sprintf("`%s`.`%s`.`%s`", catalog, schema, table)
```

It wins because the interpolation reads in place. A `sprintf()` format string makes the reader hold `%s` positions in their head and match them against a list of arguments at the far end of the call.

Multi-line SQL goes inside a single `glue()` rather than being assembled by concatenation. Continue a long line with a trailing `\\` so the string stays one logical piece:

```r
cli_alert_info(
  "{nrow(per_station)} stations, \\
   {round(as.numeric(object.size(per_station)) / 1024)} KB"
)
```

## Messages: `cli`

`cli_alert_info()`, `cli_alert_success()` and `cli_abort()`, not `message()`, `cat()` or `stop()`. Every page under `example/` uses `cli`, and there are three `message`/`cat`/`warning` calls in the whole repository.

`cli` interpolates inline like `glue()`, so no separate formatting step is needed:

```r
cli_alert_info("{nrow(catchment_panel)} catchments, {round(panel_kb)} KB")
```

Errors carry structure and semantic classes. `{.val}` for values, `{.file}` for paths, `{.fn}` for functions:

```r
cli_abort(c(
  "Unknown profile {.val {profile}}.",
  i = "{.file {file}} defines: {.val {known}}.",
  x = "config::get() would have fallen back to
       {.val default} and given you the wrong compute."
))
```

The `i` and `x` bullets are worth the extra line: the first line says what is wrong, `i` says what would have been right, and `x` says what the silent failure would have cost. That shape is why the guard pages read as helpful rather than merely strict.

## Data manipulation

`dplyr` and `tidyr` throughout, and `tibble` rather than `data.frame`.

| Instead of | Use |
|----|----|
| `df[df$x > 1, ]` | `filter(df, x > 1)` |
| `df$y <- ...` | `mutate(df, y = ...)` |
| `lapply()`, `vapply()` | `purrr::map()`, `map_dbl()`, `map_chr()` |
| `do.call(rbind, ...)` | `purrr::list_rbind()`, `bind_rows()` |
| `data.frame()` | `tibble()` |
| `read.csv()` | `readr::read_csv()` |
| `aggregate()` | `group_by()` then `summarise()` |
| `merge()` | `left_join()`, `inner_join()` |

### Querying Databricks

**Write a `dbplyr` pipeline, not a SQL string.** `dbGetQuery()` is for the few things nothing else reaches, and two plausible reasons for reaching for it are wrong:

- Spatial `ST_` functions **do not** need SQL. `dbplyr` sends an unrecognised function name to the server verbatim, so `st_area()` and its siblings push down from an ordinary pipeline with no `sql()` wrapper. **Read the warning below before using this**, because the same convenience is also the sharpest trap on the platform.
- The `odbc` `BINARY` bug **does not** need SQL. It decides which connection you open, not which idiom you write: `brickster` ships a full `dbplyr` backend.

What genuinely needs a SQL string: `SHOW FUNCTIONS` and `DESCRIBE`; DDL (`CREATE`, `DROP`, `COMMENT ON`); and a scalar expression with no `FROM` clause, which has no table to hang a `tbl()` on.

| Instead of | Use |
|----|----|
| `dbGetQuery(con, "SELECT ...")` | `tbl()` and `dplyr` verbs |
| `dbGetQuery(con, "SHOW TABLES IN ...")` | `dbListTables(con, catalog_name =, schema_name =)` |
| `tbl(con, I(glue("{catalog}.{schema}.{t}")))` | `tbl(con, in_catalog(catalog, schema, t))` |
| `head(5)` to see a table's shape | `glimpse()`, which needs no `collect()` |

```r
readings <- tbl(con, in_catalog(catalog, schema, "hydrology_readings"))

readings |>
  glimpse()
```

`in_catalog()` quotes each part of the name separately, so a catalog or table whose name needs escaping still works. It replaces the older `tbl(con, I(...))` habit, where the `I()` existed only to stop `dbplyr` re-quoting a name that already had dots in it.

Name the catalog and schema in `dbListTables()` every time. Omitting them is not an error and does not warn: it lists whatever the connection defaults to, which on a shared warehouse is someone else's schema.

### `st_area()` above `collect()` is not `sf::st_area()`

The pass-through that makes spatial work convenient is also the one place a pipeline can run cleanly and answer wrongly.

Inside a `dplyr` verb on a remote table, nothing in R evaluates `st_area(g)`. `dbplyr` captures the name and sends it as text, and the server resolves it. Attaching `sf` changes nothing; detaching it changes nothing. **The same expression is the server's function above `collect()` and `sf`'s below it.**

A name the server does not have fails loudly with `UNRESOLVED_ROUTINE`, whether it is a typo or a real `sf` function with no server equivalent. That is the safe case. The dangerous case is a name that exists on both sides and means something different:

- **Different value.** Server-side `st_distance()`, `st_length()` and `st_area()` are planar; `sf` on unprojected coordinates uses s2 spherical geometry. On two WGS84 points the server returned `5` and `sf` returned 555,813 metres. Both correct, five orders of magnitude apart, no warning.
- **Different answer, on boundaries only.** The same modelling difference makes predicates diverge exactly on a polygon's edge, where the server sees a straight line and `sf` a geodesic. Interior and exterior agree. So **"measures are unsafe, predicates are safe" is false**, and the predicate case is worse, because it surfaces as a count a few rows out rather than as an implausible number.
- **Different shape.** `st_contains()` returns one boolean per row server-side against a sparse index list in `sf`; `st_distance()` a scalar per row against a matrix; `st_buffer()` takes two arguments and rejects `sf`'s `nQuadSegs`.
- **Absent entirely.** `st_makevalid()` and about twenty other `sf` staples have no server-side equivalent. The server will tell you a polygon is invalid and will not repair it.

**Project the coordinates before writing any spatial expression that crosses the line.** That is the fix for the first two at once, because `sf` engages s2 only for longitude and latitude: on a projected CRS it runs planar GEOS, which is what the server was doing anyway. Nothing else works. `st_setsrid()` is still worth writing, but `st_distance()` ignores the SRID, so a labelled column is not a checked one; attaching `sf` does nothing; `odbc`, `brickster` and `sparklyr` are all wrong identically; and no automated guard can help, because `dbplyr` builds the SQL before anything asks the server what CRS the data is in. Do not write `sf_use_s2(FALSE)`: it switches to an ellipsoidal model, so it repairs the predicates and leaves the measures wrong, which is worse than either error alone.

So write the geometry decode and the CRS assertion in the same `mutate()`, keep `st_setsrid()` around every `st_geomfromwkb()`, project before measuring or testing, and use `show_query()` when you are unsure which side you are on: anything it shows you is the server's. `howdoi/polygons.qmd` and `ref/spatial-functions.qmd` carry the detail.

## Pipes

Base pipe `|>` only, never `%>%`. Most Spark and Databricks documentation uses `%>%`, so translate anything borrowed.

Break the pipe across lines, one verb per line, as `example/` does. That keeps the `collect()` boundary visible, which is the site's whole narrative spine.

## Iteration: `purrr`, and `furrr` where it can run

`purrr` is the default for iteration everywhere. `map()`, `map_dbl()`, `map_chr()`, `map_lgl()`, `pmap()`, never `lapply()`, `sapply()`, `vapply()` or `do.call(rbind, ...)`.

For parallel iteration the preference is `furrr::future_map()` over a `future::plan()`, which is one line of change from `purrr::map()`.

There is exactly one reason the site ever falls back to `parallel::mclapply()`, and it is environmental rather than stylistic: **`future` and `furrr` are not in the cluster runtime bundle, and `parallel` is present in every context including the worker.** Getting `furrr` onto a worker is an init-script change, which means asking an administrator and waiting, not an `install.packages()` call. So:

- **In your own session**, `furrr` once installed. Better ergonomics, one line from serial.
- **Inside anything that might run on the cluster**, `parallel::mclapply()`, because it is there.

`example/parallel.qmd` settles this once for the whole site and states the reason plainly: the difference is not about which is better R. Link to that page rather than re-arguing it, and keep the framing environmental. Writing it as though `parallel` were pedagogically preferable misrepresents the finding, and it is a fact about the runtime as it stands rather than a permanent property.

One legitimate extension: `example/bootstrap.qmd` runs `mclapply()` locally, because that run is the local half of a local-then-distributed comparison and changing backends between the halves would confound it. Matching a backend you are comparing against is environmental too.

The same test decides every other fallback. Base R appears only where the tidyverse package **provably is not available in the environment the code runs in**. Nowhere else, and never for taste. If you reach for a base function, be able to name the environment that lacks the package.

## The genuinely package-free cases

Not fallbacks, just functions with no tidyverse counterpart worth reaching for: `Sys.getenv()`, `basename()`, `file.path()`, `object.size()`, `nzchar()`, `seq_len()`, and the `DBI` calls (`dbConnect()`, `dbGetQuery()`, `dbExecute()`, `dbDisconnect()`).

## Maps: `coord_sf()`, and the CRS said out loud

Every map on this site sets its coordinate system explicitly:

```r
ggplot(catchment_map) +
  geom_sf(aes(fill = rank), colour = NA) +
  coord_sf(crs = 27700, datum = 27700) +
  theme_void(base_size = 9)
```

The data is already in EPSG 27700, the British National Grid, because that is what the Environment Agency serves: eastings and northings in metres. `geom_sf()` would pick that up on its own, so the `coord_sf()` call changes nothing about the output. It is there to say which projection the map is in, on the page, where the reader can see it.

That is worth a line of code because the failure it guards against is silent. A map drawn from unprojected longitude and latitude is stretched noticeably north to south at this latitude, and nothing errors: you get a plausible, wrong-shaped Britain. Naming the CRS is how the page shows it got that right, and it is the habit to copy into her own work.

`datum = 27700` keeps any graticule on the same grid as the data rather than defaulting to WGS 84, which otherwise draws lon/lat gridlines across a projected map.

**Not `coord_map()`.** It is superseded in `ggplot2` as of 4.0, signals as much at runtime, and its own documentation says it should not be used in new code. It also needs `mapproj`, which is a dependency this project does not otherwise have. `coord_sf()` is the supported route and it reads the CRS from the data rather than taking a projection name.

Two things follow for spatial data generally. Declare a CRS when you build an `sf` object from bare columns, because `st_as_sf(coords = c("easting", "northing"))` without `crs =` produces geometry with no idea where on Earth it is:

```r
station_xy <- readRDS("station_xy.rds") |>
  st_as_sf(coords = c("easting", "northing"), crs = 27700)
```

And keep the jitter arithmetic off the geometry. `example/bootstrap.qmd` covers why at length: adding a two-column matrix to an `sfc` recycles the matrix per geometry instead of shifting point `i` by row `i`, and the intermediate runs to gigabytes inside GEOS where `gc()` cannot see it. Do the arithmetic on a plain matrix and build the points once.

## Chunk conventions

Under `example/`, chunks carry a `label`. Pages that reach a cluster gate on `eval` and degrade to a callout rather than breaking the site render.

Under `howdoi/`, chunks are `#| eval: false` with real output pasted beneath, so those pages stay outside the `freeze: true` discipline. That output must be copied from a genuine run, never typed by hand.

## Width

The site's usable full width is 733px, about **82 characters** at the site's 17px root. `code-overflow: wrap` means an over-long line wraps silently rather than showing a scrollbar, so nothing warns you when a line is too long.

This bites on real data: a `hydrology_readings.measure` value is a long composite string beginning with a station UUID, so printing one raw overflows the measure. Select or truncate around it.
