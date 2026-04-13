# dot-mi

Custom [pi](https://github.com/PlebeiusGaragicus/pi-mono) agent teams as dotfiles.

Manage multiple pi coding agent configurations without touching `~/.pi/`. Each team or standalone agent gets its own isolated directory with extensions, agents, prompts, skills, and session history. A shell function sets `PI_CODING_AGENT_DIR` and you're running a fully isolated agent from any working directory.

## Quick Start

```bash
git clone git@github.com:PlebeiusGaragicus/dot-mi.git ~/dot-mi
cd ~/dot-mi && git submodule update --init

cp example.env .env
# Edit .env with your API keys

echo 'source ~/dot-mi/bash_aliases' >> ~/.zshrc
source ~/dot-mi/bash_aliases
```

## Create a Team

```bash
./setup.sh create my-team
# Add agents to teams/my-team/agents/
# Add prompts to teams/my-team/prompts/
```

## Docs

See the [documentation site](https://PlebeiusGaragicus.github.io/dot-mi/) for architecture, usage, extension API, and per-team details.
