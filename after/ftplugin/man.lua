if vim.bo.filetype ~= "man" then
  return
end

-- Sanitize the presentation of man buffers.
--
-- Much like Neovim's help system, the `:Man` command launches documentation in
-- an upper split, an unfortunate default on widescreens, where vertical splits
-- preserve context far more effectively. We correct this by relocating the man
-- page window to the far right, treating it as an auxiliary view rather than a
-- competing peer.
--
-- As with help buffers, we use `BufWinEnter` rather than a `FileType` pattern.
-- This is intentional: `wincmd` operates on windows, not buffers, and
-- `FileType` fires too early, often before the buffer is visible in a window.
-- Applying `wincmd` at that stage either has no effect or, worse, acts on the
-- wrong window entirely.

vim.api.nvim_create_autocmd ("BufWinEnter", {
  callback = function (event)
    if vim.bo.filetype == "man" then
      vim.api.nvim_exec2 ("wincmd L", {})
      vim.bo[event.buf].buflisted = false
      vim.keymap.set ("n", "q", "<cmd>q<cr>", { buffer = event.buf, silent = true })
    end
  end,
})
