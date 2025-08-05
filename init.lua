--      .-.      _______                             .  '  *   .  . '
--     {}``; |==|_______D                                  . *  -+-  .
--     / ('        /|\                                 . '   * .    '  *
-- (  /  |        / | \                                    * .  ' .  .-+-
--  \(_)_%s      /  |  \                                *   *  .   .

local shada = vim.o.shada
vim.o.shada = ""
vim.schedule (function ()
  vim.o.shada = shada
  pcall (vim.cmd.rshada, { bang = true })
end)

vim.g.mapleader      = vim.keycode ("<Space>")
vim.g.maplocalleader = vim.g.mapleader
vim.o.breakindent    = true
vim.o.clipboard      = "unnamedplus"
vim.o.cmdheight      = 0
vim.o.confirm        = true
vim.o.copyindent     = true
vim.o.cursorline     = true
vim.o.fillchars      = [[eob: ]]
vim.o.gdefault       = true
vim.o.guicursor      = "a:blinkwait700-blinkoff400-blinkon250,i-ci-ve:ver25,r-cr-o:hor20"
vim.o.laststatus     = 0
vim.o.list           = true
vim.o.mouse          = "a"
vim.o.mousemoveevent = true
vim.o.mousescroll    = "ver:3,hor:0"
vim.o.preserveindent = true
vim.o.pumheight      = 8
vim.o.scrolloff      = 4
vim.o.shortmess      = vim.o.shortmess .. "A"
vim.o.signcolumn     = "yes:1"
vim.o.smartindent    = true
vim.o.termguicolors  = true
vim.o.undofile       = true
