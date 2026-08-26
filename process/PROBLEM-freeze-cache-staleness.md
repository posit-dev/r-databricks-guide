# Fixed: a freeze cache could pass `check-freeze.sh` while holding output that its source never produced

**Status: fixed.** `scripts/check-freeze-code.py` now catches this, and `check-freeze.sh` calls it. The rest of this file records what the bug was and why the fix takes the shape it does, because the failure is silent and the reasoning is not obvious from the code.

## Summary

`scripts/check-freeze.sh` compared an md5 of each `.qmd` against the hash Quarto recorded in that page's `_freeze/.../html.json`. When those agreed, the check reported the cache as current. **They can agree while the cached output came from different source**, so the check passed and the site published output that no longer matches the code shown above it.

This was hit twice in one working session, on `example/spatial.qmd` and on `howdoi/interactive.qmd`. In both cases the page was edited, the cache reported itself current, and the stored output still contained code and prose that had been deleted.

## Why the check cannot see it

The hash answers "which source did Quarto last *process* for this page". It does not answer "did the stored output come from *executing* that source". Those diverge because a project-level `quarto render` will refresh a page's `hash` and its `markdown` (re-running pandoc over the source) without re-executing the R chunks, since `freeze: true` means never re-execute.

The result is a cache that is internally inconsistent: new source, new hash, old executed output. Nothing in the repository detected it until the code check below.

## How to reproduce

Kept because it is how you confirm the check still works. Before the fix, step 4 reported the cache as current; it now fails.

1. Start from a clean tree with `scripts/check-freeze.sh` passing.
2. Edit a chunk on an executable page under `example/` so its output would change (for example, rename an output column).
3. Run a project-level `quarto render`.
4. Run `scripts/check-freeze.sh`. Before the fix it reported the cache as current.
5. Inspect the cache and observe the old output:

```bash
python3 -c "
import json
d = json.load(open('_freeze/example/spatial/execute-results/html.json'))
m = d['result']['markdown'] if 'result' in d else d['markdown']
print('old column still present:', 'n_sql' in m)
print('new column present     :', 'n_server' in m)"
```

Both can be true at once, which is the clearest signal that the stored markdown is a mixture rather than the product of one execution.

## How to re-render correctly

Deleting the page's freeze directory forces a genuine re-execution. `scripts/rerender.sh` does this, and it is why that script exists rather than calling `quarto render <page>` directly:

```bash
rm -rf _freeze/<path>          # then render
scripts/rerender.sh example/spatial.qmd
```

A plain `quarto render <page>` is **not** sufficient and may leave the stale output in place.

## Why this matters here

The site publishes from the committed cache, and CI has no R, so whatever is in `_freeze/` is what readers get. The repository's stated purpose for the check is to catch exactly this class of silent staleness, and on this path it does not. Every other guard in `scripts/` was sound; this was the one that gave false assurance, which is worse than no check because it is trusted.

## The fix, and how it works

Fixed by `scripts/check-freeze-code.py`, called from `check-freeze.sh` once the hash comparison passes. Because every existing caller goes through that one script, the hook, CI, `rerender.sh` and `rebuild-site.sh` all picked it up without separate wiring.

It works on the code Quarto echoes into the cached markdown. Every executed chunk appears there inside a fence carrying the `.cell-code` class, so the cache records not just the output but the code that produced it. The check pools those lines and asks whether each one still exists somewhere in the source's `{r}` chunks.

**The test is one-directional, and that is the whole reason it is reliable.** Code in the source but missing from the cache is ordinary: an `include: false` or `echo: false` chunk never reaches the cached markdown, and the masking chunk on every connecting page is exactly that. Code in the *cache* but missing from the *source* has no innocent explanation, because Quarto only ever echoes code it was handed. Checking only that direction gives zero false positives across all 21 caches on the current site.

Two details that a reimplementation would get wrong:

- **Chunk counts are not comparable.** knitr splits one source chunk into several `.cell-code` blocks wherever output is interleaved, so `howdoi/polygons.qmd` has 9 chunks and 14 cached blocks. Comparing counts produces nothing but false alarms; comparing the pooled lines is what works.
- **Chunk options and blank lines have to come out** before comparing. A `#|` line is not code, and it is not echoed the way the code around it is.

### What it does and does not catch

| Situation | Hash check | Code check |
|----|----|----|
| Source edited, cache untouched | catches | passes |
| Hash refreshed, output stale (this bug) | **passes** | **catches** |
| Chunk added, then hash refreshed | passes | passes |

The first two rows are why both checks are kept: neither subsumes the other. The third is the honest limit. A chunk that is purely *added* leaves nothing orphaned in the cache, so neither check sees it once the hash has been refreshed; in practice the hash check catches it first, because refreshing the hash requires a render that the author would have to do deliberately.

### Verifying it still works

The bug is reproducible in about ten seconds, and worth re-running after touching either script. Rename a column in a page's source, refresh only the recorded hash, and run the check:

```bash
sed -i 's/n_server/n_srv/g' example/spatial.qmd
python3 -c "
import json, hashlib, pathlib
p = pathlib.Path('_freeze/example/spatial/execute-results/html.json')
d = json.loads(p.read_text())
d['hash'] = hashlib.md5(pathlib.Path('example/spatial.qmd').read_bytes()).hexdigest()
p.write_text(json.dumps(d))"

scripts/check-freeze.sh          # must FAIL, naming the four n_server lines
git checkout -- example/spatial.qmd _freeze/example/spatial/
```

Before the fix that sequence printed `Freeze cache is current.` and exited 0.

## A second, simpler hazard in the same area

`scripts/rerender.sh` deletes a page's freeze directory to force re-execution, then renders. Interrupt it between those two steps and the page is left with **no cache at all**, which `check-freeze.sh` correctly reports as "has R chunks but no freeze cache".

This is not the staleness bug and needs no fix beyond knowing about it: recover with `git checkout -- _freeze` and run it again. It is recorded here because both were hit in the same session and they look alike from the outside, and because the recovery differs. Note that `--stale` can queue many pages, and a cluster-backed page takes minutes, so do not run it under a short timeout.

## Related, but out of scope

The first render after deleting a `_freeze` directory can print `Error in readLines(con, warn = FALSE) : cannot open the connection` while still executing every chunk and producing correct output and HTML. It does not recur on a second render and does not appear in a full project render, which exits 0. Root cause not established; noted here only so it is not mistaken for a symptom of the staleness bug.
