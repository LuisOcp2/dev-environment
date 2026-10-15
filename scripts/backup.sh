#!/usr/bin/env bash
#
# backup.sh - back up the managed dotfiles and the local chezmoi state.
#
# What is backed up:
#   - the chezmoi source directory (a plain copy, never a git operation)
#   - the local chezmoi config and persistent state
#   - a manifest of the managed files currently applied in $HOME
#
# What is NEVER backed up or read:
#   - SSH private keys
#   - .env files with real values
#   - cloud credentials
#   - AI provider tokens
#
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

enable_error_trap

usage() {
  cat << 'EOF'
Usage: ./scripts/backup.sh [options]

Creates a timestamped backup of the chezmoi state under
${XDG_DATA_HOME:-~/.local/share}/dev-environment/backups.

Options:
  --output <dir>   write the backup somewhere else
  --list           list the backups found in the default location
  --yes, -y        do not ask for confirmation
  -h, --help       show this help

Examples:
  ./scripts/backup.sh
  ./scripts/backup.sh --output ~/tmp/dev-env-backup
  ./scripts/backup.sh --list
EOF
}

OUTPUT_DIR=""
LIST_ONLY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      [[ $# -ge 2 ]] || {
        log_error "--output requires a value."
        exit 2
      }
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --output=*)
      OUTPUT_DIR="${1#*=}"
      shift
      ;;
    --list)
      LIST_ONLY=true
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

default_backup_root() {
  printf '%s/dev-environment/backups' "$(data_home)"
}

timestamp() {
  date +"%Y%m%d-%H%M%S"
}

list_backups() {
  local root
  root="$(default_backup_root)"

  if [[ ! -d "$root" ]]; then
    log_info "no backups yet (${root})"
    return 0
  fi

  log_step "Backups in ${root}"
  local dir
  local found=0
  for dir in "$root"/*; do
    [[ -d "$dir" ]] || continue
    found=$((found + 1))
    printf '  %s  %s\n' "$(basename "$dir")" "$(du -sh "$dir" 2> /dev/null | cut -f1)"
  done
  log_line "total: ${found}"
}

write_manifest() {
  local destination="$1"

  if ! has_command chezmoi; then
    log_skip "chezmoi not installed, no manifest written"
    return 0
  fi

  if ! chezmoi source-path > /dev/null 2>&1; then
    log_skip "chezmoi is not initialised, no manifest written"
    return 0
  fi

  log_info "writing the managed file manifest"
  chezmoi managed --include files 2> /dev/null > "$destination/managed-files.txt" ||
    log_warn "could not generate the managed file list"
}

copy_chezmoi_state() {
  local destination="$1"

  if ! has_command chezmoi; then
    log_skip "chezmoi not installed"
    return 0
  fi

  local source_dir
  if ! source_dir="$(chezmoi source-path 2> /dev/null)"; then
    log_skip "chezmoi is not initialised"
    return 0
  fi

  if [[ ! -d "$source_dir" ]]; then
    log_skip "chezmoi source directory does not exist: ${source_dir}"
    return 0
  fi

  log_info "copying the chezmoi source directory"
  mkdir -p "${destination}/chezmoi-source"
  # tar keeps permissions and symlinks. --exclude prevents recursing into
  # nested repositories that are not part of the dotfiles.
  if tar -cf - -C "$source_dir" --exclude='.git' . 2> /dev/null | tar -xf - -C "${destination}/chezmoi-source"; then
    log_success "chezmoi source copied from ${source_dir}"
  else
    log_warn "could not copy the chezmoi source directory"
  fi

  # The config and persistent state are local machine state and are not in the
  # source directory, so they are copied explicitly.
  local config_dir
  # shellcheck disable=SC2154  # data_home() is defined in scripts/lib/common.sh
  config_dir="${data_home}/chezmoi"
  if [[ -d "$config_dir" ]]; then
    mkdir -p "${destination}/chezmoi-data"
    if tar -cf - -C "$config_dir" --exclude='.git' . 2> /dev/null | tar -xf - -C "${destination}/chezmoi-data"; then
      log_success "chezmoi data copied from ${config_dir}"
    else
      log_warn "could not copy the chezmoi data directory"
    fi
  fi
}

write_metadata() {
  local destination="$1"

  {
    printf 'created_at=%s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    printf 'hostname=%s\n' "$(hostname 2> /dev/null || printf 'unknown')"
    printf 'user=%s\n' "$(id -un 2> /dev/null || printf 'unknown')"
    printf 'os=%s\n' "${DETECTED_OS:-unknown}"
    printf 'distro=%s\n' "${DETECTED_DISTRO:-unknown}"
    printf 'repo=%s\n' "$REPO_ROOT"
    printf 'repo_commit=%s\n' "$(git -C "$REPO_ROOT" rev-parse HEAD 2> /dev/null || printf 'unknown')"
  } > "$destination/metadata.env"

  log_success "metadata written"
}

main() {
  detect_platform

  if is_true "$LIST_ONLY"; then
    list_backups
    return 0
  fi

  local backup_root
  backup_root="$(default_backup_root)"
  local destination="${OUTPUT_DIR:-${backup_root}/$(timestamp)}"

  log_step "Backup"
  log_line "destination: ${destination}"

  if [[ -e "$destination" ]]; then
    log_error "destination already exists: ${destination}"
    exit 1
  fi

  if ! confirm "Create the backup now?"; then
    log_skip "backup cancelled"
    return 0
  fi

  if is_true "$DRY_RUN"; then
    log_dryrun "mkdir -p ${destination}"
    log_dryrun "copy the chezmoi source and data"
    log_dryrun "write metadata.env and managed-files.txt"
    return 0
  fi

  mkdir -p "$destination"

  write_metadata "$destination"
  copy_chezmoi_state "$destination"
  write_manifest "$destination"

  cat > "${destination}/RESTORE.md" << 'EOF'
# Restore this backup

1. Move your current chezmoi source directory aside:

   mv "$(chezmoi source-path)" "$(chezmoi source-path).before-restore"

2. Copy the saved source back:

   cp -a ./chezmoi-source "$(chezmoi source-path)"

3. Restore the saved local state if needed (it contains the config file):

   cp -a ./chezmoi-data/* "$(printf '%s' "${XDG_DATA_HOME:-$HOME/.local/share}")/chezmoi/"

4. Review before applying:

   chezmoi diff

5. Apply:

   chezmoi apply

This backup contains configuration only. It never contains SSH keys, .env
files with real values, cloud credentials or AI provider tokens.
EOF

  log_success "backup complete: ${destination}"
  log_info "restore instructions: ${destination}/RESTORE.md"
  log_info "list all backups with: ./scripts/backup.sh --list"
}

main "$@"
