# dot-mi

Custom [pi](https://github.com/PlebeiusGaragicus/pi-mono) agent teams as dotfiles.

## What is this?

dot-mi is a dotfiles-style repository for managing multiple **pi coding agent** configurations. Instead of cluttering `~/.pi/` with extensions, agents, and prompts, this repo defines self-contained **team directories** and **standalone agent directories** -- each with its own extensions, skills, and session history.

A bash alias sets `PI_CODING_AGENT_DIR` to the right directory, and you get a fully isolated pi agent configuration from any working directory.

## Quick Start

```bash
# Clone the repo
git clone git@github.com:PlebeiusGaragicus/dot-mi.git ~/dot-mi

# Source the aliases
echo 'source ~/dot-mi/bash_aliases' >> ~/.zshrc
source ~/dot-mi/bash_aliases

# Set up API keys
cp ~/dot-mi/example.env ~/dot-mi/.env
# Edit .env with your API keys

# Use a team
cd /any/project
pi-recon "Find all authentication code"
pi-blog "Write a post about this project's architecture"
```

## Available Teams

| Team | Alias | Agents | Purpose |
|------|-------|--------|---------|
| **recon** | `pi-recon` | scout, planner | Fast codebase reconnaissance and implementation planning |
| **impl** | `pi-impl` | worker, reviewer | Code implementation and review |
| **blog** | `pi-blog` | researcher, writer, editor | Blog post research, writing, and editing |

## Standalone Agents

| Agent | Alias | Purpose |
|-------|-------|---------|
| **twenty-questions** | `pi-twenty-questions` | 20 questions game with custom TUI overlay (extension demo) |

Standalone agents use custom extensions instead of subagent orchestration. See [Standalone Agents](standalone-agents.md).

## Creating New Configurations

**New team** (multi-agent with subagent orchestration):

```bash
./setup.sh create my-team
```

Add agent `.md` files to `teams/my-team/agents/` and prompt templates to `teams/my-team/prompts/`.

**New standalone agent** (single agent with custom extension):

```bash
./setup.sh create-agent my-agent
```

Edit `agents/my-agent/extensions/my-agent/index.ts` for custom behavior.

Both are invokable via auto-generated `pi-<name>` aliases after re-sourcing `bash_aliases`.
