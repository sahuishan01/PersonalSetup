# Dotfiles Configuration

A cross-platform configuration setup containing optimized **Neovim v0.11+**, **Zsh** shell settings, **Node.js 24+**, and debugging tools (`DAP`) for C++, Rust, Python, and React.

## 🚀 Quick Setup

### Linux & Termux (Android)
Execute the unified bash installer to bootstrap the environment automatically:
```bash
chmod +x ./install.sh
./install.sh
```
*(Termux is detected automatically and runs rootless, bypassing sudo and installing package dependencies natively to save resources).*

### Windows (PowerShell)
Open PowerShell (as Administrator if Windows Developer Mode is disabled to allow symlinks) and run:
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\install.ps1
```
*(Uses Winget to configure Neovim, Git, and LLVM/clangd, registers NVM, installs Node 24+, symlinks configurations to `%LOCALAPPDATA%\nvim`, and bootstraps plugins).*

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
