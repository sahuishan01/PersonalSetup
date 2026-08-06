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
    pkg install -y git curl rsync patch unzip clang nodejs make cmake tar openssl
elif [ "$PKG_MGR" = "dnf" ]; then
    run_cmd dnf install -y gcc gcc-c++ make cmake unzip curl gettext tar git rsync patch pkgconfig autoconf automake libtool openssl-devel
elif [ "$PKG_MGR" = "apt" ]; then
    run_cmd apt-get update -y
    run_cmd apt-get install -y build-essential cmake unzip curl gettext tar git rsync patch pkg-config autoconf automake libtool libssl-dev
elif [ "$PKG_MGR" = "pacman" ]; then
    run_cmd pacman -Syu --noconfirm
    run_cmd pacman -S --needed --noconfirm base-devel cmake unzip curl git rsync patch openssl
elif [ "$PKG_MGR" = "zypper" ]; then
    run_cmd zypper refresh
    run_cmd zypper install -y -t pattern devel_basis
    run_cmd zypper install -y cmake unzip curl git rsync patch libopenssl-devel
elif [ "$PKG_MGR" = "brew" ]; then
    brew install cmake unzip curl gettext git rsync patch autoconf automake libtool openssl
fi
log_success "Build dependencies verified."

# Install WezTerm where the platform package manager provides it.
if ! command -v wezterm &> /dev/null; then
    if [ "$PKG_MGR" = "brew" ]; then
        brew install --cask wezterm
    elif [ "$PKG_MGR" = "apt" ]; then
        run_cmd apt-get install -y wezterm || log_warn "WezTerm is unavailable from the configured apt sources."
    fi
fi

# 3. Install uv and a managed Python runtime
log_info "Checking uv Python package manager..."
if ! command -v uv &> /dev/null; then
    log_info "Installing uv..."
    if [ "$PKG_MGR" = "brew" ]; then
        brew install uv
    else
        curl -LsSf https://astral.sh/uv/install.sh | sh
    fi
    export PATH="$HOME/.local/bin:$PATH"
fi

uv python install 3.13 --default
export PATH="$HOME/.local/bin:$PATH"
log_success "uv-managed Python ready: $(python --version 2>/dev/null || uv run --python 3.13 python --version)"

# 4. Install NVM & Node 24+
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

# 5. Install command-code CLI globally
log_info "Installing global command-code CLI..."
npm install -g command-code
log_success "command-code CLI installed."

# 6. Install Native clangd for C++
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

# 6a. Install Rust compiler toolchain
log_info "Checking Rust compiler (rustup)..."
if [ "$PKG_MGR" = "termux" ]; then
    pkg install -y rust
else
    if ! command -v rustc &> /dev/null; then
        log_info "Installing Rust via rustup..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    fi
fi

# Load cargo environment
export PATH="$HOME/.cargo/bin:$PATH"
if [ -f "$HOME/.cargo/env" ]; then
    \. "$HOME/.cargo/env"
fi
log_success "Rust compiler ready: $(rustc --version 2>/dev/null || echo 'cargo/rustup loaded')"

# 6b. Install GitUI terminal interface
log_info "Checking GitUI..."
if ! command -v gitui &> /dev/null; then
    log_info "Installing GitUI..."
    if [ "$PKG_MGR" = "pacman" ]; then
        run_cmd pacman -S --needed --noconfirm gitui
    elif [ "$PKG_MGR" = "zypper" ]; then
        run_cmd zypper install -y gitui
    elif [ "$PKG_MGR" = "brew" ]; then
        brew install gitui
    elif [ "$PKG_MGR" = "termux" ]; then
        pkg install -y gitui
    else
        # For dnf / apt, try package manager, fallback to cargo compile
        if [ "$PKG_MGR" = "dnf" ] && run_cmd dnf list gitui &> /dev/null; then
            run_cmd dnf install -y gitui
        elif [ "$PKG_MGR" = "apt" ] && run_cmd apt-cache show gitui &> /dev/null; then
            run_cmd apt-get install -y gitui
        else
            log_info "Building GitUI via Cargo (this may take a few minutes)..."
            OPENSSL_NO_VENDOR=1 cargo install gitui --locked
        fi
    fi
fi
log_success "GitUI installed: $(command -v gitui)"

# 7. Install Neovim 0.11.0+
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

# 8. Configure Symlinks (Safe backup)
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Setup WezTerm config.
if [ -f "$HOME/.wezterm.lua" ] && [ ! -L "$HOME/.wezterm.lua" ]; then
    mv "$HOME/.wezterm.lua" "$HOME/.wezterm.lua.bak"
fi
ln -sf "$DOTFILES_DIR/wezterm/.wezterm.lua" "$HOME/.wezterm.lua"
log_success "WezTerm config linked."

# Setup Zsh
log_info "Configuring ~/.zshrc..."
if [ -f "$HOME/.zshrc" ] && [ ! -L "$HOME/.zshrc" ]; then
    log_info "Backing up existing .zshrc to ~/.zshrc.bak..."
    mv "$HOME/.zshrc" "$HOME/.zshrc.bak"
fi
ln -sf "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"
log_success "Zsh config linked."

# Change default shell to Zsh if not already
if [ "$SHELL" != "$(which zsh)" ]; then
    if ! grep -q "$(which zsh)" /etc/shells 2>/dev/null; then
        command -v zsh >> /etc/shells 2>/dev/null || true
    fi
    log_info "Changing default shell to Zsh..."
    chsh -s "$(which zsh)" || log_warn "Could not change shell. Run manually: chsh -s $(which zsh)"
    log_success "Default shell changed to Zsh."
fi

# Install Oh My Zsh if not present
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    log_info "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended 2>/dev/null || true
    # Re-link .zshrc (Oh My Zsh installer overwrites it)
    ln -sf "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"
    log_success "Oh My Zsh installed."
fi

# Install Oh My Zsh custom plugins
log_info "Installing Zsh custom plugins..."
if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" 2>/dev/null
fi
if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions.git "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" 2>/dev/null
fi
log_success "Zsh custom plugins ready."

# Setup Neovim Config
log_info "Configuring ~/.config/nvim..."
mkdir -p "$HOME/.config"
if [ -d "$HOME/.config/nvim" ] && [ ! -L "$HOME/.config/nvim" ]; then
    log_info "Backing up existing nvim directory to ~/.config/nvim.bak..."
    mv "$HOME/.config/nvim" "$HOME/.config/nvim.bak"
fi
ln -sfT "$DOTFILES_DIR/nvim" "$HOME/.config/nvim"
log_success "Neovim configs linked."

# Setup shared AI agent developer profile (Claude Code, Gemini CLI, opencode, Hermes)
if [ -x "$DOTFILES_DIR/agent-profile/sync-agents.sh" ]; then
    log_info "Linking shared agent developer profile..."
    bash "$DOTFILES_DIR/agent-profile/sync-agents.sh"
    log_success "Agent profile linked."
fi

# Setup Git Config
log_info "Configuring global Git configuration include path..."
git config --global include.path "$DOTFILES_DIR/git/.gitconfig"
log_success "Git config include path registered."

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
    if ! grep -q "cargo/bin" "$HOME/.bashrc"; then
        log_info "Configuring Cargo path in ~/.bashrc..."
        echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> "$HOME/.bashrc"
    fi
fi

# 9. Synchronize Neovim Plugins and LSPs/DAPs
log_info "Bootstrapping Neovim plugins headlessly..."
nvim --headless "+Lazy! sync" +qa || log_warn "Lazy sync completed."

log_info "Installing Mason LSP servers and debuggers..."
nvim --headless "+MasonInstall rust-analyzer pyright typescript-language-server html-lsp css-lsp lua-language-server codelldb debugpy js-debug-adapter" +qa || log_warn "MasonInstall completed."

log_info "Synchronizing Treesitter parser compilers..."
nvim --headless -c "TSUpdateSync" -c "qall" || log_warn "Treesitter sync finished."

log_success "Dotfiles configuration and setup completed successfully!"
echo -e "\n${GREEN}Please restart your shell or run 'source ~/.zshrc' to start using your environment.${NC}\n"
