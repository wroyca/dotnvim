---@module "nvim-treesitter"

---@type LazyPluginSpec
local Spec = {
  "nvim-treesitter/nvim-treesitter", branch = "main", build = ":TSUpdate", lazy = false,

  ---@type TSConfig
  opts = {
    ensure_installed = {
      "c",
      "cpp",
      "lua",
      "markdown",
      "markdown_inline",
      "query",
      "vim",
      "vimdoc",
    },
  },

  config = function (_, opts)
    -- The 'filetype' value might be different from tree-sitter parser/language
    -- name. We must use vim.treesitter.language.get_filetypes() to get
    -- relevant filetypes.
    vim.iter (opts.ensure_installed):each (function (lang)
      local filetypes = vim.treesitter.language.get_filetypes(lang)
      vim.iter(filetypes):each(function(ft)
        vim.api.nvim_create_autocmd ("FileType", {
          pattern = { ft },
          callback = function ()
            require ("nvim-treesitter").install (lang) -- noop if already installed.

            -- On first glance, vim.treesitter.highlighter.new` looks like a
            -- harmless constructor. In practice, it manages to chew up 130+ ms
            -- during startup *if* Neovim is launched directly into a file (e.g.,
            -- `nvim foo.cxx`). Not great for those of us who like snappy cold
            -- boots.
            --
            -- Profiling shows the delay happens deep inside Treesitter's internal
            -- startup path, so rather than waiting on a fix or
            -- reverse-engineering their init sequence, we just dodge the whole
            -- mess by deferring `treesitter.start()` to the next event loop tick.
            --
            -- This buys us a faster startup at the cost of one mildly annoying
            -- side effect: Neovim may attempt a redraw while the parser is still
            -- mid-parse, which can lead to a momentary highlight flicker.
            --
            -- Fortunately, this specific race condition is already being
            -- addressed upstream: https://github.com/neovim/neovim/pull/33145
            --
            -- So for now, we just punt and schedule the start call.
            vim.schedule(function()
              pcall (vim.treesitter.start)
            end)
          end,
        })
      end)
    end)
  end,
}

return Spec
