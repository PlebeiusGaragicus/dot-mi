#! /bin/bash

# API key for PlebChat models
source "$HOME/dot-pi/.env"

# default tools: (if no flag): read,bash,edit,write
#
#  │ read  │ Read file contents                               │
#  │ bash  │ Execute bash commands                            │
#  │ edit  │ Edit files with find/replace                     │
#  │ write │ Write files (creates/overwrites)                 │
# ...
#  │ grep  │ Search file contents (read-only, off by default) │
#  │ find  │ Find files matching criteria (read-only)         │
#  │ ls    │ List directory contents (read-only)              │

PI_SESSIONS="$HOME/dot-pi/sessions"

# ── pi bot functions ─────────────────────────────────────────────────────────

pchat() {
  pi \
    --session-dir "$PI_SESSIONS" \
    --system-prompt 'You are knowledgeable and informative chatbot - used as an oracle to ask various questions you'\''d know how to explain.
You can help with answering questions, explaining concepts, brainstorming ideas, and casual conversation.
Be conversational and approachable in your responses while remaining terse and to-the-point.' \
    --append-system-prompt "" \
    --tools read,grep,find,ls \
    -e "$HOME/dot-pi/extensions/minimal.ts" \
    --no-skills \
    --no-prompt-templates \
    --no-themes \
    "$@"
}

pexplain() {
  pi \
    --session-dir "$PI_SESSIONS" \
    --system-prompt 'You are a codebase analyst. Your job is to thoroughly review the current repository or directory and provide a detailed, well-structured report in response to the user'\''s query.

Start by exploring the project structure, reading key files (README, config, entry points, etc.), and tracing relevant code paths. Then deliver a clear summary covering:
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

pdeep() {
  local RUN_ID=$(date +%Y-%m-%d_%H%M)
  export AGENT_TEAM="deepnews"
  local TEAM_DIR="$HOME/dot-pi/workspaces/$AGENT_TEAM"
  local WORKSPACE="$TEAM_DIR/$RUN_ID"
  mkdir -p "$WORKSPACE/stories" "$WORKSPACE/sources" "$WORKSPACE/sources/images" "$WORKSPACE/sessions" \
           "$TEAM_DIR/topics"
  export AGENT_WORKSPACE="$WORKSPACE"
  pi \
    --session "$WORKSPACE/session.jsonl" \
    -e "$HOME/dot-pi/extensions/orchestration/agent-team-new.ts" \
    -e "$HOME/dot-pi/extensions/ui/topic-edit.ts" \
    -e "$HOME/dot-pi/extensions/ui/theme-cycler.ts" \
    --theme "$HOME/dot-pi/themes/synthwave.json" \
    "$@"
}

# ── team orchestrators ───────────────────────────────────────────────────────

pteam() {
  pi \
    --session-dir "$PI_SESSIONS" \
    -e "$HOME/dot-pi/extensions/orchestration/agent-team.ts" \
    -e "$HOME/dot-pi/extensions/ui/theme-cycler.ts" \
    --theme "$HOME/dot-pi/themes" \
    "$@"
}

pteam2() {
  pi \
    --session-dir "$PI_SESSIONS" \
    -e "$HOME/dot-pi/extensions/orchestration/agent-team-2.ts" \
    -e "$HOME/dot-pi/extensions/ui/theme-cycler.ts" \
    --theme "$HOME/dot-pi/themes" \
    "$@"
}

pretro() {
  local RUN_ID=$(date +%Y-%m-%d_%H%M)
  local RETRO_WORKSPACE="$HOME/dot-pi/workspaces/retro/$RUN_ID"
  mkdir -p "$RETRO_WORKSPACE/sessions"

  local TARGET=""
  if [ -n "${1:-}" ]; then
    if [ -d "$1" ]; then
      TARGET="$1"
    elif [ -d "$HOME/dot-pi/workspaces/$1" ]; then
      TARGET="$(ls -dt "$HOME/dot-pi/workspaces/$1"/*/ 2>/dev/null | head -1)"
    fi
    shift
  fi
  if [ -z "$TARGET" ]; then
    TARGET="$(ls -dt "$HOME/dot-pi/workspaces"/*/*/ 2>/dev/null | grep -v '/retro/' | head -1)"
  fi

  export AGENT_TEAM="retro"
  export AGENT_WORKSPACE="$RETRO_WORKSPACE"
  export RETRO_TARGET="$TARGET"

  pi \
    --session "$RETRO_WORKSPACE/session.jsonl" \
    -e "$HOME/dot-pi/extensions/orchestration/agent-team-2.ts" \
    -e "$HOME/dot-pi/extensions/ui/theme-cycler.ts" \
    --theme "$HOME/dot-pi/themes" \
    --prompt-template "$HOME/dot-pi/prompts" \
    "$@"
}
