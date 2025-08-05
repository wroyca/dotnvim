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
    local filetype_to_parser = {}
    local filetypes = {}
    local parser_available = {}

    for _, lang in ipairs (opts.ensure_installed) do
      for _, ft in ipairs (vim.treesitter.language.get_filetypes (lang)) do
        filetype_to_parser[ft] = lang
        filetypes[ft] = true
      end
    end

    vim.api.nvim_create_autocmd ("FileType", {
      pattern = vim.tbl_keys (filetypes),
      callback = function ()
        local ft = vim.bo.filetype
        local lang = filetype_to_parser[ft]

        if not lang then
          return
        end

        local available = parser_available[lang]
        if available == nil then
          local ok = pcall (vim.treesitter.require_language, lang)
          parser_available[lang] = ok
          available = ok
        end

        -- Memoize the result for each language. Absent parsers are installed
        -- lazily; present ones are marked and skipped.
        if not available then
          require ("nvim-treesitter").install (lang)
        end

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
        vim.schedule (function ()
          pcall (vim.treesitter.start)
        end)
      end,
    })
  end,
}

return Spec
