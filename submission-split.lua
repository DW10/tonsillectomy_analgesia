-- Post-crossref filter that cuts a wrapper document down to the part wanted for submission.
-- Mode is set per document with `submission-keep:` in its front matter:
--   prose  : drop every float and the `.supp-only` block that is included only so Quarto
--            numbers the Figure S / Table S references correctly.
--   floats : keep only the floats, with their captions, in this order: List of Figures,
--            List of Tables, then Main figures, Main tables, Supplementary figures,
--            Supplementary tables, each float on its own page. The lists give number and
--            bold caption title (no page numbers: Word needs caption fields for that).
-- Cross-references have already been resolved when this runs, so "Figure 1", "Table S3" and
-- friends in the remaining text are correct. After cross-referencing Quarto leaves each float
-- as an anonymous Div tagged `__quarto_custom_type=FloatRefTarget`. That tag is only visible
-- when walking the document by hand (a normal Div handler does not see it), hence the
-- explicit recursion over doc.blocks.

local function is_float(d)
  return d.attributes["__quarto_custom_type"] == "FloatRefTarget"
end

local function has_class(d, c)
  for _, k in ipairs(d.classes) do if k == c then return true end end
  return false
end

-- Returns the blocks with floats / .supp-only Divs removed, recursing into Divs. Cell
-- wrappers that end up empty are dropped too.
local function strip(blocks)
  local out = pandoc.Blocks({})
  for _, b in ipairs(blocks) do
    if b.t == "Div" then
      if not (is_float(b) or has_class(b, "supp-only")) then
        local inner = strip(b.content)
        local wrapper = has_class(b, "cell") or has_class(b, "cell-output-display")
        if #inner > 0 or not wrapper then
          b.content = inner
          out:insert(b)
        end
      end
    else
      out:insert(b)
    end
  end
  return out
end

-- ---- floats mode -------------------------------------------------------------------------

local PAGE_BREAK = pandoc.RawBlock("openxml", '<w:p><w:r><w:br w:type="page"/></w:r></w:p>')

-- Float Divs in document order, without descending into a float
local function collect(blocks, acc)
  for _, b in ipairs(blocks) do
    if b.t == "Div" then
      if is_float(b) then acc:insert(b) else collect(b.content, acc) end
    end
  end
  return acc
end

-- First Plain/Para with text inside a float: its caption (the image paragraph has no text)
local function find_caption(blocks)
  for _, b in ipairs(blocks) do
    if b.t == "Plain" or b.t == "Para" then
      if pandoc.utils.stringify(b):match("%S") then return b end
    elseif b.t == "Div" then
      local c = find_caption(b.content)
      if c then return c end
    end
  end
end

local KINDS = {
  fig = { "Figure", false }, tbl = { "Table", false },
  sfig = { "Figure", true }, stbl = { "Table", true },
}

-- Number each float within its type in document order and read its bold caption title
local function describe(float, id, counters)
  local prefix = id:match("^(%a+)%-")
  local k = KINDS[prefix]
  if not k then return nil end
  counters[prefix] = (counters[prefix] or 0) + 1
  local cap = find_caption(float.content)
  local text = cap and pandoc.utils.stringify(cap) or id
  local title
  if cap then cap:walk({ Strong = function(st) title = title or pandoc.utils.stringify(st) end }) end
  title = (title or text):gsub("%.%s*$", "")
  return { float = float, kind = k[1], supp = k[2], num = counters[prefix], id = id,
           label = k[1] .. " " .. (k[2] and "S" or "") .. counters[prefix], title = title }
end

local function heading(text)
  return pandoc.Header(1, text, pandoc.Attr("", { "unnumbered" }))
end

local function build_floats(doc)
  local items = pandoc.List({})
  local floats = collect(doc.blocks, pandoc.List({}))
  local ids = doc.meta["float-order"] or {}
  if #floats ~= #ids then
    io.stderr:write(string.format("[submission-split] WARNING: %d floats found but %d labels recorded; numbering may be wrong\n", #floats, #ids))
  end
  local counters = {}
  for n, f in ipairs(floats) do
    local d = ids[n] and describe(f, pandoc.utils.stringify(ids[n]), counters)
    if d then items:insert(d) else io.stderr:write("[submission-split] unlabelled float skipped\n") end
  end
  local function pick(kind, supp)
    local out = items:filter(function(i) return i.kind == kind and i.supp == supp end)
    table.sort(out, function(a, b) return a.num < b.num end)
    return out
  end
  local groups = {
    { "Main figures", pick("Figure", false) },
    { "Main tables", pick("Table", false) },
    { "Supplementary figures", pick("Figure", true) },
    { "Supplementary tables", pick("Table", true) },
  }
  local function list(title, a, b)
    local blocks = pandoc.Blocks({ heading(title) })
    for _, g in ipairs({ a, b }) do
      for _, i in ipairs(g) do
        blocks:insert(pandoc.Para({ pandoc.Str(i.label .. ":"), pandoc.Space(), pandoc.Str(i.title) }))
      end
    end
    return blocks
  end
  local out = pandoc.Blocks({})
  out:extend(list("List of figures", groups[1][2], groups[3][2]))
  out:extend(list("List of tables", groups[2][2], groups[4][2]))
  for _, g in ipairs(groups) do
    if #g[2] > 0 then
      out:insert(PAGE_BREAK)
      out:insert(heading(g[1]))
      for n, i in ipairs(g[2]) do
        if n > 1 then out:insert(PAGE_BREAK) end
        out:insert(i.float)
      end
    end
  end
  return out
end

function Pandoc(doc)
  local keep = doc.meta["submission-keep"]
  keep = keep and pandoc.utils.stringify(keep) or ""
  if keep == "prose" then
    doc.blocks = strip(doc.blocks)
    return doc
  elseif keep == "floats" then
    doc.blocks = build_floats(doc)
    return doc
  end
end
