# Problem: a freeze cache can pass `check-freeze.sh` while holding output that its source never produced

## Summary

`scripts/check-freeze.sh` compares an md5 of each `.qmd` against the hash Quarto recorded in that page's `_freeze/.../html.json`. When those agree the check reports the cache as current. **They can agree while the cached output came from different source**, so the check passes and the site publishes output that no longer matches the code shown above it.

This was hit twice in one working session, on `example/spatial.qmd` and on `howdoi/interactive.qmd`. In both cases the page was edited, the cache reported itself current, and the stored output still contained code and prose that had been deleted.

## Why the check cannot see it

The hash answers "which source did Quarto last *process* for this page". It does not answer "did the stored output come from *executing* that source". Those diverge because a project-level `quarto render` will refresh a page's `hash` and its `markdown` (re-running pandoc over the source) without re-executing the R chunks, since `freeze: true` means never re-execute.

The result is a cache that is internally inconsistent: new source, new hash, old executed output. Nothing in the repository detects it.

## How to reproduce

1. Start from a clean tree with `scripts/check-freeze.sh` passing.
2. Edit a chunk on an executable page under `example/` so its output would change (for example, rename an output column).
3. Run a project-level `quarto render`.
4. Run `scripts/check-freeze.sh`. It reports the cache as current.
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

## The workaround in use today

Deleting the page's freeze directory forces a genuine re-execution. `scripts/rerender.sh` does this, and it is why that script exists rather than calling `quarto render <page>` directly:

```bash
rm -rf _freeze/<path>          # then render
scripts/rerender.sh example/spatial.qmd
```

A plain `quarto render <page>` is **not** sufficient and may leave the stale output in place.

## Why this matters here

The site publishes from the committed cache, and CI has no R, so whatever is in `_freeze/` is what readers get. The repository's stated purpose for the check is to catch exactly this class of silent staleness, and on this path it does not. Every other guard in `scripts/` is sound; this is the one that gives false assurance, which is worse than no check because it is trusted.

## What a fix needs to establish

- **Detect the inconsistency.** Some evidence that the stored output was produced by the stored source. Options worth investigating: whether Quarto records an execution timestamp or an engine-level hash separately from the source hash; whether the `markdown` field can be compared against the `.qmd`'s chunk contents; or whether the check should compare the code echoed inside `markdown` against the code in the source.
- **Distinguish the two render paths**, since a page-level render after deleting the cache behaves correctly and a project-level render over an edited source does not.
- **Fail loudly rather than warn**, matching the existing style: the check already exits non-zero and is wired into the pre-push hook and CI.

## Constraints for whoever picks this up

- CI has no R installed and replays `_freeze/` as text, so the check must remain pure shell or Python over the JSON. It cannot execute R.
- `_freeze/` is tracked. Anything that deletes cache files destroys output only a credentialed local render can rebuild, so a fix must not delete as a side effect of checking.
- `example/bootstrap.qmd` only produces its cluster output under `WQ_RUN_CLUSTER=true`. A fix that encourages blanket re-rendering will silently strip that page's output.
- Do not weaken the existing hash comparison; it correctly catches the common case of an edited source with an untouched cache.

## Related, but out of scope

The first render after deleting a `_freeze` directory can print `Error in readLines(con, warn = FALSE) : cannot open the connection` while still executing every chunk and producing correct output and HTML. It does not recur on a second render and does not appear in a full project render, which exits 0. Root cause not established; noted here only so it is not mistaken for a symptom of the staleness bug.
