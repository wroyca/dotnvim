---@module "mini.basics"

---@type LazyPluginSpec
local Spec = {
  "mini.basics", virtual = true, enabled = false
}

-- We initially reached for `mini.basics` just to get highlight-on-yank, which
-- it sets up for free. Nice, but that ended up being the *only* thing we used
-- from it.
--
-- Rather than enable the plugin for one autocmd, we now wire it up
-- directly.

vim.api.nvim_create_autocmd ("TextYankPost", {
  pattern = "*",
  callback = function () vim.hl.on_yank () end,
  desc = "Highlight yanked text",
})

return Spec
