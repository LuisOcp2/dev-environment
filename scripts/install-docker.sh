#!/usr/bin/env bash
#
# install-docker.sh - install Docker Engine and the Compose plugin.
#
# Uses the official convenience script only when the Docker apt repository is
# not configured yet. This script is opt-in: bootstrap.sh calls it only when
# the resolved profile enables the "docker" flag or --skip-docker was not used.
#
# It never removes containers, images or volumes.
#
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

enable_error_trap

usage() {
  cat << 'EOF'
Usage: ./scripts/install-docker.sh [options]

Installs Docker Engine, the Docker Compose plugin and the official CLI
completion from https://download.docker.com/linux/ubuntu.

Options:
  --dry-run   print what would happen and exit
  --force     run the installer even when Docker is already present
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

DOCKER_KEYRING_DIR="/etc/apt/keyrings"
DOCKER_LIST_FILE="/etc/apt/sources.list.d/docker.list"
# Debian code name used by the official Docker repository. TuxedoOS and Ubuntu
# both follow the Ubuntu codename. Resolved lazily, so the script still parses
# on a machine without /etc/os-release, and overridable with DOCKER_SUITE.
resolve_docker_suite() {
  if [[ -n "${DOCKER_SUITE:-}" ]]; then
    printf '%s' "$DOCKER_SUITE"
    return 0
  fi

  local codename=""
  if [[ -r /etc/os-release ]]; then
    codename="$(. /etc/os-release 2> /dev/null && printf '%s' "${VERSION_CODENAME:-}")" || codename=""
  fi

  printf '%s' "${codename:-noble}"
}

docker_repo_configured() {
  [[ -f "$DOCKER_LIST_FILE" ]]
}

add_user_to_docker_group() {
  local current_user group_name

  current_user="$(id -un)"
  group_name="docker"

  if ! getent group "$group_name" > /dev/null 2>&1; then
    log_skip "group '${group_name}' does not exist, skipping group membership"
    return 0
  fi

  if id -nG "$current_user" 2> /dev/null | tr ' ' '\n' | grep -qx "$group_name"; then
    log_skip "user '${current_user}' is already a member of '${group_name}'"
    return 0
  fi

  log_warn "adding '${current_user}' to the '${group_name}' group grants root equivalent access"
  if ! confirm "Add ${current_user} to the ${group_name} group?"; then
    log_skip "group membership unchanged; use rootless Docker or sudo when needed"
    return 0
  fi

  if is_true "$DRY_RUN"; then
    log_dryrun "usermod -aG ${group_name} ${current_user}"
    return 0
  fi

  run_sudo usermod -aG "$group_name" "$current_user"
  log_success "user added. Log out and back in, or run 'newgrp ${group_name}', before using docker."
}

verify_docker() {
  log_step "Verifying Docker"

  if ! has_command docker; then
    log_warn "docker is not on PATH in this shell"
    return 0
  fi

  print_version docker
  print_version "docker compose"

  if is_true "$DRY_RUN"; then
    return 0
  fi

  if docker info > /dev/null 2>&1; then
    log_success "the Docker daemon is reachable"
  else
    log_warn "the Docker daemon is not reachable yet"
    log_info "start it with: sudo systemctl enable --now docker"
    log_info "or log out and back in if you were just added to the docker group"
  fi
}

main() {
  log_step "Docker installer"

  local defaults_file="${REPO_ROOT}/config/defaults.env"
  # shellcheck disable=SC1090 # runtime path
  [[ -f "$defaults_file" ]] && source "$defaults_file"

  if ! is_root && ! has_sudo; then
    log_error "Docker installation needs root privileges and 'sudo' is not available."
    return 1
  fi

  if has_command docker && ! is_true "$FORCE"; then
    log_skip "docker is already installed: $(docker --version 2> /dev/null | head -n 1)"
    verify_docker
    add_user_to_docker_group
    return 0
  fi

  if ! is_true "$FORCE" && ! confirm "Install Docker Engine and the Compose plugin?"; then
    log_skip "Docker installation cancelled"
    return 0
  fi

  local install_url="${DOCKER_INSTALL_URL:-https://get.docker.com}"

  if is_true "$DRY_RUN"; then
    log_dryrun "curl --proto '=https' --tlsv1.2 -fsSL ${install_url} -o <tmp>"
    log_dryrun "sudo sh <tmp>"
    log_dryrun "create ${DOCKER_KEYRING_DIR}/docker.gpg from https://download.docker.com/linux/ubuntu/gpg"
    log_dryrun "write ${DOCKER_LIST_FILE} from https://download.docker.com/linux/ubuntu/$(resolve_docker_suite)/nodistro.list"
    log_dryrun "apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
    log_dryrun "usermod -aG docker $(id -un)"
    return 0
  fi

  require_command curl "curl is required to install Docker." || return 1

  # Pass SHELL so the official script does not refuse on systems where sudo is
  # available but bash is the shell. Never forward secrets.
  log_info "running the official convenience script from ${install_url}"
  curl --proto '=https' --tlsv1.2 -fsSL "$install_url" -o "${TMPDIR:-/tmp}/get-docker.sh"
  log_warn "reviewing the installer is recommended on a new machine"
  run_sudo sh "${TMPDIR:-/tmp}/get-docker.sh"
  rm -f "${TMPDIR:-/tmp}/get-docker.sh"

  log_info "repository configuration: ${DOCKER_LIST_FILE}"
  if docker_repo_configured; then
    log_skip "the Docker apt repository is already configured"
  else
    log_info "added by the installer"
  fi

  verify_docker
  add_user_to_docker_group

  log_success "Docker installation finished"
}

main "$@"
