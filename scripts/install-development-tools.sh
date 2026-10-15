#!/usr/bin/env bash
#
# install-development-tools.sh - install the tools that are NOT managed by apt.
#
# This script owns user-scoped tooling so that bootstrap.sh stays declarative:
#   - starship   (shell prompt)
#   - direnv     (per project environment, optional hook)
#   - OpenCode   (AI agent CLI, installed through npm)
#
# Every tool is optional: a missing tool degrades the environment gracefully,
# it never breaks it. Each installer is idempotent.
#
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=scripts/lib/packages.sh
source "${SCRIPT_DIR}/lib/packages.sh"

enable_error_trap

usage() {
  cat << 'EOF'
Usage: ./scripts/install-development-tools.sh [options]

Installs user-scoped developer tooling that is not available through apt:
starship, direnv shell integration and the OpenCode CLI.

Nothing here is required. Run it only when you want the extras.

Options:
  --only <list>   comma separated subset: starship,direnv,opencode
  --dry-run       print what would happen and exit
  --yes, -y       do not ask for confirmation
  -h, --help      show this help
EOF
}

ONLY=""
SELECTED_PROFILE="${SELECTED_PROFILE:-fullstack}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --only)
      [[ $# -ge 2 ]] || {
        log_error "--only requires a value."
        exit 2
      }
      ONLY="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --yes | -y)
      # Read by confirm() in scripts/lib/common.sh.
      # shellcheck disable=SC2034
      ASSUME_YES=true
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      usage
      exit 2
      ;;
  esac
done

# wants <name> honours the --only filter. An empty filter means "everything".
wants() {
  [[ -z "$ONLY" ]] && return 0
  [[ ",${ONLY}," == *",$1,"* ]]
}

install_starship() {
  log_step "starship"

  if has_command starship; then
    log_skip "starship is already installed: $(starship --version 2> /dev/null | head -n 1)"
    return 0
  fi

  if ! confirm "Install starship (shell prompt)?"; then
    log_skip "starship installation cancelled"
    return 0
  fi

  if is_true "$DRY_RUN"; then
    log_dryrun "curl -sSf https://starship.rs/install.sh | sh -s -- -y --bin-dir ${BIN_DIR}"
    return 0
  fi

  log_info "download installer: https://starship.rs/install.sh"
  log_info "review the script before running it in a sensitive environment"
  if curl --proto '=https' --tlsv1.2 -sSfL https://starship.rs/install.sh |
    sh -s -- -y --bin-dir "$(user_bin_dir)"; then
    log_success "starship installed"
  else
    log_error "starship installation failed"
    log_info "see https://starship.rs/guide/"
    return 1
  fi
}

install_direnv() {
  log_step "direnv shell integration"

  local hook_line='eval "$(direnv hook zsh)"'

  if ! has_command direnv; then
    log_warn "direnv is not installed; install it with apt or mise"
    return 0
  fi

  # The hook lives in the managed zsh config, so only report where it is.
  local zshrc="${HOME}/.zshrc"
  if [[ -f "$zshrc" ]] && grep -qF 'direnv hook' "$zshrc" 2> /dev/null; then
    log_skip "direnv hook already present in ${zshrc}"
  else
    log_warn "direnv hook not found in ${zshrc}"
    log_line "add this line after applying the dotfiles: ${hook_line}"
  fi

  # direnv must never be allowed to evaluate untrusted repositories by default.
  if [[ -f "${HOME}/.config/direnv/direnv.toml" ]]; then
    log_skip "direnv policy file already exists"
  else
    log_info "direnv policy file missing: ${HOME}/.config/direnv/direnv.toml"
    log_line "recommended content:"
    log_line "  [env] allowed = .envrc"
  fi
}

install_opencode() {
  log_step "OpenCode CLI"

  if has_command opencode; then
    log_skip "opencode is already installed: $(opencode --version 2> /dev/null | head -n 1)"
    return 0
  fi

  if ! has_command npm; then
    log_warn "npm is not available yet; install Node.js through mise first"
    return 0
  fi

  if ! confirm "Install the OpenCode CLI globally through npm?"; then
    log_skip "opencode installation cancelled"
    return 0
  fi

  if is_true "$DRY_RUN"; then
    log_dryrun "npm install -g opencode-ai"
    return 0
  fi

  if npm install -g opencode-ai; then
    log_success "opencode installed"
  else
    log_error "npm install -g opencode-ai failed"
    log_info "see https://opencode.ai/docs/ for manual installation"
    return 1
  fi
}

BIN_DIR="$(user_bin_dir)"

main() {
  log_step "User-scoped development tools"

  local defaults_file="${REPO_ROOT}/config/defaults.env"
  # shellcheck disable=SC1090 # runtime path
  [[ -f "$defaults_file" ]] && source "$defaults_file"

  ensure_dir "$BIN_DIR"

  if wants "starship"; then
    install_starship
  fi

  if wants "direnv"; then
    install_direnv
  fi

  if wants "opencode"; then
    install_opencode
  fi

  log_section "Result"
  for tool in starship direnv opencode; do
    print_version "$tool"
  done
}

main "$@"
