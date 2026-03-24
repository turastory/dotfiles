# turastory's dotfiles

Personal development environment configuration for macOS.

Uses [GNU Stow](https://www.gnu.org/software/stow/) for symlink management. Each subdirectory under `dotfiles/` mirrors the home directory structure.

## What's included

| Category | Contents |
|----------|----------|
| **Shell** | zsh, oh-my-zsh, powerlevel10k, aliases |
| **Git** | gitconfig + git-delta config |
| **Editor** | Neovim (Lua config + lazy.nvim plugins) |
| **Terminal** | tmux, iTerm2 (`DynamicProfiles`) |
| **Keyboard** | Karabiner-Elements |
| **AI Tools** | Claude Code (CLAUDE.md, settings) |
| **Dev Tools** | gh CLI, asdf/tool-versions |
| **Packages** | Brewfile + optional Brewfile.local (Homebrew) |

## Setup on a new machine

```bash
# 1. Clone
git clone https://github.com/turastory/dotfiles.git ~/dotfiles
cd ~/dotfiles

# 2. Preview what will happen (no changes made)
make dry-run

# 3. Full setup on a fresh machine
make setup

# 4. If you have EXISTING dotfiles you want to keep:
#   --adopt moves your existing files INTO the repo, then creates symlinks.
#   Review with 'git diff' afterwards.
make brew
make adopt
```

## Structure

```
dotfiles/
├── Brewfile                  # Shared Homebrew packages
├── Brewfile.local            # Optional machine/work-specific Homebrew packages
├── Makefile                  # make setup / install / dry-run / adopt / brew
├── scripts/
│   ├── bootstrap-shell.bash  # oh-my-zsh, theme, plugin bootstrap
│   ├── link-dotfiles.bash    # GNU Stow installer (with dry-run support)
│   └── install-brew.bash     # Homebrew installer
├── templates/
│   └── claude/
│       └── settings.json.template  # {{HOME}} placeholder, rendered at install
└── dotfiles/                 # Stow packages (each mirrors $HOME)
    ├── zsh/                  # .zshrc, .zprofile, .aliases, .p10k.zsh, ...
    ├── git/                  # .gitconfig, .gitconfig.delta
    ├── nvim/.config/nvim/    # init.vim + lua/ + after/
    ├── tmux/                 # .tmux.conf
    ├── karabiner/.config/    # karabiner.json
    ├── claude/.claude/       # CLAUDE.md
    ├── gh/.config/gh/        # config.yml
    └── iterm2/               # Dynamic profile package for iTerm2
        └── Library/
            └── Application Support/
                └── iTerm2/
                    └── DynamicProfiles/
                        └── Profiles.json
```

Note: iTerm2 auto-loads JSON files from `~/Library/Application Support/iTerm2/DynamicProfiles`; restart iTerm2 after install so the profile appears. The shared setup also installs `font-meslo-for-powerlevel10k`, `font-monaspace`, and `font-inter` via Homebrew, so restarting iTerm2 after `make brew` or `make setup` helps it pick up newly installed fonts.

## Homebrew sync workflow

- Keep cross-machine packages in `Brewfile`.
- Keep private, work-only, or machine-specific packages in `Brewfile.local`.
- `make brew` installs `Brewfile` first and then `Brewfile.local` if it exists.
- `make brew-dump` snapshots the current machine state into `Brewfile.local`.

For a new shared package, prefer:

```bash
brew bundle add <name> --file=/Users/yoonho/dotfiles/Brewfile
```

## Bootstrap flow

- `make setup` installs Homebrew packages, bootstraps shell dependencies, and then stows dotfiles.
- `make brew` installs shared packages from `Brewfile` plus optional machine-local packages from `Brewfile.local`.
- `make install` only links dotfiles and now exits with an error if conflicts are found.
- Rust is installed from Homebrew.
- `nvim` is the editor source of truth.
- `vim`, `vi`, and `vimdiff` are shell aliases to Neovim.
- oh-my-zsh, powerlevel10k, `zsh-autosuggestions`, and `zsh-completions` are installed by the shell bootstrap script.
