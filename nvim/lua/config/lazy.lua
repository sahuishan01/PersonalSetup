-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Set mapleader before lazy so keymaps are correct
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Load options and keymaps
require("config.options")
require("config.keymaps")

-- Setup lazy.nvim and load plugins
require("lazy").setup({
  spec = {
    { import = "plugins" },
  },
  defaults = {
    lazy = false,
  },
  install = { colorscheme = { "tokyonight" } },
  checker = { enabled = false },
})
