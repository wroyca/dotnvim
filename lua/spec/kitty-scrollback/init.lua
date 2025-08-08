---@module "kitty-scrollback"

---@type LazyPluginSpec
local Spec = {
  "mikesmithgh/kitty-scrollback.nvim", opts = {},

  event = "User KittyScrollbackLaunch",
  cmd = {
    "KittyScrollbackGenerateKittens",
    "KittyScrollbackCheckHealth",
    "KittyScrollbackGenerateCommandLineEditing",
  },
}

return Spec
