if vim.bo.filetype ~= "help" then
  return
end

-- Sanitize the presentation of help buffers.
--
-- By default, Neovim insists on opening help files in a horizontal split
-- *above* the current window, a design decision best understood as historical
-- inertia. This layout might have made sense in a terminal-bound era where
-- vertical space was cheap, and cognitive space even cheaper, but in modern
-- setups, it jars.
--
-- A help buffer is not a modal interruption; it is a sidebar reference. We
-- relocate it to the far right (`wincmd L`), where it belongs, that is,
-- spatially aligned with typical reading behavior.
--
-- Note that we use `BufWinEnter` rather than a `FileType` pattern. This is
-- intentional: `wincmd` operates on windows, not buffers, and `FileType` fires
-- too early, often before the buffer is visible in a window. Applying `wincmd`
-- at that stage either has no effect or, worse, acts on the wrong window
-- entirely.

vim.api.nvim_create_autocmd ("BufWinEnter", {
  callback = function (ev)
    if vim.bo.filetype == "help" then
      vim.api.nvim_exec2 ("wincmd L", {})
      vim.keymap.set ("n", "q", "<cmd>q<cr>", { buffer = ev.buf, silent = true })
    end
  end,
})
