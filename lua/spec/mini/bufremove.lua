---@module "mini.bufremove"

---@type LazyPluginSpec
local Spec = {
  "mini.bufremove", virtual = true,

  keys = {
    {
      "<leader>bd",
      function ()
        MiniBufremove.delete (0, false)
      end,
      desc = "Delete",
    },
    {
      "<leader>bw",
      function ()
        MiniBufremove.wipeout (0, false)
      end,
      desc = "Wipeout",
    },
    {
      "<leader>bu",
      function ()
        MiniBufremove.unshow (0)
      end,
      desc = "Unshow",
    },
  },

  -- opts shouldn't call setup, as this module self-export through _G.
  config = function (_, opts)
    require ("mini.bufremove").setup (opts)

    -- Override MiniBufremove.wipeout() to also remove the buffer's path from
    -- persistent session state: specifically, v:oldfiles and the shada file
    -- that stores it across restarts.
    --
    -- The original wipeout only detaches the buffer from the editor. It leaves
    -- the file in Neovim's recent file list. This makes sense when wipeout is
    -- used as a soft detach. It's less helpful when wipeout marks the end of
    -- the buffer's relevance, as with temporary views or previews.
    --
    -- Note that the core logic is left untouched. We call the original
    -- wipeout, then follow up with cleanup if the buffer had a name.
    local original_wipeout = MiniBufremove.wipeout
    ---@diagnostic disable-next-line: duplicate-set-field
    MiniBufremove.wipeout = function (buf_id, force)
      local buf = buf_id or vim.api.nvim_get_current_buf ()
      local bufname = vim.api.nvim_buf_get_name (buf)

      original_wipeout (buf, force)

      if bufname ~= "" then
        pcall (vim.cmd.wshada, { bang = true })
        vim.v.oldfiles = vim.tbl_filter (function (file)
          return file ~= bufname
        end, vim.v.oldfiles)
        pcall (vim.cmd.wshada, { bang = true })
      end
    end
  end,
}

return Spec
