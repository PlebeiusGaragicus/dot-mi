# Standalone Agents

Standalone agents are single-purpose pi configurations with custom extensions. Unlike [teams](architecture.md), they don't use subagent orchestration — the main pi process IS the agent, and behavior is customized entirely through extensions.

## When to Use

Use a standalone agent when you want:

- A custom tool or lifecycle hook without multi-agent delegation
- A focused, single-purpose agent (game, utility, specialized workflow)
- A playground for experimenting with the [extension API](reference/extensions.md)

Use a [team](architecture.md) when you want multiple specialized subagents that collaborate.

## Directory Layout

```
agents/<name>/
├── extensions/
│   ├── <name>/               # Your custom extension
│   │   └── index.ts
│   ├── run-finish-notify.ts  # Shared notification extension (symlinked)
│   └── startup-branding.ts   # Shared startup branding (symlinked)
├── skills/                   # Per-skill symlinks from shared/skills/
├── themes/                   # Per-theme symlinks from shared/themes/
├── banner.txt                # Startup branding (ASCII art + usage text)
├── bin/                      # → shared/bin/ (fd, rg)
├── models.json               # → shared/models.json
├── sessions/                 # Runtime conversation history (gitignored)
└── settings.json             # Pi settings: theme, quietStartup (gitignored)
```

The directory is a complete `PI_CODING_AGENT_DIR` root, just like a team directory. The key differences:

| | Team | Standalone Agent |
|--|------|-----------------|
| `subagent-teams` extension | Symlinked | Not present |
| `agents/` subdirectory | Subagent definitions | Not present |
| `prompts/` subdirectory | Workflow templates | Not present |
| `team-prompt.md` | Orchestrator instructions | Not present |
| Custom extension | Optional | Core of the agent |

## Creating a Standalone Agent

### Scaffolding

```bash
./setup.sh create-agent my-agent
```

This creates the directory structure with shared symlinks and a stub extension at `agents/my-agent/extensions/my-agent/index.ts`.

### Writing the Extension

Edit the stub extension to add your custom behavior. See [Writing Extensions](reference/extensions.md) for the full API.

A minimal extension that modifies the system prompt:

```typescript
import * as fs from "node:fs";
import * as path from "node:path";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { getAgentDir } from "@mariozechner/pi-coding-agent";

export default function (pi: ExtensionAPI) {
    const agentDir = getAgentDir();
    const configPath = path.join(agentDir, "config.md");

    let config = "";
    try {
        config = fs.readFileSync(configPath, "utf-8").trim();
    } catch { /* not found */ }

    if (config) {
        pi.on("before_agent_start", async (event) => {
            return { systemPrompt: event.systemPrompt + "\n\n" + config };
        });
    }
}
```

### Running the Agent

After sourcing `bash_aliases`, a `pi-<name>` alias is auto-generated:

```bash
source ~/dot-mi/bash_aliases
pi-my-agent "hello"
```

Or set the environment variable directly:

```bash
PI_CODING_AGENT_DIR=~/dot-mi/agents/my-agent pi "hello"
```

## Example: Twenty Questions

The `twenty-questions` agent demonstrates a custom extension with a welcome overlay and system prompt injection.

### What It Does

1. On extension load (before the user types anything), shows a styled ANSI box telling the user to think of something and say "I'm ready"
2. Injects game rules into the system prompt via `before_agent_start`
3. The agent plays 20 questions, asking yes/no questions to guess what the user is thinking of

### Source

Extension: `agents/twenty-questions/extensions/twenty-questions/index.ts`

### Running It

```bash
pi-twenty-questions
```

The extension displays the welcome box on startup. Say "I'm ready" to begin the game.

## Customizing

### Removing Skills

Standalone agents inherit all shared skills by default. To remove one:

```bash
rm agents/my-agent/skills/bowser
```

### Adding Agent-Specific Files

Place any files your extension needs in the agent directory. Use `getAgentDir()` to locate them:

```typescript
const agentDir = getAgentDir();
const myFile = path.join(agentDir, "my-config.json");
```

### Sharing Auth

To reuse authentication from a team:

```bash
./setup.sh link-auth recon my-agent
```
