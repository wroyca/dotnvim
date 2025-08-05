---@module "mason-lspconfig"

---@type LazyPluginSpec
local Spec = {
  "mason-org/mason-lspconfig.nvim", event = "VeryLazy", dependencies = "mason.nvim",

  opts = {
    ensure_installed = {
      "lua_ls",
      "clangd",
    },
  },
}

return Spec
