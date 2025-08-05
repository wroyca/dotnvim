---@module "mason"

---@type LazyPluginSpec
local Spec = {
  "mason-org/mason.nvim", event = "VeryLazy",

  opts = {
    pip = {
      upgrade_pip = true,
    },
  },
}

return Spec
