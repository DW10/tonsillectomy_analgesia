-- Builds a separate title page (BJA house style) from the title, author,
-- affiliations and keywords metadata, followed by a page break. The corresponding
-- author line gives the name, postal address (their affiliations from the plume sheet,
-- or an `address` field if one is set) and e-mail. No phone number is printed.
-- Runs only when the document sets `title-page: true`. Quarto copies the
-- full author records to `authors` and reduces `author` to names.

local str = pandoc.utils.stringify

local function as_list(x)
  if x == nil then return {} end
  if pandoc.utils.type(x) == "List" then return x end
  return { x }
end

local function is_true(x)
  return x == true or (x ~= nil and str(x) == "true")
end

local function author_name(a)
  local n = a.name
  if n == nil then return str(a) end
  if type(n) == "table" and (n.given or n.family) then
    return str(n.given or "") .. (n.given and n.family and " " or "") .. str(n.family or "")
  end
  if type(n) == "table" and n.literal then return str(n.literal) end
  return str(n)
end

local function affiliation_text(af)
  if type(af) ~= "table" or af.name == nil then return str(af) end
  local parts = { str(af.name) }
  for _, k in ipairs({ "city", "country" }) do
    if af[k] and not parts[1]:find(str(af[k]), 1, true) then
      table.insert(parts, str(af[k]))
    end
  end
  return table.concat(parts, ", ")
end

local function build(meta)
  local by_id = {}
  for _, af in ipairs(as_list(meta.affiliations)) do
    if af.id then by_id[str(af.id)] = affiliation_text(af) end
  end

  local aff_order, aff_num = {}, {}
  local function number_for(text)
    if not aff_num[text] then
      table.insert(aff_order, text)
      aff_num[text] = #aff_order
    end
    return aff_num[text]
  end

  local author_inlines, corresponding = pandoc.Inlines({}), {}
  for i, a in ipairs(as_list(meta.authors or meta.author)) do
    local marks = {}
    for _, ref in ipairs(as_list(a.affiliations)) do
      local key = type(ref) == "table" and ref.ref and str(ref.ref) or nil
      local text = key and by_id[key] or (key == nil and affiliation_text(ref)) or nil
      if text == nil then
        local s = str(ref)
        text = by_id[s] or s
      end
      table.insert(marks, tostring(number_for(text)))
    end
    local is_corr = a.attributes and is_true(a.attributes.corresponding) or is_true(a.corresponding)
    if is_corr then
      table.insert(marks, "*")
      table.insert(corresponding, a)
    end
    if i > 1 then author_inlines:extend({ pandoc.Str(","), pandoc.Space() }) end
    author_inlines:insert(pandoc.Str(author_name(a)))
    if #marks > 0 then
      author_inlines:insert(pandoc.Superscript(table.concat(marks, ",")))
    end
  end

  local blocks = pandoc.Blocks({})
  if meta.title then
    blocks:insert(pandoc.Div(pandoc.Para(meta.title), { ["custom-style"] = "Title" }))
  end
  if #author_inlines > 0 then
    blocks:insert(pandoc.Div(pandoc.Para(author_inlines), { ["custom-style"] = "Author" }))
  end
  for n, text in ipairs(aff_order) do
    blocks:insert(pandoc.Para({ pandoc.Superscript(tostring(n)), pandoc.Space(), pandoc.Str(text) }))
  end
  for _, a in ipairs(corresponding) do
    local parts = { author_name(a) }
    if a.address then
      table.insert(parts, str(a.address))
    else
      for _, ref in ipairs(as_list(a.affiliations)) do
        local key = type(ref) == "table" and ref.ref and str(ref.ref) or str(ref)
        table.insert(parts, by_id[key] or key)
      end
    end
    local line = pandoc.Inlines({ pandoc.Str("*Corresponding author: " .. table.concat(parts, ", ")) })
    if a.email then
      line:extend({ pandoc.Str("."), pandoc.Space(), pandoc.Str("E-mail:"), pandoc.Space(),
        pandoc.Link(str(a.email), "mailto:" .. str(a.email)) })
    end
    blocks:insert(pandoc.Para(line))
  end

  local kw = {}
  for _, k in ipairs(as_list(meta.keywords)) do table.insert(kw, str(k)) end
  if #kw > 0 then
    blocks:insert(pandoc.Header(1, "Keywords", { class = "unnumbered" }))
    blocks:insert(pandoc.Para(pandoc.Str(table.concat(kw, "; "))))
  end

  blocks:insert(pandoc.RawBlock("openxml", '<w:p><w:r><w:br w:type="page"/></w:r></w:p>'))
  return blocks
end

function Pandoc(doc)
  if not is_true(doc.meta["title-page"]) then return nil end
  local title_page = build(doc.meta)
  title_page:extend(doc.blocks)
  doc.blocks = title_page
  for _, k in ipairs({ "title", "subtitle", "author", "authors", "affiliations", "date" }) do
    doc.meta[k] = nil
  end
  return doc
end
