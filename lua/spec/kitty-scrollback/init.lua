---@module "kitty-scrollback"

---@type LazyPluginSpec
local Spec = {
  "mikesmithgh/kitty-scrollback.nvim", event = "User KittyScrollbackLaunch", opts = {},

  cmd = {
    "KittyScrollbackGenerateKittens",
    "KittyScrollbackCheckHealth",
    "KittyScrollbackGenerateCommandLineEditing",
  },
}

return Spec
