---@module "mini.misc"

---@type LazyPluginSpec
local Spec = {
  "mini.misc", virtual = true, lazy = false,

  -- opts shouldn't call setup, as this module self-export through _G.
  config = function (_, opts)
    require ("mini.misc").setup (opts)

    -- Automatically sets the working directory to the root of the current
    -- buffer using common project markers (e.g. `.git`).
    MiniMisc.setup_auto_root ({ ".git" })

    -- Restores the cursor to its last known position when reopening a file.
    MiniMisc.setup_restore_cursor ()

    -- Synchronizes the terminal emulator's background color with the editor's
    -- active color scheme by using standard terminal escape sequences (OSC
    -- codes).
    --
    -- The original version of this function chose not to use OSC 111 (which
    -- resets the terminal's background color to its default) out of caution.
    -- That sequence is considered an extension and, in theory, not all terminal
    -- emulators may support it. To avoid relying on it, it instead queried the
    -- terminal's current background color (via OSC 11) and cached it with the
    -- intention of restoring it later.
    --
    -- In practice, however, this strategy tends to cause more problems than it
    -- solves. Caching a background color at startup assumes that the terminal's
    -- appearance will remain fixed across the editor's lifetime, but this isn't
    -- always the case. For instance, users may switch from a dark terminal
    -- theme to a light one mid-session. In that scenario, restoring a
    -- previously cached dark background into a now-light environment can
    -- produce mismatched or unreadable text (e.g., dark-on-dark).
    --
    -- Given how widespread OSC 111 support is in modern terminals, it is both
    -- simpler and more robust to use it directly. This allows the terminal to
    -- restore its own default background color on exit, typically the same
    -- value it would have used at launch, without relying on cached state or
    -- manual guesswork.
    --
    -- As such, we now adopt the intended approach: use OSC 11 to align the
    -- terminal background with Neovim's `Normal` highlight group, and use OSC
    -- 111 on suspend or exit to return control to the terminal.
    MiniMisc.setup_termbg_sync = (function ()
      local has_stdout_tty = vim.iter(vim.api.nvim_list_uis())
        :any(function(ui) return ui.stdout_tty end)
      if not has_stdout_tty then return end

      local augroup = vim.api.nvim_create_augroup ("MiniMiscTermbgSync", { clear = true })
      local sync = function ()
        local normal = vim.api.nvim_get_hl (0, { name = "Normal" })
        if normal.bg then
          io.stdout:write (string.format ("\027]11;#%06x\007", normal.bg))
        end
      end
      local reset = function () io.stdout:write ("\027]111\007") end

      vim.api.nvim_create_autocmd ({ "VimResume", "ColorScheme" }, {
        group = augroup,
        callback = sync,
      })

      vim.api.nvim_create_autocmd ({ "VimLeavePre", "VimSuspend" }, {
        group = augroup,
        callback = reset,
      })

      -- Apply the background immediately at startup to force the terminal
      -- appearance to be synchronized from the outset, rather than lagging
      -- behind until the next event hook.
      sync ()
    end)()
  end,
}

return Spec
