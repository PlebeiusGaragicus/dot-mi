# dot-mi — Agent Guide

> Quick-reference for LLM coding agents (Cursor, pi, Copilot) working in this repo.
> For human-facing docs, see `docs/` or the deployed MkDocs site.

## What This Repo Is

dot-mi is a **dotfiles-style** repository for [pi](https://github.com/PlebeiusGaragicus/pi-mono) (a coding agent). It manages multiple isolated agent configurations via the `PI_CODING_AGENT_DIR` environment variable. When set, pi loads all config (extensions, agents, prompts, skills, sessions, models, themes) from that directory instead of `~/.pi/agent/`.

Two kinds of agent configurations live here:

- **Teams** (`teams/`): Multi-agent setups with the `subagent-teams` extension for orchestrated delegation (single, parallel, chain).
- **Standalone agents** (`agents/`): Single-agent setups with custom extensions and no subagent orchestration.

Either kind can run **in-situ** (in the user's current directory) or as a **workspace** agent (in a fresh dated directory). A `workspace.conf` file marks which mode to use — see "Workspace Agents" under Key Concepts.

## Directory Structure

```
dot-mi/
├── AGENTS.md                 # This file
├── README.md                 # Human-facing overview
├── setup.sh                  # Scaffold teams and agents
├── bash_aliases              # Shell aliases (source in .zshrc/.bashrc)
├── example.env               # API key template (copy to .env)
├── mkdocs.yml                # MkDocs config for docs site
│
├── shared/                   # Reusable resources (never used as PI_CODING_AGENT_DIR directly)
│   ├── extensions/
│   │   ├── subagent-teams/   # Team-aware subagent extension (index.ts + agents.ts)
│   │   ├── run-finish-notify.ts  # Desktop notification on agent completion
│   │   └── startup-branding.ts   # Renders banner.txt as startup header
│   ├── skills/               # Shared skill definitions (SKILL.md files)
│   ├── themes/               # Shared themes (JSON)
│   ├── bin/                  # Downloaded binaries (fd, rg) — gitignored contents
│   └── models.json           # Custom model provider config
│
├── teams/                    # Multi-agent team directories
│   ├── recon/                # Reconnaissance & planning (scout, planner)
│   ├── impl/                 # Implementation & review (worker, reviewer)
│   ├── blog/                 # Blog content (researcher, writer, editor)
│   └── deepresearch/         # Web research (scout, collector, writer, editor)
│
├── agents/                   # Standalone agent directories
│   └── twenty-questions/     # Example: 20 questions game with TUI overlay
│
├── workspaces/               # Ephemeral workspace directories (gitignored contents)
│   └── deepresearch/         # Dated subdirs created per-run
├── docs/                     # MkDocs documentation source
└── pi-mono/                  # Read-only git submodule of upstream pi
```

### Team Directory Layout (`teams/<name>/`)

Each is a complete `PI_CODING_AGENT_DIR` root:

```
teams/<name>/
├── extensions/               # Symlinked from shared/extensions/
│   ├── subagent-teams/       # → shared/extensions/subagent-teams/
│   ├── run-finish-notify.ts  # → shared/extensions/run-finish-notify.ts
│   └── startup-branding.ts   # → shared/extensions/startup-branding.ts
├── agents/                   # Subagent definitions (team-agentname.md)
├── prompts/                  # Prompt templates (slash-command workflows)
├── skills/                   # Symlinked from shared/skills/ (per-skill)
├── themes/                   # Symlinked from shared/themes/
├── team-prompt.md            # Orchestrator instructions (injected into main agent)
├── banner.txt                # Startup branding (ASCII art + usage text)
├── workspace.conf            # (optional) Marks as workspace agent; lists subdirs to pre-create
├── bin/                      # → shared/bin/
├── models.json               # → shared/models.json
├── sessions/                 # Runtime (gitignored)
├── settings.json             # Pi settings (theme, quietStartup; gitignored)
└── auth.json                 # API auth (gitignored, may be symlinked)
```

### Standalone Agent Layout (`agents/<name>/`)

Same `PI_CODING_AGENT_DIR` root but without subagent orchestration:

```
agents/<name>/
├── extensions/
│   ├── <name>/               # Custom extension (index.ts)
│   ├── run-finish-notify.ts  # → shared/extensions/run-finish-notify.ts
│   └── startup-branding.ts   # → shared/extensions/startup-branding.ts
├── skills/                   # Symlinked from shared/skills/
├── themes/                   # Symlinked from shared/themes/
├── banner.txt                # Startup branding (ASCII art + usage text)
├── workspace.conf            # (optional) Marks as workspace agent; lists subdirs to pre-create
├── bin/                      # → shared/bin/
├── models.json               # → shared/models.json
├── sessions/                 # Runtime (gitignored)
├── settings.json             # Pi settings (theme, quietStartup; gitignored)
└── auth.json                 # API auth (gitignored, may be symlinked)
```

No `agents/` subdirectory, no `team-prompt.md`. The main pi process IS the agent. Custom behavior comes from the extension.

## Key Concepts

### Extensions

TypeScript modules in `<agentDir>/extensions/`. Auto-discovered by pi on startup.

**Shape**: Default-exported function `(pi: ExtensionAPI) => void`.

**Imports**:
```typescript
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { getAgentDir, getMarkdownTheme, withFileMutationQueue, parseFrontmatter } from "@mariozechner/pi-coding-agent";
import { Container, Markdown, Spacer, Text } from "@mariozechner/pi-tui";
import type { AgentToolResult } from "@mariozechner/pi-agent-core";
import type { Message } from "@mariozechner/pi-ai";
import { StringEnum } from "@mariozechner/pi-ai";
import { Type } from "@sinclair/typebox";
```

**Lifecycle hooks**:

| Hook | Signature | Can Return |
|------|-----------|------------|
| `before_agent_start` | `async (event) => ...` | `{ systemPrompt: string }` to override |
| `agent_end` | `async (event, ctx) => ...` | void |

`before_agent_start` does NOT receive `ctx`. Use direct TTY I/O for user interaction in this hook.
`agent_end` receives `ctx` with `ctx.ui.confirm(title, msg)`, `ctx.ui.notify(title, msg)`, `ctx.cwd`, `ctx.hasUI`.

**Tool registration**:
```typescript
pi.registerTool({
    name: "tool-name",
    label: "Display Label",
    description: "Description shown to the LLM",
    parameters: Type.Object({ /* Typebox schema */ }),
    async execute(toolCallId, params, signal, onUpdate, ctx) {
        // params: validated against parameters schema
        // signal: AbortSignal for cancellation
        // onUpdate: streaming partial results callback
        // ctx: { cwd, hasUI, ui: { confirm, notify } }
        return { content: [{ type: "text", text: "result" }] };
    },
    renderCall(args, theme, context) { /* optional TUI for tool invocation */ },
    renderResult(result, { expanded }, theme, context) { /* optional TUI for result */ },
});
```

**TUI rendering** (for `renderCall`/`renderResult`):
- `new Text(content, x, y)` — styled text
- `new Container()` with `.addChild(...)` — layout container
- `new Markdown(content, x, y, theme)` — rendered markdown (use `getMarkdownTheme()`)
- `new Spacer(lines)` — vertical spacing
- `theme.fg(colorName, text)` — foreground color (`"accent"`, `"muted"`, `"dim"`, `"error"`, `"success"`, `"warning"`, `"toolTitle"`, `"toolOutput"`)
- `theme.bold(text)` — bold text

**Key utilities**:
- `getAgentDir()` — returns resolved `PI_CODING_AGENT_DIR` path
- `withFileMutationQueue(path, fn)` — serialize file writes
- `parseFrontmatter<T>(content)` — returns `{ frontmatter: T, body: string }`

### Agent Definitions (Subagent `.md` Files)

Markdown files in `<teamDir>/agents/` with YAML frontmatter. Used by the `subagent-teams` extension.

```markdown
---
name: scout
description: Fast codebase recon
tools: read, grep, find, ls, bash
skills: skills/searxng
no-skills: true
model: haiku
team: recon
---

System prompt body (becomes --append-system-prompt for the child pi process).
```

| Field | Required | Description |
|-------|----------|-------------|
| `description` | **Yes** | If missing, the file is **skipped** entirely |
| `name` | No | Defaults from filename (part after first `-`) |
| `team` | No | Defaults from filename (part before first `-`); overrides filename |
| `tools` | No | Comma-separated tool whitelist; omit for all defaults |
| `skills` | No | Comma-separated skill paths (relative to team dir or absolute) |
| `no-skills` | No | `true` disables auto-discovery; combine with `skills` for explicit-only |
| `model` | No | Model override for this subagent |

**Naming convention**: `team-agentname.md` — first `-` separates team from agent name. Files without `-` have no team and are visible to all team filters.

### Skills

Markdown files (`SKILL.md`) that teach the agent how to use specific tools or workflows. NOT code — they are instructions injected into the agent's context.

```markdown
---
name: searxng
description: Search the web using a local SearXNG instance
allowed-tools: Bash
---

# SearXNG Web Search

Use this curl command to search: ...
```

| Frontmatter | Required | Description |
|-------------|----------|-------------|
| `name` | Yes | Skill identifier |
| `description` | Yes | Short description |
| `allowed-tools` | No | Restrict which tools the agent may use with this skill |

Skills live in `shared/skills/` and are symlinked per-skill into each team/agent's `skills/` directory.

### Workspace Agents

Any team or standalone agent can run as a **workspace agent** by adding a `workspace.conf` file to its directory. When present, the auto-generated alias launches pi in a fresh dated directory (`workspaces/<name>/<timestamp>/`) inside a subshell, so the user's shell stays in its original directory after pi exits.

**`workspace.conf` format**: one subdirectory name per line. Lines starting with `#` are comments. Each listed directory is pre-created in the workspace before pi starts.

```
# teams/deepresearch/workspace.conf
sources
drafts
subagent-sessions
```

**To convert any existing team/agent to workspace mode**: create `workspace.conf` in its directory (can be empty for a bare workspace, or list subdirectories).

**To scaffold a new workspace team/agent**: use the `--workspace` flag with `setup.sh`:
```bash
./setup.sh create --workspace my-research-team
./setup.sh create-agent --workspace my-scraper
```

**Subagent session logging**: When `subagent-sessions/` exists in the working directory, the `subagent-teams` extension automatically uses `--session-dir` instead of `--no-session`, enabling retrospective analysis of subagent runs.

Workspace contents are gitignored (`workspaces/*/`).

### Prompt Templates

Markdown files in `<teamDir>/prompts/` defining reusable workflows. Invoked via `/template-name` in pi chat. Typically chain subagents with `{previous}` placeholders and reference `$@` for user input.

### team-prompt.md

Per-team orchestrator instructions, read by `subagent-teams` on startup and appended to the main agent's system prompt. Describes the team's agents, workflows, and how to use the `subagent` tool.

## Symlink Patterns

`setup.sh` wires shared resources into team/agent directories via relative symlinks:

| Resource | Team symlink | Agent symlink |
|----------|-------------|---------------|
| `subagent-teams` extension | `extensions/subagent-teams → ../../../shared/extensions/subagent-teams` | *(not linked)* |
| `run-finish-notify.ts` | `extensions/run-finish-notify.ts → ../../../shared/extensions/run-finish-notify.ts` | same |
| `startup-branding.ts` | `extensions/startup-branding.ts → ../../../shared/extensions/startup-branding.ts` | same |
| Individual skills | `skills/<name> → ../../../shared/skills/<name>` | same |
| Individual themes | `themes/<name>.json → ../../../shared/themes/<name>.json` | same |
| bin directory | `bin → ../../shared/bin` | same |
| models.json | `models.json → ../../shared/models.json` | same |

**Do not edit symlink targets** — edit the source in `shared/` instead. To exclude a skill from a team/agent, remove its symlink.

## Common Tasks

### Add a subagent to an existing team

1. Create `teams/<team>/agents/<team>-<name>.md` with YAML frontmatter (at minimum: `description`)
2. Write the system prompt in the markdown body
3. Update `teams/<team>/team-prompt.md` to mention the new agent
4. Optionally add/update prompt templates in `teams/<team>/prompts/`

### Create a new team

```bash
./setup.sh create <team-name>
./setup.sh create --workspace <team-name>   # workspace mode
```

Then: add agent `.md` files to `agents/`, write `team-prompt.md`, add prompt templates.

### Create a standalone agent

```bash
./setup.sh create-agent <agent-name>
./setup.sh create-agent --workspace <agent-name>   # workspace mode
```

Then: edit `agents/<name>/extensions/<name>/index.ts` for custom behavior.

### Add a shared skill

1. Create `shared/skills/<name>/SKILL.md` with frontmatter (`name`, `description`)
2. Symlink into desired teams: `ln -sf ../../../shared/skills/<name> teams/<team>/skills/<name>`
3. Or run `setup.sh create <team>` for a new team (auto-links all shared skills)

### Write a custom extension

1. Create a directory: `<agentDir>/extensions/<ext-name>/index.ts`
2. Default-export a function: `(pi: ExtensionAPI) => void`
3. Use `pi.on(...)` for lifecycle hooks and `pi.registerTool(...)` for tools
4. See `shared/extensions/subagent-teams/index.ts` (1025 lines, full tool + TUI) and `agents/twenty-questions/extensions/twenty-questions/index.ts` (minimal hook + TUI overlay) as examples

## Files You Should and Shouldn't Edit

| Path Pattern | Editable? | Notes |
|-------------|-----------|-------|
| `shared/extensions/**/*.ts` | Yes | Shared extension source code |
| `shared/skills/*/SKILL.md` | Yes | Shared skill definitions |
| `shared/themes/*.json` | Yes | Shared themes |
| `shared/models.json` | Yes | Model provider config |
| `teams/*/agents/*.md` | Yes | Subagent definitions |
| `teams/*/prompts/*.md` | Yes | Prompt templates |
| `teams/*/team-prompt.md` | Yes | Team orchestrator instructions |
| `*/banner.txt` | Yes | Startup branding (ASCII art + usage text) |
| `*/workspace.conf` | Yes | Workspace subdirectory list (presence marks workspace mode) |
| `agents/*/extensions/**/*.ts` | Yes | Custom agent extensions |
| `setup.sh` | Yes | Team/agent scaffolding |
| `bash_aliases` | Yes | Shell aliases |
| `docs/**/*.md` | Yes | MkDocs documentation |
| `teams/*/extensions/*` | **No** | Symlinks — edit `shared/extensions/` instead |
| `teams/*/skills/*` | **No** | Symlinks — edit `shared/skills/` instead |
| `teams/*/themes/*` | **No** | Symlinks — edit `shared/themes/` instead |
| `*/models.json` (in teams/agents) | **No** | Symlink — edit `shared/models.json` |
| `*/bin/` | **No** | Symlink — managed by pi runtime |
| `*/sessions/` | **No** | Runtime data — gitignored |
| `*/settings.json` | **No** | Pi settings (theme, quietStartup) — gitignored, scaffolded by `setup.sh` |
| `*/auth.json` | **No** | Credentials — gitignored |
