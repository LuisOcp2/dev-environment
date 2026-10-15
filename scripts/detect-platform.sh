#!/usr/bin/env bash
#
# detect-platform.sh - report the detected OS, distro, architecture and
# whether this repository supports it.
#
# Read only. Never installs anything. Safe to run on any machine.
#
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

usage() {
  cat << 'EOF'
Usage: ./scripts/detect-platform.sh [--quiet]

Print the detected operating system, distribution, architecture, home
directory and compatibility status.

Options:
  --quiet   print a single word: the detected distribution
  -h, --help  show this help
EOF
}

QUIET=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --quiet)
      QUIET=true
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

detect_platform

if is_true "$QUIET"; then
  printf '%s\n' "$DETECTED_DISTRO"
  exit 0
fi

print_banner "Platform detection"
print_platform_summary

log_section "Tool availability"
for tool in git gh curl wget jq shellcheck shfmt mise chezmoi docker code opencode zsh tmux starship direnv; do
  print_version "$tool"
done

log_section "XDG directories"
log_line "XDG_CONFIG_HOME : ${XDG_CONFIG_HOME:-<unset, defaults to ${HOME}/.config>}"
log_line "config home     : $(config_home)"
log_line "data home       : $(data_home)"
log_line "state home      : $(state_home)"
log_line "cache home      : $(cache_home)"

if is_supported_os; then
  log_success "this platform is supported"
  exit 0
fi

log_warn "this platform is not officially supported in v1"
log_info "supported: ${SUPPORTED_DISTROS// /, }"
exit 0
