---@module "mason-lspconfig"

---@return string[] declared_language_servers
local function language_servers ()
  local config_dir = vim.fs.normalize (vim.fn.stdpath ("config") .. "/lsp")

  if vim.fn.isdirectory (config_dir) ~= 1 then
    return {}
  end

  local glob_pattern = vim.fs.normalize (config_dir .. "/*.lua")
  local module_paths = vim.fn.glob (glob_pattern, false, true)

  return vim
    .iter (module_paths)
    :map (function (path)
      return vim.fn.fnamemodify (path, ":t:r")
    end)
    :totable ()
end

---@type string[]
local additional_language_servers = {
  "lua_ls",
}

---@return string[] language_servers_registry
local function language_servers_registry ()
  local all_servers = vim.iter ({ language_servers (), additional_language_servers }):flatten ():totable ()

  return vim.iter (all_servers):fold ({}, function (acc, identifier)
    if not vim.tbl_contains (acc, identifier) then
      table.insert (acc, identifier)
    end
    return acc
  end)
end

---@type LazyPluginSpec
local Spec = {
  "mason-org/mason-lspconfig.nvim", event = "VeryLazy",

  opts = {
    ensure_installed = language_servers_registry (),
  },
}

return Spec
