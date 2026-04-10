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

_dotmi_workspace_launch() {
  local name="$1" config_dir="$2"
  shift 2
  local ws="$DOT_MI_DIR/workspaces/$name/$(date +%Y-%m-%d-%H%M%S)"
  mkdir -p "$ws"
  while IFS= read -r subdir; do
    [[ -n "$subdir" && "$subdir" != \#* ]] && mkdir -p "$ws/$subdir"
  done < "$config_dir/workspace.conf"
  echo "Workspace: $ws"
  (cd "$ws" && PI_CODING_AGENT_DIR="$config_dir" pi "$@")
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
