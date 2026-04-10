---
description: Full implementation workflow using recon and impl teams
---
Use the subagent tool with the chain parameter to execute this workflow:

1. First, use the "scout" agent (team: "recon") to find all code relevant to: $@
2. Then, use the "planner" agent (team: "recon") to create an implementation plan for "$@" using the context from the previous step (use {previous} placeholder)
3. Finally, use the "worker" agent (team: "impl") to implement the plan from the previous step (use {previous} placeholder)

Execute this as a chain, passing output between steps via {previous}.
