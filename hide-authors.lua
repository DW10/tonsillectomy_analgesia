-- HTML book only: drop the author/affiliation metadata from every page except
-- those that set `show-authors: true` (the cover letter, index.qmd), so Quarto
-- builds no author block and no <meta name="author"> there. Word and PDF output
-- keep the full author list.

-- A page opts out by setting `show-authors: true` in its front matter
-- (index.qmd does); matching on the input file name is unreliable in Quarto.
local function keep_authors(meta)
  local v = meta["show-authors"]
  return v == true or (v ~= nil and pandoc.utils.stringify(v) == "true")
end

function Meta(meta)
  if not FORMAT:match("html") or keep_authors(meta) then return nil end
  for _, key in ipairs({ "author", "authors", "affiliations", "by-author", "by-affiliation" }) do
    meta[key] = nil
  end
  return meta
end
