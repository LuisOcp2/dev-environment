# Makefile - developer entry points for this repository.
#
# `make help` is the default target.
#
# Every target that changes the system requires an explicit confirmation or
# the -y flag. `make validate` never modifies anything and is safe in CI.
#
# Override the profile for a single invocation:
#   make bootstrap PROFILE=minimal
#   make verify PROFILE=backend

SHELL := /usr/bin/env bash
.SHELLFLAGS := -Eeuo pipefail -c
.DEFAULT_GOAL := help

# --- Configuration ----------------------------------------------------------
PROFILE       ?= fullstack
BOOTSTRAP     := ./bootstrap.sh
SCRIPTS       := ./scripts
SCRIPTS_DIR   := $(SCRIPTS)
VALIDATOR     := $(SCRIPTS)/validate-repository.sh

# Convenience: `make bootstrap PROFILE=minimal` becomes a non interactive run.
YES_FLAG := $(if $(filter interactive,$(PROFILE)),,--yes)

# --- Presentation -----------------------------------------------------------
BOLD  := \033[1m
RESET := \033[0m
BLUE  := \033[0;34m

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
.PHONY: help
help: ## Show this help
	@printf "$(BOLD)dev-environment$(RESET) - portable AI development environment\n\n"
	@printf "$(BOLD)Usage$(RESET): make <target> [PROFILE=<name>]\n\n"
	@printf "$(BOLD)Targets$(RESET):\n"
	@awk 'BEGIN {FS = ":.*?## "} \
		/^[a-zA-Z0-9_-]+:.*?## / { \
			printf "  $(BLUE)%-22s$(RESET) %s\n", $$1, $$2 \
		}' $(MAKEFILE_LIST)
	@printf "\n$(BOLD)Profiles$(RESET): minimal frontend backend fullstack cloud teaching\n"
	@printf "$(BOLD)Examples$(RESET):\n"
	@printf "  make dry-run PROFILE=minimal\n"
	@printf "  make bootstrap PROFILE=fullstack\n"
	@printf "  make validate\n"

# ---------------------------------------------------------------------------
# Provisioning
# ---------------------------------------------------------------------------
.PHONY: bootstrap
bootstrap: ## Provision this machine using PROFILE (default: fullstack)
	@$(BOOTSTRAP) --profile "$(PROFILE)"

.PHONY: dry-run
dry-run: ## Print the full installation plan without changing anything
	@$(BOOTSTRAP) --profile "$(PROFILE)" --dry-run

.PHONY: bootstrap-minimal
bootstrap-minimal: ## Provision with the minimal profile
	@$(MAKE) bootstrap PROFILE=minimal

.PHONY: bootstrap-yes
bootstrap-yes: ## Provision non interactively (use with care)
	@$(BOOTSTRAP) --profile "$(PROFILE)" --yes

# ---------------------------------------------------------------------------
# Dotfiles
# ---------------------------------------------------------------------------
.PHONY: diff
diff: ## Show what chezmoi would change in the home directory
	@$(SCRIPTS)/apply-dotfiles.sh --diff-only

.PHONY: apply
apply: ## Apply the dotfiles after showing the diff
	@$(SCRIPTS)/apply-dotfiles.sh

.PHONY: apply-force
apply-force: ## Apply the dotfiles without asking (use with care)
	@$(SCRIPTS)/apply-dotfiles.sh --yes

# ---------------------------------------------------------------------------
# Verification
# ---------------------------------------------------------------------------
.PHONY: verify
verify: ## Verify that the development environment is complete
	@$(SCRIPTS)/verify.sh --profile "$(PROFILE)"

.PHONY: doctor
doctor: ## Diagnose the environment without modifying anything
	@$(SCRIPTS)/doctor.sh --profile "$(PROFILE)"

.PHONY: validate
validate: ## Validate this repository only; never modifies the machine
	@$(VALIDATOR)

.PHONY: lint
lint: ## Run shellcheck and shfmt over every script
	@$(SCRIPTS)/validate-repository.sh --only shell

.PHONY: test
test: ## Run bash -n plus the repository self tests
	@$(SCRIPTS)/validate-repository.sh --only syntax,tests

# ---------------------------------------------------------------------------
# Maintenance
# ---------------------------------------------------------------------------
.PHONY: update
update: ## Check for and apply environment updates (confirms each step)
	@$(SCRIPTS)/update.sh

.PHONY: update-check
update-check: ## Report available updates without applying anything
	@$(SCRIPTS)/update.sh --check-only

.PHONY: backup
backup: ## Back up the current chezmoi state
	@$(SCRIPTS)/backup.sh

.PHONY: backup-list
backup-list: ## List the backups available on this machine
	@$(SCRIPTS)/backup.sh --list

# ---------------------------------------------------------------------------
# Discovery
# ---------------------------------------------------------------------------
.PHONY: profiles
profiles: ## List the available installation profiles
	@$(BOOTSTRAP) --list-profiles

.PHONY: tools
tools: ## Report the installed versions of the expected tools
	@$(SCRIPTS)/detect-platform.sh

.PHONY: packages
packages: ## Print the resolved package list for PROFILE
	@bash -c 'source $(SCRIPTS)/lib/common.sh; \
	           source $(SCRIPTS)/lib/packages.sh; \
	           SELECTED_PROFILE="$${1:-$(PROFILE)}"; \
	           resolve_profile "$$SELECTED_PROFILE"; \
	           resolve_packages "$$PROFILE_PACKAGE_SETS"' _ "$(PROFILE)"

.PHONY: vscode-extensions
vscode-extensions: ## Install the recommended VS Code extensions
	@$(SCRIPTS)/install-vscode-extensions.sh

.PHONY: dev-tools
dev-tools: ## Install starship, direnv integration and the OpenCode CLI
	@$(SCRIPTS)/install-development-tools.sh

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------
.PHONY: clean
clean: ## Remove generated validation artifacts (never touches your dotfiles)
	@rm -rf .validate-cache
	@printf "removed .validate-cache\n"