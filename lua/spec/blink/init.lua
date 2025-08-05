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

            local function strip_whitespace (field)
              if field and #field > 0 then
                local first = field:byte (1)
                if first == 32 or first == 9 then
                  return field:sub (2)
                end
              end
              return field
            end

            return function (ctx, items)
              local bufnr = ctx.bufnr
              if not bufnr or not should_transform[bufnr] then
                return items
              end

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
