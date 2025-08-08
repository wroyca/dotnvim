---@module "mason"

---@type LazyPluginSpec
local Spec = {
  "neovim/nvim-lspconfig",

  -- Note that `lazy.nvim` installs this plugin in a deterministic root
  -- directory, which we locate via `lazy.core.config.options.root`. We then
  -- insert that path at the beginning of `runtimepath`, thereby making
  -- `nvim-lspconfig`'s module tree available to `require()`.
  --
  -- From Neovim's point of view, the plugin is now "present" (as far as module
  -- resolution goes), but remains blissfully unaware that it is not, in fact,
  -- running.
  --
  -- This arrangement is deliberate. When loaded conventionally,
  -- `nvim-lspconfig` registers its own collection of language server handlers,
  -- which take precedence over any user-defined modules of the same name.
  --
  -- In practice, this means that a `clangd` config provided by the plugin will
  -- quietly shadow our own `lsp/clangd.lua`, leaving us none the wiser unless
  -- we go looking.

  init = function ()
    local lazy_root = require ("lazy.core.config").options.root
    local lsp_path = vim.fs.normalize (lazy_root .. "/nvim-lspconfig")

    -- Avoid re-prepending if already present in runtimepath
    if not vim.tbl_contains (vim.opt.runtimepath:get (), lsp_path) then
      vim.opt.runtimepath:prepend (lsp_path)
    end
  end,
}

return Spec
