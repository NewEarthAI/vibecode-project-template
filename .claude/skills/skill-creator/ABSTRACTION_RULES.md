# Abstraction Rules
### Extracting Patterns, Not Instances

> **Core Problem:** Skills that are too specific are self-defeating.  
> **Solution:** Always extract the MECHANISM, parameterize the INSTANCE.

---

## The Abstraction Test

Before saving any skill, ask:

```
"Would this help with a DIFFERENT but SIMILAR task?"

If NO → Too specific → Abstract further
If YES → Good abstraction → Proceed
```

---

## What to Strip (Instance-Specific)

| Type | Example Instance | Why Strip |
|------|------------------|-----------|
| Record IDs | `recABC123`, `rec_xyz` | Unique to one record |
| Workflow IDs | `wf_abc`, `workflow_123` | Unique to one workflow |
| Table names | `tblDeals`, `properties` | Project-specific |
| User IDs | `user_abc`, `usr_123` | Session-specific |
| Project IDs | `proj_xyz`, `prj123` | Environment-specific |
| Specific URLs | `https://api.myapp.com` | Deployment-specific |
| Timestamps | `2025-01-09T10:30:00Z` | Moment-specific |
| Error line numbers | `Error at line 47` | Code-version-specific |
| Exact error text | `"recABC123 not found"` | Instance-specific |

---

## What to Keep (Pattern-Level)

| Type | Example Pattern | Why Keep |
|------|-----------------|----------|
| Mechanism | "webhook nests data in body" | Universal truth |
| Error TYPE | "timeout error", "RLS violation" | Category of problem |
| Syntax pattern | `$json.body.{{field}}` | Reusable structure |
| Architecture | "validate → process → store" | Reusable flow |
| Defaults | `timeout: 5000ms` | Sensible starting point |
| Anti-patterns | "don't access $json directly" | Prevents future errors |

---

## Abstraction Transformations

### IDs → Parameters

```javascript
// ❌ Instance
await supabase.from('deals').select().eq('id', 'rec123')

// ✅ Pattern
await supabase.from('{{table}}').select().eq('{{key}}', '{{id}}')
```

### Exact Errors → Error Types

```
// ❌ Instance
"Error: Cannot read property 'dealId' of undefined at workflow wf_abc line 47"

// ✅ Pattern
"Error Type: Undefined property access"
"Cause: Attempting to access nested property without parent object"
"Pattern: Check parent object exists before accessing nested properties"
```

### Specific Flow → Generic Flow

```
// ❌ Instance
"When deal rec123 moves to closing stage in workflow wf_deals..."

// ✅ Pattern
"When {{entity}} transitions to {{target_state}} in {{workflow_type}}..."
```

---

## Parameterization Syntax

Use `{{parameter_name}}` with clear naming:

| Parameter | Naming Convention |
|-----------|-------------------|
| Tables | `{{table_name}}`, `{{target_table}}` |
| Fields | `{{field_name}}`, `{{key_field}}` |
| IDs | `{{record_id}}`, `{{entity_id}}` |
| Values | `{{value}}`, `{{new_value}}` |
| Endpoints | `{{api_endpoint}}`, `{{webhook_url}}` |
| Numbers | `{{timeout_ms}}`, `{{batch_size}}` |

---

## Defaults for Parameterized Numbers

Numbers should be parameters WITH defaults:

```markdown
### Configuration
| Parameter | Default | Adjust When |
|-----------|---------|-------------|
| `{{timeout_ms}}` | 5000 | Slow APIs need more |
| `{{batch_size}}` | 100 | Memory constrained |
| `{{max_retries}}` | 3 | Critical operations |
| `{{poll_interval_ms}}` | 1000 | Rate limited APIs |
```

---

## Validation Checklist

Before finalizing any skill:

```
□ Zero hardcoded IDs (grep for rec_, wf_, tbl, user_, proj_)
□ Zero project-specific URLs (grep for https://)
□ Error patterns describe TYPE not exact MESSAGE
□ All instance values are {{parameterized}}
□ Numbers have defaults with rationale
□ Pattern works for DIFFERENT similar task
□ Fresh Claude in NEW project could use this
□ Captures WHY (mechanism) not just WHAT (symptom)
```

---

## Quick Reference

```
INSTANCE → PATTERN CONVERSION

recABC123        → {{record_id}}
tblDeals         → {{table_name}}
wf_xyz           → {{workflow_id}}
user_abc         → {{user_id}}
https://my.api   → {{api_endpoint}}
5000             → {{timeout_ms}} (default: 5000)
"exact error"    → "error type: category"
line 47          → [remove - code-version specific]
2025-01-09       → [remove - moment specific]
```

---

## Skill Classification & Eval-Informed Abstraction

### Dual-Skill Classification

Before abstracting, classify the skill:

| Classification | Abstraction Focus | Eval Focus |
|---------------|-------------------|------------|
| **Capability Uplift** | Abstract the TECHNIQUE that enables the capability | Test output QUALITY (does the skill produce better results?) |
| **Encoded Preference** | Abstract the WORKFLOW SEQUENCE | Test workflow FIDELITY (does it follow Steps A→B→C exactly?) |

### Using Eval Failures to Improve Abstraction

When evals fail, the failure mode reveals abstraction problems:

| Failure Pattern | Abstraction Problem | Fix |
|----------------|--------------------|----|
| Works for test case but fails on variations | Too specific — hardcoded instance details | Replace specific values with `{{parameters}}` |
| Triggers on unrelated prompts | Description too broad | Narrow the "When This Applies" conditions |
| Doesn't trigger on valid prompts | Description too narrow | Broaden trigger conditions, add more context |
| Passes trivially without skill | Expectations too weak | Write expectations that are hard to pass without the skill |
| Inconsistent results across runs | Ambiguous instructions | Add explicit decision criteria and examples |

### Capability Uplift Decommissioning Check

For skills classified as `capability-uplift`, periodically ask:

```
"Can the current base model (without this skill) produce output
that matches or exceeds what this skill produces?"

If YES → Flag for decommissioning or archival
If NO → Skill still provides value, keep active
```

Run this check after major model updates (e.g., Claude 5.0 release).

---

*Abstraction Rules v4.0 — Unified with Eval-Informed Refinement*
