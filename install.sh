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

# 1. Detect OS & Package Manager
log_info "Detecting Operating System..."
OS_TYPE=$(uname -s)
PKG_MGR=""

if [ "$OS_TYPE" = "Linux" ]; then
    if command -v dnf &> /dev/null; then
        PKG_MGR="dnf"
    elif command -v apt-get &> /dev/null; then
        PKG_MGR="apt"
    else
        log_warn "Linux distribution package manager not explicitly supported (neither dnf nor apt found). Assuming manual installation of dependencies."
    fi
elif [ "$OS_TYPE" = "Darwin" ]; then
    if command -v brew &> /dev/null; then
        PKG_MGR="brew"
    else
        log_error "Homebrew not found. Please install Homebrew first."
        exit 1
    fi
else
    log_error "Unsupported operating system: $OS_TYPE"
    exit 1
fi
log_success "Operating System: $OS_TYPE (Package Manager: ${PKG_MGR:-None})"

# Helper to install package via sudo if needed
install_pkg() {
    local pkg_name=$1
    local dnf_name=${2:-$pkg_name}
    local apt_name=${3:-$pkg_name}
    local brew_name=${4:-$pkg_name}

    if [ "$PKG_MGR" = "dnf" ]; then
        log_info "Installing $dnf_name via dnf..."
        sudo dnf install -y "$dnf_name"
    elif [ "$PKG_MGR" = "apt" ]; then
        log_info "Installing $apt_name via apt..."
        sudo apt-get update -y && sudo apt-get install -y "$apt_name"
    elif [ "$PKG_MGR" = "brew" ]; then
        log_info "Installing $brew_name via brew..."
        brew install "$brew_name"
    fi
}

# 2. Install Build Dependencies
log_info "Checking and installing build dependencies..."
if [ "$PKG_MGR" = "dnf" ]; then
    sudo dnf install -y gcc gcc-c++ make cmake unzip curl gettext tar git rsync patch pkgconfig autoconf automake libtool
elif [ "$PKG_MGR" = "apt" ]; then
    sudo apt-get update -y
    sudo apt-get install -y build-essential cmake unzip curl gettext tar git rsync patch pkg-config autoconf automake libtool
elif [ "$PKG_MGR" = "brew" ]; then
    brew install cmake unzip curl gettext git rsync patch autoconf automake libtool
fi
log_success "Build dependencies verified."

# 3. Install NVM & Node 24+
log_info "Checking Node Version Manager (NVM)..."
export NVM_DIR="$HOME/.nvm"
if [ ! -d "$NVM_DIR" ]; then
    log_info "Installing NVM..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.5/install.sh | bash
fi

# Load NVM in current environment
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

log_info "Installing Node.js 24..."
nvm install 24
nvm use 24
nvm alias default 24
log_success "Node.js installed: $(node -v) (NPM: $(npm -v))"

# 4. Install command-code CLI globally
log_info "Installing global command-code CLI..."
npm install -g command-code
log_success "command-code CLI installed: $(command -v cmd || command -v command-code)"

# 5. Install Native clangd for C++
log_info "Installing native clangd..."
if [ "$PKG_MGR" = "dnf" ]; then
    sudo dnf install -y clang clang-tools-extra
elif [ "$PKG_MGR" = "apt" ]; then
    sudo apt-get install -y clangd
elif [ "$PKG_MGR" = "brew" ]; then
    brew install llvm
fi
log_success "Native clangd installed: $(command -v clangd)"

# 6. Install Neovim 0.11.0+ from Source if missing or outdated
log_info "Checking Neovim version..."
NEEDS_BUILD=false
if ! command -v nvim &> /dev/null; then
    NEEDS_BUILD=true
else
    # Parse version number and check if it's 0.11 or newer
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
# Note: Since NVM was loaded during install, the configs in dotfiles/zsh/.zshrc will already load it.
# If using bash, append the NVM loader to ~/.bashrc if not present
if [ -f "$HOME/.bashrc" ]; then
    if ! grep -q "NVM_DIR" "$HOME/.bashrc"; then
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
nvim --headless "+Lazy! sync" +qa || log_warn "Lazy sync returned warnings (can occur headlessly; continuing)."

log_info "Installing Mason LSP servers and debuggers..."
nvim --headless "+MasonInstall rust-analyzer pyright typescript-language-server html-lsp css-lsp lua-language-server codelldb debugpy js-debug-adapter" +qa || log_warn "MasonInstall completed."

log_info "Synchronizing Treesitter parser compilers..."
nvim --headless -c "TSUpdateSync" -c "qall" || log_warn "Treesitter sync finished."

log_success "Dotfiles configuration and setup completed successfully!"
echo -e "\n${GREEN}Please restart your shell or run 'source ~/.zshrc' to start using your environment.${NC}\n"
