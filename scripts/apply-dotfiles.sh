#!/usr/bin/env bash
#
# apply-dotfiles.sh - initialise chezmoi against this checkout and apply the
# managed dotfiles.
#
# Safety contract:
#   * `--dry-run` only runs `chezmoi diff`, which never writes to $HOME
#   * a real apply always asks for confirmation first
#   * the default shell is never changed without a separate confirmation
#   * no secret is ever written to disk by this script
#
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

enable_error_trap

usage() {
  cat << 'EOF'
Usage: ./scripts/apply-dotfiles.sh [options]

Initialises chezmoi with this repository as its source directory, shows the
diff it would apply and, after an explicit confirmation, applies it.

Options:
  --diff-only      run `chezmoi diff` and exit without applying
  --init-only      initialise chezmoi but do not show or apply any diff
  --dry-run        same as --diff-only
  --yes, -y        apply without asking for confirmation
  -h, --help       show this help

Examples:
  ./scripts/apply-dotfiles.sh --diff-only
  ./scripts/apply-dotfiles.sh
EOF
}

DIFF_ONLY=false
INIT_ONLY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --diff-only | --dry-run)
      DIFF_ONLY=true
      DRY_RUN=true
      shift
      ;;
    --init-only)
      INIT_ONLY=true
      shift
      ;;
    --yes | -y)
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

chezmoi_is_initialized() {
  chezmoi source-path > /dev/null 2>&1
}

initialise_chezmoi() {
  log_step "Initialising chezmoi"

  if chezmoi_is_initialized; then
    log_skip "chezmoi is already initialised"
    log_info "source: $(chezmoi source-path 2> /dev/null || printf 'unknown')"
    return 0
  fi

  if ! is_true "$DRY_RUN"; then
    if [[ ! -d "${REPO_ROOT}/.git" ]]; then
      log_error "${REPO_ROOT} is not a git repository."
      log_info "chezmoi refuses to initialise a non-git source directory."
      log_info "Clone the repository first, or use the documented remote flow:"
      log_info "  chezmoi init --apply git@github.com:LuisOcp2/dev-environment.git"
      return 1
    fi
  fi

  if ! confirm "Initialise chezmoi using this repository as source?"; then
    log_skip "chezmoi initialisation cancelled"
    return 1
  fi

  if is_true "$DRY_RUN"; then
    log_dryrun "chezmoi --source ${REPO_ROOT} init"
    return 0
  fi

  # --source points chezmoi at the current checkout. No remote is fetched and
  # no file is applied here; --apply is deliberately omitted.
  if chezmoi --source "$REPO_ROOT" init; then
    log_success "chezmoi initialised"
    log_info "source: $(chezmoi source-path 2> /dev/null || printf 'unknown')"
    return 0
  fi

  log_error "chezmoi init failed"
  return 1
}

show_diff() {
  log_step "chezmoi diff (preview, nothing is written to \$HOME)"

  if is_true "$DRY_RUN"; then
    log_dryrun "chezmoi --source ${REPO_ROOT} diff"
    log_info "run './scripts/apply-dotfiles.sh --diff-only' to see the real diff"
    return 0
  fi

  if chezmoi diff; then
    log_success "diff computed successfully; review it before applying"
  else
    log_error "chezmoi diff failed"
    return 1
  fi
}

apply_changes() {
  log_step "Applying dotfiles"

  if ! confirm "Apply the dotfiles listed in the diff above?"; then
    log_skip "apply cancelled; nothing was changed in \$HOME"
    return 0
  fi

  if chezmoi apply; then
    log_success "dotfiles applied"
    return 0
  fi

  log_error "chezmoi apply failed"
  return 1
}

post_apply_tasks() {
  log_step "Post-apply tasks"

  local user_bin_dir_value
  user_bin_dir_value="$(user_bin_dir)"

  if [[ ":${PATH}:" != *":${user_bin_dir_value}:"* ]]; then
    log_warn "${user_bin_dir_value} is not on PATH in this shell"
    log_info "start a new shell with: exec \$SHELL"
  fi

  if is_true "${OFFER_ZSH_DEFAULT:-true}"; then
    if has_command zsh; then
      log_info "zsh is installed"
      # set_shell_default asks for its own confirmation before calling chsh.
      set_shell_default "$(command -v zsh)"
    else
      log_skip "zsh is not installed, default shell left unchanged"
    fi
  fi

  if has_command starship; then
    log_info "starship is installed; run 'starship prompt' to test it"
  else
    log_skip "starship is not installed; the fallback prompt stays active"
  fi
}

main() {
  log_step "Dotfiles"

  local defaults_file="${REPO_ROOT}/config/defaults.env"
  # shellcheck disable=SC1090 # runtime path
  [[ -f "$defaults_file" ]] && source "$defaults_file"

  export DRY_RUN ASSUME_YES

  if ! has_command chezmoi; then
    log_error "chezmoi is not installed."
    log_info "run ./scripts/install-chezmoi.sh first, or use 'make bootstrap'"
    return 1
  fi

  log_info "chezmoi: $(chezmoi --version 2> /dev/null | head -n 1)"

  if ! initialise_chezmoi; then
    return 1
  fi

  if is_true "$INIT_ONLY"; then
    log_skip "init only; no diff and no apply"
    return 0
  fi

  if ! show_diff; then
    return 1
  fi

  if is_true "$DIFF_ONLY"; then
    log_skip "diff only; nothing was applied"
    return 0
  fi

  if ! apply_changes; then
    return 0
  fi

  post_apply_tasks
  return 0
}

main "$@"
