---@type vim.filetype.add
vim.filetype.add ({
  extension = {
    build = "buildfile",
  },
  pattern = {
    ["buildfile"] = "buildfile",
  },
})
