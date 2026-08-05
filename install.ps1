# install.ps1 - Native Windows Dotfiles Installer
# Run in PowerShell (as Administrator if Developer Mode is disabled for symlink creation)

$ErrorActionPreference = 'Stop'

function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Blue }
function Write-Success($msg) { Write-Host "[SUCCESS] $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-ErrorLog($msg) { Write-Host "[ERROR] $msg" -ForegroundColor Red }

function Refresh-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

function Add-UserPath($path) {
    $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $entries = @($userPath -split ';' | Where-Object { $_ })
    if ($entries -notcontains $path) {
        [System.Environment]::SetEnvironmentVariable("Path", (($entries + $path) -join ';'), "User")
    }
    Refresh-Path
}

# 1. Self-Execution Check & Path Setup
$DotfilesDir = $PSScriptRoot
Write-Info "Executing setup from: $DotfilesDir"

# 2. Check and Install Dependencies via Winget
Write-Info "Verifying development dependencies..."

# Helper to check commands and install via Winget
function Ensure-Command($commandName, $wingetId) {
    if (-not (Get-Command $commandName -ErrorAction SilentlyContinue)) {
        Write-Info "Installing $commandName using winget..."
        & winget install --exact --id $wingetId --silent --disable-interactivity --accept-package-agreements --accept-source-agreements
        Refresh-Path
    } else {
        Write-Success "$commandName is already installed."
    }
}

try {
    Ensure-Command "git" "Git.Git"
    Ensure-Command "nvim" "Neovim.Neovim"
    Ensure-Command "clangd" "LLVM.LLVM"
    Ensure-Command "rustc" "Rustlang.Rustup"
    Ensure-Command "gitui" "StephanDilly.gitui"
    Ensure-Command "uv" "astral-sh.uv"
} catch {
    Write-Warn "Winget auto-install failed or skipped. Please verify Git, Neovim, LLVM, Rust, and GitUI are installed manually."
}

# Add common installer locations that do not always update PATH immediately.
Add-UserPath "C:\Program Files\LLVM\bin"
Add-UserPath "C:\Program Files\Neovim\bin"
Add-UserPath "$env:USERPROFILE\.local\bin"

# Use uv for Python so the runtime and packages are isolated from system Python.
Write-Info "Installing managed Python through uv..."
try {
    & uv python install 3.13 --default
    Refresh-Path
    Write-Success "uv-managed Python is ready: $(python --version)"
} catch {
    Write-Warn "uv Python setup failed. Python-dependent debugging tools may be unavailable."
}

# 3. Verify Node.js 24+
Write-Info "Checking Node.js..."
$NodeInstalled = $false
if (Get-Command "node" -ErrorAction SilentlyContinue) {
    $NodeVersion = (node -v)
    Write-Info "Active Node.js version: $NodeVersion"
    if ($NodeVersion -match "^v(2[4-9]|[3-9][0-9])") {
        $NodeInstalled = $true
        Write-Success "Compatible Node.js version detected."
    }
}

if (-not $NodeInstalled) {
    Write-Info "Installing Node.js LTS via winget..."
    try {
        & winget install --exact --id "OpenJS.NodeJS.LTS" --silent --disable-interactivity --accept-package-agreements --accept-source-agreements
        Refresh-Path
        Write-Success "Node.js LTS installed. Version: $(node -v)"
    } catch {
        Write-ErrorLog "Failed to install Node.js. Please download and install Node.js 24+ manually."
        exit 1
    }
}

# 4. Install command-code globally
Write-Info "Installing command-code CLI globally..."
try {
    & npm install -g command-code
    Write-Success "command-code CLI installed."
} catch {
    Write-Warn "NPM global install failed. Ensure NPM path is in user environment."
}

# 5. Link Configuration Files (Windows paths)
Write-Info "Configuring symlinks for Neovim config..."
$NvimConfigDir = "$env:LOCALAPPDATA\nvim"
$TargetNvimDir = "$DotfilesDir\nvim"

if (Test-Path $NvimConfigDir) {
    Write-Warn "Backup existing Neovim config to: $NvimConfigDir.bak"
    if (Test-Path "$NvimConfigDir.bak") {
        Remove-Item -Recurse -Force "$NvimConfigDir.bak"
    }
    Rename-Item -Path $NvimConfigDir -NewName "nvim.bak"
}

# Create Symbolic Link or Junction
try {
    New-Item -ItemType SymbolicLink -Path $NvimConfigDir -Target $TargetNvimDir
    Write-Success "Symlinked Neovim config to $NvimConfigDir"
} catch {
    Write-Warn "Developer Mode disabled or permission denied for SymbolicLink. Attempting Junction creation..."
    try {
        New-Item -ItemType Junction -Path $NvimConfigDir -Target $TargetNvimDir
        Write-Success "Junction created for Neovim config at $NvimConfigDir"
    } catch {
        Write-ErrorLog "Failed to create directory link. Run PowerShell as Administrator or enable Developer Mode in Windows Settings."
        exit 1
    }
}

# Setup Git Config
Write-Info "Configuring global Git configuration include path..."
try {
    & git config --global include.path "$DotfilesDir\git\.gitconfig"
    Write-Success "Git config include path registered."
} catch {
    Write-Warn "Failed to configure Git include path. Ensure Git is installed and available in environment paths."
}

# 6. Bootstrap Neovim Plugins and Tools
Write-Info "Synchronizing Neovim plugins headlessly..."
try {
    & nvim --headless "+Lazy! sync" +qa
    Write-Success "Plugins synchronized."
} catch {
    Write-Warn "Headless plugins synchronization returned warnings."
}

Write-Info "Installing Mason language servers and debuggers..."
try {
    & nvim --headless "+MasonInstall rust-analyzer pyright typescript-language-server html-lsp css-lsp lua-language-server codelldb debugpy js-debug-adapter" +qa
    Write-Success "Mason components installed."
} catch {
    Write-Warn "MasonInstall completed with warnings."
}

Write-Info "Compiling Treesitter parsers..."
try {
    & nvim --headless -c "TSUpdateSync" -c "qall"
    Write-Success "Treesitter parsers compiled."
} catch {
    Write-Warn "Treesitter sync finished."
}

Write-Success "Dotfiles configuration completed successfully!"
Write-Host "Please restart your terminal to reload environment paths." -ForegroundColor Green
