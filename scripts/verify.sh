#!/usr/bin/env bash
#
# verify.sh - check that the development environment is actually usable.
#
# Read only. It never installs, updates or modifies anything, so it is safe to
# run at any time and from CI.
#
# Exit codes:
#   0  every check passed or was skipped
#   1  at least one required check failed
#
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=scripts/lib/packages.sh
source "${SCRIPT_DIR}/lib/packages.sh"

# A failing check must be reported, not abort the run. The error trap makes an
# unexpected failure visible instead of exiting silently.
enable_error_trap

usage() {
  cat << 'EOF'
Usage: ./scripts/verify.sh [options]

Verifies the development environment without modifying anything.

Options:
  --profile <name>   verify the expectations of a specific profile
  --strict           treat warnings as failures
  --quiet            print only the final verdict
  -h, --help         show this help
EOF
}

PROFILE_NAME="${SELECTED_PROFILE:-${DEFAULT_PROFILE:-fullstack}}"
STRICT=false
QUIET=false
FAILURES=0
WARNINGS=0
CHECKS=0

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
    --strict)
      STRICT=true
      shift
      ;;
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

if ! is_true "$QUIET"; then
  print_banner "Environment verification"
fi

section() {
  is_true "$QUIET" || log_section "$1"
}

pass() {
  CHECKS=$((CHECKS + 1))
  is_true "$QUIET" || log_success "$1"
}

warn_check() {
  CHECKS=$((CHECKS + 1))
  WARNINGS=$((WARNINGS + 1))
  is_true "$QUIET" || log_warn "$1"
}

fail() {
  CHECKS=$((CHECKS + 1))
  FAILURES=$((FAILURES + 1))
  is_true "$QUIET" || log_error "$1"
}

# require_tool <binary> <human description> [minimum version]
require_tool() {
  local binary="$1"
  local description="$2"
  local minimum="${3:-}"

  if ! has_command "$binary"; then
    fail "${description}: '${binary}' is not installed"
    return 1
  fi

  local version_line
  version_line="$("$binary" --version 2>&1 | head -n 1 || true)"
  pass "${description}: ${version_line:-installed}"

  if [[ -n "$minimum" ]]; then
    if ! version_at_least "$version_line" "$minimum"; then
      warn_check "${description}: '${binary}' should be >= ${minimum} (found: ${version_line})"
    fi
  fi

  return 0
}

# version_at_least <version string> <minimum> - best effort semver compare.
version_at_least() {
  local current="$1"
  local minimum="$2"

  local current_major current_minor current_patch
  local minimum_major minimum_minor minimum_patch

  if [[ "$current" =~ ([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
    current_major="${BASH_REMATCH[1]}"
    current_minor="${BASH_REMATCH[2]}"
    current_patch="${BASH_REMATCH[3]}"
  elif [[ "$current" =~ ([0-9]+)\.([0-9]+) ]]; then
    current_major="${BASH_REMATCH[1]}"
    current_minor="${BASH_REMATCH[2]}"
    current_patch=0
  else
    return 0 # cannot parse, do not fail the check
  fi

  minimum_major="${minimum%%.*}"
  minimum_minor="${minimum#*.}"
  minimum_minor="${minimum_minor%%.*}"
  minimum_patch="${minimum##*.}"

  if [[ "$current_major" -gt "$minimum_major" ]]; then return 0; fi
  if [[ "$current_major" -lt "$minimum_major" ]]; then return 1; fi
  if [[ "$current_minor" -gt "$minimum_minor" ]]; then return 0; fi
  if [[ "$current_minor" -lt "$minimum_minor" ]]; then return 1; fi
  if [[ "$current_patch" -ge "$minimum_patch" ]]; then return 0; fi
  return 1
}

# optional_tool <binary> <human description>
# Missing optional tooling degrades the experience but is not a failure.
optional_tool() {
  local binary="$1"
  local description="$2"

  if ! has_command "$binary"; then
    warn_check "${description}: '${binary}' is not installed"
    return 0
  fi

  pass "${description}: $("$binary" --version 2>&1 | head -n 1 || printf 'installed')"
}

check_platform() {
  section "Platform"
  detect_platform

  if is_supported_os; then
    pass "platform ${DETECTED_DISTRO} ${DETECTED_DISTRO_VERSION} is supported"
  else
    warn_check "platform ${DETECTED_OS}/${DETECTED_DISTRO} is not officially supported"
  fi

  [[ -n "${HOME}" ]] && pass "HOME is set (${HOME})" || fail "HOME is not set"
  [[ -w "${HOME}" ]] && pass "HOME is writable" || fail "HOME is not writable"
}

check_core_tools() {
  section "Core tools"

  local defaults_file="${REPO_ROOT}/config/defaults.env"
  # shellcheck disable=SC1090 # runtime path
  [[ -f "$defaults_file" ]] && source "$defaults_file"

  require_tool git "version control" "${MIN_GIT_VERSION:-}" || true
  require_tool curl "HTTP client" || true
  require_tool wget "HTTP client" || true
  require_tool jq "JSON processor" || true
  require_tool shellcheck "shell linter" || true
  require_tool unzip "archive helper" || true
  optional_tool rg "search (ripgrep)"
  optional_tool fd "search (fd)"
  optional_tool fzf "fuzzy finder"
  optional_tool bat "cat replacement"
  optional_tool tmux "terminal multiplexer"
}

check_shells() {
  section "Shells"

  if has_command zsh; then
    pass "zsh: $(zsh --version 2>&1 | head -n 1)"
  else
    warn_check "zsh is not installed; bash remains the default shell"
  fi

  if has_command bash; then
    pass "bash: ${BASH_VERSION}"
  else
    fail "bash is not installed"
  fi

  if [[ -f "${HOME}/.zshrc" ]]; then
    pass "${HOME}/.zshrc exists"
  else
    warn_check "${HOME}/.zshrc not found; run 'make apply' to install the dotfiles"
  fi

  if [[ -f "${HOME}/.bashrc" ]]; then
    pass "${HOME}/.bashrc exists"
  else
    warn_check "${HOME}/.bashrc not found"
  fi
}

check_chezmoi() {
  section "chezmoi"

  if ! has_command chezmoi; then
    warn_check "chezmoi is not installed; run 'make bootstrap'"
    return 0
  fi

  require_tool chezmoi "dotfile manager" "${MIN_CHEZMOI_VERSION:-}" || true

  if chezmoi source-path > /dev/null 2>&1; then
    pass "chezmoi source: $(chezmoi source-path 2> /dev/null || printf 'unknown')"
  else
    warn_check "chezmoi is installed but not initialised; run 'make apply'"
  fi

  if chezmoi doctor > /dev/null 2>&1; then
    pass "chezmoi doctor reported no problems"
  else
    warn_check "chezmoi doctor reported issues; run 'chezmoi doctor' for details"
  fi
}

check_mise() {
  section "mise"

  if ! has_command mise; then
    warn_check "mise is not installed; run './scripts/install-mise.sh'"
    return 0
  fi

  require_tool mise "version manager" "${MIN_MISE_VERSION:-}" || true

  local global_config="${MISE_GLOBAL_CONFIG:-$(config_home)/mise/config.toml}"
  if [[ -f "$global_config" ]]; then
    pass "global mise config: ${global_config}"
  else
    warn_check "global mise config missing: ${global_config}"
  fi

  if is_true "$DRY_RUN"; then
    return 0
  fi

  local installed
  installed="$(mise ls --installed 2> /dev/null || true)"
  if [[ -n "$installed" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ -z "$line" ]] && continue
      pass "mise tool: ${line}"
    done <<< "$installed"
  else
    warn_check "mise reports no installed tools; run 'mise install'"
  fi
}

check_profile_tools() {
  section "Profile '${PROFILE_NAME}'"

  if ! profile_exists "$PROFILE_NAME"; then
    fail "profile '${PROFILE_NAME}' does not exist"
    return 0
  fi

  if ! resolve_profile "$PROFILE_NAME"; then
    fail "profile '${PROFILE_NAME}' could not be resolved"
    return 0
  fi

  pass "manifests: ${PROFILE_PACKAGE_SETS}"
  pass "mise tools: ${PROFILE_MISE_TOOLS:-none}"
  pass "features: ${PROFILE_FEATURE_FLAGS:-none}"

  # Only check availability; installation belongs to install-system-packages.sh
  if is_true "$DRY_RUN"; then
    return 0
  fi

  local entry
  for entry in $(resolve_packages "$PROFILE_PACKAGE_SETS"); do
    local apt_name
    apt_name="$(resolve_package_name "$entry")"
    if package_is_installed "$apt_name"; then
      pass "package installed: ${entry}"
    else
      warn_check "package not installed: ${entry} (${apt_name})"
    fi
  done
}

check_docker() {
  section "Docker"

  if ! profile_flag_enabled "docker"; then
    is_true "$QUIET" || log_skip "Docker is not enabled for profile '${PROFILE_NAME}'"
    return 0
  fi

  if ! has_command docker; then
    fail "docker is not installed; run './scripts/install-docker.sh' or use --skip-docker"
    return 0
  fi

  pass "docker: $(docker --version 2>&1 | head -n 1)"

  if docker compose version > /dev/null 2>&1; then
    pass "docker compose: $(docker compose version 2>&1 | head -n 1)"
  else
    warn_check "the Docker Compose plugin is not available"
  fi

  if is_true "$DRY_RUN"; then
    return 0
  fi

  if docker info > /dev/null 2>&1; then
    pass "the Docker daemon is reachable"
  else
    warn_check "the Docker daemon is not reachable; start it or log in again"
  fi
}

check_editors() {
  section "Editors and AI tooling"

  if has_command code; then
    pass "VS Code: $(code --version 2>&1 | head -n 1)"
  else
    is_true "$QUIET" || log_skip "VS Code ('code') is not installed"
  fi

  if has_command opencode; then
    pass "OpenCode: $(opencode --version 2>&1 | head -n 1)"
  else
    warn_check "OpenCode is not installed; see https://opencode.ai/docs/"
  fi

  local opencode_root
  opencode_root="$(config_home)/opencode"
  local opencode_config="${opencode_root}/opencode.jsonc"
  if [[ -f "$opencode_config" ]]; then
    pass "OpenCode config: ${opencode_config}"
  else
    warn_check "OpenCode global config missing: ${opencode_config}"
  fi

  local skills_dir="${HOME}/.agents/skills"
  if [[ -d "$skills_dir" ]]; then
    local skill_count
    skill_count="$(find "$skills_dir" -mindepth 2 -maxdepth 2 -name SKILL.md 2> /dev/null | wc -l | tr -d ' ')"
    if [[ "$skill_count" -gt 0 ]]; then
      pass "global skills installed: ${skill_count} in ${skills_dir}"
    else
      warn_check "no SKILL.md found under ${skills_dir}"
    fi
  else
    warn_check "global skills directory missing: ${skills_dir}"
  fi
}

check_no_secrets_in_repo() {
  section "Repository hygiene"

  local tracked_secrets
  tracked_secrets="$(git -C "$REPO_ROOT" ls-files 2> /dev/null |
    grep -E '(^|/)(\.env($|\.)|[^/]*\.(pem|key|p12|pfx)$|id_rsa|id_ed25519|auth\.json)$' || true)"

  if [[ -z "$tracked_secrets" ]]; then
    pass "no secret-looking files are tracked in git"
  else
    fail "these files look like secrets and are tracked:"
    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ -z "$line" ]] && continue
      log_line "  ${line}"
    done <<< "$tracked_secrets"
  fi
}

final_verdict() {
  log_section "Result"
  log_line "checks   : ${CHECKS}"
  log_line "warnings : ${WARNINGS}"
  log_line "failures : ${FAILURES}"

  if [[ "$FAILURES" -gt 0 ]]; then
    log_error "verification FAILED"
    return 1
  fi

  if is_true "$STRICT" && [[ "$WARNINGS" -gt 0 ]]; then
    log_error "verification FAILED (--strict and warnings present)"
    return 1
  fi

  log_success "verification passed"
  return 0
}

main() {
  local defaults_file="${REPO_ROOT}/config/defaults.env"
  # shellcheck disable=SC1090 # runtime path
  [[ -f "$defaults_file" ]] && source "$defaults_file"

  SELECTED_PROFILE="$PROFILE_NAME"

  check_platform
  check_core_tools
  check_shells
  check_chezmoi
  check_mise
  check_profile_tools
  check_docker
  check_editors
  check_no_secrets_in_repo

  # A non-zero verdict is a normal outcome here, not an internal error. Drop
  # the ERR trap so the report is not followed by a misleading abort message.
  trap - ERR
  final_verdict
}

main "$@"
