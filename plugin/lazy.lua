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

-- Handle Lazy.nvim's plugin installation lifecycle.
--
-- On first launch, Lazy.nvim installs required plugins and opens its UI
-- (`filetype=lazy`) to show progress. Once complete, it emits the
-- `LazyInstall` event. In this case, we close the Lazy window automatically to
-- return focus to the editor, this is part of the expected first-time setup
-- flow.
--
-- However, `LazyInstall` is also triggered during manual plugin actions (e.g.,
-- updates), if the user opened the Lazy UI themselves. In that case, we do not
-- want to close it unexpectedly.
--
-- To distinguish between these two situations, we register a one-time handler
-- for both `LazyInstall` and `VeryLazy`:
--
-- - If `LazyInstall` fires *and* the current buffer is still the Lazy UI, we
--   assume this is automated startup behavior and close the window.
--
-- - If `VeryLazy` fires first, we assume the editor has reached an idle state
--   without plugin installs, or the user opened Lazy manually. In either case,
--   we cancel the `LazyInstall` autocmd, unless we're still in a Lazy buffer,
--   in which case we preserve the close logic to allow setup to complete
--   cleanly.

vim.api.nvim_create_autocmd ("User", {
  pattern = { "LazyInstall", "VeryLazy" },
  callback = function (ev)
    if ev.match == "LazyInstall" then
      if vim.o.filetype == "lazy" then
        vim.cmd.close ()
      end
    elseif ev.match == "VeryLazy" then
      if vim.o.filetype ~= "lazy" then
        pcall (vim.api.nvim_del_autocmd, ev.id)
      end
    end
  end,
})

require ("lazy").setup ("spec", opts)
