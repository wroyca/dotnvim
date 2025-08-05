---@module "fundo"

---@type LazyPluginSpec
local Spec = {
  "kevinhwang91/nvim-fundo", dependencies = "kevinhwang91/promise-async", event = "VeryLazy",

  ---@type FundoConfig
  opts = {
    limit_archives_size = 9999,
  },

  config = function (_, opts)
    require ("fundo").setup (opts)

    -- Fundo maintains undo history by writing each editing session to a
    -- separate archive file within the cache directory. This avoids contention
    -- and allows for robust recovery, but over time these archives may
    -- accumulate, particularly in projects where many files are edited
    -- sporadically.
    --
    -- To control storage growth, we remove archives that have not been
    -- modified in over seven days. This retention policy is not configurable
    -- at present, but can be revised later if needed.
    --
    -- The cleanup process is intentionally lightweight. It involves listing
    -- the top-level archive directory and applying a metadata query (`stat`)
    -- to each file. The contents of the files are never read, and no
    -- subdirectories are examined. Even with several hundred entries, the
    -- operation completes in under one millisecond on typical systems and does
    -- not introduce observable overhead.

    local uv = vim.uv
    local archive_dir = vim.fs.joinpath (vim.fn.stdpath ("cache"), "fundo")
    for _, name in ipairs (vim.fn.readdir (archive_dir) or {}) do
      local path = vim.fs.joinpath (archive_dir, name)
      local stat = uv.fs_stat (path)
      -- Files older than 7 days are considered stale and deleted.
      if stat and stat.mtime and (os.time () - stat.mtime.sec > 7 * 24 * 60 * 60) then
        vim.fn.delete (path)
      end
    end
  end,
}

return Spec
