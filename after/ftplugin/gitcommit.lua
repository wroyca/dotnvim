if vim.bo.filetype ~= "gitcommit" then
  return
end

vim.opt_local.textwidth = 72

-- 'smartindent' was originally designed for C-like languages, where
-- indentation can be inferred from simple syntactic cues. For example, if a
-- line ends with a `{`, the next line is automatically indented. Similarly,
-- lines starting with `}` are outdented. These rules work well enough for
-- structured code, but they're based on surface-level patterns, not actual
-- syntax trees.
--
-- In plain text, these heuristics are more likely to misfire. A list item
-- starting with a dash, or a sentence ending with a colon, can accidentally
-- trigger indentation. A paragraph split by an empty line may suddenly pick up
-- an indent where none was intended. These quirks are especially noticeable in
-- free-form text, such as commit messages.
--
-- Turning off 'smartindent' gives us full manual control: new lines start
-- flush-left unless we decide otherwise. For prose, that's the least
-- surprising behavior.

vim.opt_local.smartindent = false
