if package.loaded["lazy"] then
  -- https://github.com/folke/lazy.nvim/issues/1180
  return
end

---@type LazyConfig
local opts = {
  defaults = {
    lazy = true,
  },

  pkg = {
    enabled = false,
  },

  rocks = {
    enabled = false,
  },

  readme = {
    enabled = false,
  },

  -- https://github.com/folke/lazy.nvim/issues/1008
  change_detection = {
    notify = false,
  },

  install = {
    colorscheme = { "default" },
  },

  ui = {
    pills = false,
    backdrop = 100,
  }
}

-- `LazyInstall` user event is triggered by Lazy.nvim once all required plugins
-- have been installed. This typically occurs on first launch, at which point
-- Lazy opens its UI (`filetype=lazy`) to display install progress. After
-- completion, `LazyInstall` fires and we close the Lazy window automatically to
-- return focus to the editor. This is the expected flow during initial setup.
--
-- However, `LazyInstall` is also emitted when updating or installing individual
-- plugins manually. If the user has opened the Lazy UI themselves in this case,
-- we *do not* want to close it automatically - doing so would interrupt an
-- interactive session.
--
-- To distinguish between the two cases, we register a one-time handler for both
-- `LazyInstall` and `VeryLazy`. If `LazyInstall` fires and the current buffer
-- is still showing the Lazy UI (`filetype=lazy`), then we assume this is part
-- of automatic startup and close the window.
--
-- If `VeryLazy` fires first, we infer that the editor has reached an idle state
-- without triggering `LazyInstall`, likely because no plugins were installed.
-- Or, if it fires after the user has manually opened Lazy, we use it as an
-- opportunity to *cancel* the `LazyInstall` autocmd, *unless* we're still on a
-- Lazy buffer, in which case we preserve the close logic to allow first-time
-- setup to complete cleanly.
--
local id = vim.api.nvim_create_autocmd ("User", {
  once = true,
  pattern = "LazyInstall",
  callback = function ()
    if vim.o.filetype == "lazy" then
      vim.cmd.close ()
    end
  end,
})
vim.api.nvim_create_autocmd ("User", {
  once = true,
  pattern = "VeryLazy",
  callback = function ()
    if vim.o.filetype ~= "lazy" then
      pcall (vim.api.nvim_del_autocmd, id)
    end
  end,
})

require ("lazy").setup ("spec", opts)
