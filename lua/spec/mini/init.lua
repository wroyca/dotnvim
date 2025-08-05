---@module "mini"

-- This Spec serve two purposes:
--
-- 1. It declares `mini.nvim`, which is a single monolithic plugin bundling
--    all of its modules (e.g. `mini.comment`, `mini.indentscope`, etc.) into
--    one codebase. Because of this, individual modules cannot be lazy-loaded
--    in isolation using traditional plugin declarations.
--
-- 2. It imports our `spec/mini/` directory via `import = "spec.mini"`. In
--    `lazy.nvim`, importing a directory causes all Lua files inside it to be
--    automatically merged into the final plugin specification. This allows us
--    to treat each Mini module as a *virtual plugin*, colocating each one's
--    configuration in a separate file while still applying per-module
--    settings, dependencies, and lazy-loading conditions.
--
-- To avoid recursive imports (since this file also lives in the same tree
-- being imported), we check `package.loaded["mini"]`. If it's already loaded,
-- we return an empty spec to prevent re-entering this file.

---@type LazyPluginSpec
local Spec = {
  "echasnovski/mini.nvim", import = "spec.mini",
}

return package.loaded["mini"] and {} or Spec
