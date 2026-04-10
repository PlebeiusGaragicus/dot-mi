# Recon Team

Fast codebase reconnaissance and implementation planning.

## Agents

### scout

| Field | Value |
|-------|-------|
| Model | `claude-haiku-4-5` |
| Tools | read, grep, find, ls, bash |

Quickly investigates a codebase and returns structured findings (file locations, key code, architecture notes) that another agent can use without re-reading everything. Adjusts thoroughness based on the task.

### planner

| Field | Value |
|-------|-------|
| Model | `claude-sonnet-4-5` |
| Tools | read, grep, find, ls |

Takes context from a scout and produces a concrete, numbered implementation plan. Read-only -- does not make changes.

## Prompts

### `/implement`

Full implementation workflow that chains across teams:

1. **scout** (recon) gathers relevant code
2. **planner** (recon) creates an implementation plan
3. **worker** (impl) executes the plan

```
/implement add Redis caching to the session store
```

## Usage

```bash
# Via alias
pi-recon "Find all authentication code and map the auth flow"

# Direct invocation
PI_CODING_AGENT_DIR=~/dot-mi/teams/recon pi "Map the database schema"
```
