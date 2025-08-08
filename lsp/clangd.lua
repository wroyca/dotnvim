require ("lsp.handlers.document_link").setup ()
require ("lsp.handlers.inactive_regions").setup ()

---@type vim.lsp.config
local config = {
  cmd = {
    "clangd",
    "--all-scopes-completion=true",
    "--background-index-priority=normal",
    "--background-index=true",
    "--clang-tidy=true",
    "--completion-parse=always",
    "--completion-style=bundled",
    "--fallback-style=GNU",
    "--function-arg-placeholders=0",
    "--header-insertion=never",
    "--parse-forwarding-functions",
    "--pch-storage=memory",
    "--ranking-model=decision_forest",
  },

  capabilities = {
    textDocument = {
      completion = {
        completionItem = {
          snippetSupport = false,
        },
      },
      inactiveRegionsCapabilities = {
        inactiveRegions = true,
      },
    },
  },

  filetypes = {
    "c",
    "cpp",
  },
}

return config
