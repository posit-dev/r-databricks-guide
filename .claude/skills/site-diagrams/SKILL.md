---
name: site-diagrams
description: Use when adding, editing or reviewing a diagram on the R on Databricks guide. Covers the Graphviz-over-mermaid decision, the both-modes colour palette, the width budget, and how to preview a diagram with the dark mode toggle. Also use when deciding whether a passage wants a diagram at all rather than a table or a list.
---

# Diagrams on this site

Established 2026-08-25 by building four candidates and rejecting two. Read this before drawing anything: most of it was learned by paying for the alternative.

## Decide whether it should be a diagram at all

Two of the three candidates in the original brainstorm were dropped, so the default answer is no.

- A **diagram** earns its place when the relationship is spatial or topological: two sides with a boundary, a branch, a cycle. If it can be a list without loss, it was a list.
- A **table** wants two columns of genuinely parallel information and three or more rows. Two rows is a sentence.
- A **bullet list** wants items that are independent, where order carries no meaning. If each item depends on the previous, that dependency is the content and bullets throw it away.

All three are worth most on a page the reader returns to and scans. Reference pages benefit most, explanatory prose least.

The rejected case is worth knowing because it looked strong. A diagram of the four assumptions on `concepts/index.qmd` was built and dropped: four independent assumption-to-symptom pairs with no structure between them is a list, and drawing a list as boxes makes it take more space and adds nothing. Worse, the first draft drew the dependency chain and the symptom branches as two kinds of arrow out of the same node, so it read as one flow you traverse, implying you travel from an assumption to a symptom. If a diagram needs two arrow meanings, it is probably two diagrams or no diagram.

## Use `dot`, not mermaid

Both are built into Quarto with no install: no `graphviz` binary is needed, because Quarto bundles its own. Verified on Quarto 1.10.18.

Use `dot`. It is the only one of the two that gives the layout control this site's diagrams need: `rank=same` for ordering, compass ports (`:w`, `:e`) for pinning an edge to a side, `lhead`/`ltail` with `compound=true` for attaching an edge to a cluster boundary, and per-node `width` for aligning boxes.

Know the cost before choosing it, because it cuts the other way on theming:

- **Mermaid follows the Bootstrap theme automatically**, including dark mode, because this site uses bootswatch themes (`cosmo` and `darkly`). It also exposes `--mermaid-node-bg-color` and similar CSS variables.
- **Graphviz has no dark mode support at all.** No theming, no CSS variables, nothing in the Quarto docs. Colours are baked into the emitted SVG.

Rendering twice and swapping with CSS is Quarto's documented method for **images** (`.light-content` / `.dark-content`), not for diagrams. It could be hand-rolled for `dot` but means two copies of every diagram to keep in sync. Not done here.

The resolution is the palette below: one SVG that looks decent in both modes rather than ideal in either. That is a deliberate trade, not an oversight.

## The both-modes palette

The site is `#fbfaf8` paper with `#17212B` text in light mode, and `#17212B` paper with `#ccc` text in dark. A colour has to clear **3:1 against both** (the WCAG minimum for non-text graphics).

Measured, so do not substitute by eye:

| Colour | On light | On dark | Use |
|---|---|---|---|
| `#447099` | 5.00 | 3.12 | Databricks box, the outbound arrow. The site's own accent, and it survives both. |
| `#A08C6E` | 3.11 | 5.02 | The R session box, the `collect()` arrow. |
| `#8A8A8A` | 3.31 | 4.72 | Node strokes, node label text, minor arrows. |
| `#7494B1` | 3.04 | 5.13 | Spare, if a third accent is needed. |

Two traps this palette exists to avoid:

- **Never set a fill.** Use `style=rounded`, never `style="rounded,filled"`, and set `bgcolor="transparent"` on the graph. A baked `#ffffff` fill is the single thing that breaks dark mode, and it hides a failing stroke colour by giving it a white background to sit on.
- **The gold `#C9A227` fails in light mode** at 2.32:1, despite looking fine in earlier drafts precisely because it sat on a white fill. `#A08C6E` is the replacement and reads as the same warm family.

`#8A8A8A` gives 3.31:1 on light paper, which clears the graphics threshold but not the 4.5:1 text threshold. If node labels read as thin, darken `fontcolor` only and leave the stroke, which costs nothing on the dark side.

## The width budget

The site measure is **733px**, per the arithmetic in `CLAUDE.md`. A wider diagram scales down and takes its label text with it, which is the same silent failure as an over-long code line.

`fig-width` does not reliably control this: Graphviz's own sizing wins. What matters is the native `viewbox`, in points, which converts at `px = pt * 96/72`. Check it rather than trusting the chunk option:

```bash
python3 -c "
import re
h=open('_site/PAGE.html').read()
for l in re.findall(r'viewbox=\"([0-9. ]+)\"', h):
    v=l.split(); w=float(v[2]); px=w*96/72
    print(f'{w:.0f}pt = {px:.0f}px ' + ('fits' if px<=733 else 'SCALES to %.0f%%'%(733/px*100)))
"
```

Vertical layouts fit comfortably (the current home page diagram is 604px). **Horizontal ones generally do not**: two boxes side by side plus edge labels measured 757px and 841px in testing, both over budget. `rankdir=LR` looks appealing and is usually the wrong choice here.

## Aligning two cluster boxes

Graphviz sizes a cluster to fit its contents *and its label*, so two boxes only line up if both are forced. Set an explicit `width` on every node, equal across both clusters, and tune it until the boxes match. The current diagram uses `width=1.8`.

Changing a cluster label's `fontsize` breaks the alignment, because the label participates in the box's minimum width. If the boxes drift apart after an edit, check the label sizes before the node widths.

Verify by measurement, not by eye:

```bash
python3 -c "
import re
h=open('_site/PAGE.html').read()
s=re.findall(r'<svg.*?</svg>', h, re.S)[0]
for m in re.finditer(r'<title>(cluster_\w+)</title>\s*<path[^>]*?d=\"([^\"]+)\"', s):
    xs=[float(x) for x in re.findall(r'([-\d.]+),[-\d.]+', m.group(2))]
    print(f'{m.group(1):16} left={min(xs):7.2f} right={max(xs):7.2f} width={max(xs)-min(xs):6.2f}')
"
```

Equal `left` and `right` on both clusters means aligned.

## Left-to-right reading order

Within a vertical layout, put the outbound thing on the left and the returning thing on the right, so the round trip reads as a circuit rather than two arrows pointing opposite ways.

The mechanism is a `rank=same` pair with an invisible weighted edge to force the order, then compass ports to pin the arrows:

```
{ rank=same; pipe -> result [style=invis weight=10]; }
pipe:w -> query:w   // out on the left
out:e -> result:e   // back on the right
```

An arrow leaving from the right needs a node on the right to leave from. That is why the Databricks side has a separate `out` node rather than the query alone: it is load-bearing for the layout, and it also usefully distinguishes the query from its result.

## Previewing with the dark mode toggle

`quarto render diagrams.qmd --to html` gets the theme but **not** the site chrome, so the output has no light/dark toggle and cannot be checked for dark mode. `grep -c 'quarto-color-scheme-toggle'` returning 0 is the tell.

`_quarto.yml` has an explicit render list, so a scratch page must be added to it temporarily to get the toggle:

```yaml
  render:
    - index.qmd
    # TEMPORARY: scratch diagram preview, remove before committing
    - diagrams.qmd
```

Then `quarto render diagrams.qmd` (no `--to`) outputs to `_site/` with the navbar, and `quarto preview` serves it. Back up `_quarto.yml` first and **remove the entry before committing**.

Rendering a single page rather than the site avoids touching `example/`, which is frozen and would need credentials. Other pages in that preview will be stale; only the page you rendered is current.

## The current diagram

`index.qmd` carries one diagram: the `collect()` boundary, showing that her `dplyr` runs as SQL over there and `collect()` is the one moment data crosses. Source is in the page.

It is a round trip on purpose. An earlier draft had only the returning arrow, which made her session look like a passive recipient when in fact she wrote the pipeline and her session sent it. Two arrows is what "your session is a client, not a place the work happens" actually means.

The outbound arrow is labelled `runs as SQL` rather than naming a function, because there is no function call that sends it: the pipeline is lazy and the sending is implicit.
