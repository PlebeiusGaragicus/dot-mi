# dot-mi

Custom [pi](https://github.com/PlebeiusGaragicus/pi-mono) agent teams as dotfiles.

## What is this?

dot-mi is a dotfiles-style repository for managing multiple **pi coding agent** configurations. Instead of cluttering `~/.pi/` with extensions, agents, and prompts, this repo defines self-contained **team directories** -- each with its own agents, prompts, extensions, and session history.

A bash alias sets `PI_CODING_AGENT_DIR` to the right team directory, and you get a fully isolated pi agent team from any working directory.

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

## Creating a New Team

```bash
./setup.sh create my-team
```

This creates a team directory with shared extensions symlinked in. Add your agent `.md` files to `teams/my-team/agents/` and prompt templates to `teams/my-team/prompts/`, then invoke with:

```bash
PI_CODING_AGENT_DIR=~/dot-mi/teams/my-team pi "your task"
```

Or add an alias to `bash_aliases`.
