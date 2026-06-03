---
description: Prime agent with comprehensive codebase understanding
---

# Prime: Load Project Context

## Objective
Build comprehensive understanding of the codebase by analyzing structure, documentation, key files, and recent session history.

## Progressive Disclosure Rules
- Use Glob to identify files BEFORE reading them
- Do NOT read files >200 lines in full — use line ranges to read the most relevant sections
- Skip these directories entirely: node_modules, __pycache__, .git, dist, build, .next, .cache
- Prefer scanning file names and structure first, then selectively reading key files

## Process

### 1. Analyze Project Structure
List all tracked files:
!`git ls-files`

Show directory structure (top 3 levels, excluding noise):
!`tree -L 3 -I 'node_modules|__pycache__|.git|dist|build|.next|.cache' --dirsfirst 2>/dev/null || echo "tree not installed — using git ls-files above"`

### 2. Read Core Documentation
Read these files if they exist (in priority order):
- **CLAUDE.md** — Project rules, conventions, architecture (this is the anchor)
- **README.md** — Project overview and purpose
- **agency/BRIEFING.md** — Operational state across ventures (if present)
- Any architecture documentation (look for files matching `*architecture*`, `*design*`, `MASTER_PLAN*`)
- Any spec files in `specs/` (read file names only, then read the most recent 1-2)

### 3. Read Configuration Files
Identify and read key config files. Use Glob to find them:
- Package managers: `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`
- TypeScript/JS: `tsconfig.json`, `next.config.*`, `vite.config.*`
- Build tools: `Makefile`, `docker-compose.yml`, `Dockerfile`
- CI/CD: `.github/workflows/*.yml` (read file names, then read the primary one)
- Environment: `.env.example` (NEVER read `.env` — secrets)

### 4. Identify Key Entry Points
Based on the structure, identify and read:
- Main entry points (`main.py`, `index.ts`, `app.py`, `src/index.*`, `src/app.*`)
- Core model/schema definitions (look for `models/`, `schema/`, `types/`, `db/`)
- Important service or controller files (read the first 50-100 lines for interface understanding)

### 5. Understand Current State
Check recent activity:
!`git log -10 --oneline`

Check current branch and status:
!`git status`

### 6. Session Continuity
Read the 2-3 most recent session summary files for context on prior work:
- Use Glob to find `.claude/sessions/SESSION-*.md`
- Sort by modification time (most recent first)
- Read the top 2-3 files to understand what was done recently and what's next

## Output Report

Provide a concise, scannable summary covering:

### Project Overview
- Purpose and type of application
- Primary technologies and frameworks
- Current version/state

### Architecture
- Overall structure and organization
- Key architectural patterns identified
- Important directories and their purposes
- MCP servers or external integrations (if any)

### Tech Stack
- Languages and versions
- Frameworks and major libraries
- Build tools and package managers
- Testing frameworks

### Core Principles
- Code style and conventions observed (from CLAUDE.md or inferred)
- Documentation standards
- Testing approach

### Current State
- Active branch and recent changes
- Recent development focus (from git log + session summaries)
- Any immediate observations or concerns
- Open priorities or blockers (from session summaries)

**Make this summary easy to scan — use bullet points and clear headers. Keep it under 200 lines.**
