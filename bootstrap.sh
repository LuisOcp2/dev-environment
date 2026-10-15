#!/usr/bin/env bash
#
# bootstrap.sh - single entry point to provision a development machine.
#
# Design contract:
#   - strict bash, no side effects at parse time
#   - every step is delegated to a script under scripts/
#   - --dry-run prints the whole plan and changes nothing
#   - running it twice is safe: each step checks for its own work first
#
set -Eeuo pipefail

# --- Bootstrap paths -------------------------------------------------------

BOOTSTRAP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${BOOTSTRAP_DIR}/scripts/lib/common.sh"
# shellcheck source=scripts/lib/packages.sh
source "${BOOTSTRAP_DIR}/scripts/lib/packages.sh"

enable_error_trap

# --- Options ---------------------------------------------------------------

SKIP_DOCKER=false
SKIP_VSCODE=false
SKIP_DOTFILES=false
PROFILE_NAME="${DEFAULT_PROFILE:-fullstack}"

usage() {
  cat << 'EOF'
Usage: ./bootstrap.sh [options]

Provision a development machine with the tools, dotfiles, versions, editors
and AI agent configuration defined by this repository.

Options:
  --profile <name>   Installation profile to apply (default: fullstack)
  --yes, -y          Assume yes for every confirmation; non interactive
  --dry-run          Print the full plan and exit without changing anything
  --skip-docker      Do not install or configure Docker
  --skip-vscode      Do not install VS Code extensions
  --skip-dotfiles    Do not apply chezmoi managed dotfiles
  --list-profiles    Print the available profiles and exit
  --help, -h         Show this help and exit

Available profiles:
  minimal   shell, git, search tooling, chezmoi and mise
  frontend  minimal + Node.js LTS, pnpm, TypeScript toolchain, VS Code
  backend   minimal + Node, Python, Java 21 and database clients
  fullstack frontend + backend + Docker + database clients (default)
  cloud     minimal + Docker, GitHub CLI and optional IaC tooling
  teaching  minimal + Java, Python, JavaScript and Markdown tooling

Examples:
  ./bootstrap.sh --dry-run
  ./bootstrap.sh --profile minimal --yes
  ./bootstrap.sh --profile fullstack --skip-docker
EOF
}

print_profiles_catalog() {
  print_banner "Available profiles"
  local profile
  for profile in $(list_profiles); do
    printf '  %-12s %s\n' "$profile" "$(profile_description "$profile")"
  done
}

# profile_description reads PROFILE_DESCRIPTION in a subshell so the profile
# variables never leak into the current scope.
profile_description() {
  local description=""
  # shellcheck disable=SC1090 # runtime path
  description="$(PROFILE_DESCRIPTION="" bash -c "source '$(profile_path "$1")' >/dev/null 2>&1; printf '%s' \"\${PROFILE_DESCRIPTION:-}\"")"
  printf '%s' "${description:-no description}"
}

parse_args() {
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
      --yes | -y)
        ASSUME_YES=true
        shift
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --skip-docker)
        SKIP_DOCKER=true
        shift
        ;;
      --skip-vscode)
        SKIP_VSCODE=true
        shift
        ;;
      --skip-dotfiles)
        SKIP_DOTFILES=true
        shift
        ;;
      --list-profiles)
        print_profiles_catalog
        exit 0
        ;;
      --help | -h)
        usage
        exit 0
        ;;
      *)
        log_error "Unknown option: $1"
        log_info "Run './bootstrap.sh --help' to see the supported options."
        exit 2
        ;;
    esac
  done
}

# --- Plan rendering --------------------------------------------------------

print_plan() {
  log_section "Installation plan"
  log_line "profile            : ${PROFILE_NAME}"
  log_line "packages           : ${PROFILE_PACKAGE_SETS}"
  log_line "mise tools         : ${PROFILE_MISE_TOOLS}"
  log_line "docker             : $(plan_flag "$DOCKER_ENABLED")"
  log_line "vscode extensions  : $(plan_flag "$VSCODE_ENABLED")"
  log_line "dotfiles (chezmoi) : $(plan_flag "$DOTFILES_ENABLED")"
  log_line "shell switch offer : $(plan_flag "$OFFER_ZSH_DEFAULT")"
  log_line "dry run            : $(plan_flag "$DRY_RUN")"

  log_section "Ordered steps"
  local index=1
  printf '  %d. detect platform and confirm compatibility\n' "$index"
  index=$((index + 1))
  printf '  %d. install system packages from packages/*.txt\n' "$index"
  index=$((index + 1))
  printf '  %d. install chezmoi\n' "$index"
  index=$((index + 1))
  printf '  %d. install mise and the declared tool versions\n' "$index"
  index=$((index + 1))
  if is_true "$DOCKER_ENABLED"; then
    printf '  %d. install Docker from the official apt repository\n' "$index"
    index=$((index + 1))
  fi
  if is_true "$VSCODE_ENABLED"; then
    printf '  %d. install VS Code extensions from config/vscode-extensions.txt\n' "$index"
    index=$((index + 1))
  fi
  if is_true "$DOTFILES_ENABLED"; then
    printf '  %d. show the chezmoi diff and apply the dotfiles after confirmation\n' "$index"
    index=$((index + 1))
  fi
  printf '  %d. run scripts/verify.sh\n' "$index"
  index=$((index + 1))
  printf '  %d. print the final summary\n' "$index"
}

plan_flag() {
  if is_true "$1"; then printf 'yes'; else printf 'no'; fi
}

print_summary() {
  log_section "Summary"

  log_line "repository         : ${REPO_ROOT}"
  log_line "profile            : ${PROFILE_NAME}"
  log_line "packages installed : ${PACKAGES_INSTALLED_COUNT:-not reported}"
  log_line "packages missing   : ${PACKAGES_MISSING_COUNT:-not reported}"
  log_line "optional skipped   : ${PACKAGES_OPTIONAL_SKIPPED_COUNT:-not reported}"
  log_line "chezmoi            : $(status_word "$CHEZMOI_STATUS")"
  log_line "mise               : $(status_word "$MISE_STATUS")"
  log_line "docker             : $(status_word "$DOCKER_STATUS")"
  log_line "dotfiles           : $(status_word "$DOTFILES_STATUS")"

  log_section "Next steps"
  log_line "Start a new shell   : exec \$SHELL"
  log_line "Review the diff     : chezmoi diff"
  log_line "Re-apply dotfiles   : chezmoi update && chezmoi apply"
  log_line "Verify later        : make verify"
  log_line "Add a new tool      : see docs/ADDING-CONFIGURATION.md"

  if is_true "$DRY_RUN"; then
    log_warn "This was a dry run. Nothing on the machine was modified."
  fi
}

status_word() {
  case "${1:-skipped}" in
    installed) printf 'installed' ;;
    configured) printf 'configured' ;;
    skipped) printf 'skipped' ;;
    failed) printf 'FAILED' ;;
    *) printf '%s' "${1:-unknown}" ;;
  esac
}

# --- Steps -----------------------------------------------------------------

step_detect() {
  log_step "1. Detecting platform"
  detect_platform
  print_platform_summary

  if ! require_supported_platform; then
    if is_true "$DRY_RUN"; then
      log_warn "unsupported platform: continuing in dry-run to show the plan"
    else
      return 1
    fi
  else
    log_success "detection finished"
  fi
}

step_packages() {
  log_step "2. Installing system packages"

  # Reset the counters reported in the summary.
  PACKAGES_INSTALLED_COUNT=0
  PACKAGES_MISSING_COUNT=0
  PACKAGES_OPTIONAL_SKIPPED_COUNT=0

  if ! is_true "$PACKAGES_ENABLED"; then
    log_skip "system package installation disabled"
    return 0
  fi

  local script="${REPO_ROOT}/scripts/install-system-packages.sh"
  if [[ ! -x "$script" ]]; then
    log_warn "script is missing or not executable: ${script}"
    return 0
  fi

  if run "$script" --profile "$PROFILE_NAME"; then
    log_success "system packages ready"
  else
    log_error "system package installation reported problems"
  fi

  # The installer persists its counters so this process can report them.
  load_install_counters
}

# load_install_counters reads the state file written by
# scripts/install-system-packages.sh. Missing state is not an error.
load_install_counters() {
  local state_file
  state_file="$(cache_home)/dev-environment/install-state.env"

  [[ -f "$state_file" ]] || return 0

  local key value
  while IFS='=' read -r key value; do
    case "$key" in
      PACKAGES_INSTALLED_COUNT) PACKAGES_INSTALLED_COUNT="$value" ;;
      PACKAGES_MISSING_COUNT) PACKAGES_MISSING_COUNT="$value" ;;
      PACKAGES_OPTIONAL_SKIPPED_COUNT) PACKAGES_OPTIONAL_SKIPPED_COUNT="$value" ;;
    esac
  done < "$state_file"
}

step_chezmoi() {
  log_step "3. Installing chezmoi"
  CHEZMOI_STATUS="skipped"

  local script="${REPO_ROOT}/scripts/install-chezmoi.sh"
  if ! run "$script"; then
    log_warn "chezmoi installation did not complete"
    return 0
  fi

  if has_command chezmoi; then
    CHEZMOI_STATUS="installed"
    log_success "chezmoi is available: $(chezmoi --version 2> /dev/null | head -n 1)"
  else
    log_warn "chezmoi is still not on PATH"
  fi
}

step_mise() {
  log_step "4. Installing mise and declared versions"
  MISE_STATUS="skipped"

  local script="${REPO_ROOT}/scripts/install-mise.sh"
  if ! run "$script" --profile "$PROFILE_NAME"; then
    log_warn "mise installation did not complete"
    return 0
  fi

  if has_command mise; then
    MISE_STATUS="installed"
  else
    log_warn "mise is still not on PATH"
  fi
}

step_docker() {
  DOCKER_STATUS="skipped"

  if ! is_true "$DOCKER_ENABLED"; then
    log_step "5. Docker"
    log_skip "Docker is not enabled for this run"
    return 0
  fi

  log_step "5. Installing Docker"
  local script="${REPO_ROOT}/scripts/install-docker.sh"
  if run "$script"; then
    DOCKER_STATUS="installed"
  else
    DOCKER_STATUS="failed"
  fi
}

step_vscode() {
  if ! is_true "$VSCODE_ENABLED"; then
    log_skip "VS Code extension installation disabled"
    return 0
  fi

  log_step "6. Installing VS Code extensions"
  local script="${REPO_ROOT}/scripts/install-vscode-extensions.sh"
  if ! run "$script"; then
    log_warn "VS Code extension installation did not complete"
  fi
}

step_dotfiles() {
  DOTFILES_STATUS="skipped"

  if ! is_true "$DOTFILES_ENABLED"; then
    log_step "7. Dotfiles"
    log_skip "dotfile application disabled for this run"
    return 0
  fi

  log_step "7. Preparing dotfiles"
  local script="${REPO_ROOT}/scripts/apply-dotfiles.sh"
  if run "$script" --profile "$PROFILE_NAME"; then
    DOTFILES_STATUS="configured"
  else
    DOTFILES_STATUS="failed"
  fi
}

step_verify() {
  log_step "8. Verifying the environment"
  local script="${REPO_ROOT}/scripts/verify.sh"
  if ! run "$script"; then
    log_warn "verification reported issues, see the output above"
    return 0
  fi
  log_success "verification finished"
}

# --- Main ------------------------------------------------------------------

main() {
  parse_args "$@"

  print_banner "dev-environment bootstrap"

  # Git Bash on Windows is not a target this repository manages. A dry run is
  # still useful there: it shows the plan and validates the scripts themselves,
  # so the refusal is only raised when something would actually be installed.
  UNSUPPORTED_HOST=false
  if on_windows_git_bash; then
    if is_true "$DRY_RUN"; then
      UNSUPPORTED_HOST=true
      log_warn "Git Bash on Windows is not a supported target."
      log_info "Continuing in dry-run mode: the plan is printed, nothing is installed."
    else
      log_error "Git Bash on Windows is not a supported target for this repository."
      log_info "This system manages a Linux workstation. Use WSL2 Ubuntu or TuxedoOS."
      log_info "Inspect the plan first with: ./bootstrap.sh --dry-run"
      exit 1
    fi
  fi

  # Defaults first: they may define PROFILE_* values used below.
  local defaults_file="${REPO_ROOT}/config/defaults.env"
  if [[ -f "$defaults_file" ]]; then
    # shellcheck disable=SC1090 # runtime path
    source "$defaults_file"
  else
    log_error "Missing configuration file: ${defaults_file}"
    exit 1
  fi

  SELECTED_PROFILE="$PROFILE_NAME"
  export SELECTED_PROFILE DRY_RUN ASSUME_YES

  if ! profile_exists "$PROFILE_NAME"; then
    log_error "Unknown profile '${PROFILE_NAME}'."
    log_info "Available profiles: $(list_profiles | tr '\n' ' ')"
    log_info "Run './bootstrap.sh --list-profiles' for details."
    exit 2
  fi

  step_detect

  if ! resolve_profile "$PROFILE_NAME"; then
    log_error "Could not resolve profile '${PROFILE_NAME}'."
    exit 1
  fi

  # Feature flags: profile defaults, overridden by explicit CLI switches.
  PACKAGES_ENABLED=true
  DOCKER_ENABLED=false
  VSCODE_ENABLED=false
  # Dotfiles are useful for every profile, not only the ones needing Docker.
  DOTFILES_ENABLED=true

  if profile_flag_enabled "docker"; then
    DOCKER_ENABLED=true
  fi
  if profile_flag_enabled "vscode"; then
    VSCODE_ENABLED=true
  fi

  if is_true "$SKIP_DOCKER"; then
    DOCKER_ENABLED=false
    log_info "Docker disabled by --skip-docker"
  fi
  if is_true "$SKIP_VSCODE"; then
    VSCODE_ENABLED=false
    log_info "VS Code disabled by --skip-vscode"
  fi
  if is_true "$SKIP_DOTFILES"; then
    DOTFILES_ENABLED=false
    log_info "Dotfiles disabled by --skip-dotfiles"
  fi

  if is_true "$DRY_RUN"; then
    ASSUME_YES=true
  fi

  # On an unsupported host, a dry run stops after printing the plan: the
  # installers cannot be previewed meaningfully without the target package
  # manager, and pretending otherwise would be misleading.
  if is_true "$UNSUPPORTED_HOST" && is_true "$DRY_RUN"; then
    print_plan
    log_section "Resolved profile"
    print_profile_summary
    log_section "Dry run"
    log_line "The plan above is the real plan for a supported Linux host."
    log_line "Installation steps were not executed: this host has no apt-based package manager."
    log_warn "Nothing on this machine was modified."
    return 0
  fi

  print_plan

  log_section "Resolved profile"
  print_profile_summary

  if ! is_true "$DRY_RUN"; then
    if ! confirm "Proceed with this installation plan?"; then
      log_info "Aborted by the user. Nothing was changed."
      exit 0
    fi
  fi

  step_packages
  step_chezmoi
  step_mise
  step_docker
  step_vscode
  step_dotfiles
  step_verify

  print_summary
  log_success "bootstrap finished"
}

main "$@"
