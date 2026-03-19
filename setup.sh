#!/usr/bin/env bash
# =============================================================================
# Terminal Environment Setup Script for macOS
# =============================================================================

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── Helpers ───────────────────────────────────────────────────────────────────
info() { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}   $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
header() { echo -e "\n${BOLD}${CYAN}══ $* ══${NC}\n"; }

# Script directory (works even when symlinked)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Guard: macOS only ─────────────────────────────────────────────────────────
if [[ "$(uname)" != "Darwin" ]]; then
    error "This script only supports macOS."
    exit 1
fi

# ── Sudo keepalive ────────────────────────────────────────────────────────────
# Acquire sudo upfront and refresh it in the background throughout the script
echo -e "${BOLD}This script may require sudo for some installations.${NC}"
sudo -v
( while true; do sudo -n true; sleep 60; kill -0 "$$" 2>/dev/null || exit; done ) &
SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null' EXIT

# =============================================================================
# PREREQUISITE 1 — Homebrew
# =============================================================================
install_homebrew() {
    header "Homebrew"
    if command -v brew &>/dev/null; then
        success "Homebrew already installed ($(brew --version | head -1))"
    else
        info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        # Add brew to PATH for Apple Silicon
        if [[ -f /opt/homebrew/bin/brew ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
        success "Homebrew installed."
    fi
    brew update --quiet
}

# =============================================================================
# PREREQUISITE 2 — git
# =============================================================================
install_git() {
    header "git"
    brew_install git
    success "git ready."
}

# =============================================================================
# PREREQUISITE 3 — Fonts
# =============================================================================
install_fonts() {
    header "Fonts"
    local font_dir="$HOME/Library/Fonts"
    mkdir -p "$font_dir"
    local tmp_dir
    tmp_dir="$(mktemp -d)"

    # Check if a font is already installed by searching all font dirs via fc-list or find
    _font_installed() {
        local keyword="$1"
        # fc-list is most reliable if available
        if command -v fc-list &>/dev/null; then
            fc-list | grep -qi "$keyword" && return 0
        fi
        # Fall back: search common macOS font directories
        find "$HOME/Library/Fonts" /Library/Fonts /System/Library/Fonts \
            \( -name "*${keyword}*.ttf" -o -name "*${keyword}*.otf" \) \
            -maxdepth 3 2>/dev/null | grep -q . && return 0
        return 1
    }

    _install_nerd_font_zip() {
        local name="$1" url="$2"
        if _font_installed "$name"; then
            success "Font '$name' already installed — skipping."
            return
        fi
        info "Downloading $name..."
        local zip="$tmp_dir/${name}.zip"
        curl -fsSL "$url" -o "$zip"
        unzip -o -q "$zip" -d "$tmp_dir/$name"
        find "$tmp_dir/$name" \( -name "*.ttf" -o -name "*.otf" \) -exec cp {} "$font_dir/" \;
        success "$name installed."
    }

    _install_nerd_font_zip "CaskaydiaCove" \
        "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/CascadiaCode.zip"
    _install_nerd_font_zip "BlexMono" \
        "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/IBMPlexMono.zip"
    _install_nerd_font_zip "CaskaydiaMono" \
        "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/CascadiaMono.zip"

    # Sarasa Term SC Nerd — via brew tap
    if _font_installed "Sarasa Term SC Nerd"; then
        success "Font 'Sarasa-Term-SC-Nerd' already installed — skipping."
    else
        info "Installing Sarasa-Term-SC-Nerd via brew..."
        brew tap laishulu/homebrew 2>/dev/null || true
        brew install font-sarasa-nerd
        success "Sarasa-Term-SC-Nerd installed."
    fi

    # Sarasa-Mono-SC-Nerd has no releases — download repo zip directly
    if _font_installed "Sarasa Mono SC Nerd"; then
        success "Font 'Sarasa-Mono-SC-Nerd' already installed — skipping."
    else
        info "Downloading Sarasa-Mono-SC-Nerd (repo zip)..."
        local sarasa_zip="$tmp_dir/Sarasa-Mono-SC-Nerd.zip"
        local http_code
        http_code="$(curl -sSL -w "%{http_code}" \
            "https://github.com/XuanXiaoming/Sarasa-Mono-SC-Nerd/archive/refs/heads/master.zip" \
            -o "$sarasa_zip" 2>/dev/null || true)"
        if [[ "$http_code" == "200" ]]; then
            unzip -o -q "$sarasa_zip" -d "$tmp_dir/Sarasa-Mono-SC-Nerd"
            find "$tmp_dir/Sarasa-Mono-SC-Nerd" \( -name "*.ttf" -o -name "*.otf" \) -exec cp {} "$font_dir/" \;
            success "Sarasa-Mono-SC-Nerd installed."
        else
            warn "Failed to download Sarasa-Mono-SC-Nerd (HTTP $http_code) — skipping."
        fi
    fi

    rm -rf "$tmp_dir"

    # Refresh font cache
    if command -v fc-cache &>/dev/null; then fc-cache -fv &>/dev/null; fi
    success "All fonts processed."
}

# =============================================================================
# MODULE: zsh (includes tmux, fzf, yazi)
# =============================================================================
setup_zsh() {
    header "zsh + Oh-My-Zsh + plugins + theme + tmux + fzf + yazi"

    # ── zsh ──────────────────────────────────────────────────────────────────
    brew_install zsh

    # ── oh-my-zsh ────────────────────────────────────────────────────────────
    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        success "Oh-My-Zsh already installed."
    else
        info "Installing Oh-My-Zsh..."
        RUNZSH=no CHSH=no sh -c \
            "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
        success "Oh-My-Zsh installed."
    fi

    local ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

    # ── plugins ───────────────────────────────────────────────────────────────
    clone_if_missing() {
        local dest="$1" repo="$2" depth_flag="${3:-}"
        if [[ -d "$dest" ]]; then
            success "$(basename "$dest") already present."
        else
            info "Cloning $(basename "$dest")..."
            # shellcheck disable=SC2086
            git clone $depth_flag "$repo" "$dest"
            success "$(basename "$dest") cloned."
        fi
    }

    clone_if_missing "$ZSH_CUSTOM/plugins/fzf-zsh-plugin" \
        "https://github.com/unixorn/fzf-zsh-plugin.git" "--depth 1"
    clone_if_missing "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" \
        "https://github.com/zsh-users/zsh-syntax-highlighting.git"
    clone_if_missing "$ZSH_CUSTOM/plugins/zsh-autosuggestions" \
        "https://github.com/zsh-users/zsh-autosuggestions"
    clone_if_missing "$ZSH_CUSTOM/themes/powerlevel10k" \
        "https://gitee.com/romkatv/powerlevel10k.git" "--depth=1"

    # ── dotfile symlinks ──────────────────────────────────────────────────────
    link_dotfiles_zsh

    # ── .zshrc.local ─────────────────────────────────────────────────────────
    if [[ ! -f "$HOME/.zshrc.local" ]]; then
        touch "$HOME/.zshrc.local"
        success "Created ~/.zshrc.local"
    else
        success "~/.zshrc.local already exists."
    fi

    # ── tmux ─────────────────────────────────────────────────────────────────
    brew_install tmux
    local tmux_src="$SCRIPT_DIR/tmux/.tmux.conf"
    if [[ -f "$tmux_src" ]]; then
        safe_link "$tmux_src" "$HOME/.tmux.conf"
    else
        warn "tmux config not found: $tmux_src"
    fi

    # ── fzf ──────────────────────────────────────────────────────────────────
    brew_install fzf
    "$(brew --prefix)/opt/fzf/install" --all --no-bash --no-fish 2>/dev/null || true

    # ── yazi ─────────────────────────────────────────────────────────────────
    info "Installing yazi and dependencies..."
    brew install yazi ffmpeg-full sevenzip jq poppler fd ripgrep fzf zoxide resvg imagemagick-full font-symbols-only-nerd-font 2>/dev/null ||
        brew install yazi sevenzip jq poppler fd ripgrep fzf zoxide font-symbols-only-nerd-font || true

    success "zsh setup complete."
}

link_dotfiles_zsh() {
    info "Linking zsh dotfiles..."
    local zsh_src="$SCRIPT_DIR/zsh"
    if [[ -d "$zsh_src" ]]; then
        for f in "$zsh_src"/.*; do
            [[ "$(basename "$f")" == "." || "$(basename "$f")" == ".." ]] && continue
            safe_link "$f" "$HOME/$(basename "$f")"
        done
    else
        warn "zsh source directory not found: $zsh_src"
    fi
}

# =============================================================================
# MODULE: ghostty
# =============================================================================
setup_ghostty() {
    header "Ghostty"

    if brew list --cask ghostty &>/dev/null 2>&1; then
        success "Ghostty already installed."
    else
        info "Installing Ghostty..."
        brew install --cask ghostty
        success "Ghostty installed."
    fi

    local ghostty_src="$SCRIPT_DIR/ghostty/config"
    if [[ -f "$ghostty_src" ]]; then
        mkdir -p "$HOME/.config/ghostty"
        safe_link "$ghostty_src" "$HOME/.config/ghostty/config"
    else
        warn "Ghostty config not found: $ghostty_src"
    fi

    success "Ghostty setup complete."
}

# =============================================================================
# MODULE: neovim
# =============================================================================
setup_neovim() {
    header "Neovim"
    brew_install neovim

    if [[ -d "$HOME/.config/nvim" ]]; then
        success "Neovim config already present at ~/.config/nvim"
    else
        info "Cloning tvim config..."
        git clone https://github.com/timlzh/tvim.git "$HOME/.config/nvim"
        success "Neovim config installed."
    fi
    success "Neovim setup complete."
}

# =============================================================================
# MODULE: development runtimes
# =============================================================================
setup_runtimes() {
    header "Development Runtimes (Python / Go / Java / Node / Bun)"

    # Python 3.12
    if ! brew list python@3.12 &>/dev/null; then
        info "Installing Python 3.12..."
        brew install python@3.12
        brew link python@3.12 --force 2>/dev/null || true
    else
        success "Python 3.12 already installed."
    fi

    # Go
    brew_install go

    # Java JDK (OpenJDK via temurin)
    if ! brew list --cask temurin &>/dev/null; then
        info "Installing Java JDK (Temurin)..."
        brew install --cask temurin
    else
        success "Java JDK already installed."
    fi

    # Node + npm
    brew_install node

    # Bun
    if command -v bun &>/dev/null; then
        success "Bun already installed."
    else
        info "Installing Bun..."
        curl -fsSL https://bun.sh/install | bash
        success "Bun installed."
    fi

    success "Runtimes setup complete."
}

# =============================================================================
# MODULE: Claude Code
# =============================================================================
setup_claude() {
    header "Claude Code"

    # Install Claude Code
    if command -v claude &>/dev/null; then
        success "Claude Code already installed."
    else
        info "Installing Claude Code..."
        curl -fsSL https://claude.ai/install.sh | bash
        success "Claude Code installed."
    fi

    # Reload PATH so 'claude' is available
    export PATH="$HOME/.claude/bin:$PATH"

    # Symlink settings
    mkdir -p "$HOME/.claude"
    local settings_src="$SCRIPT_DIR/claude/settings.json"
    if [[ -f "$settings_src" ]]; then
        safe_link "$settings_src" "$HOME/.claude/settings.json"
    else
        warn "Claude settings.json not found: $settings_src"
    fi

    # Symlink claude-hud config
    local hud_src="$SCRIPT_DIR/claude/claude_hud_config.json"
    if [[ -f "$hud_src" ]]; then
        mkdir -p "$HOME/.claude/plugins/claude-hud"
        safe_link "$hud_src" "$HOME/.claude/plugins/claude-hud/config.json"
    else
        warn "claude_hud_config.json not found: $hud_src"
    fi

    # Login guide
    echo ""
    info "Please log in to Claude Code:"
    if command -v claude &>/dev/null; then
        claude login || warn "Login skipped or failed — run 'claude login' manually."
    else
        warn "'claude' not found in PATH. Run 'claude login' after restarting your shell."
    fi

    # everything-claude-code
    info "Setting up everything-claude-code..."
    if command -v claude &>/dev/null; then
        claude mcp add --transport sse everything-claude-code \
            https://mcp.everything-claude-code.com/sse 2>/dev/null ||
            warn "everything-claude-code MCP setup failed — see https://github.com/affaan-m/everything-claude-code"
    else
        warn "Skipping everything-claude-code — claude CLI not available."
    fi

    # claude-hud
    info "Setting up claude-hud..."
    if command -v claude &>/dev/null; then
        claude mcp add --transport sse claude-hud \
            https://mcp.claude-hud.com/sse 2>/dev/null ||
            warn "claude-hud MCP setup failed — see https://github.com/jarrodwatts/claude-hud"
    else
        warn "Skipping claude-hud — claude CLI not available."
    fi

    success "Claude Code setup complete."
}

# =============================================================================
# MODULE: Gemini CLI
# =============================================================================
setup_gemini() {
    header "Gemini CLI"
    if command -v gemini &>/dev/null; then
        success "Gemini CLI already installed."
    else
        info "Installing Gemini CLI via npm..."
        npm install -g @google/gemini-cli 2>/dev/null ||
            warn "Gemini CLI install failed — ensure Node/npm is installed."
    fi
    success "Gemini CLI setup complete."
}

# =============================================================================
# Utilities
# =============================================================================
brew_install() {
    local pkg="$1"
    if brew list "$pkg" &>/dev/null 2>&1; then
        success "$pkg already installed."
    else
        info "Installing $pkg..."
        brew install "$pkg"
        success "$pkg installed."
    fi
}

safe_link() {
    local src="$1" dest="$2"
    if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
        success "Link already correct: $dest -> $src"
        return
    fi
    if [[ -e "$dest" && ! -L "$dest" ]]; then
        warn "Backing up existing $dest to ${dest}.bak"
        mv "$dest" "${dest}.bak"
    fi
    ln -sfn "$src" "$dest"
    success "Linked: $dest -> $src"
}

# =============================================================================
# MENU
# =============================================================================
print_menu() {
    echo ""
    echo -e "${BOLD}${CYAN}┌────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}${CYAN}│   macOS Terminal Environment Setup     │${NC}"
    echo -e "${BOLD}${CYAN}└────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "  ${BOLD}0)${NC} All-in-one (complete setup)"
    echo -e "  ${BOLD}1)${NC} Ghostty"
    echo -e "  ${BOLD}2)${NC} zsh + Oh-My-Zsh + plugins + theme + tmux + fzf + yazi"
    echo -e "  ${BOLD}3)${NC} Neovim + tvim config"
    echo -e "  ${BOLD}4)${NC} Dev runtimes (Python / Go / Java / Node / Bun)"
    echo -e "  ${BOLD}5)${NC} Claude Code"
    echo -e "  ${BOLD}6)${NC} Gemini CLI"
    echo -e "  ${BOLD}q)${NC} Quit"
    echo ""
}

run_prerequisites() {
    install_homebrew
    install_git
    install_fonts
}

run_module() {
    run_prerequisites
    case "$1" in
    0)
        setup_ghostty
        setup_zsh
        setup_neovim
        setup_runtimes
        setup_gemini
        setup_claude
        ;;
    1) setup_ghostty ;;
    2) setup_zsh ;;
    3) setup_neovim ;;
    4) setup_runtimes ;;
    5) setup_claude ;;
    6) setup_gemini ;;
    *) warn "Unknown option: $1" ;;
    esac
}

# =============================================================================
# MAIN
# =============================================================================
main() {
    # ── CLI argument mode ──────────────────────────────────────────────────────
    if [[ $# -gt 0 ]]; then
        for arg in "$@"; do
            run_module "$arg"
        done
        echo ""
        success "Done!"
        exit 0
    fi

    # ── Interactive menu ───────────────────────────────────────────────────────
    while true; do
        print_menu
        read -rp "Choose an option: " choice
        case "$choice" in
        q | Q)
            echo "Bye!"
            exit 0
            ;;
        0 | 1 | 2 | 3 | 4 | 5 | 6) run_module "$choice" ;;
        *) warn "Invalid choice '$choice'. Please try again." ;;
        esac
        echo ""
        read -rp "Press Enter to return to the menu..."
    done
}

main "$@"
