# Subagent Teams: Exploration and Findings

## Goal

Create isolated, team-based subagent configurations for pi that can be invoked from any working directory via bash aliases, keeping `~/.pi` clean.

---

## 1. How Does pi-mono Support Sub-agents?

Sub-agents are an **extension example** (not built into core) at `packages/coding-agent/examples/extensions/subagent/`. The extension registers a `subagent` tool that spawns separate `pi` processes (`--mode json -p --no-session`), each with an isolated context window. Output is captured via JSON stdout parsing in real time.

**Three execution modes:**
- **Single** `{ agent, task }` — one agent, one task
- **Parallel** `{ tasks: [...] }` — up to 8 tasks, 4 concurrent, no data flow between them
- **Chain** `{ chain: [...] }` — sequential pipeline; `{previous}` placeholder injects prior step's final text output into the next step's task via string substitution

## 2. What Are "Agents"?

Agents are **markdown files with YAML frontmatter** stored in `~/.pi/agent/agents/` (user-level) or `.pi/agents/` (project-level). They define a name, description, tool whitelist, model, and system prompt. They are a concept of the subagent extension, not pi's core.

```yaml
---
name: scout
description: Fast codebase recon
tools: read, grep, find, ls, bash
model: claude-haiku-4-5
---
System prompt body becomes --append-system-prompt for the child pi process.
```

## 3. How Is the Extension Loaded?

Pi auto-discovers extensions from `~/.pi/agent/extensions/` and `.pi/extensions/`. It looks for [index.ts](cci:7://file:///Users/satoshi/dot-pi/reference/pi-mono/packages/coding-agent/examples/extensions/subagent/index.ts:0:0-0:0) in subdirectories. The subagent example uses symlinks from the repo into `~/.pi/agent/extensions/subagent/` for development convenience.

## 4. Can Subagents Call Subagents?

Yes, mechanically. Each subprocess loads extensions from `~/.pi/agent/extensions/`. **However**, agents that specify a `tools:` whitelist in frontmatter restrict the subprocess to only those built-in tools — the `subagent` extension tool won't be available. Agents without a `tools:` field (like [worker](cci:1://file:///Users/satoshi/dot-pi/reference/pi-mono/packages/coding-agent/src/core/package-manager.ts:1461:2-1470:4)) get all defaults + extensions, enabling nesting.

**Visibility limitation**: The parent only captures `message_end` and `tool_result_end` events. A grandchild's activity appears as flattened text inside the child's messages — no structured detail panel in the top-level UI.

## 5. Chain Error Handling

Chains fail-fast: if any step's subprocess exits non-zero or the LLM returns `stopReason: "error"`, the chain aborts. No `continueOnError` option exists yet. A bash error *inside* a subagent is typically self-corrected by that subagent's own agent loop — the chain only stops on subprocess-level failure.

## 6. Team-Based Filtering (New Extension)

No built-in team concept existed. We created `subagent-teams` at `packages/coding-agent/examples/extensions/subagent-teams/` that adds:

- **Filename convention**: `team-agentname.md` (first `-` separates team from name)
- **Frontmatter override**: `team` field takes precedence over filename
- **`team` parameter** on the subagent tool filters visible agents
- **[getAvailableTeams()](cci:1://file:///Users/satoshi/dot-pi/reference/pi-mono/packages/coding-agent/examples/extensions/subagent-teams/agents.ts:156:0-163:1)** helper lists discovered teams
- Sample agents: `recon-scout`, `recon-planner`, `impl-worker`, `impl-reviewer`

## 7. Invoking Teams from Any Directory

**Key discovery**: `PI_CODING_AGENT_DIR` env var (defined in `src/config.ts:207-216`) overrides pi's entire config root. When set, all config — extensions, agents, skills, prompts, themes, sessions, settings, auth — resolves from that directory instead of `~/.pi/agent/`.

**Solution**: Self-contained team directories + bash aliases.

```
~/pi-teams/
├── recon-team/
│   ├── extensions/subagent-teams/  → symlinks to extension source
│   ├── agents/                     → recon-scout.md, recon-planner.md
│   ├── prompts/                    → team-specific workflows
│   └── settings.json
├── impl-team/
│   ├── extensions/subagent-teams/  → symlinks to extension source
│   ├── agents/                     → impl-worker.md, impl-reviewer.md
│   └── ...
└── full-team/
    └── ...                         → all agents combined
```

```bash
alias pi-recon='PI_CODING_AGENT_DIR=~/pi-teams/recon-team pi'
alias pi-impl='PI_CODING_AGENT_DIR=~/pi-teams/impl-team pi'
alias pi-full='PI_CODING_AGENT_DIR=~/pi-teams/full-team pi'
```

Works from any directory. `~/.pi` stays untouched. Each team has fully isolated sessions, settings, and agent visibility. Shared auth can be symlinked across team directories.

---

## Files Created

All under `packages/coding-agent/examples/extensions/subagent-teams/`:

NOTE: the bottom links are not correct:

| File | Purpose |
|------|---------|
| [agents.ts](cci:7://file:///Users/satoshi/dot-pi/reference/pi-mono/packages/coding-agent/examples/extensions/subagent/agents.ts:0:0-0:0) | Agent discovery with team parsing from filename/frontmatter |
| [index.ts](cci:7://file:///Users/satoshi/dot-pi/reference/pi-mono/packages/coding-agent/examples/extensions/subagent/index.ts:0:0-0:0) | Extension entry point — subagent tool with `team` parameter |
| [agents/recon-scout.md](cci:7://file:///Users/satoshi/dot-pi/reference/pi-mono/packages/coding-agent/examples/extensions/subagent-teams/agents/recon-scout.md:0:0-0:0) | [recon] Fast codebase recon, Haiku |
| [agents/recon-planner.md](cci:7://file:///Users/satoshi/dot-pi/reference/pi-mono/packages/coding-agent/examples/extensions/subagent-teams/agents/recon-planner.md:0:0-0:0) | [recon] Implementation planning, Sonnet |
| [agents/impl-worker.md](cci:7://file:///Users/satoshi/dot-pi/reference/pi-mono/packages/coding-agent/examples/extensions/subagent-teams/agents/impl-worker.md:0:0-0:0) | [impl] General-purpose worker, Sonnet |
| [agents/impl-reviewer.md](cci:7://file:///Users/satoshi/dot-pi/reference/pi-mono/packages/coding-agent/examples/extensions/subagent-teams/agents/impl-reviewer.md:0:0-0:0) | [impl] Code review, Sonnet |
| [prompts/implement.md](cci:7://file:///Users/satoshi/dot-pi/reference/pi-mono/packages/coding-agent/examples/extensions/subagent/prompts/implement.md:0:0-0:0) | Cross-team chain: scout → planner → worker |
| [prompts/implement-and-review.md](cci:7://file:///Users/satoshi/dot-pi/reference/pi-mono/packages/coding-agent/examples/extensions/subagent/prompts/implement-and-review.md:0:0-0:0) | Impl team chain: worker → reviewer → worker |
| [README.md](cci:7://file:///Users/satoshi/dot-pi/reference/pi-mono/packages/coding-agent/examples/extensions/subagent/README.md:0:0-0:0) | Full documentation |

## What Remains

- **Setup script**: Create `~/pi-teams/` directory structures and symlinks automatically
- **Shared auth**: Symlink `auth.json` across team directories
- **Testing**: Verify the extension loads and team filtering works end-to-end
- **Optional enhancements**: `continueOnError` for chains, per-agent `--extension` forwarding, nested subagent UI visibility