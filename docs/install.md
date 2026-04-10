# Installation & Setup

## Requirements

- [pi](https://github.com/PlebeiusGaragicus/pi-mono) installed and on your `PATH`
- bash or zsh
- git (for cloning and the pi-mono reference submodule)

## Install

```bash
# Clone the repo (anywhere you like)
git clone git@github.com:PlebeiusGaragicus/dot-mi.git ~/dot-mi
cd ~/dot-mi

# Initialize the pi-mono reference submodule (optional, for reading upstream source)
git submodule update --init
```

The repo can live at any path -- `bash_aliases` auto-detects its own location at source time.

## API Keys

Copy the example env file and fill in your keys:

```bash
cp example.env .env
```

Edit `.env` with your API key(s). The file is gitignored and sourced automatically by `bash_aliases`:

```bash
export PLEBCHAT_API_KEY=your-key-here
```

## Shell Aliases

Add this line to your `~/.zshrc` or `~/.bashrc`, using the actual path to where you cloned the repo:

```bash
source ~/dot-mi/bash_aliases
```

Then reload your shell:

```bash
source ~/.zshrc  # or source ~/.bashrc
```

This gives you the team aliases (`pi-recon`, `pi-impl`, `pi-blog`) and the standalone bots (`pchat`, `pexplain`).

`DOT_MI_DIR` is auto-detected from the script's location, so the repo can live anywhere. If you need to override it for some reason, set `DOT_MI_DIR` before sourcing:

```bash
export DOT_MI_DIR="/custom/path"
source /custom/path/bash_aliases
```

## Verify

Check that your teams are set up and extensions are linked:

```bash
cd ~/dot-mi
./setup.sh list
```

You should see:

```
  blog   (3 agents, 2 prompts, extensions linked: yes)
  impl   (2 agents, 1 prompts, extensions linked: yes)
  recon  (2 agents, 1 prompts, extensions linked: yes)
```

Test a team:

```bash
cd /any/project
pi-recon "What does this project do?"
```

---

## The Setup Script

`setup.sh` manages team directories. It handles scaffolding, listing, and auth sharing.

### `./setup.sh create <team-name>`

Creates a new team directory at `teams/<team-name>/` with the following structure:

```
teams/<team-name>/
├── extensions/
│   ├── subagent-teams -> ../../../shared/extensions/subagent-teams
│   └── run-finish-notify.ts -> ../../../shared/extensions/run-finish-notify.ts
├── agents/              (empty -- add your agent .md files here)
├── prompts/             (empty -- add prompt templates here)
├── skills/ -> ../../shared/skills
├── sessions/            (runtime session storage, gitignored)
└── models.json -> ../../shared/models.json
```

The `extensions/`, `skills/`, and `models.json` are symlinks to `shared/`, so all teams use the same extension code, skill library, and model provider config. Agents and prompts are per-team. Individual agents can select which skills to load via frontmatter (`skills`, `no-skills`).

Example:

```bash
./setup.sh create docs-team
```

After creating a team, you need to:

1. **Add agents** -- create `.md` files in `teams/<team-name>/agents/` with YAML frontmatter (`name`, `description`, optionally `tools`, `skills`, `no-skills`, `model`, `team`) and a system prompt body.

2. **Add prompts** (optional) -- create `.md` files in `teams/<team-name>/prompts/` that define chain/parallel workflows using `$@` as the user input placeholder.

3. **Add a shell alias** -- add a function to `bash_aliases`:

    ```bash
    pi-docs() {
      PI_CODING_AGENT_DIR="$DOT_MI_DIR/teams/docs-team" pi "$@"
    }
    ```

4. **Re-source** -- re-source `bash_aliases` in your shell

### `./setup.sh list`

Shows all teams with their agent/prompt counts and whether extensions are properly symlinked:

```bash
./setup.sh list
```

```
  blog   (3 agents, 2 prompts, extensions linked: yes)
  impl   (2 agents, 1 prompts, extensions linked: yes)
  recon  (2 agents, 1 prompts, extensions linked: yes)
```

If `extensions linked` shows `no`, the symlinks are broken -- re-run `create` or manually fix them.

### `./setup.sh link-auth <source> <destination>`

Each team has its own `PI_CODING_AGENT_DIR`, which means separate `auth.json` files. After authenticating pi through one team, share that auth with others:

```bash
# Authenticate via recon (pi prompts for API key on first run)
pi-recon "hello"

# Share that auth.json with other teams
./setup.sh link-auth recon impl
./setup.sh link-auth recon blog
```

The `<source>` can be a team name (looks for `teams/<source>/auth.json`) or a direct file path. The destination is always a team name.

This creates a symlink so all linked teams use the same credentials, and re-authenticating in any one of them updates all of them.
