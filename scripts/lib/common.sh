#!/usr/bin/env bash
# shellcheck shell=bash
# The REPO_* and runtime state variables below are consumed by
# scripts/lib/packages.sh and by the entry points, which ShellCheck analyses as
# separate files.
# shellcheck disable=SC2034
#
# common.sh - shared runtime helpers for every script in scripts/.
#
# Sourced by every entry point. Do not execute directly.
#
# Responsibilities:
#   - locate the repository root from any script location
#   - XDG/HOME path resolution (never hardcoded machine paths)
#   - dry-run aware command execution
#   - interactive confirmation
#   - idempotent one-shot shell mutations
#
# Everything else lives in a dedicated library so that entry points stay thin.

# Guard against double sourcing.
if [[ -n "${DEV_ENV_COMMON_LOADED:-}" ]]; then
  return 0
fi
DEV_ENV_COMMON_LOADED=1

# Resolve and load sibling libraries relative to this file, not to $PWD.
_COMMON_LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/logging.sh
source "${_COMMON_LIB_DIR}/logging.sh"
# shellcheck source=scripts/lib/platform.sh
source "${_COMMON_LIB_DIR}/platform.sh"

# --- Repository layout -----------------------------------------------------

# REPO_ROOT: directory that contains bootstrap.sh, packages/, config/, scripts/.
# Works no matter which script is executed or from which working directory.
REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

# Standard subdirectories. Kept as variables so scripts never concatenate
# paths by hand. See the file level directive at the top of this file.
REPO_PACKAGES_DIR="${REPO_ROOT}/packages"
REPO_CONFIG_DIR="${REPO_ROOT}/config"
REPO_PROFILES_DIR="${REPO_CONFIG_DIR}/profiles"

# --- Runtime state ---------------------------------------------------------
#
# DRY_RUN is read by run/run_sudo/run_shell; ASSUME_YES is read by confirm;
# SELECTED_PROFILE is read by scripts/lib/packages.sh and by the installers.

# DRY_RUN=true means "print what would happen, change nothing".
DRY_RUN="${DRY_RUN:-false}"
# ASSUME_YES=true skips interactive confirmation.
ASSUME_YES="${ASSUME_YES:-false}"
# SELECTED_PROFILE is the active profile name.
SELECTED_PROFILE="${SELECTED_PROFILE:-fullstack}"

# --- User path resolution --------------------------------------------------

# config_home honours XDG_CONFIG_HOME and always ends without a trailing slash.
config_home() {
  printf '%s' "${XDG_CONFIG_HOME:-${HOME}/.config}"
}

# data_home honours XDG_DATA_HOME.
data_home() {
  printf '%s' "${XDG_DATA_HOME:-${HOME}/.local/share}"
}

# state_home honours XDG_STATE_HOME.
state_home() {
  printf '%s' "${XDG_STATE_HOME:-${HOME}/.local/state}"
}

# cache_home honours XDG_CACHE_HOME.
cache_home() {
  printf '%s' "${XDG_CACHE_HOME:-${HOME}/.cache}"
}

# user_bin_dir is where user-scoped binaries are installed.
user_bin_dir() {
  printf '%s' "${HOME}/.local/bin"
}

# ensure_dir creates a directory when missing. Dry-run aware.
ensure_dir() {
  local dir="$1"
  [[ -d "$dir" ]] && return 0

  if is_true "$DRY_RUN"; then
    log_dryrun "mkdir -p ${dir}"
    return 0
  fi

  mkdir -p "$dir"
}

# --- Boolean helpers -------------------------------------------------------

is_true() {
  case "${1,,}" in
    1 | true | yes | on) return 0 ;;
    *) return 1 ;;
  esac
}

is_false() {
  case "${1,,}" in
    0 | false | no | off) return 0 ;;
    *) return 1 ;;
  esac
}

# --- Command execution -----------------------------------------------------

# run executes a command, or only reports it when DRY_RUN is enabled.
# Usage: run git --version
#       run_sudo apt-get update
run() {
  if is_true "$DRY_RUN"; then
    log_dryrun "$(printf '%q ' "$@")"
    return 0
  fi
  "$@"
}

# run_sudo executes a command with root privileges, avoiding sudo when the
# current user is already root (common on WSL and in containers).
run_sudo() {
  if is_root; then
    run "$@"
    return
  fi

  if ! has_sudo; then
    log_error "Root privileges required but 'sudo' is not available."
    return 1
  fi

  if is_true "$DRY_RUN"; then
    log_dryrun "sudo $(printf '%q ' "$@")"
    return 0
  fi

  sudo "$@"
}

# run_shell executes a shell snippet with bash -c. Dry-run aware.
run_shell() {
  if is_true "$DRY_RUN"; then
    log_dryrun "bash -c $(printf '%q' "$1")"
    return 0
  fi
  bash -c "$1"
}

# --- Capability checks -----------------------------------------------------

# has_command -> 0 when a binary is on PATH.
has_command() {
  command -v "$1" > /dev/null 2>&1
}

# require_command dies with an actionable message when a binary is missing.
require_command() {
  local cmd_name="$1"
  local hint="${2:-}"

  if ! has_command "$cmd_name"; then
    log_error "Required command '${cmd_name}' was not found in PATH."
    [[ -n "$hint" ]] && log_info "${hint}"
    return 1
  fi
}

# print_version renders "<binary>: <first line of --version>" or a warning.
print_version() {
  local cmd_name="$1"

  if ! has_command "$cmd_name"; then
    log_skip "${cmd_name} is not installed"
    return 0
  fi

  local version_line
  version_line="$("$cmd_name" --version 2>&1 | head -n 1 || true)"
  [[ -z "$version_line" ]] && version_line="(version unavailable)"
  log_line "$(printf '%-12s %s' "$cmd_name" "$version_line")"
}

# --- Confirmation ----------------------------------------------------------

# confirm asks the user to approve an operation.
# Returns 0 on approval, 1 otherwise. Honors --yes and --dry-run.
confirm() {
  local prompt_text="$1"

  if is_true "$DRY_RUN"; then
    log_dryrun "would ask: ${prompt_text}"
    return 0
  fi

  if is_true "$ASSUME_YES"; then
    log_info "auto-approved (--yes): ${prompt_text}"
    return 0
  fi

  if [[ ! -t 0 ]]; then
    log_warn "Non-interactive session and --yes not provided: ${prompt_text}"
    return 1
  fi

  local answer=""
  printf '%s [y/N] ' "$prompt_text" >&2
  read -r answer || return 1

  case "${answer,,}" in
    y | yes) return 0 ;;
    *) return 1 ;;
  esac
}

# --- Idempotent shell mutations --------------------------------------------

# append_once adds a line to a file only when an equivalent line is absent.
# Prevents duplicated PATH entries across repeated bootstrap runs.
# Usage: append_once "$HOME/.profile" 'export PATH="$HOME/.local/bin:$PATH"'
append_once() {
  local target_file="$1"
  local line="$2"

  if [[ -f "$target_file" ]] && grep -qxF "$line" "$target_file" 2> /dev/null; then
    log_skip "already present in ${target_file}: ${line}"
    return 0
  fi

  if is_true "$DRY_RUN"; then
    log_dryrun "append to ${target_file}: ${line}"
    return 0
  fi

  ensure_dir "$(dirname "$target_file")"
  if [[ -f "$target_file" ]] && [[ -s "$target_file" ]] && [[ -n "$(tail -c 1 "$target_file")" ]]; then
    printf '\n' >> "$target_file"
  fi
  printf '%s\n' "$line" >> "$target_file"
  log_success "added to ${target_file}"
}

# set_shell_default switches the login shell only after explicit confirmation.
set_shell_default() {
  local target_shell="$1"

  if [[ "$(basename "$SHELL")" == "$target_shell" ]]; then
    log_skip "default shell is already ${target_shell}"
    return 0
  fi

  log_warn "Changing the default login shell requires an explicit confirmation."
  if ! confirm "Set ${target_shell} as the default login shell for $(id -un)?"; then
    log_skip "default shell left unchanged"
    return 0
  fi

  run_sudo chsh -s "$target_shell" "$(id -un)"
}

# --- Misc ------------------------------------------------------------------

# on_windows_git_bash detects Git Bash / MSYS so scripts can refuse politely
# instead of failing halfway through.
on_windows_git_bash() {
  case "$(uname -s 2> /dev/null || true)" in
    MINGW* | MSYS* | CYGWIN*) return 0 ;;
    *) return 1 ;;
  esac
}

# require_supported_platform dies unless the OS/distro pair is supported.
require_supported_platform() {
  if is_supported_os; then
    log_success "platform ${DETECTED_DISTRO} is supported"
    return 0
  fi

  log_error "Unsupported platform: ${DETECTED_OS}/${DETECTED_DISTRO}."
  log_info "Supported in v1: ${SUPPORTED_DISTROS// /, } (Ubuntu, TuxedoOS, Debian)."
  log_info "You may continue, but package installation is only implemented for apt-based systems."
  return 1
}

# repository_root_banner prints a consistent header for every entry point.
print_banner() {
  local title="$1"
  printf '%s==============================================%s\n' "$C_CYAN" "$C_RESET"
  printf '%s %s%s\n' "$C_BOLD" "$title" "$C_RESET"
  printf '%s dev-environment%s\n' "$C_CYAN" "$C_RESET"
  printf '%s==============================================%s\n' "$C_CYAN" "$C_RESET"
}
