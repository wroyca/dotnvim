---@module "conform"

---@type LazyPluginSpec
local Spec = {
  "stevearc/conform.nvim", event = "VeryLazy",

  init = function ()
    vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
  end,

  opts = {
    formatters_by_ft = {
      cpp = { "clang-format" },
      lua = { "stylua" },
    },
  },
}

return Spec
