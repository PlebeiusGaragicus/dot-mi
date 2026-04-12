# dot-mi

Custom [pi](https://github.com/PlebeiusGaragicus/pi-mono) agent teams as dotfiles.

Manage multiple pi coding agent configurations without touching `~/.pi/`. Each team gets its own isolated directory with agents, prompts, extensions, and session history. A bash alias sets `PI_CODING_AGENT_DIR` and you're running a fully isolated agent team from any working directory.

## Quick Start

```bash
git clone git@github.com:PlebeiusGaragicus/dot-mi.git ~/dot-mi
cd ~/dot-mi && git submodule update --init

# Set up API keys
cp example.env .env
# Edit .env with your keys

# Source aliases
echo 'source ~/dot-mi/bash_aliases' >> ~/.zshrc
source ~/dot-mi/bash_aliases

# Use a team
pi-recon "Find all authentication code"
pi-blog "Write a post about this project"
```

## Teams

| Alias | Agents | Purpose |
|-------|--------|---------|
| `pi-recon` | scout, planner | Codebase reconnaissance and planning |
| `pi-impl` | worker, reviewer | Implementation and code review |
| `pi-blog` | researcher, writer, editor | Blog post pipeline |
| `pi-deepresearch` | scout, collector, writer, editor | Web research with sourced reports (workspace mode) |

## Create a Team

```bash
./setup.sh create my-team
# Add agents to teams/my-team/agents/
# Add prompts to teams/my-team/prompts/
```

## How It Works

Pi's `getAgentDir()` checks `PI_CODING_AGENT_DIR` before falling back to `~/.pi/agent/`. Each team alias sets this env var to a self-contained directory under `teams/`, giving full isolation of extensions, agents, prompts, sessions, and settings.

See the [docs](https://PlebeiusGaragicus.github.io/dot-mi/) for full architecture details.
