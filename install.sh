#!/usr/bin/env bash

set -euo pipefail

# ANSI color codes for logs
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Helper to run commands with sudo if needed
run_cmd() {
    if [ "${IS_ROOTLESS:-false}" = "true" ] || [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        if command -v sudo &> /dev/null; then
            sudo "$@"
        else
            log_warn "sudo not found, running command directly..."
            "$@"
        fi
    fi
}

# 1. Detect OS & Platform (including Termux)
log_info "Detecting Operating System and Platform..."
OS_TYPE=$(uname -s)
PKG_MGR=""
IS_ROOTLESS=false

# Detect Termux
if [ -d "/data/data/com.termux/files/usr" ] || [[ "${PREFIX:-}" =~ com.termux ]]; then
    log_info "Termux environment detected."
    PKG_MGR="termux"
    IS_ROOTLESS=true
elif [ "$OS_TYPE" = "Linux" ]; then
    if command -v dnf &> /dev/null; then
        PKG_MGR="dnf"
    elif command -v apt-get &> /dev/null; then
        PKG_MGR="apt"
    elif command -v pacman &> /dev/null; then
        PKG_MGR="pacman"
    elif command -v zypper &> /dev/null; then
        PKG_MGR="zypper"
    else
        log_warn "Linux distribution package manager not explicitly supported. Assuming manual dependency installation."
    fi
elif [ "$OS_TYPE" = "Darwin" ]; then
    if command -v brew &> /dev/null; then
        PKG_MGR="brew"
    else
        log_warn "Homebrew not found. Continuing without package manager installation."
    fi
else
    log_error "Unsupported operating system: $OS_TYPE"
    exit 1
fi
log_success "Operating System: $OS_TYPE (Package Manager: ${PKG_MGR:-None})"

# 2. Install Build Dependencies
log_info "Checking and installing build dependencies..."
if [ "$PKG_MGR" = "termux" ]; then
    pkg update -y
    pkg install -y git curl rsync patch unzip clang nodejs make cmake tar
elif [ "$PKG_MGR" = "dnf" ]; then
    run_cmd dnf install -y gcc gcc-c++ make cmake unzip curl gettext tar git rsync patch pkgconfig autoconf automake libtool
elif [ "$PKG_MGR" = "apt" ]; then
    run_cmd apt-get update -y
    run_cmd apt-get install -y build-essential cmake unzip curl gettext tar git rsync patch pkg-config autoconf automake libtool
elif [ "$PKG_MGR" = "pacman" ]; then
    run_cmd pacman -Syu --noconfirm
    run_cmd pacman -S --needed --noconfirm base-devel cmake unzip curl git rsync patch
elif [ "$PKG_MGR" = "zypper" ]; then
    run_cmd zypper refresh
    run_cmd zypper install -y -t pattern devel_basis
    run_cmd zypper install -y cmake unzip curl git rsync patch
elif [ "$PKG_MGR" = "brew" ]; then
    brew install cmake unzip curl gettext git rsync patch autoconf automake libtool
fi
log_success "Build dependencies verified."

# 3. Install NVM & Node 24+
# On Termux, the native nodejs package is typically version 24+ out of the box, so we can skip NVM unless requested.
if [ "$PKG_MGR" = "termux" ] && command -v node &> /dev/null && node -v | grep -qE "v(2[4-9]|[3-9][0-9])"; then
    log_success "Termux native Node.js version $(node -v) matches requirements. Skipping NVM."
else
    log_info "Checking Node Version Manager (NVM)..."
    export NVM_DIR="$HOME/.nvm"
    if [ ! -d "$NVM_DIR" ]; then
        log_info "Installing NVM..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.5/install.sh | bash
    fi

    # Load NVM
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

    log_info "Installing Node.js 24..."
    nvm install 24
    nvm use 24
    nvm alias default 24
    log_success "Node.js version $(node -v) ready."
fi

# 4. Install command-code CLI globally
log_info "Installing global command-code CLI..."
npm install -g command-code
log_success "command-code CLI installed."

# 5. Install Native clangd for C++
log_info "Installing native clangd..."
if [ "$PKG_MGR" = "termux" ]; then
    # In Termux, clang package provides clangd
    pkg install -y clang
elif [ "$PKG_MGR" = "dnf" ]; then
    run_cmd dnf install -y clang clang-tools-extra
elif [ "$PKG_MGR" = "apt" ]; then
    run_cmd apt-get install -y clangd
elif [ "$PKG_MGR" = "pacman" ]; then
    run_cmd pacman -S --needed --noconfirm clang
elif [ "$PKG_MGR" = "zypper" ]; then
    run_cmd zypper install -y llvm-clang
elif [ "$PKG_MGR" = "brew" ]; then
    brew install llvm
fi
log_success "Native clangd verified."

# 6. Install Neovim 0.11.0+
log_info "Checking Neovim version..."
NEEDS_BUILD=false

if [ "$PKG_MGR" = "termux" ]; then
    # Termux maintains up-to-date neovim packages, install it natively to save CPU/battery
    log_info "Installing Neovim via pkg..."
    pkg install -y neovim
else
    if ! command -v nvim &> /dev/null; then
        NEEDS_BUILD=true
    else
        CURRENT_VERSION=$(nvim --version | head -n 1 | awk '{print $2}')
        log_info "Found existing Neovim version: $CURRENT_VERSION"
        if [[ ! "$CURRENT_VERSION" =~ ^v(0\.1[1-9]|0\.[2-9][0-9]|\.[0-9]+|[1-9][0-9]*) ]]; then
            NEEDS_BUILD=true
            log_warn "Neovim version is older than v0.11.0. Upgrading..."
        fi
    fi

    if [ "$NEEDS_BUILD" = true ]; then
        log_info "Downloading and building Neovim v0.11.0 from source..."
        mkdir -p "$HOME/.local/bin"
        BUILD_DIR=$(mktemp -d)
        git clone --depth 1 --branch v0.11.0 https://github.com/neovim/neovim.git "$BUILD_DIR"
        cd "$BUILD_DIR"
        make CMAKE_BUILD_TYPE=Release CMAKE_INSTALL_PREFIX="$HOME/.local" install
        cd -
        rm -rf "$BUILD_DIR"
        log_success "Neovim v0.11.0 compiled and installed to $HOME/.local/bin"
    else
        log_success "Compatible Neovim version already active."
    fi
fi

# Ensure $HOME/.local/bin is in PATH for shell scripts
export PATH="$HOME/.local/bin:$PATH"

# 7. Configure Symlinks (Safe backup)
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Setup Zsh
log_info "Configuring ~/.zshrc..."
if [ -f "$HOME/.zshrc" ] && [ ! -L "$HOME/.zshrc" ]; then
    log_info "Backing up existing .zshrc to ~/.zshrc.bak..."
    mv "$HOME/.zshrc" "$HOME/.zshrc.bak"
fi
ln -sf "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"
log_success "Zsh config linked."

# Setup Neovim Config
log_info "Configuring ~/.config/nvim..."
mkdir -p "$HOME/.config"
if [ -d "$HOME/.config/nvim" ] && [ ! -L "$HOME/.config/nvim" ]; then
    log_info "Backing up existing nvim directory to ~/.config/nvim.bak..."
    mv "$HOME/.config/nvim" "$HOME/.config/nvim.bak"
fi
ln -sfT "$DOTFILES_DIR/nvim" "$HOME/.config/nvim"
log_success "Neovim configs linked."

# Ensure PATH updates are present in shell configs (NVM loading, ~/.local/bin)
if [ -f "$HOME/.bashrc" ]; then
    if ! grep -q "NVM_DIR" "$HOME/.bashrc" && [ "$PKG_MGR" != "termux" ]; then
        log_info "Configuring NVM startup loading script in ~/.bashrc..."
        cat << 'EOF' >> "$HOME/.bashrc"

export PATH="$HOME/.local/bin:$PATH"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
EOF
    fi
fi

# 8. Synchronize Neovim Plugins and LSPs/DAPs
log_info "Bootstrapping Neovim plugins headlessly..."
nvim --headless "+Lazy! sync" +qa || log_warn "Lazy sync completed."

log_info "Installing Mason LSP servers and debuggers..."
nvim --headless "+MasonInstall rust-analyzer pyright typescript-language-server html-lsp css-lsp lua-language-server codelldb debugpy js-debug-adapter" +qa || log_warn "MasonInstall completed."

log_info "Synchronizing Treesitter parser compilers..."
nvim --headless -c "TSUpdateSync" -c "qall" || log_warn "Treesitter sync finished."

log_success "Dotfiles configuration and setup completed successfully!"
echo -e "\n${GREEN}Please restart your shell or run 'source ~/.zshrc' to start using your environment.${NC}\n"
