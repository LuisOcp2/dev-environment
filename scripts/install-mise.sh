#!/usr/bin/env bash
#
# install-mise.sh - install mise and the tool versions declared by a profile.
#
# Idempotent: exits early when mise already exists, and `mise install` is a
# no-op when the requested versions are already present.
#
# The global tool list lives in home/dot_config/mise/config.toml and is applied
# by chezmoi. This script only installs the interpreter for the current machine
# and then asks mise to install whatever that config declares.
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
Usage: ./scripts/install-mise.sh [options]

Installs mise into ~/.local/bin and installs the tool versions declared by
home/dot_config/mise/config.toml (managed by chezmoi).

Options:
  --profile <name>   profile whose declared mise tools should be installed
  --dry-run          print what would happen and exit
  --skip-versions    install mise but do not run `mise install`
  --force            reinstall mise even when it is already present
  --yes, -y          do not ask for confirmation
  -h, --help         show this help
EOF
}

PROFILE_NAME="${SELECTED_PROFILE:-${DEFAULT_PROFILE:-fullstack}}"
SKIP_VERSIONS=false
FORCE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      [[ $# -ge 2 ]] || {
        log_error "--profile requires a value."
        exit 2
      }
      PROFILE_NAME="$2"
      shift 2
      ;;
    --profile=*)
      PROFILE_NAME="${1#*=}"
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --skip-versions)
      SKIP_VERSIONS=true
      shift
      ;;
    --force)
      FORCE=true
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

BIN_DIR="$(user_bin_dir)"

install_mise_binary() {
  local installer_url="$1"
  local tmp_installer
  tmp_installer="$(mktemp "${TMPDIR:-/tmp}/mise-install.XXXXXX")"

  log_info "downloading ${installer_url}"
  if ! curl --proto '=https' --tlsv1.2 -fsSL "$installer_url" -o "$tmp_installer"; then
    log_error "failed to download ${installer_url}"
    rm -f "$tmp_installer"
    return 1
  fi

  if [[ ! -s "$tmp_installer" ]]; then
    log_error "downloaded an empty installer from ${installer_url}"
    rm -f "$tmp_installer"
    return 1
  fi

  log_info "running the official installer"
  # MISE_INSTALL_PATH controls where the binary lands; no profile is modified.
  if ! env MISE_INSTALL_PATH="$BIN_DIR" sh "$tmp_installer"; then
    log_error "the mise installer failed"
    rm -f "$tmp_installer"
    return 1
  fi

  rm -f "$tmp_installer"
  return 0
}

# activate_mise makes mise available in the current process so the version
# installation step does not depend on the user's shell being reloaded.
activate_mise() {
  export PATH="${BIN_DIR}:${PATH}"
  if ! has_command mise && [[ -x "${BIN_DIR}/mise" ]]; then
    log_warn "mise was installed but is not on PATH"
    return 1
  fi
  return 0
}

install_declared_versions() {
  log_step "Installing declared tool versions"

  local global_config="${MISE_GLOBAL_CONFIG:-$(config_home)/mise/config.toml}"

  if [[ ! -f "$global_config" ]]; then
    log_warn "global mise config not found yet: ${global_config}"
    log_info "apply the dotfiles first: ./scripts/apply-dotfiles.sh"
    log_info "declared profile tools: ${PROFILE_MISE_TOOLS}"
    return 0
  fi

  log_info "config: ${global_config}"
  run mise ls
  run mise install

  log_success "mise finished installing the declared versions"
}

main() {
  log_step "mise installer"

  local defaults_file="${REPO_ROOT}/config/defaults.env"
  # shellcheck disable=SC1090 # runtime path
  [[ -f "$defaults_file" ]] && source "$defaults_file"

  SELECTED_PROFILE="$PROFILE_NAME"
  export SELECTED_PROFILE DRY_RUN ASSUME_YES

  if resolve_profile "$PROFILE_NAME"; then
    log_info "profile '${PROFILE_NAME}' declares these mise tools: ${PROFILE_MISE_TOOLS:-none}"
  else
    log_warn "could not resolve profile '${PROFILE_NAME}', continuing with the global config only"
  fi

  if has_command mise && ! is_true "$FORCE"; then
    log_skip "mise is already installed: $(mise --version 2> /dev/null | head -n 1)"
  else
    if ! is_true "$FORCE" && ! confirm "Install mise into ${BIN_DIR}?"; then
      log_skip "mise installation cancelled"
      return 0
    fi

    ensure_dir "$BIN_DIR"

    if is_true "$DRY_RUN"; then
      log_dryrun "curl --proto '=https' --tlsv1.2 -fsSL ${MISE_INSTALL_URL:-https://mise.run} -o <tmp>"
      log_dryrun "MISE_INSTALL_PATH=${BIN_DIR} sh <tmp>"
    else
      require_command curl "curl is required to install mise." || return 1
      if ! install_mise_binary "${MISE_INSTALL_URL:-https://mise.run}"; then
        return 1
      fi
      log_success "mise installed at ${BIN_DIR}/mise"
    fi
  fi

  if [[ ":${PATH}:" != *":${BIN_DIR}:"* ]] && ! is_true "$DRY_RUN"; then
    append_once "${HOME}/.profile" "export PATH=\"\${PATH}:${BIN_DIR}\""
  fi

  activate_mise || true

  if is_true "$SKIP_VERSIONS"; then
    log_skip "tool version installation disabled (--skip-versions)"
    return 0
  fi

  if is_true "$DRY_RUN"; then
    log_step "Installing declared tool versions (dry run)"
    log_dryrun "mise ls"
    log_dryrun "mise install"
    return 0
  fi

  if has_command mise; then
    install_declared_versions
  else
    log_warn "mise is unavailable, skipping version installation"
  fi
}

main "$@"
