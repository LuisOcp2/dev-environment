#!/usr/bin/env bash
#
# install-vscode-extensions.sh - install the extensions listed in
# config/vscode-extensions.txt through `code --install-extension`.
#
# Idempotent: already installed extensions are reported as SKIPPED and are not
# reinstalled. Runs unattended because extension installation is reversible and
# never modifies project files.
#
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

enable_error_trap

usage() {
  cat << 'EOF'
Usage: ./scripts/install-vscode-extensions.sh [options]

Installs every extension listed in config/vscode-extensions.txt.
Extensions already present are skipped.

Options:
  --list         print the extension list and exit
  --dry-run      print what would be installed and exit
  --yes, -y      do not ask for confirmation
  -h, --help     show this help
EOF
}

LIST_ONLY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --list)
      LIST_ONLY=true
      shift
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

EXTENSIONS_FILE="${REPO_ROOT}/config/vscode-extensions.txt"

read_extensions() {
  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    printf '%s\n' "$line"
  done < "$EXTENSIONS_FILE"
}

extension_is_installed() {
  local extension_id="$1"
  # `code --list-extensions` is the only reliable source of truth.
  code --list-extensions 2> /dev/null | grep -qxF "$extension_id"
}

main() {
  if [[ ! -f "$EXTENSIONS_FILE" ]]; then
    log_error "extension list not found: ${EXTENSIONS_FILE}"
    return 1
  fi

  if is_true "$LIST_ONLY"; then
    read_extensions
    return 0
  fi

  log_step "VS Code extensions"

  if ! has_command code; then
    log_warn "the 'code' command was not found"
    log_info "install Visual Studio Code, then run: make apply-vscode-extensions"
    return 0
  fi

  log_info "code: $(code --version 2> /dev/null | head -n 1)"

  local installed=0
  local skipped=0
  local failed=0
  local extension

  while IFS= read -r extension; do
    [[ -z "$extension" ]] && continue

    if extension_is_installed "$extension"; then
      skipped=$((skipped + 1))
      log_skip "${extension} is already installed"
      continue
    fi

    log_info "installing ${extension}"
    if is_true "$DRY_RUN"; then
      log_dryrun "code --install-extension ${extension} --force"
    elif code --install-extension "$extension"; then
      installed=$((installed + 1))
    else
      failed=$((failed + 1))
      log_warn "could not install ${extension} (unknown id or network error)"
    fi
  done < <(read_extensions)

  log_section "Result"
  log_line "installed : ${installed}"
  log_line "skipped   : ${skipped}"
  log_line "failed    : ${failed}"

  if [[ "$failed" -gt 0 ]]; then
    log_warn "some extensions could not be installed; fix them manually in VS Code"
  fi
}

main "$@"
