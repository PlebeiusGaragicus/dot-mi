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
    local _resume_args=()
    [ -d "$target/sessions" ] && _resume_args+=(--session-dir "$target/sessions")
    (cd "$target" && PI_CODING_AGENT_DIR="$config_dir" pi "${_resume_args[@]}" --resume "$@")
    return
  fi

  # Default: create fresh workspace
  local ws="$ws_root/$(date +%Y-%m-%d-%H%M%S)"
  mkdir -p "$ws"
  while IFS= read -r subdir; do
    [[ -n "$subdir" && "$subdir" != \#* ]] && mkdir -p "$ws/$subdir"
  done < "$config_dir/workspace.conf"
  echo "Workspace: $ws"
  local _launch_args=()
  [ -d "$ws/sessions" ] && _launch_args+=(--session-dir "$ws/sessions")
  (cd "$ws" && PI_CODING_AGENT_DIR="$config_dir" pi "${_launch_args[@]}" "$@")
}

# ── retro workspace runner ──────────────────────────────────────────────────
#
# Non-interactive retro analysis targeting workspace directories.
# The existing pi-retro (auto-generated below) remains for manual in-situ use.
#
# User-facing:
#   run-retro <team>                        Analyze latest workspace
#   run-retro <team> <date-prefix>          Analyze workspace matching prefix
#   run-retro <team> --list                 List workspaces for team
#   run-retro <team> --pick                 Interactive menu to choose a workspace
#   run-retro <team> [date] -- "hint"       With optional steering prompt
#
# Internal (used by eval script):
#   run-retro --workspace-path <path> [-- "hint"]

run-retro() {
  local ws_path="" hint="" team=""

  if [ "${1:-}" = "--workspace-path" ]; then
    [ -z "${2:-}" ] && { echo "Error: --workspace-path requires a path" >&2; return 1; }
    ws_path="$2"
    shift 2
    team=$(basename "$(dirname "$ws_path")")
    if [ "${1:-}" = "--" ]; then shift; hint="$*"; fi
  else
    team="${1:?Usage: run-retro <team> [--list|--pick] [date-prefix] [-- hint]}"
    shift
    local ws_root="$DOT_MI_DIR/workspaces/$team"

    if [ "${1:-}" = "--list" ]; then
      if [ ! -d "$ws_root" ] || [ -z "$(ls -A "$ws_root" 2>/dev/null)" ]; then
        echo "No workspaces for $team"
        return 0
      fi
      echo "Workspaces for $team:"
      for d in "$ws_root"/*/; do
        [ -d "$d" ] || continue
        local ts=$(basename "$d")
        local files=$(find "$d" -maxdepth 2 -type f 2>/dev/null | wc -l | tr -d ' ')
        local has_retro=""
        [ -f "$d/retrospective-report.md" ] && has_retro="  [retro]"
        echo "  $ts  ($files files)$has_retro"
      done
      return 0
    fi

    if [ "${1:-}" = "--pick" ]; then
      shift
      local pick_paths=()
      local pick_labels=()
      local _d
      while IFS= read -r _d; do
        [ -z "$_d" ] && continue
        _d="${_d%/}"
        [ ! -d "$_d" ] && continue
        pick_paths+=("$_d")
        local _ts=$(basename "$_d")
        local _files=$(find "$_d" -maxdepth 2 -type f 2>/dev/null | wc -l | tr -d ' ')
        local _hr=""
        [ -f "$_d/retrospective-report.md" ] && _hr=" [retro]"
        pick_labels+=("$_ts  ($_files files)$_hr")
      done < <(ls -dt "$ws_root"/*/ 2>/dev/null)
      if [ ${#pick_paths[@]} -eq 0 ]; then
        echo "No workspaces for $team" >&2
        return 1
      fi
      echo "Select a workspace for $team:"
      local PS3="Number: "
      local _choice
      select _choice in "${pick_labels[@]}" "Cancel"; do
        if [ "$_choice" = "Cancel" ]; then
          echo "Cancelled." >&2
          return 1
        fi
        if [ -z "$_choice" ]; then
          echo "Invalid choice; try again." >&2
          continue
        fi
        local _idx=$((REPLY - 1))
        if [ "$_idx" -ge 0 ] && [ "$_idx" -lt ${#pick_paths[@]} ]; then
          ws_path="${pick_paths[$_idx]}"
          break
        fi
        echo "Invalid choice; try again." >&2
      done
    elif [ -n "${1:-}" ] && [ "$1" != "--" ]; then
      ws_path=$(ls -d "$ws_root/$1"* 2>/dev/null | tail -1)
      [ -z "$ws_path" ] && { echo "No workspace matching '$1' in $ws_root" >&2; return 1; }
      shift
    else
      ws_path=$(ls -dt "$ws_root"/*/ 2>/dev/null | head -1)
      [ -z "$ws_path" ] && { echo "No workspaces for $team" >&2; return 1; }
    fi

    if [ "${1:-}" = "--" ]; then shift; hint="$*"; fi
  fi

  [ ! -d "$ws_path" ] && { echo "Error: workspace not found: $ws_path" >&2; return 1; }

  local team_prompt="$DOT_MI_DIR/teams/$team/team-prompt.md"
  if [ -f "$team_prompt" ] && [ ! -e "$ws_path/.source-team-prompt.md" ]; then
    ln -s "$team_prompt" "$ws_path/.source-team-prompt.md"
  fi

  local prompt="Analyze this $team workspace."
  [ -n "$hint" ] && prompt="$prompt Focus: $hint"

  local retro_dir="$DOT_MI_DIR/teams/retro"
  local retro_sessions="$retro_dir/sessions"
  mkdir -p "$retro_sessions"
  echo "Retro: $ws_path"
  (cd "$ws_path" && PI_CODING_AGENT_DIR="$retro_dir" pi --session-dir "$retro_sessions" -p "$prompt" < /dev/null)
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
    eval "pi-${_dotmi_name}() { PI_CODING_AGENT_DIR=\"$_dotmi_dir\" pi \"\$@\"; }"
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
