path_prepend() {
  if [ -d "$1" ]; then
    path=("$1" ${path:#$1})
    export PATH
  fi
}

export EDITOR="nvim"
export VISUAL="nvim"

if [ -f "$HOME/.cargo/env" ]; then
  . "$HOME/.cargo/env"
else
  path_prepend "$HOME/.cargo/bin"
fi

path_prepend "$HOME/.asdf/shims"

export NVM_DIR="$HOME/.nvm"
if [ -r "$NVM_DIR/alias/default" ]; then
  nvm_default_version="$(cat "$NVM_DIR/alias/default")"
  nvm_default_bin="$NVM_DIR/versions/node/$nvm_default_version/bin"
  path_prepend "$nvm_default_bin"
  unset nvm_default_version nvm_default_bin
fi

export PNPM_HOME="$HOME/Library/pnpm"
path_prepend "$PNPM_HOME"

export PYENV_ROOT="$HOME/.pyenv"
path_prepend "$PYENV_ROOT/shims"
path_prepend "$PYENV_ROOT/bin"

path_prepend "$HOME/.local/bin"

export BUN_INSTALL="$HOME/.bun"
path_prepend "$BUN_INSTALL/bin"

unset -f path_prepend
