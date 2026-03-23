.PHONY: install dry-run adopt brew brew-dump setup all

install:
	@./scripts/link-dotfiles.bash

dry-run:
	@./scripts/link-dotfiles.bash --dry-run

adopt:
	@echo "Adopting existing files into dotfiles repo..."
	@cd dotfiles && for pkg in */; do \
		pkg=$${pkg%/}; \
		[ -f "$$pkg/.skipstow" ] && continue; \
		stow --adopt -t "$$HOME" -d . "$$pkg" 2>&1 || true; \
	done
	@echo "Done. Check 'git diff' to review what was adopted."

brew:
	@./scripts/install-brew.bash

brew-dump:
	@brew bundle dump --force --describe --file="$(CURDIR)/Brewfile.local"

setup:
	@./scripts/install-brew.bash
	@./scripts/bootstrap-shell.bash
	@./scripts/link-dotfiles.bash

all: setup
