local opt = vim.opt

-- General Options
opt.number = true            -- Show line numbers
opt.relativenumber = true    -- Relative line numbers
opt.termguicolors = true     -- True color support
opt.mouse = "a"              -- Enable mouse support
opt.clipboard = "unnamedplus" -- Sync system clipboard

-- Tabs & Indentation
opt.tabstop = 4              -- Number of spaces a tab counts for
opt.shiftwidth = 4           -- Size of an indent
opt.expandtab = true         -- Use spaces instead of tabs
opt.autoindent = true        -- Insert indents automatically

-- Search
opt.ignorecase = true        -- Ignore case in search patterns
opt.smartcase = true         -- Override ignorecase if search contains capitals
opt.hlsearch = false         -- Clear highlight after search

-- Splits
opt.splitright = true        -- Put new windows to the right of current
opt.splitbelow = true        -- Put new windows below current

-- Undo & Backup
opt.undofile = true          -- Save undo history
opt.swapfile = false         -- Disable swap files
opt.backup = false           -- Disable backup files
