---@module "mini.files"

local uv = vim.uv

---@class MiniFilesEntry
---@field name string Entry name
---@field path string Full path
---@field fs_type string Entry type ('file' or 'directory')

---@class GitignoreCache
---@field ignored table<string, boolean> Map of file paths to ignored status
---@field timestamp number Cache creation timestamp
---@field gitignore_files table<string, number> Map of gitignore file paths to their mtime
---@field expires_at number When this cache entry expires

---@class PerformanceMetrics
---@field cache_hits number Number of cache hits
---@field cache_misses number Number of cache misses
---@field sync_operations number Number of synchronous operations
---@field async_operations number Number of asynchronous operations
---@field total_processing_time number Total time spent processing

---@class MiniFilesGitignoreConfig
---@field max_cache_size number Maximum number of directories to cache (default: 1000)
---@field cache_ttl number Cache time-to-live in seconds (default: 300)
---@field sync_threshold number Max files for sync processing (default: 100)
---@field prefetch_depth number Depth for prefetching subdirectories (default: 2)
---@field enable_metrics boolean Enable performance metrics (default: false)
---@field log_level number Logging level (default: vim.log.levels.WARN)
---@field enable_logging boolean Enable/disable logging (default: false)

---Gitignore integration for mini.files
---@class MiniFilesGitignore
---@field private config MiniFilesGitignoreConfig Configuration options
---@field private cache table<string, GitignoreCache> Directory path to cache mapping
---@field private state boolean Current filtering state (true = show all, false = respect gitignore)
---@field private initial_sort function Original sort function from options
---@field private initial_filter function Original filter function from options
---@field private current_sort function Current active sort function
---@field private current_filter function Current active filter function
---@field private git_roots table<string, string> Map of directory paths to their git root
---@field private fs_watchers table<string, uv_handle_t> Map of paths to filesystem watchers
---@field private job_pool table<number, table> Pool of active jobs
---@field private metrics PerformanceMetrics Performance tracking
---@field private logger table Logger instance
local MiniFilesGitignore = {}

---Default configuration
---@type MiniFilesGitignoreConfig
local DEFAULT_CONFIG = {
  max_cache_size = 1000,
  cache_ttl = 300,
  sync_threshold = 100,
  prefetch_depth = 2,
  enable_metrics = false,
  enable_logging = false,
  log_level = vim.log.levels.WARN,
}

---Create a new logger instance
---@param level number Log level
---@param enabled boolean Whether logging is enabled
---@return table logger Logger instance
local function create_logger (level, enabled)
  if not enabled then
    return {
      level = nil,
      debug = function () end,
      info = function () end,
      warn = function () end,
      error = function () end,
    }
  end
  return {
    level = level,
    debug = function (self, msg, ...)
      if self.level <= vim.log.levels.DEBUG then
        vim.notify (string.format ("debug: " .. msg, ...), vim.log.levels.DEBUG)
      end
    end,
    info = function (self, msg, ...)
      if self.level <= vim.log.levels.INFO then
        vim.notify (string.format ("info: " .. msg, ...), vim.log.levels.INFO)
      end
    end,
    warn = function (self, msg, ...)
      if self.level <= vim.log.levels.WARN then
        vim.notify (string.format ("warn: " .. msg, ...), vim.log.levels.WARN)
      end
    end,
    error = function (self, msg, ...)
      if self.level <= vim.log.levels.ERROR then
        vim.notify (string.format ("error: " .. msg, ...), vim.log.levels.ERROR)
      end
    end,
  }
end

---Initialize new MiniFilesGitignore instance
---@param opts MiniFilesSpec Configuration options
---@param config? MiniFilesGitignoreConfig Gitignore-specific configuration
---@return MiniFilesGitignore
function MiniFilesGitignore.new (opts, config)
  local self = setmetatable ({}, { __index = MiniFilesGitignore })

  -- Merges the provided configuration with default values.
  self.config = vim.tbl_deep_extend ("force", DEFAULT_CONFIG, config or {})

  -- Initializes the internal state of the gitignore manager. Note that `state`
  -- being false indicates that gitignore filtering is active by default.
  self.cache = {}
  self.state = false
  self.initial_sort = opts.content.sort
  self.initial_filter = opts.content.filter
  self.current_sort = self.initial_sort
  self.current_filter = self.initial_filter
  self.git_roots = {}
  self.fs_watchers = {}
  self.job_pool = {}

  -- Initializes performance metrics to zero.
  self.metrics = {
    cache_hits = 0,
    cache_misses = 0,
    sync_operations = 0,
    async_operations = 0,
    total_processing_time = 0,
  }

  -- Creates a logger instance based on the configuration.
  self.logger = create_logger (self.config.log_level, self.config.enable_logging)

  return self
end

---Get current sort function
---@return function sort Current sort function
function MiniFilesGitignore:get_sort ()
  return self.current_sort
end

---Get current filter function
---@return function filter Current filter function
function MiniFilesGitignore:get_filter ()
  return self.current_filter
end

---Get performance metrics
---@return PerformanceMetrics metrics Current performance metrics
function MiniFilesGitignore:get_metrics ()
  return vim.deepcopy (self.metrics)
end

---Find git root for a given directory
---@param dir string Directory path
---@return string|nil git_root Git root directory or nil if not in git repo
---@private
function MiniFilesGitignore:find_git_root (dir)
  if self.git_roots[dir] then
    return self.git_roots[dir]
  end

  -- Traverses upwards from the given directory to locate a `.git` directory.
  local current = dir
  while current and current ~= "/" do
    local git_dir = current .. "/.git"
    local stat = uv.fs_stat (git_dir)
    -- If `uv.fs_stat` returns a table, the `.git` path exists and is either a
    -- directory (traditional) or a file (worktrees).
    if stat then
      self.git_roots[dir] = current
      return current
    end
    current = vim.fn.fnamemodify (current, ":h")
  end

  -- Caches nil result if we couldn't locate `.git` to avoid re-computation.
  self.git_roots[dir] = nil
  return nil
end

---Get all gitignore files that affect a directory
---@param dir string Directory path
---@return string[] gitignore_files List of gitignore file paths
---@private
function MiniFilesGitignore:get_gitignore_files (dir)
  local git_root = self:find_git_root (dir)
  -- Returns an empty list if the directory is not within a git repository.
  -- That is, Gitignore rules are only applicable within a repository context.
  if not git_root then
    return {}
  end

  local gitignore_files = {}
  local current = dir

  -- Collects all `.gitignore` files by traversing from the current directory
  -- up to the determined git root.
  while current and current:find (git_root, 1, true) == 1 do
    local gitignore_path = current .. "/.gitignore"
    if uv.fs_stat (gitignore_path) then
      table.insert (gitignore_files, gitignore_path)
    end

    -- Stops traversal once git root is reached.
    if current == git_root then
      break
    end
    current = vim.fn.fnamemodify (current, ":h")
  end

  return gitignore_files
end

---Calculate cache key for directory
---@param dir string Directory path
---@param gitignore_files string[] List of gitignore files
---@return string cache_key Unique cache key
---@private
function MiniFilesGitignore:calculate_cache_key (dir, gitignore_files)
  -- The cache key incorporates the directory path and the modification times
  -- of all relevant gitignore files for cache invalidation when gitignore
  -- rules change.
  local key_parts = { dir }

  for _, file in ipairs (gitignore_files) do
    local stat = uv.fs_stat (file)
    if stat then
      -- Includes the file path and its last modification time in the key.
      table.insert (key_parts, string.format ("%s:%d", file, stat.mtime.sec))
    end
  end

  return table.concat (key_parts, "|")
end

---Check if cache entry is valid
---@param dir string Directory path
---@return boolean valid Whether cache is valid
---@private
function MiniFilesGitignore:is_cache_valid (dir)
  local cache_entry = self.cache[dir]
  if not cache_entry then
    return false
  end

  -- Validates the cache entry against its TTL.
  if cache_entry.expires_at < uv.hrtime () / 1e9 then
    self.logger:debug ("cache expired for directory: %s", dir)
    return false
  end

  -- Verifies that the modification times of associated gitignore files match
  -- the times stored at cache creation. A mismatch indicates that gitignore
  -- rules may have changed, invalidating the cache.
  for file_path, cached_mtime in pairs (cache_entry.gitignore_files) do
    local stat = uv.fs_stat (file_path)
    local current_mtime = stat and stat.mtime.sec or 0
    if current_mtime ~= cached_mtime then
      self.logger:debug ("gitignore file changed: %s (cached: %d, current: %d)", file_path, cached_mtime, current_mtime)
      return false
    end
  end

  return true
end

---Cleanup expired cache entries
---@private
function MiniFilesGitignore:cleanup_cache ()
  local current_time = uv.hrtime () / 1e9
  local removed_count = 0

  -- Iterates through the cache and removes entries whose expiration time
  -- is earlier than the current time.
  for dir, cache_entry in pairs (self.cache) do
    if cache_entry.expires_at < current_time then
      self.cache[dir] = nil
      removed_count = removed_count + 1
    end
  end

  -- Enforces the maximum cache size limit defined in the configuration. If the
  -- cache exceeds this limit, then older entries are evicted.
  local cache_size = vim.tbl_count (self.cache)
  if cache_size > self.config.max_cache_size then
    local entries = {}
    for dir, cache_entry in pairs (self.cache) do
      table.insert (entries, { dir = dir, timestamp = cache_entry.timestamp })
    end

    -- Sorts entries by timestamp to identify the oldest ones for eviction.
    table.sort (entries, function (a, b)
      return a.timestamp < b.timestamp
    end)

    -- Evict the oldest entries until the cache size is within the configured
    -- limit.
    local to_remove = cache_size - self.config.max_cache_size
    for i = 1, to_remove do
      self.cache[entries[i].dir] = nil
      removed_count = removed_count + 1
    end
  end

  if removed_count > 0 then
    self.logger:debug ("cleaned up %d expired cache entries", removed_count)
  end
end

---Check if file is ignored by gitignore rules
---@param dir string Directory path
---@param file_path string File path to check
---@return boolean ignored Whether file is ignored
---@private
function MiniFilesGitignore:is_file_ignored (dir, file_path)
  -- If the cache for the directory is invalid (e.g., expired or gitignore files
  -- changed), it's treated as a cache miss. The file is considered not ignored
  -- by default in this case, pending a cache refresh.
  if not self:is_cache_valid (dir) then
    self.metrics.cache_misses = self.metrics.cache_misses + 1
    return false
  end

  -- Increments cache hit counter and retrieves ignored status from the valid
  -- cache entry.
  self.metrics.cache_hits = self.metrics.cache_hits + 1

  -- Returns true if the file path exists as a key in the `ignored` map, false
  -- otherwise.
  return self.cache[dir].ignored[file_path] or false
end

---Process files synchronously using git check-ignore
---@param dir string Directory path
---@param file_paths string[] List of file paths to check
---@return table<string, boolean> ignored_map Map of file paths to ignored status
---@private
function MiniFilesGitignore:process_files_sync (dir, file_paths)
  local start_time = uv.hrtime ()
  self.metrics.sync_operations = self.metrics.sync_operations + 1

  -- If not in a git repository, no files are considered ignored by git.
  local git_root = self:find_git_root (dir)
  if not git_root then
    return {}
  end

  -- Creates a temporary file to pass file paths to `git check-ignore --stdin`.
  -- This approach is generally more performant than invoking `git check-ignore`
  -- per file.
  local temp_file = vim.fn.tempname ()
  local file_handle = io.open (temp_file, "w")
  if not file_handle then
    self.logger:error ("failed to create temporary file: %s", temp_file)
    return {}
  end

  for _, file_path in ipairs (file_paths) do
    file_handle:write (file_path .. "\n")
  end
  file_handle:close ()

  -- Executes `git check-ignore` synchronously. The command is run from the git
  -- root directory. `--stdin` reads paths from standard input, and `<
  -- temp_file` redirects the temp file content.
  local cmd = string.format (
    "cd %s && git check-ignore --stdin < %s",
    vim.fn.shellescape (git_root),
    vim.fn.shellescape (temp_file)
  )

  local result = vim.fn.system (cmd)
  vim.fn.delete (temp_file) -- cleans up the temporary file

  -- Parses the output of `git check-ignore`. Each line in the output is a path
  -- that is ignored (see above for details).
  local ignored_map = {}
  if vim.v.shell_error == 0 then
    for ignored_file in result:gmatch ("[^\n]+") do
      ignored_map[ignored_file] = true
    end
  end

  local elapsed = (uv.hrtime () - start_time) / 1e6 -- Convert to milliseconds
  self.metrics.total_processing_time = self.metrics.total_processing_time + elapsed
  self.logger:debug ("processed %d files synchronously in %.2fms", #file_paths, elapsed)

  return ignored_map
end

---Process files asynchronously using git check-ignore
---@param dir string Directory path
---@param file_paths string[] List of file paths to check
---@param callback function Callback function to call with results
---@private
function MiniFilesGitignore:process_files_async (dir, file_paths, callback)
  local start_time = uv.hrtime ()
  self.metrics.async_operations = self.metrics.async_operations + 1

  local git_root = self:find_git_root (dir)
  if not git_root then
    callback ({})
    return
  end

  local ignored_files = {}

  -- Configures an asynchronous job to run `git check-ignore`.
  -- `stdout_buffered = true` accumulates stdout data for the `on_stdout`
  -- callback.
  local job_config = {
    stdout_buffered = true,
    on_stdout = function (_, data)
      -- Processes lines from stdout, adding each ignored file path to the
      -- `ignored_files` table. `data` is a list of lines; empty lines are
      -- skipped.
      for _, line in ipairs (data) do
        if line and line ~= "" then
          ignored_files[line] = true
        end
      end
    end,
    on_exit = function (job_id, exit_code)
      -- Removes the job from the active pool upon completion. Note that we use
      -- the `job_id` parameter from the callback, as the `job_id` variable from
      -- the outer scope might be stale if multiple async jobs run.
      if self.job_pool and self.job_pool[job_id] then
        self.job_pool[job_id] = nil
      end

      local elapsed = (uv.hrtime () - start_time) / 1e6
      self.metrics.total_processing_time = self.metrics.total_processing_time + elapsed
      self.logger:debug ("processed %d files asynchronously in %.2fms (exit: %d)", #file_paths, elapsed, exit_code)

      callback (ignored_files)
    end,
  }

  local job_id = vim.fn.jobstart ({ "git", "-C", git_root, "check-ignore", "--stdin" }, job_config)

  if job_id > 0 then
    self.job_pool[job_id] = { dir = dir, start_time = start_time }

    -- Sends file paths to the job's stdin, one path per line and then closes
    -- the stdin channel to signal end of input to `git check-ignore`.
    vim.fn.chansend (job_id, table.concat (file_paths, "\n"))
    vim.fn.chanclose (job_id, "stdin")
  else
    self.logger:error ("failed to start git check-ignore job for directory: %s", dir)
    callback ({})
  end
end

---Cache gitignore results for directory
---@param dir string Directory path
---@param ignored_map table<string, boolean> Map of file paths to ignored status
---@private
function MiniFilesGitignore:cache_results (dir, ignored_map)
  local gitignore_files = self:get_gitignore_files (dir)
  local gitignore_mtimes = {}
  -- Stores the modification times of all relevant gitignore files. Used later
  -- to validate cache freshness.
  for _, file_path in ipairs (gitignore_files) do
    local stat = uv.fs_stat (file_path)
    gitignore_mtimes[file_path] = stat and stat.mtime.sec or 0
  end

  local current_time = uv.hrtime () / 1e9
  self.cache[dir] = {
    ignored = ignored_map,
    timestamp = current_time,
    gitignore_files = gitignore_mtimes,
    expires_at = current_time + self.config.cache_ttl,
  }

  self.logger:debug (
    "cached results for directory: %s (%d files, %d ignored)",
    dir,
    vim.tbl_count (ignored_map),
    vim.tbl_count (vim.tbl_filter (function (v)
      return v
    end, ignored_map))
  )

  self:cleanup_cache ()
end

---Setup filesystem watcher for directory
---@param dir string Directory path
---@private
function MiniFilesGitignore:setup_fs_watcher (dir)
  -- Avoids setting up multiple watchers for the same directory or gitignore
  -- file. Watchers are keyed by the gitignore file path they monitor.
  --
  -- @@: Consider if `self.fs_watchers` should key by gitignore_file
  -- path directly.
  --
  if self.fs_watchers[dir] then
    return
  end

  -- No watchers are needed if there are no gitignore files affecting the
  -- directory.
  local gitignore_files = self:get_gitignore_files (dir)
  if #gitignore_files == 0 then
    return
  end

  for _, gitignore_file in ipairs (gitignore_files) do
    local handle = uv.new_fs_event ()
    if handle then
      self.fs_watchers[gitignore_file] = handle

      -- Starts watching the gitignore file for changes. The callback is
      -- triggered when the file is modified (e.g., saved).
      uv.fs_event_start (handle, gitignore_file, {}, function (err, filename, events)
        if not err then
          vim.schedule (function ()
            self.logger:debug ("gitignore file changed: %s (events: %s)", gitignore_file, vim.inspect (events))
          end)
          -- Invalidates cache entries for all directories that could be
          -- affected by a change in this gitignore file. This typically
          -- includes the directory containing the gitignore file and its
          -- subdirectories.
          for cached_dir, _ in pairs (self.cache) do
            -- `fnamemodify(gitignore_file, ":h")` gets the directory of the
            -- changed .gitignore. If a cached directory path starts with the
            -- path of the changed .gitignore's directory, it means this
            -- .gitignore file could influence it.
            if cached_dir:find (vim.fn.fnamemodify (gitignore_file, ":h"), 1, true) == 1 then
              self.cache[cached_dir] = nil
              vim.schedule (function ()
                self.logger:debug ("invalidated cache for directory: %s", cached_dir)
              end)
            end
          end

          vim.schedule (function ()
            if not MiniFiles.is_busy then
              MiniFiles.refresh ({
                content = {
                  sort = self.current_sort,
                  filter = self.current_filter,
                },
              })
            end
          end)
        end
      end)
    end
  end
end

---Prefetch gitignore data for subdirectories
---@param parent_dir string Parent directory path
---@param depth number Current depth (for recursion limit)
---@private
function MiniFilesGitignore:prefetch_subdirectories (parent_dir, depth)
  -- Stops recursion if the current depth is invalid or exceeds the configured
  -- prefetch depth. Prefetching aims to proactively populate the cache for
  -- directories likely to be visited soon.
  if depth <= 0 or depth > self.config.prefetch_depth then
    return
  end

  -- Aborts if scanning the parent directory fails.
  local handle = uv.fs_scandir (parent_dir)
  if not handle then
    return
  end

  -- Scans the parent directory for subdirectories. Note that we ignores hidden
  -- directories (names starting with a dot).
  local subdirs = {}
  while true do
    local name, type = uv.fs_scandir_next (handle)
    if not name then
      break
    end

    if type == "directory" and not name:match ("^%.") then
      local subdir_path = parent_dir .. "/" .. name
      table.insert (subdirs, subdir_path)
    end
  end

  -- Asynchronously processes each subdirectory found.
  for _, subdir in ipairs (subdirs) do
    -- Prefetches only if the subdirectory's gitignore status is not already
    -- cached and valid.
    if not self:is_cache_valid (subdir) then
      vim.schedule (function ()
        local files = {}
        local sub_handle = uv.fs_scandir (subdir)
        if sub_handle then
          -- Collects all file and directory names within the subdirectory which
          -- are needed for `git check-ignore`.
          while true do
            local sub_name, sub_type = uv.fs_scandir_next (sub_handle)
            if not sub_name then
              break
            end
            table.insert (files, subdir .. "/" .. sub_name)
          end

          if #files > 0 then
            -- Processes the collected files to determine their gitignore
            -- status.
            self:process_files_async (subdir, files, function (ignored_map)
              self:cache_results (subdir, ignored_map)

              -- Recursively prefetches for deeper levels of subdirectories.
              -- Note that the depth is decremented for each level of recursion.
              self:prefetch_subdirectories (subdir, depth - 1)
            end)
          end
        end
      end)
    end
  end
end

---Custom sort function that handles gitignore integration
---@param fs_entries MiniFilesEntry[] List of filesystem entries
---@return MiniFilesEntry[] Sorted and filtered entries
function MiniFilesGitignore:sort_entries (fs_entries)
  -- If `self.state` is true, it signifies an "unfiltered" mode where all files
  -- are shown. In this mode, gitignore processing is bypassed, and a default
  -- sort is applied.
  if self.state then
    return MiniFiles.default_sort (fs_entries)
  end

  -- Returns immediately if there are no entries to process.
  if #fs_entries == 0 then
    return fs_entries
  end

  local start_time = uv.hrtime ()

  -- Groups filesystem entries by their parent directory to allows batch
  -- processing of `git check-ignore` for files in the same directory.
  local dirs_to_process = {}
  local dirs_files = {}

  for _, entry in ipairs (fs_entries) do
    local dir = vim.fn.fnamemodify (entry.path, ":h")
    if not dirs_files[dir] then
      dirs_files[dir] = {}
      -- If the cache for this directory is not valid, it's added to
      -- `dirs_to_process`.
      if not self:is_cache_valid (dir) then
        table.insert (dirs_to_process, dir)
      end
    end
    table.insert (dirs_files[dir], entry.path)
  end

  -- Processes directories whose gitignore status is not cached or is stale.
  for _, dir in ipairs (dirs_to_process) do
    local files = dirs_files[dir]

    -- Sets up filesystem watchers for `.gitignore` files relevant to this
    -- directory so changes to `.gitignore` files trigger cache invalidation.
    self:setup_fs_watcher (dir)

    -- Chooses between synchronous and asynchronous processing based on the
    -- number of files. For a small number of files, synchronous processing
    -- might be faster due to less overhead.
    if #files <= self.config.sync_threshold then
      -- Process synchronously for small file sets
      local ignored_map = self:process_files_sync (dir, files)
      self:cache_results (dir, ignored_map)
    else
      -- Process asynchronously for large file sets
      self:process_files_async (dir, files, function (ignored_map)
        self:cache_results (dir, ignored_map)

        -- After asynchronous processing completes, schedules a refresh of the
        -- mini.files view. This is necessary because the initial filtering
        -- might have occurred before the async results were available.R
        vim.schedule (function ()
          if not MiniFiles.is_busy then
            MiniFiles.refresh ({
              content = {
                sort = self.current_sort,
                filter = self.current_filter,
              },
            })
          end
        end)
      end)
    end

    -- Initiates prefetching for subdirectories to improve perceived performance
    -- when navigating into them (see above for details).
    self:prefetch_subdirectories (dir, self.config.prefetch_depth)
  end

  -- Filters the filesystem entries based on the (potentially updated) cached
  -- gitignore status. Note that entries determined to be ignored by git are
  -- excluded.
  local filtered_entries = vim.tbl_filter (function (entry)
    local dir = vim.fn.fnamemodify (entry.path, ":h")
    return not self:is_file_ignored (dir, entry.path)
  end, fs_entries)

  local elapsed = (uv.hrtime () - start_time) / 1e6
  self.logger:debug (
    "processed %d entries in %.2fms (filtered: %d)",
    #fs_entries,
    elapsed,
    #fs_entries - #filtered_entries
  )

  return MiniFiles.default_sort (filtered_entries)
end

---Toggle between filtered and unfiltered views
function MiniFilesGitignore:toggle_filtering ()
  self.state = not self.state

  -- Switches the active sort and filter functions based on the new state. If
  -- `self.state` is true (unfiltered), uses default mini.files sort/filter.
  -- Otherwise (filtered), uses the initial sort/filter, which incorporates
  -- gitignore logic.
  if self.state then
    self.current_sort = MiniFiles.default_sort
    self.current_filter = MiniFiles.default_filter
    self.logger:info ("switched to unfiltered view (showing all files)")
  else
    self.current_sort = self.initial_sort
    self.current_filter = self.initial_filter
    self.logger:info ("switched to filtered view (respecting gitignore)")
  end

  self:force_refresh ()
end

---Force refresh file view
---@private
function MiniFilesGitignore:force_refresh ()
  -- Workaround to compel `mini.files` to refresh its view. `mini.files`
  -- might not always refresh if only sort/filter functions change without
  -- other apparent changes to its internal state or view parameters. The
  -- workaround involves applying temporary, distinct dummy filters. Each
  -- application of `MiniFiles.refresh` with a new filter function instance
  -- is expected to trigger a re-evaluation of the displayed content.
  local function refresh_with_dummy_filter (char)
    MiniFiles.refresh ({
      content = {
        -- The dummy filter function is unique for each call due to the `char`
        -- closure.
        filter = function (fs_entry)
          return not vim.startswith (fs_entry.name, char)
        end,
      },
    })
  end

  -- Applies two distinct dummy filters sequentially. The specific characters
  -- (";" and ".") are arbitrary but different.
  refresh_with_dummy_filter (";")
  refresh_with_dummy_filter (".")

  -- After the dummy refreshes, applies the actual current sort and filter
  -- functions to reflects the desired state (gitignore-aware or unfiltered).
  MiniFiles.refresh ({
    content = {
      sort = self.current_sort,
      filter = self.current_filter,
    },
  })
end

---Cleanup resources
function MiniFilesGitignore:cleanup ()
  -- Stops all active filesystem watchers. `handle:is_closing()` checks if a
  -- handle is already in the process of closing. `handle:close()` releases the
  -- underlying libuv resources.
  for path, handle in pairs (self.fs_watchers) do
    if handle and not handle:is_closing () then
      handle:close ()
    end
  end
  self.fs_watchers = {}

  -- Terminates all active asynchronous jobs (e.g., `git check-ignore`
  -- processes). `pcall` is used to safely attempt `vim.fn.jobstop` as a job
  -- might have already exited.
  for job_id, _ in pairs (self.job_pool) do
    pcall (vim.fn.jobstop, job_id)
  end
  self.job_pool = {}

  -- Clears the gitignore cache to release memory.
  self.cache = {}
end

---@class MiniFilesSpec
---@field content table Configuration for file content display
---@field content.sort function Custom sort function for filesystem entries
---@field content.filter function Custom filter function for filesystem entries
---@field windows table Window display configuration
---@field windows.max_number number Maximum number of windows to show
---@field options table General plugin options
---@field options.permanent_delete boolean Whether to permanently delete files
---@field gitignore? MiniFilesGitignoreConfig Gitignore-specific configuration

---@type LazyPluginSpec
local Spec = {
  "mini.files", virtual = true,

  keys = {
    {
      "<leader>f",
      function ()
        -- Opens mini.files. If the current buffer is associated with a readable
        -- file, mini.files opens at that file's location. Otherwise, it opens
        -- at the current working directory. Note that we also refreshes its
        -- content using the sort and filter functions provided by the gitignore
        -- manager so that its initial view respects gitignore rules.
        local file = vim.api.nvim_buf_get_name (0)
        local file_exists = vim.fn.filereadable (file) ~= 0
        MiniFiles.open (file_exists and file or nil)
        MiniFiles.reveal_cwd ()
        MiniFiles.refresh ({
          content = {
            sort = MiniFiles.gitignore:get_sort (),
            filter = MiniFiles.gitignore:get_filter (),
          },
        })
      end,
      desc = "Files",
    },
    -- {
    --   "<leader>fm",
    --   function ()
    --     if MiniFiles.gitignore then
    --       local metrics = MiniFiles.gitignore:get_metrics ()
    --       vim.notify (
    --         string.format (
    --           "Gitignore Metrics:\n"
    --             .. "Cache hits: %d\n"
    --             .. "Cache misses: %d\n"
    --             .. "Sync operations: %d\n"
    --             .. "Async operations: %d\n"
    --             .. "Total processing time: %.2fms",
    --           metrics.cache_hits,
    --           metrics.cache_misses,
    --           metrics.sync_operations,
    --           metrics.async_operations,
    --           metrics.total_processing_time
    --         ),
    --         vim.log.levels.INFO
    --       )
    --     end
    --   end,
    --   desc = "Show gitignore metrics",
    -- },
  },

  opts = {
    content = {
      ---Custom sort function that handles gitignore integration
      ---@param fs_entries MiniFilesEntry[] List of filesystem entries
      ---@return MiniFilesEntry[] Sorted and filtered entries
      sort = function (fs_entries)
        return MiniFiles.gitignore:sort_entries (fs_entries)
      end,

      ---Default filter to hide dotfiles
      ---@param fs_entry MiniFilesEntry Entry to check
      ---@return boolean true if entry should be shown
      filter = function (fs_entry)
        return not vim.startswith (fs_entry.name, ".")
      end,
    },

    windows = { max_number = 1 },
    options = { permanent_delete = false },

    -- Gitignore-specific configuration
    gitignore = {
      max_cache_size = 1000,
      cache_ttl = 300,
      sync_threshold = 100,
      prefetch_depth = 2,
      enable_metrics = true,
      enable_logging = false, -- Set to true to enable debug logs
      log_level = vim.log.levels.DEBUG, -- Only matters when enable_logging = true
    },
  },

  ---Plugin setup function
  ---@param _ any Unused
  ---@param opts MiniFilesSpec Configuration options
  config = function (_, opts)
    require ("mini.files").setup (opts)

    -- Initializes the gitignore manager and attaches it to the `MiniFiles`
    -- module. This makes the gitignore instance accessible globally via
    -- `MiniFiles.gitignore`. The gitignore-specific configuration from
    -- `opts.gitignore` is passed here.
    MiniFiles.gitignore = MiniFilesGitignore.new (opts, opts.gitignore)

    -- Sets up key mapping restricted to to mini.files buffer.
    vim.api.nvim_create_autocmd ("User", {
      pattern = "MiniFilesBufferCreate",
      callback = function (args)
        vim.keymap.set ("n", ".", function ()
          MiniFiles.gitignore:toggle_filtering ()
        end, {
          buffer = args.data.buf_id,
          desc = "Toggle gitignore filtering",
        })
      end,
    })

    -- Clean up resources when Neovim is about to exit. "VimLeavePre" is
    -- triggered just before Neovim exits.
    vim.api.nvim_create_autocmd ("VimLeavePre", {
      callback = function ()
        if MiniFiles.gitignore then
          MiniFiles.gitignore:cleanup ()
        end
      end,
    })
  end,
}

return Spec

