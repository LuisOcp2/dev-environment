#!/usr/bin/env bash
#
# install-chezmoi.sh - install chezmoi into the user bin directory.
#
# Idempotent: exits immediately when chezmoi is already on PATH.
# Never stores credentials and never runs `chezmoi apply`.
#
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

enable_error_trap

usage() {
  cat << 'EOF'
Usage: ./scripts/install-chezmoi.sh [options]

Installs chezmoi from https://get.chezmoi.io into ~/.local/bin.
Skips everything when chezmoi is already available.

Options:
  --dry-run   print what would happen and exit
  --force     reinstall even when chezmoi is already present
  --yes, -y   do not ask for confirmation
  -h, --help  show this help
EOF
}

FORCE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --force)
      FORCE=true
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

BIN_DIR="$(user_bin_dir)"

# download_installer fetches an installer into a temporary file so it is never
# piped straight into a shell, and never leaves anything behind on failure.
download_installer() {
  local url="$1"
  local destination="$2"

  if ! command -v curl > /dev/null 2>&1; then
    log_error "curl is required to download ${url}"
    return 1
  fi

  # --proto and --tlsv1.2 avoid downgrade attacks on the TLS connection.
  if ! curl --proto '=https' --tlsv1.2 -fsSL "$url" -o "$destination"; then
    log_error "failed to download ${url}"
    return 1
  fi

  if [[ ! -s "$destination" ]]; then
    log_error "downloaded an empty installer from ${url}"
    return 1
  fi

  return 0
}

main() {
  log_step "chezmoi installer"

  local defaults_file="${REPO_ROOT}/config/defaults.env"
  # shellcheck disable=SC1090 # runtime path
  [[ -f "$defaults_file" ]] && source "$defaults_file"

  if has_command chezmoi && ! is_true "$FORCE"; then
    log_skip "chezmoi is already installed: $(chezmoi --version 2> /dev/null | head -n 1)"
    return 0
  fi

  if ! is_true "$FORCE" && ! confirm "Install chezmoi into ${BIN_DIR}?"; then
    log_skip "chezmoi installation cancelled"
    return 0
  fi

  log_info "target directory: ${BIN_DIR}"
  ensure_dir "$BIN_DIR"

  local installer_url="${CHEZMOI_INSTALL_URL:-https://get.chezmoi.io}"
  local tmp_installer=""
  tmp_installer="$(mktemp "${TMPDIR:-/tmp}/chezmoi-install.XXXXXX")"
  # shellcheck disable=SC2064 # expand tmp_installer now, it is a literal path
  trap "rm -f '${tmp_installer}'" EXIT

  log_info "downloading ${installer_url}"
  if is_true "$DRY_RUN"; then
    log_dryrun "curl --proto '=https' --tlsv1.2 -fsSL ${installer_url} -o <tmp>"
    log_dryrun "sh ${tmp_installer} -- -b ${BIN_DIR}"
    rm -f "$tmp_installer"
    trap - EXIT
    return 0
  fi

  if ! download_installer "$installer_url" "$tmp_installer"; then
    rm -f "$tmp_installer"
    trap - EXIT
    return 1
  fi

  log_info "running the official installer"
  sh "$tmp_installer" -- -b "$BIN_DIR"

  rm -f "$tmp_installer"
  trap - EXIT

  if [[ -x "${BIN_DIR}/chezmoi" ]]; then
    log_success "chezmoi installed at ${BIN_DIR}/chezmoi"
  else
    log_warn "installer finished but ${BIN_DIR}/chezmoi was not created"
    log_info "check https://www.chezmoi.io/install/ for manual steps"
    return 1
  fi

  if [[ ":${PATH}:" != *":${BIN_DIR}:"* ]]; then
    log_warn "${BIN_DIR} is not on PATH in this shell"
    append_once "${HOME}/.profile" "export PATH=\"\${PATH}:${BIN_DIR}\""
  fi

  log_info "next step: ./scripts/apply-dotfiles.sh --dry-run"
}

main "$@"
