---@module "grug-far"

---@type LazyPluginSpec
local Spec = {
  "MagicDuck/grug-far.nvim", cmd = { "GrugFar", "GrugFarWithin" },

  keys = {
    {
      "<leader>sr",
      function ()
        require ("grug-far").open ()
      end,
      desc = "Search & Replace",
    },
    {
      "<leader>sw",
      function ()
        require ("grug-far").open ({ prefills = { search = vim.fn.expand ("<cword>") } })
      end,
      desc = "Search word under cursor",
    },
    {
      "<leader>sf",
      function ()
        require ("grug-far").open ({ prefills = { paths = vim.fn.expand ("%") } })
      end,
      desc = "Search in current file",
    },
    {
      "<leader>sv",
      function ()
        require ("grug-far").with_visual_selection ()
      end,
      mode = "v",
      desc = "Search visual selection",
    },
  },

  opts = {
    folding = { enabled = false },
    icons = { enabled = false },
    maxWorkers = vim.uv.available_parallelism (),
    resultLocation = { showNumberLabel = false },
    showEngineInfo = false,
    windowCreationCommand = "botright vsplit",
  },

  config = function (_, opts)
    require ("grug-far").setup (opts)

    -- Install a buffer-local 'q' key mapping to close 'grug-far' buffers.
    vim.api.nvim_create_autocmd ("FileType", {
      pattern = {
        "grug-far",
      },
      callback = function (event)
        vim.keymap.set ("n", "q", function ()
          require ("mini.bufremove").wipeout (0, true)
          -- close the split window
          vim.cmd.close ()
        end, { buffer = event.buf, silent = true })
      end,
    })
  end,
}

return Spec
