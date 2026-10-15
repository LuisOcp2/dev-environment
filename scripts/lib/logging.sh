#!/usr/bin/env bash
# shellcheck shell=bash
#
# logging.sh - leveled, color-aware logging helpers.
#
# Sourced by every entry point in scripts/. Do not execute directly.
#
# Levels: INFO, SUCCESS, WARNING, ERROR, SKIPPED, DRY-RUN, PLAN, SECTION
#
# Colors are disabled automatically when:
#   - stdout is not a TTY            (redirected output, CI logs)
#   - NO_COLOR is set (any value)    (https://no-color.org)
#   - TERM is unset or "dumb"
#
# Shellcheck directives:
#   SC2034 - log level variables are assigned conditionally on purpose.

# Guard against double sourcing.
if [[ -n "${DEV_ENV_LOGGING_LOADED:-}" ]]; then
  return 0
fi
DEV_ENV_LOGGING_LOADED=1

# --- Color setup -----------------------------------------------------------

LOG_USE_COLOR="false"

if [[ -z "${NO_COLOR+x}" ]] && [[ "${TERM:-dumb}" != "dumb" ]] && [[ -t 1 ]]; then
  LOG_USE_COLOR="true"
fi

if [[ "$LOG_USE_COLOR" == "true" ]]; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_DIM=$'\033[2m'
  C_RED=$'\033[0;31m'
  C_GREEN=$'\033[0;32m'
  C_YELLOW=$'\033[0;33m'
  C_BLUE=$'\033[0;34m'
  C_CYAN=$'\033[0;36m'
else
  C_RESET=""
  C_BOLD=""
  C_DIM=""
  C_RED=""
  C_GREEN=""
  C_YELLOW=""
  C_BLUE=""
  C_CYAN=""
fi

# --- Level helpers ---------------------------------------------------------

log_info() {
  printf '%s[INFO]%s %s\n' "$C_BLUE" "$C_RESET" "$*"
}

log_success() {
  printf '%s[SUCCESS]%s %s\n' "$C_GREEN" "$C_RESET" "$*"
}

log_warn() {
  printf '%s[WARNING]%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2
}

log_error() {
  printf '%s[ERROR]%s %s\n' "$C_RED" "$C_RESET" "$*" >&2
}

log_skip() {
  printf '%s[SKIPPED]%s %s\n' "$C_DIM" "$C_RESET" "$*"
}

log_dryrun() {
  printf '%s[DRY-RUN]%s %s\n' "$C_CYAN" "$C_RESET" "$*"
}

log_step() {
  printf '\n%s==> %s%s\n' "$C_BOLD" "$*" "$C_RESET"
}

log_section() {
  printf '\n%s--- %s ---%s\n' "$C_BOLD" "$*" "$C_RESET"
}

# Raw output used inside plan/table blocks (no level prefix).
log_line() {
  printf '  %s\n' "$*"
}

# --- Trap helper -----------------------------------------------------------

# enable_error_trap prints a readable message when a command fails under
# `set -Eeuo pipefail`. Called by entry points, never by libraries.
enable_error_trap() {
  trap 'on_error_exit $? $LINENO "$BASH_COMMAND"' ERR
}

on_error_exit() {
  local exit_code="$1"
  local line_no="$2"
  local command="$3"

  if [[ "$exit_code" -eq 0 ]]; then
    return 0
  fi

  log_error "Command failed (exit ${exit_code}) at ${BASH_SOURCE[1]:-?}:${line_no}"
  log_error "  command: ${command}"
  log_error "  Aborting. Fix the problem or re-run with --dry-run to preview."
  exit "$exit_code"
}
