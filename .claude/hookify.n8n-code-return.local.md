---
name: n8n-code-return
enabled: false
event: PreToolUse
tool_matcher: Bash
action: warn
conditions:
  combinator: and
  conditions:
    - field: command
      operator: contains
      pattern: n8n
    - field: command
      operator: contains
      pattern: jsCode
---

**[WARNING] n8n Code node return pattern check**

Before deploying n8n Code node code, verify the return statements follow these rules:

## `runOnceForEachItem` mode

| Pattern | Status | Why |
|---------|--------|-----|
| `return $input.item` | CORRECT | Perfect pass-through, preserves pairedItem metadata |
| `return [{json: {...$json, newField: val}}]` | CORRECT | Spread into plain object for transforms |
| `return {json: {key: val}}` | CORRECT | Single new item |
| `return []` | CORRECT | Filter/drop the item |
| `return [{json: $json}]` | **BROKEN** | `$json` is a sandbox proxy — fails `validateItem()` type check |
| `return $json` | **BROKEN** | Raw data without `json` wrapper |

## `runOnceForAllItems` mode

| Pattern | Status | Why |
|---------|--------|-----|
| `return $input.all()` | CORRECT | Pass-through all items |
| `return items.map(i => ({json: {...i.json, newField: val}}))` | CORRECT | Transform all items |
| `return [{json: $json}]` | **BROKEN** | Only processes first item (1-of-N bug) |

**Key rule**: NEVER pass the raw `$json` proxy as the `json` property. Always use `$input.item` for pass-through or `{...$json}` spread for transforms.
