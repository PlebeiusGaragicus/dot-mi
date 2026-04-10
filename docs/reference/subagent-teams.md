# Subagent Teams Extension

The `subagent-teams` extension is a team-aware fork of the upstream pi `subagent` example. It registers a `subagent` tool that spawns isolated pi child processes, each with their own context window.

Source: `shared/extensions/subagent-teams/`

## Agent Definition Format

Agents are markdown files with YAML frontmatter stored in `<agentDir>/agents/`:

```markdown
---
name: scout
description: Fast codebase recon
team: recon
tools: read, grep, find, ls, bash
skills: skills/searxng
no-skills: true
---

System prompt goes here. This becomes the --append-system-prompt
for the spawned pi child process.
```

### Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | No | Agent name (defaults to filename-derived name) |
| `description` | **Yes** | Short description (shown to the LLM for agent selection) |
| `team` | No | Team name (overrides filename convention) |
| `tools` | No | Comma-separated tool whitelist (omit for all defaults) |
| `skills` | No | Comma-separated skill paths (relative to team dir or absolute) |
| `no-skills` | No | If `true`, disables skill auto-discovery for this agent |
| `model` | No | Model override for this agent |

### Per-Agent Skills

By default, each subagent inherits all skills from the team's `skills/` directory. The `skills` and `no-skills` fields give per-agent control:

| `no-skills` | `skills` | Result |
|-------------|----------|--------|
| absent | absent | All team skills auto-discovered (default) |
| absent | set | Team skills + additional explicit skills |
| `true` | absent | No skills |
| `true` | set | Only the listed skills |

Skill paths are resolved relative to the team directory (`PI_CODING_AGENT_DIR`). For example, `skills: skills/searxng` resolves to `teams/<team>/skills/searxng`.

Shared skills live in `shared/skills/` and are individually symlinked into each team's `skills/` directory (e.g. `teams/blog/skills/searxng -> ../../../shared/skills/searxng`). To exclude a skill from a team, remove its symlink. To restrict at the agent level, use `no-skills: true` with an explicit `skills:` list.

## Team Naming Convention

The first `-` in the filename separates team from agent name:

| Filename | Team | Agent Name |
|----------|------|------------|
| `recon-scout.md` | recon | scout |
| `impl-worker.md` | impl | worker |
| `blog-editor.md` | blog | editor |
| `scout.md` | *(none)* | scout |

A `team` field in frontmatter overrides the filename-derived team.

## Tool Modes

### Single

```json
{ "agent": "scout", "task": "Find all auth code", "team": "recon" }
```

### Parallel

```json
{
  "tasks": [
    { "agent": "scout", "task": "Find auth code" },
    { "agent": "planner", "task": "Review architecture" }
  ],
  "team": "recon"
}
```

Up to 8 tasks, 4 concurrent.

### Chain

```json
{
  "chain": [
    { "agent": "scout", "task": "Find code related to auth" },
    { "agent": "planner", "task": "Plan changes based on: {previous}" },
    { "agent": "worker", "task": "Implement the plan: {previous}" }
  ]
}
```

Sequential pipeline. `{previous}` is replaced with the prior step's output.

## Agent Discovery

Agents are discovered fresh on each tool invocation from two locations:

1. **User-level**: `<PI_CODING_AGENT_DIR>/agents/`
2. **Project-level**: `.pi/agents/` (relative to cwd, walking up)

The `agentScope` parameter controls which are loaded (`"user"`, `"project"`, or `"both"`). Project agents override user agents with the same name when scope is `"both"`.
