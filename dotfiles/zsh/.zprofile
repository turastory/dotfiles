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
