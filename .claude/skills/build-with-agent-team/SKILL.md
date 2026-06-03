---
name: build-with-agent-team
description: |
  Build projects using parallel Claude agent teams with contract-first coordination, NSM alignment,
  and full pre-flight safety. Use when: "build with agent team", "spawn agents", "parallel build",
  "agent team", or when a plan document needs multiple agents to implement collaboratively.
  Requires tmux and CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1.
allowed-tools: Read, Write, Edit, Glob, Grep, Agent, Bash
---

# Build with Agent Team

A skill for building projects using Agent Teams — multiple Claude instances working in parallel
in tmux split panes, communicating with each other, and coordinating autonomously.

## Usage

```
/build-with-agent-team [plan-path] [num-agents]
```

## Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `plan-path` | Yes | Path to your plan markdown file |
| `num-agents` | No | Number of agents to spawn (auto-determined if omitted) |

## Prerequisites

1. tmux installed (`brew install tmux`)
2. Agent teams enabled:
   - In `~/.claude/settings.json`: `{"env": {"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"}}`
   - Or in shell: `export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`

## How It Works

1. Reads your plan document
2. Analyzes it to determine agent roles (frontend, backend, database, etc.)
3. Spawns agents in tmux split panes
4. Agents coordinate via shared task list and direct messaging
5. Agents challenge each other's work and agree on interfaces

## When to Use

- Multiple components need to integrate (frontend + backend + database)
- Agents need to agree on interfaces and contracts
- Building something complex enough to warrant coordination
- You want to see parallel progress in real-time

## Plan Format

Your plan should include:
- What you're building and why
- Tech stack and architecture
- Project structure
- Key components and how they interact
- Data models or API contracts
- Acceptance criteria

See `example-plan/session-manager-plan.md` for a reference.
