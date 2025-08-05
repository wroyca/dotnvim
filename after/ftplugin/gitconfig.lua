if vim.bo.filetype ~= "gitconfig" then
  return
end

-- Normalize comment syntax for Git config files.
--
-- By default, Neovim treats `.gitconfig` as an INI-style file and assigns `;`
-- as the comment leader. While technically valid per Git's parser, this choice
-- clashes with the de facto convention used in the wild, and, indeed, by Git
-- itself when writing config files: `#` is preferred almost universally.

vim.opt_local.comments = ":#"
vim.opt_local.commentstring = "# %s"
