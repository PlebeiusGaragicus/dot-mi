#!/bin/bash

# ── dot-mi: unified pi agent launcher ───────────────────────────────────────
#
# Source this file from ~/.bashrc or ~/.zshrc:
#   source ~/path/to/dot-mi/bash_aliases
#
# Provides a single `p` command that dispatches to any team or agent:
#   p <name> [flags...] [prompt]
#   echo "prompt" | p <name>
#
# DOT_MI_DIR is auto-detected from this script's location.
# Override by setting DOT_MI_DIR before sourcing.

# disable version telemetry
PI_TELEMETRY=0

# auto-detect DOT_MI_DIR from this script's location
DOT_MI_DIR="${DOT_MI_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)}"

# Load API keys if present
[ -f "$DOT_MI_DIR/.env" ] && source "$DOT_MI_DIR/.env"

# ── workspace launcher ───────────────────────────────────────────────────────
#
# Used by `p` when a team/agent has a workspace.conf file.
# Creates a fresh dated directory, pre-creates subdirs listed in workspace.conf,
# then launches pi inside a subshell so the user's shell stays put after exit.
#
# Flags:
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
    echo "Resuming: $target" >&2
    local _resume_args=()
    [ -d "$target/sessions" ] && _resume_args+=(--session-dir "$target/sessions")
    (cd "$target" && PI_CODING_AGENT_DIR="$config_dir" pi "${_resume_args[@]}" --resume "$@")
    return $?
  fi

  # Default: create fresh workspace
  local ws="$ws_root/$(date +%Y-%m-%d-%H%M%S)"
  mkdir -p "$ws"
  while IFS= read -r subdir; do
    [[ -n "$subdir" && "$subdir" != \#* ]] && mkdir -p "$ws/$subdir"
  done < "$config_dir/workspace.conf"
  echo "Workspace: $ws" >&2
  local _launch_args=()
  [ -d "$ws/sessions" ] && _launch_args+=(--session-dir "$ws/sessions")
  (cd "$ws" && PI_CODING_AGENT_DIR="$config_dir" pi "${_launch_args[@]}" "$@")
  return $?
}

# ── retro workspace runner ──────────────────────────────────────────────────
#
# Non-interactive retro analysis targeting workspace directories.
# For manual in-situ use: p retro
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
  echo "Retro: $ws_path" >&2
  (cd "$ws_path" && PI_CODING_AGENT_DIR="$retro_dir" pi --mode json \
    --session-dir "$retro_sessions" -p "$prompt" < /dev/null) | _dotmi_json_filter
  return ${PIPESTATUS[0]:-${pipestatus[1]:-$?}}
}

# ── p: unified agent dispatcher ──────────────────────────────────────────────
#
# Single entry point for all teams, agents, and built-in bots.
#
#   p <name> [flags...] [prompt]        Team or agent by name
#   p <name> -p "do something"          Explicit prompt (non-interactive)
#   echo "do something" | p <name>      Pipe stdin as prompt (non-interactive)
#   p <name>                            Interactive (tty)
#   p <name> --list                     Workspace teams: list past runs
#   p <name> --resume [prefix]          Workspace teams: resume a run
#
# Built-in bots (no PI_CODING_AGENT_DIR, flags passed directly to pi):
#   p chat [prompt]
#   p explain [prompt]

_dotmi_has_flag() {
  local flag="$1"; shift
  for arg in "$@"; do [ "$arg" = "$flag" ] && return 0; done
  return 1
}

# ── batch mode filter ────────────────────────────────────────────────────────
#
# Reads pi's --mode json event stream from stdin.
# Emits compact progress lines to stderr.
# Emits only the final assistant text to stdout.

_dotmi_json_filter() {
  local turn=0 final_text=""
  while IFS= read -r line; do
    local type
    type=$(printf '%s' "$line" | jq -r '.type // empty' 2>/dev/null) || continue
    case "$type" in
      turn_start)
        turn=$((turn + 1))
        ;;
      tool_execution_start)
        local tool_name
        tool_name=$(printf '%s' "$line" | jq -r '.toolName // "?"')
        printf '[turn %d] tool: %s\n' "$turn" "$tool_name" >&2
        ;;
      tool_execution_end)
        local tool_name is_err
        tool_name=$(printf '%s' "$line" | jq -r '.toolName // "?"')
        is_err=$(printf '%s' "$line" | jq -r '.isError // false')
        if [ "$is_err" = "true" ]; then
          printf '[turn %d] tool: %s ERROR\n' "$turn" "$tool_name" >&2
        fi
        ;;
      message_end)
        local role text
        role=$(printf '%s' "$line" | jq -r '.message.role // empty')
        if [ "$role" = "assistant" ]; then
          text=$(printf '%s' "$line" | jq -r '
            [.message.content[]? | select(.type == "text") | .text]
            | join("\n")' 2>/dev/null)
          [ -n "$text" ] && final_text="$text"
        fi
        ;;
      agent_end)
        printf '[agent done]\n' >&2
        ;;
    esac
  done
  [ -n "$final_text" ] && printf '%s\n' "$final_text"
}

p() {
  local name="${1:?Usage: p <name> [flags...] [prompt]}"
  shift

  # Built-in bots (no team/agent directory)
  case "$name" in
    chat)
      pi \
        --system-prompt 'You are a knowledgeable and informative chatbot.
You help with answering questions, explaining concepts, brainstorming ideas, and casual conversation.
Be conversational and approachable while remaining terse and to-the-point.' \
        --tools read,grep,find,ls \
        --no-skills \
        --no-prompt-templates \
        --no-themes \
        "$@"
      return $?
      ;;
    explain)
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
      return $?
      ;;
  esac

  # Resolve config directory: teams/ first, then agents/
  local config_dir=""
  if [ -d "$DOT_MI_DIR/teams/$name" ]; then
    config_dir="$DOT_MI_DIR/teams/$name"
  elif [ -d "$DOT_MI_DIR/agents/$name" ]; then
    config_dir="$DOT_MI_DIR/agents/$name"
  else
    echo "p: unknown agent or team: $name" >&2
    echo "Available:" >&2
    (cd "$DOT_MI_DIR" && ls -d teams/*/  agents/*/ 2>/dev/null | sed 's|.*/\(.*\)/|  \1|')
    return 1
  fi

  # Detect batch mode: non-tty stdin or -p flag present
  local _batch=false
  if [ ! -t 0 ] || _dotmi_has_flag "-p" "$@"; then
    _batch=true
  fi

  # Stdin pipe detection: if stdin is not a tty and -p wasn't given,
  # read stdin and pass it as -p.
  if [ ! -t 0 ] && ! _dotmi_has_flag "-p" "$@"; then
    local _stdin_prompt
    _stdin_prompt=$(cat)
    set -- -p "$_stdin_prompt" "$@"
  fi

  # In batch mode, use JSON event stream and pipe through progress filter.
  # Progress goes to stderr, final assistant text goes to stdout.
  if [ "$_batch" = true ]; then
    set -- --mode json "$@"
  fi

  # Dispatch: workspace or in-situ
  if [ -f "$config_dir/workspace.conf" ]; then
    if [ "$_batch" = true ]; then
      _dotmi_workspace_launch "$name" "$config_dir" "$@" | _dotmi_json_filter
      return ${PIPESTATUS[0]:-${pipestatus[1]:-$?}}
    else
      _dotmi_workspace_launch "$name" "$config_dir" "$@"
      return $?
    fi
  else
    if [ "$_batch" = true ]; then
      PI_CODING_AGENT_DIR="$config_dir" pi "$@" | _dotmi_json_filter
      return ${PIPESTATUS[0]:-${pipestatus[1]:-$?}}
    else
      PI_CODING_AGENT_DIR="$config_dir" pi "$@"
      return $?
    fi
  fi
}
