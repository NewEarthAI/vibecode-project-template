# Token-Savers Composition Order

**Origin**: 2026-05-03. Codifies how `caveman` (shipped 2026-05-02) composes with `layman-mode` (existing) and the deferred token-savers `jCodeMunch` + `CodeBurn` (per `project_token-savers-newclaw-reeval.md`).
**Pairs with**: `caveman` SKILL.md (Auto-Clarity Exception extension), `layman-mode.md` rule, `pocock-implicit-activation.md`.

---

## The principle

Token-savers compose, they don't replace each other. Each operates on a different layer of the response. Order of operations matters: vocabulary first, brevity second, code-block compression last (when shipped). Safety carve-outs are sacrosanct across all layers — destructive-action confirmations always escape compression.

---

## The 4-layer composition stack

| Layer | What it does | Status | Carve-outs |
|---|---|---|---|
| **L1 — Layman mode** | Replaces jargon with plain-English definitions on first use; Commonwealth spelling in prose; numbers stay precise | SHIPPED (existing rule) | Code identifiers, file paths, sub-agent prompts, council reports stay technical |
| **L2 — Caveman** | Drops articles + filler + pleasantries + hedging from prose | SHIPPED 2026-05-02 (Spec 22); **ALWAYS-ON since 2026-05-18** via the `caveman-always-on` hookify rule (`prompt` event, fires every turn) — no longer a per-session opt-in | Code blocks verbatim; destructive-keyword Auto-Clarity Exception; multi-step sequence safety |
| **L3 — jCodeMunch** | Inline code compression (semantic-preserving minification of code samples in chat) | DEFERRED — re-eval at NewClaw Phase 1 (per `project_token-savers-newclaw-reeval.md`) | Production code paths untouched; sample compression only |
| **L4 — CodeBurn** | Output stream compression (drop redundant scaffolding, repeated headers, identical formatting) | DEFERRED — re-eval at NewClaw Phase 1 | Header anchors preserved when ToC navigation needed |

---

## Order of operations (when multiple layers active)

For prose:
1. **Layman mode** runs first — defines vocabulary
2. **Caveman** runs second — compresses prose
3. **CodeBurn** (when shipped) runs third — compresses formatting

For code blocks:
1. Layman + Caveman both pass code blocks through verbatim (existing carve-out)
2. **jCodeMunch** (when shipped) — only layer that may touch code samples in chat, never production paths

For destructive-action confirmations (DELETE / DROP / deploy production / force-push / etc.):
- ALL layers pause via the Auto-Clarity Exception
- Full warning + rollback path + unambiguous confirmation phrase ALWAYS surface in plain English at full length
- Resume normal composition AFTER user confirms

---

## Composition with Pocock skills

| Pocock skill | Compatible with token-savers? | How they compose |
|---|---|---|
| `pocock-diagnose` | YES | Internal mechanism (Phases 1-6) runs verbatim. Chat-summary register goes through L1+L2. Phase 4 tagged debug logs `[DEBUG-XXXX]` are code, untouched. |
| `pocock-grill-with-docs` | YES | Grilling questions go through L1+L2. **NSF-1 review-gate is Auto-Clarity-protected**: pre-write CONTEXT.md/ADR diff displays at full length, never compressed. |
| `pocock-improve-codebase-architecture` | YES | Glossary terms (Module, Interface, Depth, Seam, Adapter) stay verbatim per L1 carve-out — NOT redefined every time. Recommendations go through L2. |
| `pocock-zoom-out` | YES | 7-line skill output is already terse; caveman is no-op. Domain glossary terms stay verbatim. |
| Pocock skill recommends an action | depends | If the recommendation involves a destructive-keyword path, Auto-Clarity fires. Otherwise normal composition. |

---

## Forward compatibility — when jCodeMunch + CodeBurn ship

Before shipping either:

1. Re-evaluate this rule at NewClaw Phase 1 per `project_token-savers-newclaw-reeval.md`.
2. Add a smoke-test for the new layer parallel to caveman's `council/sessions/2026-05-02-caveman-safety-smoke-test.md`. Required tests: irreversible-action confirmation, multi-step migration, production deploy.
3. Update this rule's L3/L4 row from "DEFERRED" to "SHIPPED" with the smoke-test reference.
4. Verify Pocock skill compatibility — particularly `pocock-grill-with-docs` NSF-1 review-gate (the diff that's displayed before CONTEXT.md write must NEVER be compressed by jCodeMunch/CodeBurn).

If a new token-saver violates ANY destructive-action carve-out during smoke-test → DO NOT ship until the carve-out is preserved.

---

## What this rule is NOT

- **Not a precedence-among-savers tournament**: all savers compose; they don't fight for dominance. Each operates on its layer.
- **Not for tools other than chat output**: code-review reports, council session bodies, sub-agent prompts, rule files all stay technical (carve-outs in `code-review-identity.md` + `layman-mode.md`).
- **Not a budget enforcer**: this rule defines composition order. L1 (layman) and L2 (caveman) are both ALWAYS-ON, each enforced by an always-fires hookify `prompt` rule — no per-session opt-in. L3/L4 remain deferred.

---

## Failure mode prevention

The 2026-05-02 caveman smoke-test (`council/sessions/2026-05-02-caveman-safety-smoke-test.md`) defines 4 canonical test scenarios. Composition with future savers MUST pass all 4 + any new layer-specific scenarios before shipping. The risk is asymmetric: a layer that compresses a destructive-action warning to "Run? y/n" is not just a quality issue — it's a possible data-loss vector.

---

## References

- `caveman` SKILL.md (Auto-Clarity Exception extension)
- `~/.claude/rules/layman-mode.md` (L1 layer)
- `agency/memory/project_token-savers-newclaw-reeval.md` (jCodeMunch + CodeBurn deferral state)
- `council/sessions/2026-05-01-token-optimization-stack-adoption.md` (origin council)
- `council/sessions/2026-05-02-caveman-safety-smoke-test.md` (composition test pattern)
- `.claude/rules/pocock-implicit-activation.md` (composition with Pocock toolkit)
