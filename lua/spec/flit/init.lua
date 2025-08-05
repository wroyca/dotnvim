---@module "flit"

---@type LazyPluginSpec
local Spec = {
  "ggandor/flit.nvim", dependencies = "ggandor/leap.nvim", commit = "669c5a3c0494b1d032b7366e8935888bfa3953a2",

  keys = {
    {
      "f",
      mode = { "n", "x", "o" },
      desc = "Flit forward to",
    },
    {
      "F",
      mode = { "n", "x", "o" },
      desc = "Flit backward to",
    },
    {
      "t",
      mode = { "n", "x", "o" },
      desc = "Flit forward till",
    },
    {
      "T",
      mode = { "n", "x", "o" },
      desc = "Flit backward till",
    },
  },

  opts = {
    multiline = false,
    labeled_modes = "nx",
  },
}

return Spec
