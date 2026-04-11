# Usage Guide

This guide walks through concrete examples of how to use dot-mi day-to-day.

## Prerequisites

You have pi installed, the repo cloned to `~/dot-mi`, and aliases sourced:

```bash
source ~/dot-mi/bash_aliases
```

## 1. Recon a Codebase

You're dropped into an unfamiliar project and need to understand it fast.

```bash
cd ~/projects/some-api
pi-recon "Map the authentication flow -- which files handle login, session management, and token refresh?"
```

**What happens:** pi starts with only the recon team's agents (scout, planner) visible. The LLM can use the `subagent` tool to delegate to either agent. A typical flow:

1. The LLM calls `subagent` with `{ agent: "scout", task: "Find all authentication-related code..." }`
2. Scout (Haiku, fast and cheap) greps for auth patterns, reads key files, and returns a structured summary with file paths and line ranges
3. The LLM reads the summary and either answers you directly or delegates to planner for a deeper analysis

### Using the `/implement` prompt template

If you want the full scout-plan-implement chain in one shot:

```bash
pi-recon
> /implement add rate limiting to the /api/login endpoint
```

This triggers a three-step chain:

1. **scout** (recon) finds all code relevant to the login endpoint
2. **planner** (recon) creates a numbered implementation plan from the scout's findings
3. **worker** (impl) executes the plan

Each step runs in its own isolated pi process. The output of each step flows into the next via the `{previous}` placeholder.

## 2. Implement and Review

You know what needs to change and want the work done with a review pass.

```bash
cd ~/projects/some-api
pi-impl
> /implement-and-review add input validation to all POST endpoints in src/routes/
```

This triggers:

1. **worker** implements the changes (has full read/write/edit/bash access)
2. **reviewer** reviews the diff (read-only, uses `git diff` to inspect changes)
3. **worker** applies the review feedback

Or skip the prompt template and just talk to the team directly:

```bash
pi-impl "Fix the race condition in src/queue/processor.ts -- the dequeue and ack aren't atomic"
```

The LLM decides how to use the available agents. It might send the task straight to worker, or ask reviewer to inspect the area first.

## 3. Write a Blog Post

You want to write a technical blog post about a project you're working on.

```bash
cd ~/projects/my-cool-library
pi-blog
> /research-write-edit how this library's plugin system works and why we chose that architecture
```

This chains three agents:

1. **researcher** (Haiku) explores the codebase, gathers key facts, code examples, and suggests angles
2. **writer** (Sonnet) drafts an 800-1500 word blog post from the research
3. **editor** (Sonnet) reviews for accuracy, clarity, and structure, then returns a polished draft

For a quicker loop when you already know the material:

```bash
pi-blog
> /write-and-edit 5 practical tips for writing maintainable TypeScript
```

This skips research and goes straight to write-review-revise.

## 4. Deep Research (Workspace Team)

Workspace teams launch in a fresh dated directory so artifacts stay isolated.

```bash
pi-deepresearch "What are the latest developments in WebTransport protocol?"
```

**What happens:** The alias creates `workspaces/deepresearch/<timestamp>/` with `sources/`, `drafts/`, and `subagent-sessions/` subdirectories, then launches pi inside it. The orchestrator runs a four-step pipeline:

1. **scout** searches SearXNG for relevant sources
2. **collector** (parallel, one per URL) fetches each page via headless browser, strips boilerplate, saves to `sources/`
3. **writer** reads all sources and synthesizes a structured report to `drafts/report.md`
4. **editor** reviews the draft against sources and produces `report.md`

### Listing and resuming workspaces

Each run creates a new workspace. To see past runs:

```bash
pi-deepresearch --list
```

```
Workspaces for deepresearch:
  2026-04-10-125602  (12 files)
  2026-04-10-130214  (3 files)
```

To resume the most recent workspace session:

```bash
pi-deepresearch --resume
```

Or resume a specific one by prefix:

```bash
pi-deepresearch --resume 2026-04-10-125602
```

This cd's into the original workspace directory (so all files are present) and opens pi's session selector.

## 5. Ad-hoc Single Agent Use

You don't always need prompt templates. Just describe what you want:

```bash
# Quick recon question
pi-recon "What ORM does this project use and how are migrations handled?"

# Direct implementation
pi-impl "Rename the User model to Account everywhere"

# Blog with specific instructions
pi-blog "Write a short post comparing our REST and GraphQL endpoints, keep it under 600 words"
```

The LLM sees the team's agents and decides whether to delegate via subagent or handle the task directly.

## 6. Standalone Bots (No Teams)

For quick tasks that don't need team orchestration:

```bash
# General-purpose chatbot (read-only tools, no subagent extension)
pchat "Explain the difference between OAuth 2.0 and OIDC"

# Codebase explainer (read-only, produces structured reports)
cd ~/projects/some-api
pexplain "How does the caching layer work?"
```

These don't use `PI_CODING_AGENT_DIR` at all -- they pass flags directly to pi and use `~/.pi` as the config root.

## 7. Create a Custom Team

Say you want a team for writing documentation:

```bash
# Scaffold the team directory (in-situ mode)
./setup.sh create docs-team

# Or as a workspace team (creates workspace.conf)
./setup.sh create --workspace docs-team
```

This creates `teams/docs-team/` with extensions, skills, and models already symlinked. Now add agents:

```bash
cat > ~/dot-mi/teams/docs-team/agents/docs-writer.md << 'EOF'
---
name: writer
description: Writes clear technical documentation from code and context
tools: read, grep, find, ls
skills: skills/searxng
no-skills: true
---

You are a documentation writer. Read the code and produce clear, well-structured
documentation in markdown. Include code examples from the actual source.

Output format:
- Title and overview
- Sections with headers
- Code examples with language tags
- A "See also" section linking related files
EOF
```

The `no-skills: true` + `skills: skills/searxng` combination means this agent loads only the searxng skill, ignoring any others in the team's `skills/` directory. Omit both fields to load all team skills, or set only `no-skills: true` to load none.

Re-source aliases and use it -- the `pi-docs-team` alias is auto-generated from the directory name:

```bash
source ~/dot-mi/bash_aliases
cd ~/projects/my-api
pi-docs-team "Write API reference docs for all endpoints in src/routes/"
```

## 8. Sharing Auth Across Teams

Each team has its own config root, including API authentication. After you authenticate in one team, share it with others:

```bash
# Authenticate via the recon team
pi-recon
# (pi prompts for API key on first run, saves to teams/recon/auth.json)

# Share that auth with other teams
./setup.sh link-auth recon impl
./setup.sh link-auth recon blog
```

## 9. Check Your Setup

See what teams are configured and whether their extensions are properly linked:

```bash
./setup.sh list
```

```
Teams:
  blog  (in-situ, 3 agents, 2 prompts, extensions linked: yes)
  deepresearch  (workspace, 4 agents, 0 prompts, extensions linked: yes)
  impl  (in-situ, 2 agents, 1 prompts, extensions linked: yes)
  recon  (in-situ, 2 agents, 1 prompts, extensions linked: yes)

Standalone agents:
  twenty-questions  (in-situ, extensions: 1)
```
