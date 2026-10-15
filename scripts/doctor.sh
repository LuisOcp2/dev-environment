#!/usr/bin/env bash
#
# doctor.sh - diagnose the development environment.
#
# Read only by contract. It inspects PATH, versions, configuration files and
# known failure modes, and prints an actionable report. It never writes.
#
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=scripts/lib/packages.sh
source "${SCRIPT_DIR}/lib/packages.sh"

usage() {
  cat << 'EOF'
Usage: ./scripts/doctor.sh [options]

Diagnoses the development environment without modifying anything.

Options:
  --profile <name>   diagnose against a specific profile
  --json             print machine readable findings when possible
  -h, --help         show this help
EOF
}

PROFILE_NAME="${SELECTED_PROFILE:-fullstack}"

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
    --json)
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

diagnose_platform() {
  log_section "Platform"
  detect_platform
  print_platform_summary

  if is_wsl; then
    log_warn "running inside WSL"
    log_info "systemd support and file watching behave differently here"
  fi
}

diagnose_path() {
  log_section "PATH"

  local entry
  local count=0
  local -A seen=()

  local IFS_backup="${IFS}"
  IFS=':'
  # shellcheck disable=SC2206 # deliberate split on colons
  local -a path_entries=(${PATH})
  IFS="$IFS_backup"

  for entry in "${path_entries[@]}"; do
    [[ -z "$entry" ]] && continue
    count=$((count + 1))
    if [[ -n "${seen[$entry]:-}" ]]; then
      log_warn "duplicated PATH entry: ${entry}"
    fi
    seen["$entry"]=1
    if [[ ! -d "$entry" ]]; then
      log_warn "PATH entry does not exist: ${entry}"
    fi
  done

  log_line "entries: ${count}"
  log_line "user bin: $(user_bin_dir)"
  if [[ ":${PATH}:" != *":$(user_bin_dir):"* ]]; then
    log_warn "$(user_bin_dir) is not on PATH"
    log_line "fix: exec \$SHELL, or check ~/.profile"
  else
    log_success "$(user_bin_dir) is on PATH"
  fi
}

diagnose_xdg() {
  log_section "XDG directories"
  log_line "XDG_CONFIG_HOME : ${XDG_CONFIG_HOME:-<unset>}"
  log_line "config home     : $(config_home)"
  log_line "data home       : $(data_home)"
  log_line "state home      : $(state_home)"
  log_line "cache home      : $(cache_home)"

  local dir
  for dir in "$(config_home)" "$(data_home)" "$(state_home)" "$(cache_home)"; do
    if [[ -d "$dir" ]]; then
      log_success "exists: ${dir}"
    else
      log_info "not created yet: ${dir}"
    fi
  done
}

diagnose_tools() {
  log_section "Tool versions"
  for tool in git gh curl wget jq shellcheck shfmt mise chezmoi docker code opencode zsh bash tmux starship direnv node pnpm python3 uv java psql mysql redis-cli rg fd fzf bat; do
    print_version "$tool"
  done
}

diagnose_shell() {
  log_section "Shell configuration"

  log_line "login shell  : ${SHELL:-<unset>}"
  log_line "current shell: ${BASH_VERSION:+bash ${BASH_VERSION}}"

  local rc_file
  for rc_file in "${HOME}/.zshrc" "${HOME}/.bashrc" "${HOME}/.profile"; do
    if [[ -f "$rc_file" ]]; then
      log_success "found ${rc_file}"
    else
      log_warn "missing ${rc_file}; run 'make apply' to install the dotfiles"
    fi
  done

  if [[ -f "${HOME}/.zshrc" ]]; then
    local check
    for check in "starship init" "direnv hook" "mise activate" "shfmt"; do
      if grep -qF "$check" "${HOME}/.zshrc" 2> /dev/null; then
        log_success ".zshrc integrates '${check}'"
      else
        log_info ".zshrc does not mention '${check}'"
      fi
    done
  fi
}

diagnose_dotfiles() {
  log_section "chezmoi"

  if ! has_command chezmoi; then
    log_warn "chezmoi is not installed"
    return 0
  fi

  log_line "version: $(chezmoi --version 2>&1 | head -n 1)"

  if chezmoi source-path > /dev/null 2>&1; then
    local source_dir
    source_dir="$(chezmoi source-path 2> /dev/null || printf 'unknown')"
    log_success "source directory: ${source_dir}"
    if [[ "$source_dir" == "$REPO_ROOT" ]]; then
      log_success "source points at this repository (local checkout mode)"
    else
      log_info "source is not this repository; run 'chezmoi update' to refresh it"
    fi
  else
    log_warn "chezmoi is not initialised"
  fi

  log_section "chezmoi verify"
  local verify_output
  verify_output="$(chezmoi verify 2>&1 || true)"
  if [[ -z "$verify_output" ]]; then
    log_success "chezmoi verify reported no differences"
  else
    printf '%s\n' "$verify_output" | head -n 40 | sed 's/^/  /'
    log_warn "chezmoi verify reported differences; run 'chezmoi diff' for detail"
  fi
}

diagnose_mise() {
  log_section "mise"

  if ! has_command mise; then
    log_warn "mise is not installed"
    return 0
  fi

  log_line "version: $(mise --version 2>&1 | head -n 1)"

  local global_config="${MISE_GLOBAL_CONFIG:-$(config_home)/mise/config.toml}"
  if [[ -f "$global_config" ]]; then
    log_success "global config: ${global_config}"
  else
    log_warn "global config missing: ${global_config}"
  fi

  if is_true "$DRY_RUN"; then
    return 0
  fi

  local installed
  installed="$(mise ls --installed 2> /dev/null || true)"
  if [[ -n "$installed" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ -z "$line" ]] && continue
      log_line "installed: ${line}"
    done <<< "$installed"
  else
    log_warn "no tools installed through mise; run 'mise install'"
  fi
}

diagnose_opencode() {
  log_section "OpenCode"

  if ! has_command opencode; then
    log_warn "OpenCode is not installed"
    log_info "see https://opencode.ai/docs/ and docs/OPENCODE.md"
    return 0
  fi

  log_line "version: $(opencode --version 2>&1 | head -n 1)"

  if opencode debug paths > /dev/null 2>&1; then
    log_section "OpenCode paths"
    opencode debug paths 2>&1 | sed 's/^/  /'
  fi

  if opencode debug agents > /dev/null 2>&1; then
    log_section "OpenCode agents"
    opencode debug agents 2>&1 | head -n 60 | sed 's/^/  /'
  fi

  local skills_dir="${HOME}/.agents/skills"
  if [[ -d "$skills_dir" ]]; then
    local skill_count
    skill_count="$(find "$skills_dir" -mindepth 2 -maxdepth 2 -name SKILL.md 2> /dev/null | wc -l | tr -d ' ')"
    log_line "global skills found: ${skill_count} (${skills_dir})"
  else
    log_warn "global skills directory missing: ${skills_dir}"
  fi

  local config_root
  config_root="$(config_home)/opencode"
  local agents_dir="${config_root}/agents"
  local commands_dir="${config_root}/commands"

  [[ -d "$agents_dir" ]] && log_success "agents directory: ${agents_dir}" || log_warn "missing ${agents_dir}"
  [[ -d "$commands_dir" ]] && log_success "commands directory: ${commands_dir}" || log_warn "missing ${commands_dir}"
}

diagnose_profile() {
  log_section "Profile '${PROFILE_NAME}'"

  if ! profile_exists "$PROFILE_NAME"; then
    log_error "profile '${PROFILE_NAME}' does not exist"
    log_info "available: $(list_profiles | tr '\n' ' ')"
    return 0
  fi

  if resolve_profile "$PROFILE_NAME"; then
    print_profile_summary
  else
    log_error "profile '${PROFILE_NAME}' could not be resolved"
  fi
}

diagnose_repository() {
  log_section "Repository"

  log_line "root: ${REPO_ROOT}"

  if git -C "$REPO_ROOT" rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    log_success "git repository detected"
    log_line "branch: $(git -C "$REPO_ROOT" branch --show-current 2> /dev/null || printf 'unknown')"

    local dirty
    dirty="$(git -C "$REPO_ROOT" status --porcelain 2> /dev/null | wc -l | tr -d ' ')"
    if [[ "$dirty" -eq 0 ]]; then
      log_success "working tree is clean"
    else
      log_info "uncommitted changes: ${dirty}"
    fi
  else
    log_warn "${REPO_ROOT} is not a git repository"
  fi
}

main() {
  local defaults_file="${REPO_ROOT}/config/defaults.env"
  # shellcheck disable=SC1090 # runtime path
  [[ -f "$defaults_file" ]] && source "$defaults_file"

  SELECTED_PROFILE="$PROFILE_NAME"

  print_banner "Environment doctor"
  log_info "read only: this script never modifies the system"

  diagnose_repository
  diagnose_platform
  diagnose_path
  diagnose_xdg
  diagnose_tools
  diagnose_shell
  diagnose_dotfiles
  diagnose_mise
  diagnose_opencode
  diagnose_profile

  log_section "Next steps"
  log_line "re-run validation : make validate"
  log_line "preview dotfiles  : make diff"
  log_line "full verification : make verify"
}

main "$@"
