#!/usr/bin/env bash
# shellcheck shell=bash
#
# platform.sh - operating system, distribution and privilege detection.
#
# Sourced by every entry point in scripts/. Do not execute directly.
#
# Design note: this layer only *detects*. It never installs anything.
# Adding a new platform means adding a detector here and a case in
# install-system-packages.sh, nothing else.

# Guard against double sourcing.
if [[ -n "${DEV_ENV_PLATFORM_LOADED:-}" ]]; then
  return 0
fi
DEV_ENV_PLATFORM_LOADED=1

# Populated by detect_platform().
DETECTED_OS=""          # linux | macos | windows | unknown
DETECTED_DISTRO=""      # ubuntu | tuxedo | debian | fedora | arch | ... | unknown
DETECTED_DISTRO_VERSION=""
DETECTED_DISTRO_ID=""   # /etc/os-release ID
DETECTED_DISTRO_LIKE="" # /etc/os-release ID_LIKE
DETECTED_ARCH=""        # x86_64 | aarch64 | ...
DETECTED_KERNEL=""
DETECTED_WSL="false"

# Distributions this repository is known to support in v1.
SUPPORTED_DISTROS="ubuntu tuxedo debian"

detect_platform() {
  DETECTED_KERNEL="$(uname -s 2> /dev/null || printf 'unknown')"
  DETECTED_ARCH="$(uname -m 2> /dev/null || printf 'unknown')"

  case "$DETECTED_KERNEL" in
    Linux*)
      DETECTED_OS="linux"
      ;;
    Darwin*)
      DETECTED_OS="macos"
      ;;
    MINGW* | MSYS* | CYGWIN* | Windows_NT)
      DETECTED_OS="windows"
      ;;
    *)
      DETECTED_OS="unknown"
      ;;
  esac

  if [[ "$DETECTED_OS" == "linux" ]]; then
    detect_wsl
    detect_linux_distro
  else
    DETECTED_DISTRO="unknown"
  fi
}

detect_wsl() {
  if [[ -n "${WSL_DISTRO_NAME:-}" ]] || [[ -r /proc/version ]] && grep -qiE 'microsoft|wsl' /proc/version 2> /dev/null; then
    DETECTED_WSL="true"
  fi
}

detect_linux_distro() {
  if [[ ! -r /etc/os-release ]]; then
    DETECTED_DISTRO="unknown"
    return 0
  fi

  # shellcheck disable=SC1091 # system file, may be absent on non-Linux
  DETECTED_DISTRO_ID="$(. /etc/os-release 2> /dev/null && printf '%s' "${ID:-}")"
  DETECTED_DISTRO_LIKE="$(. /etc/os-release 2> /dev/null && printf '%s' "${ID_LIKE:-}")"
  DETECTED_DISTRO_VERSION="$(. /etc/os-release 2> /dev/null && printf '%s' "${VERSION_ID:-}")"

  case "$DETECTED_DISTRO_ID" in
    tuxedo)
      DETECTED_DISTRO="tuxedo"
      ;;
    ubuntu)
      DETECTED_DISTRO="ubuntu"
      ;;
    debian)
      DETECTED_DISTRO="debian"
      ;;
    fedora)
      DETECTED_DISTRO="fedora"
      ;;
    arch | archlinux | manjaro)
      DETECTED_DISTRO="arch"
      ;;
    *)
      DETECTED_DISTRO="unknown"
      ;;
  esac
}

# is_supported_os -> 0 when the current OS/distro combination is supported.
is_supported_os() {
  [[ "$DETECTED_OS" == "linux" ]] || return 1

  local supported
  for supported in $SUPPORTED_DISTROS; do
    [[ "$DETECTED_DISTRO" == "$supported" ]] && return 0
  done

  return 1
}

# is_root -> 0 when the current effective user is uid 0.
is_root() {
  [[ "$(id -u 2> /dev/null || printf '1000')" -eq 0 ]]
}

# needs_sudo -> 0 when privileged commands must be escalated.
# On WSL the user is frequently root already, which avoids a password prompt.
needs_sudo() {
  if is_root; then
    return 1
  fi
  return 0
}

# has_sudo -> 0 when a usable sudo binary is on PATH.
has_sudo() {
  command -v sudo > /dev/null 2>&1
}

# require_root_or_sudo dies when neither root nor sudo is available.
require_root_or_sudo() {
  if is_root; then
    return 0
  fi
  if has_sudo; then
    return 0
  fi
  log_error "This operation needs root privileges and 'sudo' is not available."
  return 1
}

# is_wsl -> 0 when running inside Windows Subsystem for Linux.
is_wsl() {
  [[ "$DETECTED_WSL" == "true" ]]
}

# print_platform_summary renders a human readable detection block.
print_platform_summary() {
  log_line "os            : ${DETECTED_OS}"
  log_line "distro        : ${DETECTED_DISTRO} ${DETECTED_DISTRO_VERSION}"
  log_line "distro_id     : ${DETECTED_DISTRO_ID}"
  log_line "distro_like   : ${DETECTED_DISTRO_LIKE:-n/a}"
  log_line "arch          : ${DETECTED_ARCH}"
  log_line "kernel        : ${DETECTED_KERNEL}"
  log_line "home          : ${HOME:-n/a}"
  log_line "wsl           : ${DETECTED_WSL}"

  if is_supported_os; then
    log_line "compatibility : supported"
  else
    log_line "compatibility : NOT officially supported in v1"
  fi
}
