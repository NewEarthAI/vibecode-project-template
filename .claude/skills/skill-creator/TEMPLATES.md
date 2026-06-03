# Skill Templates
### Properly Abstracted Examples

> **Rule:** Every template uses `{{parameters}}`, never hardcoded values.

---

## Standard Pattern Skill

```markdown
---
name: {{domain}}-{{pattern-type}}
description: |
  {{Mechanism description in ~50 tokens}}. Use when {{trigger conditions}}.
  Handles {{error types}}.
version: 1.0
parameters:
  - name: {{param_1}}
    default: {{value}}
  - name: {{param_2}}
    default: {{value}}
validated_on:
  - {{different_use_case_1}}
  - {{different_use_case_2}}
---

# {{Pattern Name}}

## When This Applies
- {{trigger_1}}
- {{trigger_2}}
- {{error_symptom}}

## Pattern

{{Parameterized code or structure}}

```{{language}}
// Works for any {{entity_type}}
{{parameterized_code}}
```

## Anti-Patterns

| Wrong | Why | Right |
|-------|-----|-------|
| {{wrong_approach}} | {{mechanism_explanation}} | {{right_approach}} |
| {{wrong_approach}} | {{mechanism_explanation}} | {{right_approach}} |
| {{wrong_approach}} | {{mechanism_explanation}} | {{right_approach}} |

## Defaults

| Parameter | Default | Adjust When |
|-----------|---------|-------------|
| `{{param}}` | {{value}} | {{condition}} |

## Validation

This skill works for:
- ✓ Different {{entity_type}}
- ✓ Different {{environment}}
- ✓ New projects without prior context
```

---

## MCP Wrapper Skill

```markdown
---
name: {{mcp}}-{{domain}}-patterns
description: |
  {{MCP}} operations for {{domain}}. Use when {{triggers}}.
  Handles {{error_types}}.
version: 1.0
parameters:
  - name: table_name
    type: string
  - name: timeout_ms
    default: 5000
---

# {{MCP}} {{Domain}} Patterns

## Quick Reference

| Operation | Tool | Pattern |
|-----------|------|---------|
| {{op_1}} | `{{tool}}` | {{syntax}} |
| {{op_2}} | `{{tool}}` | {{syntax}} |

## Syntax Patterns

### {{Pattern Name}}

```{{language}}
// Parameters: {{table_name}}, {{field_name}}
{{parameterized_code}}
```

**Works for any** `{{table_name}}` — not tied to specific tables.

## Anti-Patterns

| Wrong | Why | Right |
|-------|-----|-------|
| `{{wrong_syntax}}` | {{mechanism}} | `{{right_syntax}}` |

## Error Types

| Error Type | Cause | Solution |
|------------|-------|----------|
| {{error_category}} | {{mechanism}} | {{solution}} |

## Defaults

| Parameter | Default | Rationale |
|-----------|---------|-----------|
| `timeout_ms` | 5000 | Standard for most APIs |
| `batch_size` | 100 | Platform limit |
```

---

## Orchestration Skill

```markdown
---
name: {{workflow}}-orchestration
description: |
  Coordinates {{system_1}}, {{system_2}}, {{system_3}} for {{purpose}}.
  Use when {{triggers}}.
version: 1.0
parameters:
  - name: entity_type
    description: What is being processed
  - name: source_system
    default: {{default_source}}
  - name: target_system
    default: {{default_target}}
---

# {{Workflow}} Orchestration

## Flow (Max 4 Steps)

```
1. [{{System_1}}] {{action_1}}
   └─ Input: {{parameterized_input}}
   └─ Output: {{parameterized_output}}

2. [{{System_2}}] {{action_2}}
   └─ Uses: Step 1 output
   └─ Output: {{parameterized_output}}

3. [{{System_3}}] {{action_3}}
   └─ Uses: Step 2 output
   └─ Output: Final result
```

## Error Recovery

| Step | Error Type | Recovery | Critical? |
|------|------------|----------|-----------|
| 1 | {{error_type}} | {{recovery}} | {{yes/no}} |
| 2 | {{error_type}} | {{recovery}} | {{yes/no}} |
| 3 | {{error_type}} | {{recovery}} | {{yes/no}} |

## Anti-Patterns

| Wrong | Why | Right |
|-------|-----|-------|
| {{wrong_flow}} | {{mechanism}} | {{right_flow}} |

## Validation

Works for any:
- `{{entity_type}}` (not just specific entities)
- `{{source_system}}` configuration
- `{{target_system}}` configuration
```

---

## Parameter Naming Conventions

| Domain | Parameters |
|--------|------------|
| **Database** | `{{table_name}}`, `{{field_name}}`, `{{record_id}}`, `{{key_field}}` |
| **API** | `{{endpoint}}`, `{{timeout_ms}}`, `{{max_retries}}`, `{{batch_size}}` |
| **Workflow** | `{{workflow_id}}`, `{{trigger_type}}`, `{{webhook_url}}` |
| **Entity** | `{{entity_type}}`, `{{entity_id}}`, `{{state}}`, `{{transition}}` |
| **Auth** | `{{user_id}}`, `{{role}}`, `{{permission}}` |

---

---

## Eval Template

```json
{
  "evals": [
    {
      "id": "eval-001",
      "prompt": "{{realistic_prompt_that_should_trigger}}",
      "description": "Tests core skill activation on typical use case",
      "should_trigger": true,
      "expectations": [
        "{{verifiable_output_assertion_1}}",
        "{{verifiable_output_assertion_2}}",
        "{{verifiable_output_assertion_3}}"
      ]
    },
    {
      "id": "eval-002",
      "prompt": "{{edge_case_prompt_that_should_trigger}}",
      "description": "Tests skill activation on edge case",
      "should_trigger": true,
      "expectations": [
        "{{edge_case_assertion}}"
      ]
    },
    {
      "id": "eval-003",
      "prompt": "{{similar_prompt_that_should_NOT_trigger}}",
      "description": "Tests that skill does NOT fire on similar but irrelevant prompt",
      "should_trigger": false,
      "expectations": []
    }
  ]
}
```

**Eval Writing Rules:**
- `should_trigger: true` evals need 2-3 **discriminating** expectations
- `should_trigger: false` evals test that the skill stays silent
- Expectations must be **hard to pass without actually doing the work**
- Use concrete, verifiable assertions (file exists, content contains X, format matches Y)
- Avoid trivial assertions (output is not empty, response was given)

---

## Benchmark Results Template

```markdown
# Benchmark Report — {{skill_name}}

**Runs:** {{run_count}} | **Generated:** {{timestamp}}

## Pass Rate
| Metric | Value |
|--------|-------|
| Mean   | {{mean}}% |
| Std Dev| {{stddev}} |
| Min    | {{min}}% |
| Max    | {{max}}% |

## Individual Runs
| Run | Pass Rate | Duration | Tokens |
|-----|-----------|----------|--------|
| {{run_id}} | {{rate}}% | {{duration}}ms | {{tokens}} |
```

---

*Templates v5.0 — Unified with Eval & Benchmark Templates*
