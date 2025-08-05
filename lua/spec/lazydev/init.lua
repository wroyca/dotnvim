---@module "lazydev"

---@type LazyPluginSpec[]
local Spec = {
  {
    "folke/lazydev.nvim", ft = "lua",

    ---@type lazydev.Config
    opts = {
      library = {
        { path = "luvit-meta/library", words = { "vim%.uv" } },
      },
    },
  },

  -- XXX: https://github.com/neovim/neovim/pull/33375
  { "Bilal2453/luvit-meta" },
}

return Spec
