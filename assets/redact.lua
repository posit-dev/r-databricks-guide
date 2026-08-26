-- Redact workspace identifiers from every page, at pandoc time.
--
-- Declared in _quarto.yml under `filters:`, so it applies to the whole site
-- with no per-page opt-in. That is the point: the R-side hooks in R/setup.R
-- have to be added to each page by hand, and most executing pages do not have
-- them. They are safe only because nothing on them happens to print an
-- identifier today, which is luck rather than design.
--
-- WHAT THIS DOES NOT REPLACE. This runs after the freeze cache is written, so
-- it protects the rendered HTML and the search index but NOT _freeze/, which
-- is tracked and published. Masking a value before it is stored is the job of
-- wq_mask_all(), and this filter is a second layer rather than a substitute.
-- Removing the R hooks would leave secrets in a committed file.
--
-- It also only redacts what it is told about. The leak that reached a page in
-- this repo was a cluster's display name, dangerous precisely because nothing
-- knew that string was sensitive until it appeared in output. Neither layer
-- catches an identifier nobody has named, so scripts/check-public.sh remains
-- the backstop.
--
-- Kept in sync with wq_mask_all() in R/setup.R by hand. If you add a pattern
-- there, add it here.

local subs = {}

-- The catalog. Read from the environment rather than written in: this file is
-- tracked, so a literal here would be the leak it exists to prevent. The
-- schema is deliberately NOT masked: it is a substring of real table names
-- (bathing_water_classifications), so replacing it corrupts output the page is
-- teaching from.
--
-- IMPORTANT: pandoc's Lua reads the process environment, and this project
-- keeps its identifiers in .Renviron, which ONLY R reads. So os.getenv() here
-- returns nothing unless the variable is also exported to the shell that runs
-- quarto. A filter that silently substitutes nothing is worse than no filter,
-- because it looks like protection, so this warns rather than passing quietly.
local catalog = os.getenv("DATABRICKS_CATALOG")
if catalog and catalog ~= "" then
  table.insert(subs, { pattern = catalog, replacement = "your_catalog", plain = true })
else
  io.stderr:write(
    "redact.lua: DATABRICKS_CATALOG is not set in the environment, so the " ..
    "catalog will NOT be redacted from rendered output. It is read from " ..
    ".Renviron by R, which pandoc does not see. Export it to the shell " ..
    "running quarto, or rely on the knitr hooks and check-public.sh.\n"
  )
end

-- A Databricks host, which names the workspace.
local host = os.getenv("DATABRICKS_HOST")
if host and host ~= "" then
  table.insert(subs, { pattern = host, replacement = "<host>", plain = true })
end

-- A cluster id, and a worker hostname built from one.
table.insert(subs, { pattern = "%d%d%d%d%-%d%d%d%d%d%d%-%w%w%w%w%w%w%w%w+",
                     replacement = "<cluster-id>" })

-- A Workbench session name embeds the person who started it.
table.insert(subs, { pattern = "session%-%w+%-[%w%-]+", replacement = "<my-session>" })

local function redact(s)
  if s == nil then return nil end
  local changed = false
  for _, sub in ipairs(subs) do
    local new, n
    if sub.plain then
      -- `plain` avoids Lua pattern magic in a value read from the
      -- environment: a host name contains dots, which are wildcards.
      new, n = s:gsub(sub.pattern:gsub("(%W)", "%%%1"), sub.replacement)
    else
      new, n = s:gsub(sub.pattern, sub.replacement)
    end
    if n > 0 then s = new; changed = true end
  end
  if changed then return s end
  return nil
end

-- Executed output and echoed source both arrive as CodeBlock.
function CodeBlock(el)
  local new = redact(el.text)
  if new then el.text = new; return el end
end

-- Inline code in prose, e.g. a fully qualified table name.
function Code(el)
  local new = redact(el.text)
  if new then el.text = new; return el end
end

-- Prose. Pandoc splits text on whitespace, so a match has to be within one
-- Str; that is true of every identifier above, none of which contain spaces.
function Str(el)
  local new = redact(el.text)
  if new then return pandoc.Str(new) end
end

-- A link target can carry a host.
function Link(el)
  local new = redact(el.target)
  if new then el.target = new; return el end
end
