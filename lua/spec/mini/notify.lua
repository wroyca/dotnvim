---@module "mini.notify"

---@type LazyPluginSpec
local Spec = {
  "mini.notify", virtual = true, event = "VeryLazy",

  keys = {
    {
      "<leader>nh",
      function ()
        MiniNotify.show_history ()
      end,
      desc = "Show notification history",
    },
    {
      "<leader>nc",
      function ()
        MiniNotify.clear ()
      end,
      desc = "Clear all notifications",
    },
    {
      "<leader>nr",
      function ()
        MiniNotify.refresh ()
      end,
      desc = "Refresh notification window",
    },
  },

  opts = function ()
    local filterout_lua_diagnosing = function (notif_arr)
      local not_diagnosing = function (notif)
        return not vim.startswith (notif.msg, "lua_ls: Diagnosing")
      end
      notif_arr = vim.tbl_filter (not_diagnosing, notif_arr)
      return MiniNotify.default_sort (notif_arr)
    end
    return {
      content = { sort = filterout_lua_diagnosing },
    }
  end,

  -- opts shouldn't call setup, as mini modules self-export through _G.
  config = function (_, opts)
    require ("mini.notify").setup (opts)

    -- Creates an implementation of |vim.notify()| powered by this module.
    -- General idea is that notification is shown right away (as soon as safely
    -- possible, see |vim.schedule()|) and removed after a configurable amount
    -- of time.
    vim.notify = MiniNotify.make_notify ()

    -- Install a buffer-local 'q' key mapping to close 'mininotify-history'
    -- buffers.
    --
    -- These buffers are transient by design: their sole purpose is to allow
    -- inspection of prior notifications, after which they should be discarded.
    vim.api.nvim_create_autocmd ("FileType", {
      pattern = {
        "mininotify-history",
      },
      callback = function (event)
        vim.keymap.set ("n", "q", function ()
          require ("mini.bufremove").wipeout (0, true)
        end, { buffer = event.buf, silent = true })
      end,
    })
  end,
}

return Spec
