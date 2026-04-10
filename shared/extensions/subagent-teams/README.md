# Subagent Teams Example

Delegate tasks to team-organized specialized subagents with isolated context windows.

Extends the [subagent](../subagent/README.md) example with team-based agent filtering.

## Features

- **Team-based filtering**: Restrict visible agents to a specific team
- **Filename convention**: Teams derived from `team-agentname.md` naming
- **Frontmatter override**: `team` field in frontmatter takes precedence over filename
- **Isolated context**: Each subagent runs in a separate `pi` process
- **Streaming output**: See tool calls and progress as they happen
- **Parallel streaming**: All parallel tasks stream updates simultaneously
- **Markdown rendering**: Final output rendered with proper formatting (expanded view)
- **Usage tracking**: Shows turns, tokens, cost, and context usage per agent
- **Abort support**: Ctrl+C propagates to kill subagent processes

## Structure

```
subagent-teams/
├── README.md            # This file
├── index.ts             # The extension (entry point)
├── agents.ts            # Agent discovery logic with team support
├── agents/              # Sample agent definitions
│   ├── recon-scout.md   # [recon] Fast recon, returns compressed context
│   ├── recon-planner.md # [recon] Creates implementation plans
│   ├── impl-worker.md   # [impl] General-purpose (full capabilities)
│   └── impl-reviewer.md # [impl] Code review
└── prompts/             # Workflow presets (prompt templates)
    ├── implement.md         # recon team scouts+plans, impl team implements
    └── implement-and-review.md  # impl team: worker -> reviewer -> worker
```

## Installation

From the repository root, symlink the files:

```bash
# Symlink the extension (must be in a subdirectory with index.ts)
mkdir -p ~/.pi/agent/extensions/subagent-teams
ln -sf "$(pwd)/packages/coding-agent/examples/extensions/subagent-teams/index.ts" ~/.pi/agent/extensions/subagent-teams/index.ts
ln -sf "$(pwd)/packages/coding-agent/examples/extensions/subagent-teams/agents.ts" ~/.pi/agent/extensions/subagent-teams/agents.ts

# Symlink agents
mkdir -p ~/.pi/agent/agents
for f in packages/coding-agent/examples/extensions/subagent-teams/agents/*.md; do
  ln -sf "$(pwd)/$f" ~/.pi/agent/agents/$(basename "$f")
done

# Symlink workflow prompts
mkdir -p ~/.pi/agent/prompts
for f in packages/coding-agent/examples/extensions/subagent-teams/prompts/*.md; do
  ln -sf "$(pwd)/$f" ~/.pi/agent/prompts/$(basename "$f")
done
```

**Note**: If you also have the original `subagent` extension installed, both will register a tool named `subagent`. Remove or disable the original to avoid conflicts.

## Team Naming Convention

Agent files use the pattern `team-agentname.md`:

```
recon-scout.md      → team: recon, name: scout
recon-planner.md    → team: recon, name: planner
impl-worker.md      → team: impl,  name: worker
impl-reviewer.md    → team: impl,  name: reviewer
scout.md            → team: (none), name: scout
```

The first `-` in the filename separates team from agent name. Files without a `-` have no team and are visible regardless of team filter.

A `team` field in YAML frontmatter overrides the filename-derived team:

```markdown
---
name: my-agent
description: Custom agent
team: custom-team
---
```

## Usage

### Single agent (any team)
```
Use scout to find all authentication code
```

### Single agent (filtered to team)
```
Use the subagent tool with team "recon" to have scout find all auth code
```

### Parallel execution within a team
```
Run 2 agents from the recon team in parallel: scout finds models, planner reviews architecture
```

### Cross-team chain
```
Chain: recon team's scout finds code, then impl team's worker implements changes
```

### Workflow prompts
```
/implement add Redis caching to the session store
/implement-and-review add input validation to API endpoints
```

## Tool Modes

| Mode | Parameter | Description |
|------|-----------|-------------|
| Single | `{ agent, task, team? }` | One agent, one task |
| Parallel | `{ tasks: [...], team? }` | Multiple agents run concurrently (max 8, 4 concurrent) |
| Chain | `{ chain: [...], team? }` | Sequential with `{previous}` placeholder |

The `team` parameter is optional in all modes. When set, only agents belonging to that team are visible. When omitted, all agents are available.

## Agent Definitions

Agents are markdown files with YAML frontmatter:

```markdown
---
name: my-agent
description: What this agent does
team: my-team
tools: read, grep, find, ls
model: claude-haiku-4-5
---

System prompt for the agent goes here.
```

**Locations:**
- `~/.pi/agent/agents/*.md` - User-level (always loaded)
- `.pi/agents/*.md` - Project-level (only with `agentScope: "project"` or `"both"`)

Project agents override user agents with the same name when `agentScope: "both"`.

## Sample Teams

### `recon` - Reconnaissance
| Agent | Purpose | Model | Tools |
|-------|---------|-------|-------|
| `scout` | Fast codebase recon | Haiku | read, grep, find, ls, bash |
| `planner` | Implementation plans | Sonnet | read, grep, find, ls |

### `impl` - Implementation
| Agent | Purpose | Model | Tools |
|-------|---------|-------|-------|
| `worker` | General-purpose | Sonnet | (all default) |
| `reviewer` | Code review | Sonnet | read, grep, find, ls, bash |

## Error Handling

- **Exit code != 0**: Tool returns error with stderr/output
- **stopReason "error"**: LLM error propagated with error message
- **stopReason "aborted"**: User abort (Ctrl+C) kills subprocess, throws error
- **Chain mode**: Stops at first failing step, reports which step failed

## Limitations

- Output truncated to last 10 items in collapsed view (expand to see all)
- Agents discovered fresh on each invocation (allows editing mid-session)
- Parallel mode limited to 8 tasks, 4 concurrent
