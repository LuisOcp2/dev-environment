#!/usr/bin/env bash
#
# validate-repository.sh - validate this repository without modifying it.
#
# Runs in CI and is safe to run at any time. It never installs anything, never
# applies dotfiles, and never touches the home directory.
#
# Checks
#   1. bash -n over every shell file
#   2. shellcheck, when installed
#   3. shfmt formatting, when installed
#   4. JSON validity
#   5. JSONC validity (comments stripped before parsing)
#   6. Skill structure, frontmatter and name/directory agreement
#   7. Agent and command frontmatter
#   8. Obvious secret patterns
#   9. Executable bit on the entry points
#  10. Repository invariants (.chezmoiroot, required files)
#
# Any check whose tooling is unavailable is reported as SKIPPED, never as a
# silent pass.
#
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=scripts/lib/packages.sh
source "${SCRIPT_DIR}/lib/packages.sh"

usage() {
  cat << 'EOF'
Usage: ./scripts/validate-repository.sh [options]

Validates this repository. Read only: nothing is installed and nothing in the
home directory is modified.

Options:
  --only <list>    run only these checks, comma separated. Available checks:
                    syntax, shellcheck, format, json, skills, frontmatter,
                    secrets, permissions, structure
  --skip <list>    skip these checks, comma separated
  --no-warnings    print only failures and the final verdict
  -h, --help       show this help

Exit codes:
  0  no failures (warnings allowed)
  1  at least one failure
  2  invalid usage
EOF
}

ONLY=""
SKIP=""
QUIET_WARNINGS=false

FAILURES=0
WARNINGS=0
PASSES=0
SKIPPED=0

# Files that must be executable.
REQUIRED_EXECUTABLE=(
  "bootstrap.sh"
  "scripts/apply-dotfiles.sh"
  "scripts/backup.sh"
  "scripts/detect-platform.sh"
  "scripts/doctor.sh"
  "scripts/install-chezmoi.sh"
  "scripts/install-development-tools.sh"
  "scripts/install-docker.sh"
  "scripts/install-mise.sh"
  "scripts/install-system-packages.sh"
  "scripts/install-vscode-extensions.sh"
  "scripts/update.sh"
  "scripts/validate-repository.sh"
  "scripts/verify.sh"
)

REQUIRED_PATHS=(
  ".chezmoiroot"
  ".editorconfig"
  ".gitignore"
  ".gitattributes"
  "AGENTS.md"
  "README.md"
  "CHANGELOG.md"
  "Makefile"
  "bootstrap.sh"
  "packages/base.txt"
  "packages/fullstack.txt"
  "config/defaults.env"
  "config/vscode-extensions.txt"
  "home/.chezmoi.toml.tmpl"
  "home/.chezmoiignore"
  "home/dot_gitconfig.tmpl"
  "home/dot_zshrc"
  "home/dot_bashrc"
  "home/dot_profile"
  "home/dot_tmux.conf"
  "home/dot_config/starship.toml"
  "home/dot_config/mise/config.toml"
  "home/dot_config/opencode/AGENTS.md"
  "home/dot_config/opencode/opencode.jsonc"
  "home/dot_config/Code/User/settings.json"
  "home/dot_config/Code/User/keybindings.json"
  "templates/skill/SKILL.md"
  "templates/project-agents/AGENTS.md"
  "templates/mise/mise.toml"
  "templates/devcontainer/devcontainer.json"
  "templates/devcontainer/compose.yml"
  "docs/ARCHITECTURE.md"
  "docs/INSTALLATION.md"
  "docs/PROFILES.md"
  "docs/ADDING-CONFIGURATION.md"
  "docs/ADDING-SKILLS.md"
  "docs/OPENCODE.md"
  "docs/SECURITY.md"
  "docs/TROUBLESHOOTING.md"
  "docs/ROADMAP.md"
  ".github/workflows/validate.yml"
)

# --- Reporting --------------------------------------------------------------

pass() {
  PASSES=$((PASSES + 1))
  is_true "$QUIET_WARNINGS" || log_success "$1"
}

warn_check() {
  WARNINGS=$((WARNINGS + 1))
  is_true "$QUIET_WARNINGS" || log_warn "$1"
}

fail() {
  FAILURES=$((FAILURES + 1))
  log_error "$1"
}

skip() {
  SKIPPED=$((SKIPPED + 1))
  is_true "$QUIET_WARNINGS" || log_skip "$1"
}

detail() {
  is_true "$QUIET_WARNINGS" || log_line "$1"
}

section() {
  is_true "$QUIET_WARNINGS" || log_section "$1"
}

# --- Check selection --------------------------------------------------------

in_list() {
  local needle="$1"
  local haystack="$2"
  [[ ",${haystack}," == *",${needle},"* ]]
}

# in_space_list matches a word inside a space separated list, for example the
# valid OpenCode frontmatter keys.
in_space_list() {
  local needle="$1"
  local haystack="$2"
  [[ " ${haystack} " == *" ${needle} "* ]]
}

want() {
  local name="$1"
  [[ -z "$ONLY" ]] && return 0
  in_list "$name" "$ONLY"
}

skipping() {
  local name="$1"
  [[ -n "$SKIP" ]] && in_list "$name" "$SKIP" && return 0
  return 1
}

# --- 1. Bash syntax ---------------------------------------------------------

all_shell_files() {
  find "$REPO_ROOT" -type f \
    \( -name '*.sh' -o -name '*.bash' -o -name '.bashrc' -o -name '.zshrc' -o -name '.profile' \) \
    -not -path "${REPO_ROOT}/.git/*" \
    -not -path "${REPO_ROOT}/.validate-cache/*" |
    sort
}

check_syntax() {
  section "1. Bash syntax"

  if ! has_command bash; then
    skip "bash is not available, cannot run 'bash -n'"
    return 0
  fi

  local count=0
  local file
  local relative

  while IFS= read -r file; do
    count=$((count + 1))
    relative="${file#"${REPO_ROOT}/"}"

    local output
    if output="$(bash -n "$file" 2>&1)"; then
      :
    else
      fail "${relative} has a syntax error"
      detail "${output}"
    fi
  done < <(all_shell_files)

  if [[ "$count" -gt 0 ]]; then
    pass "bash -n parsed ${count} shell file(s) with no syntax error"
  else
    warn_check "no shell files found"
  fi
}

# --- 2. Shellcheck ----------------------------------------------------------

check_shellcheck() {
  section "2. Shellcheck"

  if ! has_command shellcheck; then
    skip "shellcheck is not installed; install it with: apt-get install shellcheck"
    return 0
  fi

  local file
  local relative
  local problems=0

  while IFS= read -r file; do
    relative="${file#"${REPO_ROOT}/"}"
    local output
    # -S warning drops the informational noise; -e SC1091 covers the
    # runtime-sourced library pattern used by this repository.
    if output="$(shellcheck --shell=bash --severity=warning \
      --exclude=SC1091,SC1090,SC2317 "$file" 2>&1)"; then
      :
    else
      problems=$((problems + 1))
      fail "${relative}"
      detail "${output}"
    fi
  done < <(all_shell_files)

  [[ "$problems" -eq 0 ]] && pass "shellcheck found no warnings or errors"
}

# --- 3. Formatting ----------------------------------------------------------

check_format() {
  section "3. Script formatting"

  if ! has_command shfmt; then
    skip "shfmt is not installed; install it with: apt-get install shfmt"
    return 0
  fi

  local file
  local relative
  local problems=0

  while IFS= read -r file; do
    relative="${file#"${REPO_ROOT}/"}"
    if shfmt -d -i 2 -ci -sr -kp "$file" > /dev/null 2>&1; then
      :
    else
      problems=$((problems + 1))
      fail "${relative} is not formatted with 'shfmt -i 2 -ci -sr -kp'"
    fi
  done < <(all_shell_files)

  [[ "$problems" -eq 0 ]] && pass "every script matches the shfmt formatting rules"
}

# --- 4/5. JSON and JSONC ----------------------------------------------------

# strip_jsonc produces plain JSON on stdout. Uses node when available, then
# python3, and reports failure when neither exists.
jsonc_to_json() {
  if has_command node; then
    node -e '
      const fs = require("fs");
      let s = fs.readFileSync(process.argv[1], "utf8");
      let out = "";
      let i = 0;
      const n = s.length;
      while (i < n) {
        const c = s[i];
        if (c === "\"") {
          let j = i + 1;
          while (j < n) {
            if (s[j] === "\\") { j += 2; continue; }
            if (s[j] === "\"") break;
            j++;
          }
          out += s.slice(i, j + 1);
          i = j + 1;
          continue;
        }
        if (c === "/" && s[i + 1] === "/") {
          while (i < n && s[i] !== "\n") i++;
          continue;
        }
        if (c === "/" && s[i + 1] === "*") {
          i += 2;
          while (i < n && !(s[i] === "*" && s[i + 1] === "/")) i++;
          i += 2;
          continue;
        }
        out += c;
        i++;
      }
      process.stdout.write(out.replace(/,(\s*[}\]])/g, "$1"));
    ' "$1"
    return $?
  fi

  if has_command python3; then
    python3 -c '
import sys, re

path = sys.argv[1]
text = open(path, encoding="utf-8").read()
out = []
i = 0
n = len(text)
while i < n:
    c = text[i]
    if c == "\"":
        j = i + 1
        while j < n:
            if text[j] == "\\":
                j += 2
                continue
            if text[j] == "\"":
                break
            j += 1
        out.append(text[i:j + 1])
        i = j + 1
        continue
    if c == "/" and i + 1 < n and text[i + 1] == "/":
        while i < n and text[i] != "\n":
            i += 1
        continue
    if c == "/" and i + 1 < n and text[i + 1] == "*":
        i += 2
        while i < n and not (text[i] == "*" and i + 1 < n and text[i + 1] == "/"):
            i += 1
        i += 2
        continue
    out.append(c)
    i += 1

result = "".join(out)
result = re.sub(r",(\s*[}\]])", r"\1", result)
sys.stdout.write(result)
' "$1"
    return $?
  fi

  return 2
}

validate_json_file() {
  local file="$1"
  local kind="$2"

  if has_command jq; then
    local output
    if output="$(jq empty "$file" 2>&1)"; then
      return 0
    fi
    if [[ "$kind" == "jsonc" ]]; then
      # jq cannot parse comments; retry through the stripper.
      local stripped
      stripped="$(jsonc_to_json "$file" 2> /dev/null)" || {
        fail "${file#"${REPO_ROOT}/"}: could not strip JSONC comments"
        return 1
      }
      if printf '%s' "$stripped" | jq empty > /dev/null 2>&1; then
        return 0
      fi
      fail "${file#"${REPO_ROOT}/"} is not valid JSONC"
      return 1
    fi
    fail "${file#"${REPO_ROOT}/"} is not valid JSON: ${output}"
    return 1
  fi

  # No jq: use node or python3 directly.
  if has_command node || has_command python3; then
    local stripped
    if stripped="$(jsonc_to_json "$file" 2> /dev/null)" && [[ -n "$stripped" ]]; then
      return 0
    fi
    if [[ "$kind" == "json" ]] && has_command node; then
      fail "${file#"${REPO_ROOT}/"} is not valid JSON"
      return 1
    fi
    if [[ "$kind" == "jsonc" ]] && has_command node; then
      fail "${file#"${REPO_ROOT}/"} is not valid JSONC"
      return 1
    fi
  fi

  fail "${file#"${REPO_ROOT}/"} could not be validated: no jq, node or python3"
  return 1
}

check_json() {
  section "4/5. JSON and JSONC"

  local json_files jsonc_files
  json_files="$(find "$REPO_ROOT" -type f -name '*.json' \
    -not -path "${REPO_ROOT}/.git/*" -not -path "${REPO_ROOT}/node_modules/*" | sort)"
  jsonc_files="$(find "$REPO_ROOT" -type f -name '*.jsonc' \
    -not -path "${REPO_ROOT}/.git/*" -not -path "${REPO_ROOT}/node_modules/*" | sort)"

  if [[ -z "$json_files" && -z "$jsonc_files" ]]; then
    skip "no JSON or JSONC files found"
    return 0
  fi

  local file
  for file in $json_files; do
    validate_json_file "$file" json || true
  done
  for file in $jsonc_files; do
    validate_json_file "$file" jsonc || true
  done

  local json_count jsonc_count
  json_count="$(printf '%s\n' "$json_files" | grep -c . || true)"
  jsonc_count="$(printf '%s\n' "$jsonc_files" | grep -c . || true)"

  pass "validated ${json_count} JSON and ${jsonc_count} JSONC file(s)"
}

# --- Frontmatter primitives -------------------------------------------------

# frontmatter_field <file> <key> -> the raw scalar value of a top level key.
frontmatter_field() {
  local file="$1"
  local key="$2"

  awk -v key="$key" '
    NR == 1 { if ($0 != "---") exit 1; inblock = 1; next }
    inblock && $0 == "---" { exit 0 }
    inblock {
      line = $0
      sub(/^[ \t]+/, "", line)
      if (line ~ "^" key "[ \t]*:") {
        sub("^" key "[ \t]*:[ \t]*", "", line)
        print line
        exit 0
      }
    }
    END { }
  ' "$file" 2> /dev/null || true
}

has_frontmatter() {
  local file="$1"
  local first
  first="$(head -n 1 "$file" 2> /dev/null || true)"
  [[ "$first" == "---" ]] || return 1
  grep -qx -- '---' "$file" 2> /dev/null || return 1
  return 0
}

# strip_quotes removes surrounding single or double quotes.
strip_quotes() {
  local value="$1"
  value="${value%"${value##*[![:space:]]}"}"
  if [[ "$value" == \"*\" && "$value" == *\" ]]; then
    value="${value:1:${#value}-2}"
  elif [[ "$value" == \'*\' && "$value" == *\' ]]; then
    value="${value:1:${#value}-2}"
  fi
  printf '%s' "$value"
}

# --- 6. Skills --------------------------------------------------------------

SKILLS_DIR="${REPO_ROOT}/home/dot_agents/skills"

check_skills() {
  section "6. Skills"

  if [[ ! -d "$SKILLS_DIR" ]]; then
    fail "skills directory is missing: home/dot_agents/skills"
    return 0
  fi

  local dir_count=0
  local dir

  for dir in "$SKILLS_DIR"/*/; do
    [[ -d "$dir" ]] || continue
    dir_count=$((dir_count + 1))

    local name
    name="$(basename "$dir")"
    local skill_file="${dir}SKILL.md"
    local relative="home/dot_agents/skills/${name}/SKILL.md"

    # Directory name rules.
    if [[ ! "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
      fail "${name}: directory name must match ^[a-z0-9]+(-[a-z0-9]+)*\$"
      continue
    fi

    if [[ ! -f "$skill_file" ]]; then
      fail "${relative}: SKILL.md is missing"
      continue
    fi

    if ! has_frontmatter "$skill_file"; then
      fail "${relative}: missing or malformed YAML frontmatter"
      continue
    fi

    local declared_name
    declared_name="$(strip_quotes "$(frontmatter_field "$skill_file" "name")")"

    local description
    description="$(strip_quotes "$(frontmatter_field "$skill_file" "description")")"

    if [[ -z "$declared_name" ]]; then
      fail "${relative}: frontmatter is missing 'name'"
      continue
    fi

    if [[ -z "$description" ]]; then
      fail "${relative}: frontmatter is missing 'description'"
      continue
    fi

    if [[ "$declared_name" != "$name" ]]; then
      fail "${relative}: frontmatter name '${declared_name}' does not match directory '${name}'"
      continue
    fi

    # The description drives automatic selection, so require a real length.
    if [[ "${#description}" -lt 40 ]]; then
      warn_check "${relative}: description is short (${#description} chars); it may not be selected reliably"
    fi

    # Required body sections.
    local section_name
    local missing=""
    for section_name in "## Objective" "## When to use" "## When not to use" \
      "## Required inputs" "## Procedure" "## Constraints" \
      "## Validation checklist" "## Mandatory output format" "## Completion criteria"; do
      if ! grep -qF "$section_name" "$skill_file"; then
        missing+=" ${section_name}"
      fi
    done

    if [[ -n "$missing" ]]; then
      fail "${relative}: missing required section(s):${missing}"
      continue
    fi

    pass "${relative}: valid"
  done

  if [[ "$dir_count" -eq 0 ]]; then
    fail "no skills found under home/dot_agents/skills"
  else
    detail "checked ${dir_count} skill(s)"
  fi
}

# --- 7. Agents and commands -------------------------------------------------

# check_agent_frontmatter <file>
check_agent_frontmatter() {
  local file="$1"
  local relative="${file#"${REPO_ROOT}/"}"

  if ! has_frontmatter "$file"; then
    fail "${relative}: missing YAML frontmatter"
    return 1
  fi

  local frontmatter
  frontmatter="$(sed -n '2,/^---$/p' "$file")"

  local key
  # Fields valid for OpenCode v2 Markdown agents. Anything else is either a
  # V1 leftover that V2 no longer interprets, or a typo that would silently
  # disable the intended setting.
  local valid_keys="description mode model permissions steps hidden color disabled request"
  local legacy_keys="tools temperature top_p prompt permission maxSteps disable subtask"

  for key in $legacy_keys; do
    if printf '%s\n' "$frontmatter" | grep -qE "^[[:space:]]*${key}[[:space:]]*:|^[[:space:]]*\"${key}\"[[:space:]]*:"; then
      fail "${relative}: uses the removed OpenCode v1 field '${key}'"
    fi
  done

  # Every top level key in the frontmatter must be a known V2 field.
  local unknown
  unknown="$(printf '%s\n' "$frontmatter" |
    grep -oE '^[A-Za-z_][A-Za-z0-9_-]*[[:space:]]*:' |
    tr -d ' :' |
    sort -u)"

  for key in $unknown; do
    if ! in_space_list "$key" "$valid_keys"; then
      fail "${relative}: '${key}' is not a valid OpenCode v2 agent field"
    fi
  done

  local description
  description="$(strip_quotes "$(frontmatter_field "$file" "description")")"
  if [[ -z "$description" ]]; then
    fail "${relative}: frontmatter is missing 'description'"
    return 1
  fi

  if ! printf '%s\n' "$frontmatter" | grep -qE "^[[:space:]]*mode[[:space:]]*:[[:space:]]*(primary|subagent|all)[[:space:]]*$"; then
    fail "${relative}: 'mode' must be one of primary, subagent, all"
    return 1
  fi

  return 0
}

check_command_frontmatter() {
  local file="$1"
  local relative="${file#"${REPO_ROOT}/"}"

  if ! has_frontmatter "$file"; then
    # A command without frontmatter is valid; the body is the template.
    return 0
  fi

  local frontmatter
  frontmatter="$(sed -n '2,/^---$/p' "$file")"

  local key
  local legacy_keys="template subtask tools temperature"
  for key in $legacy_keys; do
    if printf '%s\n' "$frontmatter" | grep -qE "^[[:space:]]*${key}[[:space:]]*:"; then
      case "$key" in
        template)
          # `template` is JSON-only; in Markdown the body supplies it.
          fail "${relative}: 'template' must not appear in Markdown frontmatter"
          ;;
        subtask)
          fail "${relative}: 'subtask' is deprecated; use 'subagent'"
          ;;
        *)
          fail "${relative}: uses the removed OpenCode v1 field '${key}'"
          ;;
      esac
    fi
  done

  local description
  description="$(strip_quotes "$(frontmatter_field "$file" "description")")"
  if [[ -z "$description" ]]; then
    warn_check "${relative}: command has no description; it will be harder to discover"
  fi
}

check_frontmatter() {
  section "7. Agent and command frontmatter"

  local agents_dir="${REPO_ROOT}/home/dot_config/opencode/agents"
  local commands_dir="${REPO_ROOT}/home/dot_config/opencode/commands"

  local agent_count=0
  local file
  if [[ -d "$agents_dir" ]]; then
    for file in "$agents_dir"/*.md; do
      [[ -e "$file" ]] || continue
      agent_count=$((agent_count + 1))
      check_agent_frontmatter "$file" && pass "${file#"${REPO_ROOT}/"}: valid agent frontmatter"
    done
  else
    fail "agents directory is missing: home/dot_config/opencode/agents"
  fi

  local command_count=0
  if [[ -d "$commands_dir" ]]; then
    for file in "$commands_dir"/*.md; do
      [[ -e "$file" ]] || continue
      command_count=$((command_count + 1))
      check_command_frontmatter "$file" && pass "${file#"${REPO_ROOT}/"}: valid command frontmatter"
    done
  else
    fail "commands directory is missing: home/dot_config/opencode/commands"
  fi

  detail "checked ${agent_count} agent(s) and ${command_count} command(s)"
}

# --- 8. Secrets -------------------------------------------------------------

# Patterns that match real credentials. Kept specific on purpose: a scanner
# that flags every mention of "password" in documentation is ignored, which
# defeats the purpose.
SECRET_PATTERNS=(
  'AKIA[0-9A-Z]{16}'
  'ASIA[0-9A-Z]{16}'
  'ghp_[A-Za-z0-9]{30,}'
  'gho_[A-Za-z0-9]{30,}'
  'ghs_[A-Za-z0-9]{30,}'
  'ghu_[A-Za-z0-9]{30,}'
  'github_pat_[A-Za-z0-9_]{40,}'
  'glpat-[A-Za-z0-9_-]{20,}'
  'sk-[A-Za-z0-9]{24,}'
  'sk-ant-[A-Za-z0-9_-]{24,}'
  'xox[baprs]-[A-Za-z0-9-]{10,}'
  'AIza[0-9A-Za-z_-]{35}'
  '-----BEGIN [A-Z ]*PRIVATE KEY-----'
  'eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}'
)

# Values that are obviously placeholders and must not be reported.
PLACEHOLDER_PATTERN='EXAMPLE|example|placeholder|PLACEHOLDER|your-|YOUR_|your_|xxxx|XXXX|changeme|CHANGEME|REPLACE|replace-me|fake|FAKE|dummy|DUMMY|local-development-only|not-a-real|<[^>]+>|\$\{[^}]+\}|{{[^}]+}}'

check_secrets() {
  section "8. Secret patterns"

  local tracked_files
  tracked_files="$(git -C "$REPO_ROOT" ls-files 2> /dev/null || true)"

  if [[ -z "$tracked_files" ]]; then
    # Not a git repository yet: scan the working tree instead.
    tracked_files="$(cd "$REPO_ROOT" && find . -type f \
      -not -path './.git/*' -not -path './.validate-cache/*' | sed 's|^\./||')"
    warn_check "not a git repository; scanned the working tree instead of tracked files"
  fi

  local found=0
  local pattern
  local matches

  for pattern in "${SECRET_PATTERNS[@]}"; do
    # shellcheck disable=SC2086 # the pattern is a single token by design
    matches="$(printf '%s\n' "$tracked_files" |
      xargs -r grep -lIE "$pattern" 2> /dev/null || true)"

    if [[ -n "$matches" ]]; then
      while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        if printf '%s' "$file" | grep -qE "$PLACEHOLDER_PATTERN"; then
          continue
        fi
        fail "possible secret (${pattern}) in ${file}"
        found=$((found + 1))
      done <<< "$matches"
    fi
  done

  # Filenames that must never be tracked.
  local suspicious_names
  suspicious_names="$(printf '%s\n' "$tracked_files" |
    grep -E '(^|/)(\.env($|\.)|[^/]*\.(pem|key|p12|pfx|jks|keystore)$|id_rsa|id_ed25519|id_ecdsa|\.netrc|credentials|auth\.json|kubeconfig)' || true)"

  if [[ -n "$suspicious_names" ]]; then
    while IFS= read -r name; do
      [[ -z "$name" ]] && continue
      # .env.example files are expected and must be tracked.
      if printf '%s' "$name" | grep -qE '\.example($|\.)'; then
        continue
      fi
      fail "tracked file with a secret-like name: ${name}"
      found=$((found + 1))
    done <<< "$suspicious_names"
  fi

  if [[ "$found" -eq 0 ]]; then
    pass "no obvious secret pattern found in tracked files"
  else
    detail "this scan is a heuristic and is NOT a guarantee; review manually"
  fi
}

# --- 9. Permissions ---------------------------------------------------------

check_permissions() {
  section "9. Executable permissions"

  local file
  local relative
  local filesystem_ok=true

  for relative in "${REQUIRED_EXECUTABLE[@]}"; do
    file="${REPO_ROOT}/${relative}"
    if [[ ! -f "$file" ]]; then
      fail "${relative} is missing"
      continue
    fi
    if [[ ! -x "$file" ]]; then
      filesystem_ok=false
      log_warn "${relative} is not executable on this filesystem"
    fi
  done

  # On systems without a POSIX mode bit (NTFS, as used by Git for Windows and
  # WSL with a Windows filesystem), Git records the executable bit in the index
  # instead. Check there before failing, so a Windows checkout is not
  # permanently unfixable.
  if ! is_true "$filesystem_ok"; then
    log_info "falling back to the Git index mode (core.filemode may be false)"

    for relative in "${REQUIRED_EXECUTABLE[@]}"; do
      local mode
      mode="$(git -C "$REPO_ROOT" ls-files --stage -- "$relative" 2> /dev/null |
        awk '{print $1}' | head -n 1)"

      if [[ -z "$mode" ]]; then
        fail "${relative} is not tracked by Git; run 'git add ${relative}'"
      elif [[ "$mode" != "100755" ]]; then
        fail "${relative} is ${mode} in the Git index, expected 100755"
        log_line "fix with: git update-index --chmod=+x ${relative}"
      fi
    done

    pass "checked ${#REQUIRED_EXECUTABLE[@]} required entry point(s) in the Git index"
    return 0
  fi

  pass "checked ${#REQUIRED_EXECUTABLE[@]} required entry point(s)"
}

# --- 10. Repository invariants ---------------------------------------------

check_structure() {
  section "10. Repository structure"

  local relative
  for relative in "${REQUIRED_PATHS[@]}"; do
    if [[ ! -e "${REPO_ROOT}/${relative}" ]]; then
      fail "required path is missing: ${relative}"
    fi
  done

  local chezmoiroot_content
  chezmoiroot_content="$(tr -d '[:space:]' < "${REPO_ROOT}/.chezmoiroot" 2> /dev/null || printf 'missing')"
  if [[ "$chezmoiroot_content" != "home" ]]; then
    fail ".chezmoiroot must contain 'home' (found '${chezmoiroot_content}')"
  else
    pass ".chezmoiroot points at home"
  fi

  # Every profile referenced by the README must exist.
  local profile
  for profile in minimal frontend backend fullstack cloud teaching; do
    if ! profile_exists "$profile"; then
      fail "documented profile does not exist: ${profile}"
    else
      if ! resolve_profile "$profile"; then
        fail "profile '${profile}' could not be resolved"
      fi
    fi
  done

  # Every profile must resolve to at least one existing manifest.
  for profile in minimal frontend backend fullstack cloud teaching; do
    profile_exists "$profile" || continue
    resolve_profile "$profile" || continue
    local manifest
    for manifest in $PROFILE_PACKAGE_SETS; do
      if ! manifest_exists "$manifest"; then
        fail "profile '${profile}' references a missing manifest: ${manifest}"
      fi
    done
  done

  pass "structure, profiles and manifests are consistent"
}

# --- Final verdict ----------------------------------------------------------

final_verdict() {
  log_section "Result"
  log_line "checks   : $((PASSES + FAILURES + WARNINGS + SKIPPED))"
  log_line "passed   : ${PASSES}"
  log_line "warnings : ${WARNINGS}"
  log_line "skipped  : ${SKIPPED}"
  log_line "failures : ${FAILURES}"

  if [[ "$FAILURES" -gt 0 ]]; then
    log_error "repository validation FAILED"
    return 1
  fi

  if [[ "$WARNINGS" -gt 0 || "$SKIPPED" -gt 0 ]]; then
    log_warn "repository validation passed with warnings; every skipped check is listed above"
  else
    log_success "repository validation passed"
  fi

  return 0
}

# --- Main -------------------------------------------------------------------

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --only)
        [[ $# -ge 2 ]] || {
          log_error "--only requires a value."
          exit 2
        }
        ONLY="$2"
        shift 2
        ;;
      --only=*)
        ONLY="${1#*=}"
        shift
        ;;
      --skip)
        [[ $# -ge 2 ]] || {
          log_error "--skip requires a value."
          exit 2
        }
        SKIP="$2"
        shift 2
        ;;
      --skip=*)
        SKIP="${1#*=}"
        shift
        ;;
      --no-warnings)
        QUIET_WARNINGS=true
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

  print_banner "Repository validation"
  log_info "read only: no installation and no change to \$HOME"
  log_info "repository: ${REPO_ROOT}"

  want syntax && ! skipping syntax && check_syntax
  want shellcheck && ! skipping shellcheck && check_shellcheck
  want format && ! skipping format && check_format
  want json && ! skipping json && check_json
  want skills && ! skipping skills && check_skills
  want frontmatter && ! skipping frontmatter && check_frontmatter
  want secrets && ! skipping secrets && check_secrets
  want permissions && ! skipping permissions && check_permissions
  want structure && ! skipping structure && check_structure

  final_verdict
}

main "$@"
