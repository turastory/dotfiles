vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

local opt = vim.opt
local fn = vim.fn

opt.number = true
opt.relativenumber = true
opt.cursorline = true
opt.mouse = "a"
opt.showcmd = true
opt.ruler = true
opt.wildmenu = true
opt.wildmode = { "longest:full", "full" }
opt.splitbelow = true
opt.splitright = true
opt.scrolloff = 4
opt.sidescrolloff = 8
opt.hidden = true
opt.wrap = false
opt.linebreak = true
opt.ignorecase = true
opt.smartcase = true
opt.incsearch = true
opt.hlsearch = true
opt.tabstop = 2
opt.shiftwidth = 2
opt.softtabstop = 2
opt.expandtab = true
opt.smartindent = true
opt.updatetime = 250
opt.timeoutlen = 400
opt.completeopt = { "menuone", "noselect" }
opt.backspace = { "indent", "eol", "start" }
opt.termguicolors = true

if fn.has("unnamedplus") == 1 then
  opt.clipboard = { "unnamed", "unnamedplus" }
elseif fn.has("clipboard") == 1 then
  opt.clipboard = "unnamed"
end

if fn.executable("rg") == 1 then
  opt.grepprg = "rg --vimgrep --smart-case"
  opt.grepformat = "%f:%l:%c:%m"
end

vim.g.netrw_banner = 0
vim.g.netrw_liststyle = 3
vim.g.netrw_browse_split = 0
vim.g.netrw_altv = 1
vim.g.netrw_winsize = 20

local state_dir = fn.stdpath("state")
for _, dir in ipairs({ "backup", "swap", "undo" }) do
  fn.mkdir(state_dir .. "/" .. dir, "p")
end

opt.backupdir = state_dir .. "/backup//"
opt.directory = state_dir .. "/swap//"
opt.undofile = true
opt.undodir = state_dir .. "/undo//"

vim.cmd("silent! colorscheme murphy")

vim.api.nvim_create_user_command("C", function()
  vim.fn.setreg("/", "")
  vim.cmd("nohlsearch")
end, {})

local keymap = vim.keymap.set
keymap("n", "<leader>w", "<cmd>write<cr>")
keymap("n", "<leader>q", "<cmd>quit<cr>")
keymap("n", "<leader>h", "<cmd>nohlsearch<cr>")
keymap("n", "<leader>e", "<cmd>Ex<cr>")
keymap("n", "<leader>n", "<cmd>cnext<cr>")
keymap("n", "<leader>p", "<cmd>cprev<cr>")
