-- Replaces cross-document references (here the @sec-sm-* supplementary sections) with fixed
-- text from `xref-hardcode:` in the document's metadata (generated into submission/xref-map.yml
-- by scripts/xref_map.R). Also fixes references inside float caption attributes
-- (fig-cap / tbl-cap), which are only parsed later by Quarto.
local map = {}

local function replace_refs(s)
  return (s:gsub("@([%w%-_]+)", function(id) return map[id] end))
end

return {
  {
    Meta = function(m)
      for k, v in pairs(m["xref-hardcode"] or {}) do
        map[k] = pandoc.utils.stringify(v)
      end
    end
  },
  {
    Cite = function(c)
      if #c.citations == 1 and map[c.citations[1].id] then
        return pandoc.Str(map[c.citations[1].id])
      end
    end,
    Div = function(d)
      local changed = false
      for _, k in ipairs({ "fig-cap", "tbl-cap" }) do
        local v = d.attributes[k]
        if v then
          local nv = replace_refs(v)
          if nv ~= v then d.attributes[k] = nv; changed = true end
        end
      end
      if changed then return d end
    end
  }
}
