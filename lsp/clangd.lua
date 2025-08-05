---@type vim.lsp.config
local config = {
  cmd = {
    "clangd",
    "--all-scopes-completion=true",
    "--background-index=true",
    "--background-index-priority=normal",
    "--clang-tidy=true",
    "--completion-parse=always",
    "--ranking-model=decision_forest",
    "--completion-style=bundled",
    "--fallback-style=GNU",
    "--function-arg-placeholders=0",
    "--header-insertion=never",
    "--pch-storage=memory",
    "--parse-forwarding-functions",
  },

  capabilities = {
    textDocument = {
      inactiveRegionsCapabilities = {
        inactiveRegions = true,
      },
    },
  },

  filetypes = {
    "c",
    "cpp",
  },

  root_markers = {
    ".git",
  },
}

return config
