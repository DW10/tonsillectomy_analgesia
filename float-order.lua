-- Records the label of every float, in document order, as `float-order` metadata (a list of
-- ids such as fig-venn-adult, sfig-dag, stbl-missing-data). Quarto removes float ids and adds
-- the "Figure 1:" prefix only at the very end of Word rendering, so submission-split.lua uses
-- this list to know which float is which. Floats are numbered in document order per type.
local ids = pandoc.List({})

return {
  {
    FloatRefTarget = function(float)
      ids:insert(pandoc.MetaString(float.identifier))
    end
  },
  {
    Meta = function(m)
      m["float-order"] = pandoc.MetaList(ids)
      return m
    end
  }
}
