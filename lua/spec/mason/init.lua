---@module "mason"

---@type LazyPluginSpec
local Spec = {
  "mason-org/mason.nvim", event = "VeryLazy",

  opts = {
    pip = {
      upgrade_pip = true,
    },

    ui = {
      backdrop = 100,
    },
  },
}

return Spec
