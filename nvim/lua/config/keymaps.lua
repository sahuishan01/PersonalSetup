local map = vim.keymap.set

-- Exit Insert Mode
map("i", "jk", "<ESC>", { desc = "Exit Insert Mode" })
map("i", "kj", "<ESC>", { desc = "Exit Insert Mode" })

-- General Keymaps
map("n", "<leader>e", ":Neotree toggle<CR>", { desc = "Toggle Explorer" })
map("n", "<leader>nh", ":nohlsearch<CR>", { desc = "Clear Search Highlights" })
map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear Search Highlights" })

-- Window Splits
map("n", "<leader>sv", "<C-w>v", { desc = "Split Window Vertically" })
map("n", "<leader>sh", "<C-w>s", { desc = "Split Window Horizontally" })
map("n", "<leader>se", "<C-w>=", { desc = "Make Splits Equal Size" })
map("n", "<leader>sx", "<cmd>close<CR>", { desc = "Close Current Split" })

-- Window Navigation
map("n", "<C-h>", "<C-w>h", { desc = "Go to Left Window" })
map("n", "<C-j>", "<C-w>j", { desc = "Go to Lower Window" })
map("n", "<C-k>", "<C-w>k", { desc = "Go to Upper Window" })
map("n", "<C-l>", "<C-w>l", { desc = "Go to Right Window" })

-- Buffer Navigation
map("n", "<S-h>", ":bprevious<CR>", { desc = "Previous Buffer" })
map("n", "<S-l>", ":bnext<CR>", { desc = "Next Buffer" })
map("n", "<leader>bd", ":bdelete<CR>", { desc = "Delete Buffer" })

-- Move Lines in Visual Mode
map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move Selected Lines Down" })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move Selected Lines Up" })

-- Keep Cursor Centered on Scroll/Search
map("n", "<C-d>", "<C-d>zz", { desc = "Scroll Down (Center Cursor)" })
map("n", "<C-u>", "<C-u>zz", { desc = "Scroll Up (Center Cursor)" })
map("n", "n", "nzzzv", { desc = "Next Search Match (Center Cursor)" })
map("n", "N", "Nzzzv", { desc = "Prev Search Match (Center Cursor)" })

-- Better Indentation in Visual Mode
map("v", "<", "<gv", { desc = "Indent Left (Keep Selection)" })
map("v", ">", ">gv", { desc = "Indent Right (Keep Selection)" })

-- Paste over selection without losing current paste register
map("v", "p", '"_dP', { desc = "Paste over selection without losing register" })

-- Diagnostic navigation
map("n", "<leader>d", vim.diagnostic.open_float, { desc = "Show Line Diagnostics" })
map("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Open Diagnostics List" })
