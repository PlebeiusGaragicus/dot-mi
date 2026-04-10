#!/usr/bin/env bash
set -euo pipefail

DOT_MI_DIR="$(cd "$(dirname "$0")" && pwd)"
SHARED_DIR="$DOT_MI_DIR/shared"

usage() {
  cat <<EOF
dot-mi team manager

Usage: $(basename "$0") <command> [args]

Commands:
  create <team-name>     Create a new team directory with shared extension symlinks
  list                   List existing teams and their agents
  link-auth <src> <dst>  Symlink auth.json from one team (or path) into another

Examples:
  $(basename "$0") create blog
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
  echo "    sessions/            (runtime session data, gitignored)"
  echo "    models.json          (symlinked to shared)"
  echo ""
  echo "Next steps:"
  echo "  1. Add agent .md files to $team_dir/agents/"
  echo "  2. Add prompt templates to $team_dir/prompts/"
  echo "  3. Source bash_aliases and invoke: pi-$team_name \"your task\""
}

list_teams() {
  local found=0
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
    echo "  (no teams found -- run '$0 create <name>' to create one)"
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
  else
    echo "Error: cannot find auth.json at '$src' or in team '$src'"
    exit 1
  fi

  local dst_dir="$DOT_MI_DIR/teams/$dst"
  if [ ! -d "$dst_dir" ]; then
    echo "Error: team '$dst' does not exist"
    exit 1
  fi

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
