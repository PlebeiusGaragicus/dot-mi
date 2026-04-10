#!/usr/bin/env bash
set -euo pipefail

DOT_MI_DIR="$(cd "$(dirname "$0")" && pwd)"
SHARED_DIR="$DOT_MI_DIR/shared"

usage() {
  cat <<EOF
dot-mi manager

Usage: $(basename "$0") <command> [args]

Commands:
  create <team-name>         Create a new team directory with shared extension symlinks
  create-agent <agent-name>  Create a standalone agent directory with a stub extension
  list                       List existing teams and standalone agents
  link-auth <src> <dst>      Symlink auth.json from one team/agent (or path) into another

Examples:
  $(basename "$0") create blog
  $(basename "$0") create-agent twenty-questions
  $(basename "$0") list
  $(basename "$0") link-auth recon blog
EOF
  exit 1
}

create_team() {
  local team_name="$1"
  local team_dir="$DOT_MI_DIR/teams/$team_name"

  if [ -d "$team_dir" ]; then
    echo "Error: team '$team_name' already exists at $team_dir"
    exit 1
  fi

  echo "Creating team '$team_name'..."
  mkdir -p "$team_dir/extensions" "$team_dir/agents" "$team_dir/prompts" "$team_dir/skills" "$team_dir/sessions"

  # Symlink shared extensions into the team's extensions/ directory.
  # pi auto-discovers extensions from <agentDir>/extensions/.
  ln -sf "../../../shared/extensions/subagent-teams" "$team_dir/extensions/subagent-teams"
  ln -sf "../../../shared/extensions/run-finish-notify.ts" "$team_dir/extensions/run-finish-notify.ts"
  ln -sf "../../../shared/extensions/auto-theme.ts" "$team_dir/extensions/auto-theme.ts"

  # Symlink each shared skill individually into the team's skills/ directory.
  # pi auto-discovers skills from <agentDir>/skills/.
  # Remove unwanted symlinks to exclude skills from a team.
  # Per-agent skill selection is also controlled via frontmatter (skills, no-skills).
  for skill in "$SHARED_DIR"/skills/*/; do
    [ -d "$skill" ] || continue
    ln -sf "../../../shared/skills/$(basename "$skill")" "$team_dir/skills/$(basename "$skill")"
  done

  # Symlink each shared theme individually into the team's themes/ directory.
  # pi auto-discovers themes from <agentDir>/themes/.
  mkdir -p "$team_dir/themes"
  for theme in "$SHARED_DIR"/themes/*.json; do
    [ -f "$theme" ] || continue
    ln -sf "../../../shared/themes/$(basename "$theme")" "$team_dir/themes/$(basename "$theme")"
  done

  # Symlink shared bin directory.
  # pi downloads fd/rg here on first run; the symlink means all teams share one copy.
  mkdir -p "$SHARED_DIR/bin"
  ln -sf "../../shared/bin" "$team_dir/bin"

  # Symlink shared model provider config
  ln -sf "../../shared/models.json" "$team_dir/models.json"

  echo "Created team at $team_dir"
  echo ""
  echo "Directory layout:"
  echo "  $team_dir/"
  echo "    extensions/          (symlinked to shared)"
  echo "    agents/              (add your agent .md files here)"
  echo "    prompts/             (add workflow prompt templates here)"
  echo "    skills/              (individual skills symlinked from shared)"
  echo "    themes/              (individual themes symlinked from shared)"
  echo "    bin/                 (symlinked to shared/bin, gitignored contents)"
  echo "    sessions/            (runtime session data, gitignored)"
  echo "    models.json          (symlinked to shared)"
  echo ""
  echo "Next steps:"
  echo "  1. Add agent .md files to $team_dir/agents/"
  echo "  2. Add prompt templates to $team_dir/prompts/"
  echo "  3. Source bash_aliases and invoke: pi-$team_name \"your task\""
}

create_agent() {
  local agent_name="$1"
  local agent_dir="$DOT_MI_DIR/agents/$agent_name"

  if [ -d "$agent_dir" ]; then
    echo "Error: agent '$agent_name' already exists at $agent_dir"
    exit 1
  fi

  echo "Creating standalone agent '$agent_name'..."
  mkdir -p "$agent_dir/extensions/$agent_name" "$agent_dir/skills" "$agent_dir/sessions"

  # Symlink shared extensions (but NOT subagent-teams -- standalone agents don't need it).
  ln -sf "../../../shared/extensions/run-finish-notify.ts" "$agent_dir/extensions/run-finish-notify.ts"
  ln -sf "../../../shared/extensions/auto-theme.ts" "$agent_dir/extensions/auto-theme.ts"

  # Create a stub extension for the agent to customize
  cat > "$agent_dir/extensions/$agent_name/index.ts" <<'STUB'
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

export default function (pi: ExtensionAPI) {
	// Add lifecycle hooks and custom tools here.
	// See AGENTS.md or docs/reference/extensions.md for the full API.
}
STUB

  # Symlink shared skills, themes, bin, models (same as teams)
  for skill in "$SHARED_DIR"/skills/*/; do
    [ -d "$skill" ] || continue
    ln -sf "../../../shared/skills/$(basename "$skill")" "$agent_dir/skills/$(basename "$skill")"
  done

  mkdir -p "$agent_dir/themes"
  for theme in "$SHARED_DIR"/themes/*.json; do
    [ -f "$theme" ] || continue
    ln -sf "../../../shared/themes/$(basename "$theme")" "$agent_dir/themes/$(basename "$theme")"
  done

  mkdir -p "$SHARED_DIR/bin"
  ln -sf "../../shared/bin" "$agent_dir/bin"

  ln -sf "../../shared/models.json" "$agent_dir/models.json"

  echo "Created standalone agent at $agent_dir"
  echo ""
  echo "Directory layout:"
  echo "  $agent_dir/"
  echo "    extensions/$agent_name/  (your custom extension)"
  echo "    skills/                  (individual skills symlinked from shared)"
  echo "    themes/                  (individual themes symlinked from shared)"
  echo "    bin/                     (symlinked to shared/bin, gitignored contents)"
  echo "    sessions/                (runtime session data, gitignored)"
  echo "    models.json              (symlinked to shared)"
  echo ""
  echo "Next steps:"
  echo "  1. Edit $agent_dir/extensions/$agent_name/index.ts"
  echo "  2. Source bash_aliases and invoke: pi-$agent_name \"your task\""
}

list_teams() {
  local found=0

  echo "Teams:"
  for dir in "$DOT_MI_DIR"/teams/*/; do
    [ -d "$dir" ] || continue
    local name
    name=$(basename "$dir")
    found=1
    local agent_count
    agent_count=$(find "$dir/agents" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
    local prompt_count
    prompt_count=$(find "$dir/prompts" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
    local ext_ok="no"
    [ -e "$dir/extensions/subagent-teams/index.ts" ] && ext_ok="yes"
    echo "  $name  ($agent_count agents, $prompt_count prompts, extensions linked: $ext_ok)"
  done
  if [ "$found" -eq 0 ]; then
    echo "  (none -- run '$0 create <name>' to create one)"
  fi

  echo ""
  echo "Standalone agents:"
  local agent_found=0
  for dir in "$DOT_MI_DIR"/agents/*/; do
    [ -d "$dir" ] || continue
    local name
    name=$(basename "$dir")
    agent_found=1
    local ext_count
    ext_count=$(find "$dir/extensions" -maxdepth 2 -name 'index.ts' 2>/dev/null | wc -l | tr -d ' ')
    echo "  $name  (extensions: $ext_count)"
  done
  if [ "$agent_found" -eq 0 ]; then
    echo "  (none -- run '$0 create-agent <name>' to create one)"
  fi
}

resolve_dir() {
  local name="$1"
  if [ -d "$DOT_MI_DIR/teams/$name" ]; then
    echo "$DOT_MI_DIR/teams/$name"
  elif [ -d "$DOT_MI_DIR/agents/$name" ]; then
    echo "$DOT_MI_DIR/agents/$name"
  else
    return 1
  fi
}

link_auth() {
  local src="$1"
  local dst="$2"

  local src_path
  if [ -f "$src" ]; then
    src_path="$(cd "$(dirname "$src")" && pwd)/$(basename "$src")"
  elif [ -f "$DOT_MI_DIR/teams/$src/auth.json" ]; then
    src_path="$DOT_MI_DIR/teams/$src/auth.json"
  elif [ -f "$DOT_MI_DIR/agents/$src/auth.json" ]; then
    src_path="$DOT_MI_DIR/agents/$src/auth.json"
  else
    echo "Error: cannot find auth.json at '$src' or in team/agent '$src'"
    exit 1
  fi

  local dst_dir
  dst_dir=$(resolve_dir "$dst") || {
    echo "Error: '$dst' does not exist as a team or agent"
    exit 1
  }

  ln -sf "$src_path" "$dst_dir/auth.json"
  echo "Linked $dst_dir/auth.json -> $src_path"
}

# ── main ─────────────────────────────────────────────────────────────────────

[ $# -lt 1 ] && usage

case "$1" in
  create)
    [ $# -lt 2 ] && { echo "Error: team name required"; usage; }
    create_team "$2"
    ;;
  create-agent)
    [ $# -lt 2 ] && { echo "Error: agent name required"; usage; }
    create_agent "$2"
    ;;
  list)
    list_teams
    ;;
  link-auth)
    [ $# -lt 3 ] && { echo "Error: source and destination required"; usage; }
    link_auth "$2" "$3"
    ;;
  *)
    echo "Error: unknown command '$1'"
    usage
    ;;
esac
