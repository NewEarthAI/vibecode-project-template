---
name: api-handoff-docs
description: |
  Structured API handoff documentation for frontend/frontend integration. Supabase RPCs,
  Edge Functions, webhook payloads. Produces copy-paste-ready handoff docs.
  Use when backend work is complete and needs to be documented for frontend integration.
version: 1.1
source: davila7/claude-code-templates (enhanced for the project)
classification: capability-uplift
triggers:
  - "API handoff"
  - "document this API"
  - "frontend integration docs"
  - "Lovable handoff"
do-not-trigger:
  - "code review" → use master-code-reviewer
  - "security review" → use master-security-review
paths:
  - "clients/**"
---

# API Handoff Documentation

> **No Chat Output**: Produce the handoff document only. No discussion, no explanation.

Backend developer completing API work. Produces a structured handoff document giving frontend developers full business and technical context to build integration/UI without needing to ask backend questions.

> **Simple API shortcut**: If the API is straightforward (CRUD, no complex business logic), skip the full template — just provide endpoint, method, and example request/response JSON.

## Goal
Copy-paste-ready handoff document with all context a frontend AI needs to build UI/integration correctly.

## Inputs
- Completed API code (endpoints, controllers, services, DTOs, validation)
- Related business context from the task/user story
- Constraints, edge cases, or gotchas discovered during implementation

## Workflow

1. **Collect context** — confirm feature name, endpoints, DTOs, auth rules, edge cases
2. **Create handoff file** — write to `.claude/docs/ai/<feature-name>/api-handoff.md`
3. **Fill template** — every section with concrete data, omit only when truly N/A
4. **Double-check** — payloads match actual API, auth scopes accurate, validation reflects backend

## Template Structure

```markdown
# API Handoff: [Feature Name]

## Business Context
[2-4 sentences: problem, users, domain terms]

## Endpoints
### [METHOD] /path/to/endpoint
- **Purpose**: [1 line]
- **Auth**: [role/permission or "public"]
- **Request**: [JSON with field types, constraints]
- **Response** (success): [JSON]
- **Response** (error): [HTTP codes and shapes]
- **Notes**: [edge cases, rate limits, pagination]

## Data Models / DTOs
[Key models with field types, nullability, enums, business meaning]

## Enums & Constants
[Values, meanings, display labels]

## Validation Rules
[Key rules frontend should mirror for UX]

## Business Logic & Edge Cases
[Non-obvious behaviors, constraints, gotchas]

## Integration Notes
- Recommended flow
- Optimistic UI safety
- Caching / real-time considerations

## Test Scenarios
1. Happy path
2. Validation error
3. Not found
4. Permission denied

## Open Questions / TODOs
```

## Rules
- Be precise: types, constraints, examples — not vague prose
- Include real example payloads
- Surface non-obvious behaviors
- No backend implementation details unless relevant to integration
- Keep it scannable: headers, tables, bullets, code blocks
