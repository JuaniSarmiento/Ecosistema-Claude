PLUGIN_DIR := $(CURDIR)
INSTALL_DIR := $(HOME)/.claude/plugins/gentleman-native

.PHONY: help verify-env bootstrap init install install-dev uninstall test-hooks smoke dev package clean status

help:
	@echo "Targets:"
	@echo "  make install      - Install plugin globally (copy mode)"
	@echo "  make install-dev  - Install plugin globally (symlink mode, for developers)"
	@echo "  make uninstall    - Remove global plugin installation"
	@echo "  make init         - Bootstrap the current project (.claude/memory, .claude/specs, AGENTS.md)"
	@echo "  make verify-env   - Verify minimum dependencies"
	@echo "  make bootstrap    - Alias for init (legacy)"
	@echo "  make test-hooks   - Run hook unit tests"
	@echo "  make smoke        - Run smoke test checklist"
	@echo "  make dev          - Launch Claude with the local plugin"
	@echo "  make package      - Package the plugin"
	@echo "  make status       - Run diagnostic status report"
	@echo "  make clean        - Remove build artifacts"

verify-env:
	@./scripts/verify-env.sh

bootstrap: init

init:
	@./scripts/bootstrap-project.sh

install:
	@chmod +x ./scripts/install.sh
	@./scripts/install.sh

install-dev:
	@chmod +x ./scripts/install.sh
	@./scripts/install.sh --dev

uninstall:
	@chmod +x ./scripts/install.sh
	@./scripts/install.sh --uninstall

test-hooks:
	@./tests/test-hooks.sh

smoke:
	@./tests/smoke-plugin.sh

dev:
	@claude --plugin-dir "$(PLUGIN_DIR)"

package:
	@./scripts/package-plugin.sh

status:
	@chmod +x ./scripts/status.sh
	@./scripts/status.sh

clean:
	@rm -rf dist
