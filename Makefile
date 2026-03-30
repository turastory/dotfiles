.PHONY: install dry-run adopt brew brew-dump setup all

install:
	@./scripts/link-dotfiles.bash

dry-run:
	@./scripts/link-dotfiles.bash --dry-run

adopt:
	@echo "Adopting existing files into dotfiles repo..."
	@cd dotfiles && failed=0; for pkg in */; do \
		pkg=$${pkg%/}; \
		[ -f "$$pkg/.skipstow" ] && continue; \
		if ! stow --adopt -t "$$HOME" -d . "$$pkg"; then \
			failed=1; \
		fi; \
	done; \
	if [ "$$failed" -ne 0 ]; then \
		echo "One or more packages failed to adopt." >&2; \
		exit 1; \
	fi
	@echo "Done. Check 'git diff' to review what was adopted."

brew:
	@./scripts/install-brew.bash

brew-dump:
	@brew bundle dump --force --describe --file="$(CURDIR)/Brewfile.local"

setup:
	@./scripts/install-brew.bash; \
	if command -v brew >/dev/null 2>&1; then \
		eval "$$(brew shellenv)"; \
	elif [ -x /opt/homebrew/bin/brew ]; then \
		eval "$$(/opt/homebrew/bin/brew shellenv)"; \
	elif [ -x /usr/local/bin/brew ]; then \
		eval "$$(/usr/local/bin/brew shellenv)"; \
	fi; \
	./scripts/bootstrap-shell.bash; \
	./scripts/link-dotfiles.bash

all: setup
