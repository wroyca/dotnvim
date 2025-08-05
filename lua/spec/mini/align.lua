---@module "mini.align"

---@type LazyPluginSpec
local Spec = {
  "mini.align", virtual = true, event = "VeryLazy", opts = {},

  init = function ()
    -- github.com/echasnovski/mini.nvim/issues/1875
    vim.o.showmode = false
  end
}

return Spec
