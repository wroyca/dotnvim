---@module "mini.pairs"

---@type LazyPluginSpec
local Spec = {
  "mini.pairs", virtual = true,

  keys = {
    { "`", mode = "i" },
    { "'", mode = "i" },
    { '"', mode = "i" },
    { "{", mode = "i" },
    { "}", mode = "i" },
    { "<", mode = "i" },
    { ">", mode = "i" },
    { "(", mode = "i" },
    { ")", mode = "i" },
    { "[", mode = "i" },
    { "]", mode = "i" },
  },

  opts = {
    mappings = {
      ["`"] = { action = "closeopen", pair = "``", neigh_pattern = "[^%S][^%S]", register = { cr = false } },
      ["'"] = { action = "closeopen", pair = "''", neigh_pattern = "[^%S][^%S]", register = { cr = false } },
      ['"'] = { action = "closeopen", pair = '""', neigh_pattern = "[^%S][^%S]", register = { cr = false } },
      ["{"] = { action = "closeopen", pair = "{}", neigh_pattern = "[^%S][^%S]", register = { cr = false } },
      ["<"] = { action = "closeopen", pair = "<>", neigh_pattern = "[^%S][^%S]", register = { cr = false } },
      ["("] = { action = "closeopen", pair = "()", neigh_pattern = "[^%S][^%S]", register = { cr = false } },
      ["["] = { action = "closeopen", pair = "[]", neigh_pattern = "[^%S][^%S]", register = { cr = false } },
    },
  },
}

return Spec
