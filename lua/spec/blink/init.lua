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
          transform_items = function (ctx, items)
            local bufnr = ctx.bufnr
            local filetype = bufnr and vim.bo[bufnr].filetype
            if not bufnr or (filetype ~= "c" and filetype ~= "cpp") then
              return items
            end

            -- Strip leading whitespace from completion items
            vim.iter (items):each (function (item)
              local function strip_whitespace (field)
                if field and #field > 0 then
                  local first_char = field:byte (1)
                  if first_char == 32 or first_char == 9 then -- space or tab
                    return field:sub (2)
                  end
                end
                return field
              end

              item.label = strip_whitespace (item.label)
              item.insertText = strip_whitespace (item.insertText)
              item.filterText = strip_whitespace (item.filterText)
              if item.textEdit and item.textEdit.newText then
                item.textEdit.newText = strip_whitespace (item.textEdit.newText)
              end
            end)

            return items
          end,
        },
      },
    },
  },
}

return Spec
