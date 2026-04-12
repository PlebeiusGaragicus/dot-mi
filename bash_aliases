#!/bin/bash

# ── dot-mi: pi agent team aliases ───────────────────────────────────────────
#
# Source this file from ~/.bashrc or ~/.zshrc:
#   source ~/path/to/dot-mi/bash_aliases
#
# Each team alias sets PI_CODING_AGENT_DIR to an isolated config root
# so ~/.pi stays completely untouched.
#
# DOT_MI_DIR is auto-detected from this script's location.
# Override by setting DOT_MI_DIR before sourcing.

DOT_MI_DIR="${DOT_MI_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)}"

# Load API keys if present
[ -f "$DOT_MI_DIR/.env" ] && source "$DOT_MI_DIR/.env"

# ── pi.flags reader ──────────────────────────────────────────────────────────
#
# Reads per-team default CLI flags from <team>/pi.flags (if present).
# One flag per line; comments (#) and blank lines are ignored.
# Flags are applied before "$@" so the user can override at invocation time.

_dotmi_read_flags() {
  _DOTMI_FLAGS=()
  local flags_file="$1/pi.flags"
  [ -f "$flags_file" ] || return 0
  # zsh doesn't word-split unquoted vars by default; enable it locally
  [ -n "$ZSH_VERSION" ] && setopt local_options shwordsplit
  while IFS= read -r line || [ -n "$line" ]; do
    [[ -n "$line" && "$line" != \#* ]] && _DOTMI_FLAGS+=($line)
  done < "$flags_file"
}

# ── workspace launcher ───────────────────────────────────────────────────────
#
# Used by auto-generated aliases when a team/agent has a workspace.conf file.
# Creates a fresh dated directory, pre-creates subdirs listed in workspace.conf,
# then launches pi inside a subshell so the user's shell stays put after exit.
#
# Flags (must be first argument after the alias):
#   --list              Show existing workspaces and exit
#   --resume [prefix]   Resume into an existing workspace (most recent, or by prefix)

_dotmi_workspace_launch() {
  local name="$1" config_dir="$2"
  shift 2
  local ws_root="$DOT_MI_DIR/workspaces/$name"

  # --list: show existing workspaces and exit
  if [ "${1:-}" = "--list" ]; then
    if [ ! -d "$ws_root" ] || [ -z "$(ls -A "$ws_root" 2>/dev/null)" ]; then
      echo "No workspaces for $name"
      return 0
    fi
    echo "Workspaces for $name:"
    for d in "$ws_root"/*/; do
      [ -d "$d" ] || continue
      local ts=$(basename "$d")
      local files=$(find "$d" -maxdepth 2 -type f 2>/dev/null | wc -l | tr -d ' ')
      echo "  $ts  ($files files)"
    done
    return 0
  fi

  # --resume [prefix]: cd into existing workspace instead of creating new
  if [ "${1:-}" = "--resume" ]; then
    shift
    local target
    if [ -n "${1:-}" ]; then
      target=$(ls -d "$ws_root"/"$1"* 2>/dev/null | tail -1)
      if [ -z "$target" ]; then
        echo "No workspace matching '$1' in $ws_root"
        return 1
      fi
      shift
    else
      target=$(ls -dt "$ws_root"/*/ 2>/dev/null | head -1)
      if [ -z "$target" ]; then
        echo "No workspaces to resume for $name"
        return 1
      fi
    fi
    echo "Resuming: $target"
    _dotmi_read_flags "$config_dir"
    local _resume_args=()
    [ -d "$target/sessions" ] && _resume_args+=(--session-dir "$target/sessions")
    (cd "$target" && PI_CODING_AGENT_DIR="$config_dir" pi "${_resume_args[@]}" "${_DOTMI_FLAGS[@]}" --resume "$@")
    return
  fi

  # Default: create fresh workspace
  local ws="$ws_root/$(date +%Y-%m-%d-%H%M%S)"
  mkdir -p "$ws"
  while IFS= read -r subdir; do
    [[ -n "$subdir" && "$subdir" != \#* ]] && mkdir -p "$ws/$subdir"
  done < "$config_dir/workspace.conf"
  echo "Workspace: $ws"
  _dotmi_read_flags "$config_dir"
  local _launch_args=()
  [ -d "$ws/sessions" ] && _launch_args+=(--session-dir "$ws/sessions")
  (cd "$ws" && PI_CODING_AGENT_DIR="$config_dir" pi "${_launch_args[@]}" "${_DOTMI_FLAGS[@]}" "$@")
}

# ── auto-generated aliases ──────────────────────────────────────────────────
#
# Scans teams/ and agents/ directories and creates a pi-<name> function for each.
# If the directory contains workspace.conf, the alias launches in a fresh dated
# workspace directory. Otherwise it runs in-situ (the user's current directory).

for _dotmi_dir in "$DOT_MI_DIR"/{teams,agents}/*/; do
  [ -d "$_dotmi_dir" ] || continue
  _dotmi_name=$(basename "$_dotmi_dir")
  if [ -f "$_dotmi_dir/workspace.conf" ]; then
    eval "pi-${_dotmi_name}() { _dotmi_workspace_launch \"${_dotmi_name}\" \"$_dotmi_dir\" \"\$@\"; }"
  else
    eval "pi-${_dotmi_name}() { _dotmi_read_flags \"$_dotmi_dir\"; PI_CODING_AGENT_DIR=\"$_dotmi_dir\" pi \"\${_DOTMI_FLAGS[@]}\" \"\$@\"; }"
  fi
done
unset _dotmi_dir _dotmi_name

# ── standalone bot aliases ───────────────────────────────────────────────────
#
# These don't use PI_CODING_AGENT_DIR -- they pass flags directly to pi.
# Useful for quick one-off tasks that don't need team orchestration.

pchat() {
  pi \
    --system-prompt 'You are a knowledgeable and informative chatbot.
You help with answering questions, explaining concepts, brainstorming ideas, and casual conversation.
Be conversational and approachable while remaining terse and to-the-point.' \
    --tools read,grep,find,ls \
    --no-skills \
    --no-prompt-templates \
    --no-themes \
    "$@"
}

pexplain() {
  pi \
    --system-prompt 'You are a codebase analyst. Thoroughly review the current repository or directory and provide a detailed, well-structured report.

Start by exploring the project structure, reading key files (README, config, entry points), and tracing relevant code paths. Then deliver a clear summary covering:
- Project purpose and architecture
- Key files and directories relevant to the query
- How the pieces fit together
- Any notable patterns, dependencies, or concerns

Be thorough but organized. Use headings and bullet points. Cite specific files and line numbers.' \
    --tools read,grep,find,ls \
    --no-skills \
    --no-prompt-templates \
    "$@"
}
