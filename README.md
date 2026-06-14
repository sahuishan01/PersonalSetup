# Dotfiles Configuration

A cross-platform configuration setup containing optimized **Neovim v0.11+**, **Zsh** shell settings, **Node.js 24+**, and debugging tools (`DAP`) for C++, Rust, Python, and React.

## 🚀 Quick Setup

Run the unified installer script to bootstrap everything automatically:
```bash
./install.sh
```

The script will:
1. Detect your OS and package manager (`dnf`/`apt`/`brew`).
2. Install standard compilation dependencies (`cmake`, compilers, etc.).
3. Configure **NVM** and install **Node.js 24**.
4. Install global tools (`command-code` CLI, system `clangd`).
5. Compile and install **Neovim v0.11.0+** from source.
6. Backup existing configurations and symlink configs into `~/.zshrc` and `~/.config/nvim`.
7. Boot Neovim headlessly to sync all plugins, Tree-sitter parsers, and Mason LSP/DAP adapters.

---

## 📂 Repository Structure

*   `zsh/.zshrc` – Standard Oh My Zsh theme/plugin configuration and NVM hooks.
*   `nvim/` – Modern modular Lua config for Neovim:
    *   `init.lua` – Bootstraps configuration files.
    *   `lua/config/options.lua` – Tab settings, mouse, absolute/relative line numbers.
    *   `lua/config/keymaps.lua` – Keyboard shortcuts (`jk` for escape, splits, line blocks, cursor locks).
    *   `lua/plugins/ui.lua` – Theme (Tokyonight), statusline (Lualine), tabs (Bufferline), tree (Neo-tree).
    *   `lua/plugins/telescope.lua` – Fuzzy finder controls.
    *   `lua/plugins/treesitter.lua` – Code syntax parsers.
    *   `lua/plugins/lsp.lua` – Core LSP autocompletions (clangd, rust-analyzer, pyright, ts_ls, cssls, html, lua_ls).
    *   `lua/plugins/dap.lua` – Debug adapters (codelldb, debugpy, js-debug-adapter).

---

## ⌨️ Essential Keyboard Shortcuts

### General Navigation
*   `jk` or `kj` – Exit Insert Mode.
*   `<Esc>` – Clear search result highlights.
*   `<leader>e` (Space + `e`) – Toggle Neo-tree File Explorer.
*   `Ctrl + h/j/k/l` – Switch splits/windows.
*   `Shift + h/l` – Cycle between buffers/tabs.
*   `<leader>bd` (Space + `bd`) – Close current buffer.

### Splits
*   `<leader>sv` (Space + `sv`) – Split window vertically.
*   `<leader>sh` (Space + `sh`) – Split window horizontally.
*   `<leader>se` (Space + `se`) – Normalize split sizes.
*   `<leader>sx` (Space + `sx`) – Close current split.

### Fuzzy Finder (Telescope)
*   `<leader>ff` (Space + `ff`) – Find files.
*   `<leader>fg` (Space + `fg`) – Live grep search text.
*   `<leader>fb` (Space + `fb`) – Search open buffers.

### LSP (Language Server Protocol)
*   `gd` – Go to Definition.
*   `K` – Show hover documentation.
*   `<leader>ca` (Space + `ca`) – Trigger Code Actions.
*   `<leader>rn` (Space + `rn`) – Rename symbol.
*   `[d` / `]d` – Jump between syntax/compiler errors.

### DAP (Debugger)
*   `<F5>` – Start / Continue debugging.
*   `<F10>` – Step Over.
*   `<F11>` – Step Into.
*   `<F12>` – Step Out.
*   `<leader>b` (Space + `b`) – Toggle Breakpoint.
*   `<leader>du` (Space + `du`) – Toggle Debugger UI windows.
