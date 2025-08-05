---@module "which-key"

---@type LazyPluginSpec
local Spec = {
  "folke/which-key.nvim", event = "VeryLazy", opts_extend = { "spec" },

  ---@type wk.Opts
  opts = {
    preset = "helix",

    delay = function (ctx)
      return ctx.plugin and 0 or 500
    end,

    filter = function (ctx)
      return ctx.desc and ctx.desc ~= ""
    end,

    defer = function (ctx)
      return ctx.mode == "v" or ctx.mode == "V" or ctx.mode == "<C-V>"
    end,

    plugins = {
      marks = false,
      registers = false,
      spelling = {
        enabled = false,
      },
      presets = {
        g = false,
        motions = false,
        nav = false,
        operators = false,
        text_objects = false,
        windows = false,
        z = false,
      },
    },

    win = {
      border = "single",
    },

    sort = {
      "manual",
    },

    icons = {
      mappings = false,
      separator = "│",
    },

    show_help = false,
    show_keys = false,

    spec = {
      { "<leader>b", group = "Buffer" },
      { "<leader>n", group = "Notify" },
      { "<leader>s", group = "Search" },
    },
  },
}

return Spec
