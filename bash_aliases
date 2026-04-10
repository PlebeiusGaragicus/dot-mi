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

# ── team aliases ─────────────────────────────────────────────────────────────
#
# Each alias points PI_CODING_AGENT_DIR at a self-contained team directory.
# pi loads extensions, agents, prompts, sessions, and settings from there.

pi-recon() {
  PI_CODING_AGENT_DIR="$DOT_MI_DIR/teams/recon" pi "$@"
}

pi-impl() {
  PI_CODING_AGENT_DIR="$DOT_MI_DIR/teams/impl" pi "$@"
}

pi-blog() {
  PI_CODING_AGENT_DIR="$DOT_MI_DIR/teams/blog" pi "$@"
}

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
