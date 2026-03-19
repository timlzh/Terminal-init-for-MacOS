# terminal_setup

macOS terminal environment setup script. Idempotent — safe to run multiple times.

## Repository Structure

```
terminal_setup/
├── setup.sh               # Main setup script
├── ghostty/
│   └── config             # Ghostty terminal config
├── tmux/
│   └── .tmux.conf         # tmux config
├── zsh/
│   ├── .zshrc             # zsh config
│   └── .p10k.zsh          # Powerlevel10k theme config
└── claude/
    ├── settings.json       # Claude Code settings
    └── claude_hud_config.json
```

## Quick Install

One-liner full setup (no git required):

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/timlzh/Terminal-init-for-MacOS/main/setup.sh)"
```

Or clone and run interactively:

```bash
git clone git@github.com:timlzh/Terminal-init-for-MacOS.git ~/terminal_setup
cd ~/terminal_setup
./setup.sh
```

## Usage

```bash
# Interactive menu
./setup.sh

# One-liner full setup
./setup.sh 0

# Single module
./setup.sh 1   # Ghostty
./setup.sh 2   # zsh + tmux + fzf + yazi
./setup.sh 3   # Neovim
./setup.sh 4   # Dev runtimes
./setup.sh 5   # Claude Code
./setup.sh 6   # Gemini CLI

# Multiple modules
./setup.sh 2 3
```

## Prerequisites (always run before selected module)

These run automatically regardless of which module is chosen:

| Step | What it does |
|------|-------------|
| Homebrew | Installs Homebrew if missing, then `brew update` |
| git | Installs git via Homebrew |
| Fonts | Installs Nerd Fonts + Sarasa fonts (see below) |

## Modules

| Option | Module | Includes |
|--------|--------|---------|
| 1 | Ghostty | Install via cask, symlink `ghostty/config → ~/.config/ghostty/config` |
| 2 | zsh | zsh, Oh-My-Zsh, plugins, Powerlevel10k theme, tmux, fzf, yazi |
| 3 | Neovim | neovim + [tvim](https://github.com/timlzh/tvim) config |
| 4 | Dev runtimes | Python 3.12, Go, Java (Temurin JDK), Node/npm, Bun |
| 5 | Claude Code | Install, login, settings symlink, everything-claude-code, claude-hud |
| 6 | Gemini CLI | `npm install -g @google/gemini-cli` |

## Fonts Installed

- [CascadiaCode Nerd Font](https://github.com/ryanoasis/nerd-fonts)
- [IBMPlexMono Nerd Font](https://github.com/ryanoasis/nerd-fonts)
- [CascadiaMono Nerd Font](https://github.com/ryanoasis/nerd-fonts)
- [Sarasa Term SC Nerd](https://github.com/laishulu/Sarasa-Term-SC-Nerd) — via `brew tap laishulu/homebrew`
- [Sarasa Mono SC Nerd](https://github.com/XuanXiaoming/Sarasa-Mono-SC-Nerd) — downloaded from repo zip

## Symlinks Created

| Source (this repo) | Destination |
|--------------------|-------------|
| `ghostty/config` | `~/.config/ghostty/config` |
| `tmux/.tmux.conf` | `~/.tmux.conf` |
| `zsh/.zshrc` | `~/.zshrc` |
| `zsh/.p10k.zsh` | `~/.p10k.zsh` |
| `claude/settings.json` | `~/.claude/settings.json` |
| `claude/claude_hud_config.json` | `~/.claude/plugins/claude-hud/config.json` |

Existing files are backed up to `<file>.bak` before being replaced.

## zsh Plugins

| Plugin | Source |
|--------|--------|
| fzf-zsh-plugin | https://github.com/unixorn/fzf-zsh-plugin |
| zsh-syntax-highlighting | https://github.com/zsh-users/zsh-syntax-highlighting |
| zsh-autosuggestions | https://github.com/zsh-users/zsh-autosuggestions |
| powerlevel10k | https://gitee.com/romkatv/powerlevel10k |
