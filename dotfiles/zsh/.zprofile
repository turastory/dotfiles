brew_candidates=()

if brew_path="$(command -v brew 2>/dev/null)"; then
  brew_candidates+=("$brew_path")
fi

brew_candidates+=(/opt/homebrew/bin/brew /usr/local/bin/brew)

for brew_path in "${brew_candidates[@]}"; do
  if [[ -x "$brew_path" ]]; then
    eval "$("$brew_path" shellenv)"
    break
  fi
done

path_prepend() {
  if [ -d "$1" ]; then
    path=("$1" ${path:#$1})
    export PATH
  fi
}

# `brew shellenv` prepends Homebrew, so restore version-manager priority.
path_prepend "$HOME/.asdf/shims"

export NVM_DIR="$HOME/.nvm"
if [ -r "$NVM_DIR/alias/default" ]; then
  nvm_default_version="$(cat "$NVM_DIR/alias/default")"
  nvm_default_bin="$NVM_DIR/versions/node/$nvm_default_version/bin"
  path_prepend "$nvm_default_bin"
  unset nvm_default_version nvm_default_bin
fi

unset -f path_prepend
