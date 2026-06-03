---
name: design-review
description: Run a NewEarth Design Suite review on any input — live URL, attached screenshot, screenshot file path, code path, or Figma export. Pulls the full L1 + L2 + L3 stack and grades against every layer.
---

# /design-review

Run a NewEarth Design Suite review on whatever you point me at. Accepts:

| Input | How to invoke |
|---|---|
| **Live URL** | `/design-review https://buybox-ai.com/pipeline` |
| **Attached screenshot** | Paste/drag the image into the chat, then `/design-review` |
| **Screenshot on disk** | `/design-review path/to/screenshot.png` |
| **Code path** | `/design-review src/components/analytics/KPICards.tsx` |
| **Figma frame** | Export PNG first → invoke with the file path (Figma MCP integration is a future enhancement) |
| **"Make this perfect"** | `/design-review https://... make this perfect` — escalates to iterate-until-clean mode |

## What it does

Loads the full NewEarth Design Suite three-layer stack (L1 identity contracts + L2 anti-slop overlay + L3 house specialty skills) and grades the surface against every layer in one pass. Each flagged issue carries a layer tag so the operator can see whether the violation came from brand contract, dial baseline, or absolute house rule.

## Pre-flight

The skill halts loudly if `PRODUCT.md` + `DESIGN.md` (L1 contracts) are missing — a review without those produces generic critique, not NewEarth review. Run the pre-flight to check:

```bash
bash .claude/skills/newearth-ui-design/scripts/preflight-contract-files.sh
```

If FAIL: run `impeccable teach` (interactive, Justin in the loop) to author the L1 contracts. After Phase 3.2 ships, /design-review goes from "halt on missing contracts" to full multi-layer review.

## Bound to skill

This command invokes the `design-review` skill at `.claude/skills/design-review/SKILL.md`. See that file for the full rule set, priority weighting, and review process.
