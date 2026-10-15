-- Post-crossref filter that cuts a wrapper document down to the part wanted for submission.
-- Mode is set per document with `submission-keep:` in its front matter:
--   prose  : drop every float and the `.supp-only` block that is included only so Quarto
--            numbers the Figure S / Table S references correctly.
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

function Pandoc(doc)
  local keep = doc.meta["submission-keep"]
  if keep and pandoc.utils.stringify(keep) == "prose" then
    doc.blocks = strip(doc.blocks)
    return doc
  end
end
