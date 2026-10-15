#!/usr/bin/env bash
#
# update.sh - update the environment from a newer version of this repository.
#
# Safety contract:
#   * never runs `git pull`, `chezmoi update` or `apt upgrade` without an
#     explicit confirmation
#   * never performs a major version upgrade of a language runtime
#   * always takes a backup first when scripts/backup.sh is available
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
Usage: ./scripts/update.sh [options]

Updates the development environment from a newer version of this repository.

Steps, each individually confirmed:
  1. back up the current chezmoi state
  2. git fetch (never pull without confirmation)
  3. refresh the chezmoi source and show the diff
  4. apply the dotfiles
  5. re-install mise tools (existing versions are kept)

Options:
  --check-only      only report what would be done
  --allow-major     allow major runtime upgrades (off by default)
  --yes, -y         confirm every step
  -h, --help        show this help
EOF
}

CHECK_ONLY=false
ALLOW_MAJOR=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check-only)
      CHECK_ONLY=true
      DRY_RUN=true
      shift
      ;;
    --allow-major)
      ALLOW_MAJOR=true
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

report_state() {
  log_section "Current state"
  log_line "repository : ${REPO_ROOT}"

  if git -C "$REPO_ROOT" rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    log_line "branch     : $(git -C "$REPO_ROOT" branch --show-current 2> /dev/null || printf 'unknown')"
    log_line "commit     : $(git -C "$REPO_ROOT" rev-parse --short HEAD 2> /dev/null || printf 'unknown')"
  else
    log_warn "not a git repository"
  fi

  print_version chezmoi
  print_version mise
  print_version opencode

  if has_command chezmoi && chezmoi source-path > /dev/null 2>&1; then
    log_line "chezmoi src: $(chezmoi source-path 2> /dev/null || printf 'unknown')"
  fi
}

take_backup() {
  local backup_script="${REPO_ROOT}/scripts/backup.sh"

  if [[ ! -x "$backup_script" ]]; then
    log_skip "backup script not available"
    return 0
  fi

  log_step "Backing up the current state"
  if run "$backup_script"; then
    log_success "backup finished"
  else
    log_warn "backup reported problems"
    return 1
  fi
}

refresh_git() {
  log_step "Fetching repository updates"

  if ! git -C "$REPO_ROOT" rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    log_skip "not a git repository, skipping fetch"
    return 0
  fi

  local dirty
  dirty="$(git -C "$REPO_ROOT" status --porcelain 2> /dev/null | wc -l | tr -d ' ')"
  if [[ "$dirty" -gt 0 ]]; then
    log_warn "the working tree has ${dirty} uncommitted change(s)"
    log_info "commit or stash them before updating to avoid conflicts"
    if ! confirm "Continue anyway?"; then
      log_skip "update cancelled"
      return 1
    fi
  fi

  run git -C "$REPO_ROOT" fetch --prune origin

  local current upstream
  current="$(git -C "$REPO_ROOT" rev-parse HEAD 2> /dev/null || true)"
  upstream="$(git -C "$REPO_ROOT" rev-parse '@{upstream}' 2> /dev/null || true)"

  if [[ -z "$upstream" ]]; then
    log_warn "no upstream branch configured"
    return 0
  fi

  if [[ "$current" == "$upstream" ]]; then
    log_success "already up to date"
    return 0
  fi

  log_info "local    : $(git -C "$REPO_ROOT" rev-parse --short "$current")"
  log_info "upstream : $(git -C "$REPO_ROOT" rev-parse --short "$upstream")"

  local behind
  behind="$(git -C "$REPO_ROOT" rev-list --count "HEAD..@{upstream}" 2> /dev/null || printf '?')"
  log_info "commits behind: ${behind}"

  if is_true "$CHECK_ONLY"; then
    log_dryrun "git -C ${REPO_ROOT} pull --ff-only"
    return 0
  fi

  if ! confirm "Fast-forward the working tree to origin?"; then
    log_skip "pull cancelled"
    return 0
  fi

  run git -C "$REPO_ROOT" pull --ff-only
}

check_chezmoi_source() {
  log_step "Checking the chezmoi source"

  if ! has_command chezmoi; then
    log_skip "chezmoi is not installed"
    return 0
  fi

  if ! chezmoi source-path > /dev/null 2>&1; then
    log_warn "chezmoi is not initialised"
    return 0
  fi

  local source_dir
  source_dir="$(chezmoi source-path 2> /dev/null || printf 'unknown')"
  log_line "source directory: ${source_dir}"

  if is_true "$CHECK_ONLY"; then
    log_dryrun "chezmoi update"
    log_dryrun "chezmoi diff"
    return 0
  fi

  if ! confirm "Run 'chezmoi update' to refresh the source from its remote?"; then
    log_skip "chezmoi update cancelled"
    return 0
  fi

  run chezmoi update

  log_step "chezmoi diff"
  run chezmoi diff

  if ! confirm "Apply the updated dotfiles?"; then
    log_skip "apply cancelled; run 'make apply' later"
    return 0
  fi

  run chezmoi apply
}

update_mise_tools() {
  log_step "Runtime versions"

  if ! has_command mise; then
    log_skip "mise is not installed"
    return 0
  fi

  local global_config="${MISE_GLOBAL_CONFIG:-$(config_home)/mise/config.toml}"
  if [[ ! -f "$global_config" ]]; then
    log_warn "global mise config missing: ${global_config}"
    return 0
  fi

  if ! is_true "$ALLOW_MAJOR"; then
    log_info "major runtime upgrades are disabled (--allow-major to enable)"
    log_line "declared versions stay pinned in ${global_config}"
  fi

  if is_true "$CHECK_ONLY"; then
    log_dryrun "mise install"
    return 0
  fi

  if ! confirm "Run 'mise install' to add any newly declared versions?"; then
    log_skip "mise install cancelled"
    return 0
  fi

  run mise install
}

report_outdated_packages() {
  log_step "System package updates"

  if ! has_command apt-get; then
    log_skip "apt-get is not available"
    return 0
  fi

  if is_true "$CHECK_ONLY" || is_true "$DRY_RUN"; then
    log_dryrun "apt-get update && apt list --upgradable"
    log_info "apt upgrade is never run automatically by this repository"
    return 0
  fi

  if ! confirm "Run 'apt-get update' to refresh package metadata (no upgrade)?"; then
    log_skip "apt metadata not refreshed"
    return 0
  fi

  run env DEBIAN_FRONTEND=noninteractive apt-get update -y

  local upgradable
  upgradable="$(apt list --upgradable 2> /dev/null | grep -c upgradable || true)"
  log_line "upgradable packages: ${upgradable:-0}"
  log_info "review them with: apt list --upgradable"
  log_info "this repository never runs 'apt upgrade' for you"
}

main() {
  local defaults_file="${REPO_ROOT}/config/defaults.env"
  # shellcheck disable=SC1090 # runtime path
  [[ -f "$defaults_file" ]] && source "$defaults_file"

  export DRY_RUN ASSUME_YES

  print_banner "Environment update"
  log_info "check only : $(is_true "$CHECK_ONLY" && printf 'yes' || printf 'no')"
  log_info "major      : $(is_true "$ALLOW_MAJOR" && printf 'allowed' || printf 'blocked')"

  report_state

  if is_true "$CHECK_ONLY"; then
    log_section "Planned actions"
    log_line "  1. backup the current chezmoi state"
    log_line "  2. git fetch and fast-forward (no automatic pull)"
    log_line "  3. chezmoi update + diff + apply"
    log_line "  4. mise install for newly declared versions"
    log_line "  5. report upgradable system packages"
    log_info "run './scripts/update.sh' to execute"
    return 0
  fi

  take_backup || log_warn "continuing without a backup"
  refresh_git
  check_chezmoi_source
  update_mise_tools
  report_outdated_packages

  log_success "update finished"
  log_info "verify with: make verify"
}

main "$@"
