---@module "blink.cmp"

---@type LazyPluginSpec
local Spec = {
  "saghen/blink.cmp", version = "1.*", event = "VeryLazy",

  ---@type blink.cmp.Config
  opts = {
    keymap = {
      preset = "super-tab",
    },
    completion = {
      menu = {
        draw = {
          columns = {
            { "label", "label_description" },
          },
        },
      },
    },

    sources = {
      default = { "lsp", "path", "snippets", "buffer" },

      providers = {
        lsp = {
          transform_items = (function ()
            local relevant_filetypes = {
              c = true,
              cpp = true,
            }

            local should_transform = setmetatable ({}, {
              __index = function (t, bufnr)
                local ft = vim.bo[bufnr].filetype
                local result = relevant_filetypes[ft] or false
                rawset (t, bufnr, result)
                return result
              end,
            })

            --- Strips a leading whitespace character left by clangd when
            --- include insertion is disabled.
            ---
            --- When `clangd.completeIncludeInsertion` is set to `false`,
            --- clangd omits the little dot (`·`) marker it normally prefixes
            --- to completion items that trigger auto-includes.
            ---
            --- Unfortunately, in this configuration clangd still inserts a
            --- *space* character in place of the dot, causing completion item
            --- labels to appear misaligned (visually indented).
            ---
            --- NOTE: Only a single leading space or tab is removed. Other
            --- whitespace is preserved.

            local function strip_whitespace (field)
              if field and #field > 0 then
                local first = field:byte (1)
                if first == 32 or first == 9 then
                  return field:sub (2)
                end
              end
              return field
            end

            --- Prioritize completion items that are likely project headers.
            ---
            --- Here we want to improves the sorting of LSP completion results
            --- (e.g., from clangd) by boosting the score of suggestions that
            --- appear to belong to the current project.
            ---
            --- Below logic uses two strategies to determine the project's root
            --- directory:
            ---
            ---   1. If the clangd client is attached, we extract the root from
            ---      its config.
            ---
            ---   2. Otherwise, we fallback to using `git rev-parse --show-toplevel`,
            ---      which only works if the current working directory is
            ---      inside a Git repository.
            ---
            --- Once we determine the project name (e.g., from the directory
            --- name of the root), we boost completion items whose paths match
            --- certain patterns:
            ---
            ---   - Headers directly inside the project or `lib<project>`
            ---     subdirectories (P1204R0).
            ---
            ---   - Matches at the beginning of the path are given higher
            ---     priority.
            ---

            local function prioritize_project_headers (ctx, items)
              local clients = vim.lsp.get_clients({ bufnr = ctx.bufnr, name = "clangd" })
              local root_dir = clients and clients[1] and clients[1].config.root_dir

              -- Fallback: if the clangd client didn't set a root directory,
              -- try to infer it using Git.
              --
              if not root_dir then
                local output = vim.fn.systemlist("git rev-parse --show-toplevel")
                root_dir = vim.v.shell_error == 0 and output[1] or nil
              end

              local project_name = root_dir and vim.fn.fnamemodify(root_dir, ":t")
              if not project_name then
                return items
              end
              local lib_project_name = "lib" .. project_name

              local boost_patterns = {
                { pattern = "^" .. vim.pesc(project_name)     .. "/", score = 1000 },
                { pattern = "^" .. vim.pesc(lib_project_name) .. "/", score = 1000 },
                { pattern = "/" .. vim.pesc(project_name)     .. "/", score = 500  },
                { pattern = "/" .. vim.pesc(lib_project_name) .. "/", score = 500  },
              }

              vim.iter(items):each(function(item)
                local text = item.label or item.insertText or ""
                for _, boost in ipairs(boost_patterns) do
                  if text:find(boost.pattern) then
                    item.score_offset = (item.score_offset or 0) + boost.score
                    break -- apply only the first matching pattern
                  end
                end
              end)

              table.sort(items, function(a, b)
                local sa, sb = a.score_offset or 0, b.score_offset or 0
                return sa ~= sb and sa > sb or (a.label or "") < (b.label or "")
              end)

              return items
            end

            return function (ctx, items)
              local bufnr = ctx.bufnr
              if not bufnr or not should_transform[bufnr] then
                return items
              end

              -- Fast-path: are we inside an #include <...> directive?
              --
              -- This is both a correctness check (only prioritize headers
              -- here) and an optimization to avoid running `strip_whitespace()`
              -- unnecessarily.

              if vim.tbl_contains({'<', '>'}, ctx.trigger.character) and
                                              ctx.line and
                                              ctx.line:match("#include%s*<")
              then
                return prioritize_project_headers (ctx, items)
              end

              -- Strip whitespace from all items (only for non-include contexts)
              vim.iter (items):each (function (item)
                item.label = strip_whitespace (item.label)
                item.insertText = strip_whitespace (item.insertText)
                item.filterText = strip_whitespace (item.filterText)
                if item.textEdit and item.textEdit.newText then
                  item.textEdit.newText = strip_whitespace (item.textEdit.newText)
                end
              end)

              return items
            end
          end) (),
        },
      },
    },
  },
}

return Spec
