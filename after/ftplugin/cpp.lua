if vim.bo.filetype ~= "cpp" then
  return
end

-- The `cinkeys` setting controls which keys trigger automatic reindentation
-- when using the `smartindent` or `cindent` features. By default, for C-like
-- languages, the colon (`:`) is included as a trigger. This means typing a
-- colon, such as in a `case` label or after an access modifier, causes Neovim
-- to automatically reindent the line.
--
-- The issue is that `cinkeys` cannot distinguish between different contexts
-- for `:`. For example, when typing `foo::`, it will reindent after the first
-- colon as if it's a `case` label.
--
-- One possible workaround is to disable `cinkeys` and instead rely on the
-- LSP's *format-on-type* feature. However, that approach applies full
-- formatting, not just indentation, it's often too heavy-handed for real-time
-- use.
--
-- As far as I know, there's no proper solution. Writing a custom plugin to
-- handle it correctly is impractical and reindentation logic is notoriously
-- difficult to get right.
--
-- The Emacs manual puts it well:
--
-- > Writing a good indentation function can be difficult and to a large extent
-- > it is still a black art. Many major mode authors will start by writing a
-- > simple indentation function that works for simple cases, for example by
-- > comparing with the indentation of the previous text line. For most
-- > programming languages that are not really line-based, this tends to scale
-- > very poorly: improving such a function to let it handle more diverse
-- > situations tends to become more and more difficult, resulting in the end
-- > with a large, complex, unmaintainable indentation function which nobody
-- > dares to touch.
--
-- This applies just as much to Neovim. Indentation is deceptively complex, and
-- tweaking it rarely yields clean, sustainable results.

vim.opt_local.cinkeys:remove (":")
