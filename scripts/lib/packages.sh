#!/usr/bin/env bash
# shellcheck shell=bash
#
# packages.sh - manifest and profile resolution.
#
# Sourced by every entry point. Do not execute directly.
#
# This module owns *data*, not installation. Adding a package must never
# require editing a script:
#
#   packages/*.txt          flat manifests, one entry per line
#   config/profiles/*.env   cumulative profiles referencing manifests + tools
#
# Manifest syntax
#   # comment or blank line   ignored
#   package-name              required; an error if apt cannot resolve it
#   ?package-name             optional; silently skipped when not available
#
# Profile variables (see config/defaults.env for defaults)
#   PROFILE_DESCRIPTION   human readable summary
#   PROFILE_INHERITS      space separated parent profiles, applied first
#   PACKAGE_SETS          space separated manifest names from packages/
#   MISE_TOOLS            space separated tool identifiers for mise
#   PROFILE_FLAGS         space separated feature flags, e.g. docker vscode
#
# Shellcheck directive SC2034: accumulators are populated by this file and
# consumed by scripts/install-system-packages.sh.

# Guard against double sourcing.
if [[ -n "${DEV_ENV_PACKAGES_LOADED:-}" ]]; then
  return 0
fi
DEV_ENV_PACKAGES_LOADED=1

# --- Manifest access -------------------------------------------------------

manifest_path() {
  printf '%s/%s.txt' "$REPO_PACKAGES_DIR" "$1"
}

manifest_exists() {
  [[ -f "$(manifest_path "$1")" ]]
}

# list_manifests prints every manifest name, sorted.
list_manifests() {
  local file
  for file in "${REPO_PACKAGES_DIR}"/*.txt; do
    [[ -e "$file" ]] || continue
    basename "$file" .txt
  done
}

# read_manifest prints the entries of a manifest, one per line, comments and
# blank lines removed. Fails when the manifest does not exist.
read_manifest() {
  local name="$1"
  local file
  file="$(manifest_path "$name")"

  if [[ ! -f "$file" ]]; then
    log_error "Package manifest not found: ${file}"
    return 1
  fi

  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"   # ltrim
    line="${line%"${line##*[![:space:]]}"}"   # rtrim
    [[ -z "$line" ]] && continue
    printf '%s\n' "$line"
  done < "$file"
}

# --- Profile access --------------------------------------------------------

profile_path() {
  printf '%s/%s.env' "$REPO_PROFILES_DIR" "$1"
}

profile_exists() {
  [[ -f "$(profile_path "$1")" ]]
}

# list_profiles prints every profile name, sorted.
list_profiles() {
  local file
  for file in "${REPO_PROFILES_DIR}"/*.env; do
    [[ -e "$file" ]] || continue
    basename "$file" .env
  done
}

# --- Cumulative resolution -------------------------------------------------
#
# Profiles are a DAG. `_PROFILE_VISITED` guards against cycles introduced by a
# future mistake, so a bad profile degrades instead of hanging the bootstrap.

declare -A _PROFILE_VISITED=()

# Accumulators, reset by resolve_profile.
PROFILE_PACKAGE_SETS=""
PROFILE_MISE_TOOLS=""
# Accumulated feature flags. Deliberately NOT named PROFILE_FLAGS: that name is
# the per-profile variable sourced from config/profiles/*.env, and reusing it
# would make each iteration erase the previous ones.
PROFILE_FEATURE_FLAGS=""
# Descriptions of every profile that contributed, parents first.
PROFILE_DESCRIPTIONS=""

_profile_collect() {
  local name="$1"
  local depth="$2"

  if [[ -z "$name" ]]; then
    return 0
  fi

  if [[ "$depth" -gt 8 ]]; then
    log_error "Profile inheritance nested deeper than 8 levels at '${name}'. Check for a cycle."
    return 1
  fi

  if [[ -n "${_PROFILE_VISITED[$name]:-}" ]]; then
    return 0
  fi

  if ! profile_exists "$name"; then
    log_error "Unknown profile '${name}'. Available: $(list_profiles | tr '\n' ' ')"
    return 1
  fi

  _PROFILE_VISITED["$name"]=1

  local inherits=""
  local package_sets=""
  local mise_tools=""
  local flags=""
  local description=""

  # shellcheck disable=SC1090 # runtime path, checked above by profile_exists
  source "$(profile_path "$name")"

  inherits="${PROFILE_INHERITS:-}"
  package_sets="${PACKAGE_SETS:-}"
  mise_tools="${MISE_TOOLS:-}"
  flags="${PROFILE_FLAGS:-}"
  description="${PROFILE_DESCRIPTION:-}"

  local parent
  for parent in $inherits; do
    _profile_collect "$parent" "$((depth + 1))" || return 1
  done

  PROFILE_PACKAGE_SETS+=" ${package_sets}"
  PROFILE_MISE_TOOLS+=" ${mise_tools}"
  PROFILE_FEATURE_FLAGS+=" ${flags}"
  [[ -n "$description" ]] && PROFILE_DESCRIPTIONS+="${description}"$'\n'

  # Reset the sourced locals so a later iteration cannot inherit them.
  PROFILE_INHERITS=""
  PACKAGE_SETS=""
  MISE_TOOLS=""
  PROFILE_FLAGS=""
  PROFILE_DESCRIPTION=""

  return 0
}

# resolve_profile <name> fills PROFILE_PACKAGE_SETS, PROFILE_MISE_TOOLS and
# PROFILE_FLAGS with the cumulative, de-duplicated result. Parents come first.
resolve_profile() {
  local name="$1"

  _PROFILE_VISITED=()
  PROFILE_PACKAGE_SETS=""
  PROFILE_MISE_TOOLS=""
  PROFILE_FEATURE_FLAGS=""
  PROFILE_DESCRIPTIONS=""

  if ! _profile_collect "$name" 0; then
    return 1
  fi

  _dedupe_words "$PROFILE_PACKAGE_SETS"
  PROFILE_PACKAGE_SETS="$REPLY"
  _dedupe_words "$PROFILE_MISE_TOOLS"
  PROFILE_MISE_TOOLS="$REPLY"
  _dedupe_words "$PROFILE_FEATURE_FLAGS"
  PROFILE_FEATURE_FLAGS="$REPLY"

  return 0
}

# _dedupe_words <space separated words> -> $REPLY (stable, unique)
_dedupe_words() {
  local seen=" "
  local out=""
  local word

  for word in $1; do
    [[ "$seen" == *" ${word} "* ]] && continue
    seen+="${word} "
    out+="${word} "
  done

  REPLY="${out% }"
}

# print_profile_summary renders what a resolved profile actually contains.
print_profile_summary() {
  log_line "profile         : ${SELECTED_PROFILE}"
  log_line "manifests       : ${PROFILE_PACKAGE_SETS}"
  log_line "mise tools      : ${PROFILE_MISE_TOOLS}"
  log_line "features        : ${PROFILE_FEATURE_FLAGS:-none}"
  if [[ -n "$PROFILE_DESCRIPTIONS" ]]; then
    log_line "inherits        :"
    local line
    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ -n "$line" ]]; then
        log_line "  - ${line}"
      fi
    done <<< "$PROFILE_DESCRIPTIONS"
  fi
}

# profile_flag_enabled <flag> -> 0 when the resolved profile enables it.
profile_flag_enabled() {
  local flag="$1"
  [[ " ${PROFILE_FEATURE_FLAGS} " == *" ${flag} "* ]]
}

# --- Package list resolution ----------------------------------------------

# resolve_packages <space separated manifests> -> newline separated packages,
# required and optional entries preserved with their original prefix.
resolve_packages() {
  local manifest_name
  local entry

  for manifest_name in $1; do
    if ! manifest_exists "$manifest_name"; then
      log_warn "Package manifest '${manifest_name}' not found, skipping it."
      continue
    fi

    while IFS= read -r entry; do
      printf '%s\n' "$entry"
    done < <(read_manifest "$manifest_name")
  done
}

# --- Distro specific package naming ---------------------------------------
#
# Some packages carry different names across Debian derivatives. Keeping the
# mapping here means manifests always use the "nice" name.

# resolve_package_name <entry> -> apt package name, or empty when unknown.
resolve_package_name() {
  local entry="${1#?}"
  local distro="${DETECTED_DISTRO:-ubuntu}"

  if [[ "$distro" == "ubuntu" || "$distro" == "tuxedo" || "$distro" == "debian" ]]; then
    case "$entry" in
      fd) printf 'fd-find' ;;
      *) printf '%s' "$entry" ;;
    esac
    return 0
  fi

  printf '%s' "$entry"
}

# package_is_installed <apt name> -> 0 when dpkg reports it installed.
package_is_installed() {
  local pkg="$1"
  local status

  status="$(dpkg-query -W -f='${Status}' "$pkg" 2> /dev/null || true)"
  [[ "$status" == *"install ok installed"* ]]
}

# apt_package_exists <apt name> -> 0 when apt knows the package.
apt_package_exists() {
  local pkg="$1"
  apt-cache show "$pkg" > /dev/null 2>&1
}
