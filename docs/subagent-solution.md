
There it is. Let me also check the project-level config resolution:

This is the key finding. Let me also check how the subagent extension's [agents.ts](cci:7://file:///Users/satoshi/dot-pi/reference/pi-mono/packages/coding-agent/examples/extensions/subagent/agents.ts:0:0-0:0) resolves the agent dir:

Here's the full picture. There's a clean solution that avoids touching `~/.pi` entirely.

## The `PI_CODING_AGENT_DIR` Env Var

pi resolves its entire config directory via [getAgentDir()](cci:1://file:///Users/satoshi/dot-pi/reference/pi-mono/packages/coding-agent/src/config.ts:205:0-215:1) at `@/Users/satoshi/dot-pi/reference/pi-mono/packages/coding-agent/src/config.ts:207-216`. It checks the env var `PI_CODING_AGENT_DIR` first. If set, **all** of pi's config — extensions, agents, skills, prompts, themes, sessions, settings — comes from that directory instead of `~/.pi/agent/`.

This means you can create **self-contained team directories**, each with its own extensions, agents, prompts, and settings:

```
~/pi-teams/
├── recon-team/
│   ├── extensions/
│   │   └── subagent-teams/
│   │       ├── index.ts
│   │       └── agents.ts
│   ├── agents/
│   │   ├── recon-scout.md
│   │   └── recon-planner.md
│   ├── prompts/
│   │   └── scout-and-plan.md
│   └── settings.json
├── impl-team/
│   ├── extensions/
│   │   └── subagent-teams/
│   │       ├── index.ts
│   │       └── agents.ts
│   ├── agents/
│   │   ├── impl-worker.md
│   │   └── impl-reviewer.md
│   ├── prompts/
│   │   └── implement-and-review.md
│   └── settings.json
└── full-team/
    ├── extensions/
    │   └── subagent-teams/ ...
    ├── agents/
    │   ├── recon-scout.md
    │   ├── recon-planner.md
    │   ├── impl-worker.md
    │   └── impl-reviewer.md
    └── prompts/ ...
```

### Bash Aliases

```bash
# In ~/.bashrc or ~/.zshrc

# Each alias points PI_CODING_AGENT_DIR at a different team directory
alias pi-recon='PI_CODING_AGENT_DIR=~/pi-teams/recon-team pi'
alias pi-impl='PI_CODING_AGENT_DIR=~/pi-teams/impl-team pi'
alias pi-full='PI_CODING_AGENT_DIR=~/pi-teams/full-team pi'
```

Now from **any directory**:
```bash
cd /some/random/project
pi-recon "Find all authentication code"    # only scout + planner visible
pi-impl "Fix the login bug"                # only worker + reviewer visible
pi-full "Implement OAuth support"          # all agents visible
```

### Key Benefits

- **`~/.pi` stays clean** — completely untouched
- **No `.pi/agents/` needed in cwd** — everything comes from the team directory
- **Full isolation** — each team has its own sessions, settings, extensions
- **Works from any directory** — the env var overrides regardless of cwd
- **Composable** — use symlinks to share common agent `.md` files across teams

### One Caveat

Since `PI_CODING_AGENT_DIR` controls **everything** (sessions, settings, auth, etc.), each team gets its own session history and API key storage. If you want shared auth across teams, you can symlink the `auth.json`:

```bash
# Set up auth once in a shared location
ln -sf ~/pi-teams/shared/auth.json ~/pi-teams/recon-team/auth.json
ln -sf ~/pi-teams/shared/auth.json ~/pi-teams/impl-team/auth.json
```

### With the Team Filter (Optional)

If you prefer a single agent directory with **all** agents and use the `team` parameter to filter at runtime, you can also combine both approaches — one alias per team that pre-sets a system prompt instructing the LLM to always pass `team: "recon"`:

```bash
alias pi-recon='PI_CODING_AGENT_DIR=~/pi-teams/shared pi --append-system-prompt ~/pi-teams/recon-system.md'
```

Where `recon-system.md` says:
```
When using the subagent tool, always set team: "recon".
```

But the per-directory approach is cleaner since it gives you hard isolation — the LLM literally can't see agents from other teams.