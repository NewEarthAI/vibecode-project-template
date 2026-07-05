# Hook Profile Gating — Per-Hook Kill-Switch Convention

**Scope**: every hook script in `.claude/hooks/*.sh` (and equivalents) authored from 2026-05-22 forward. Retroactive retrofit is **opt-in per hook**, NOT required — this rule is forward-applying.

**Origin**: 2026-05-22 — Phase 2 of the ECC audit programme (`agency/memory/audit_ecc-2026-05-22.md`). Borrowed-and-adapted from `affaan-m/everything-claude-code` (ECC, 188k★, MIT) — specifically the per-hook env-var disable pattern in `quality-gate.js` + `gateguard-fact-force.js`. The 2026-05-22 5-agent council surfaced two amendments (safety-hook exclusion + session-start visibility) without which this convention would be a footgun; both are mandatory below.

**Pairs with**: `.claude/skills/autovibe/SKILL.md` § Phase 4.8 (the `AUTOVIBE_AUTOFIRE` kill-switch is the **grandfathered seed precedent** — autovibe shipped this convention before it was generalised; this rule generalises what autovibe already proved).

---

## The principle

Hooks are non-skippable by design — they fire on every matching tool call or session event. That is what makes them reliable. But three legitimate scenarios need to disable a specific hook for a specific session:

1. **The hook itself is broken** (regex compile fail, python3 absent, network dependency unreachable) and is producing noise rather than signal. The user needs to suppress it until it's fixed.
2. **The hook's purpose does not apply** to the current work (e.g., a code-review-load hook during a docs-only session, where loading the identity preamble adds tokens without value).
3. **The user is testing a hook's behaviour** and needs an A/B comparison (run-with vs run-without).

Hard-coded "always on" hooks force users to comment-out the hook entry in `settings.local.json`, lose the comment when the file is regenerated, and re-suffer the noise. A documented per-hook env-var kill-switch is the durable answer.

---

## The convention

### Env-var naming (precise algorithm)

The kill-switch env-var name is derived from the hook filename by this algorithm — **no `_DISABLED` suffix**, matching the `AUTOVIBE_AUTOFIRE` precedent (a feature flag, not a state assertion):

```
HOOK_<UPPER_STEM>
```

Where `UPPER_STEM` = the hook filename with the `.sh` (or `.py`, `.js`) extension stripped, then UPPER-cased, then hyphens replaced with underscores. Examples:

| Hook script | Kill-switch env var |
|---|---|
| `framing-audit-activation.sh` | `HOOK_FRAMING_AUDIT_ACTIVATION` |
| `pocock-implicit-activation.sh` | `HOOK_POCOCK_IMPLICIT_ACTIVATION` |
| `vault-capture.sh` | `HOOK_VAULT_CAPTURE` |
| `session-summarizer.sh` | `HOOK_SESSION_SUMMARIZER` |

**Semantics** (no-suffix pattern — feature-flag, not state-assertion): `HOOK_FRAMING_AUDIT_ACTIVATION=0` reads as "the framing-audit-activation hook is set to 0 (off)". Default (unset/empty) = ENABLED. Setting to `0` (or any disable variant) = DISABLED. Setting to `1`/`true`/`yes` = ENABLED (same as default — explicit "on"). This matches `AUTOVIBE_AUTOFIRE=0` = "autofire is off".

The algorithm is deterministic — two authors who follow it independently produce the same name. Do NOT abbreviate. Do NOT pluralise. Do NOT add a `_DISABLED` suffix (the original ECC convention used mixed shapes; we standardise on the cleaner no-suffix form to match autovibe). Do NOT prefix with `CLAUDE_` or `NEWEARTH_` (that would couple the convention to a single project; this rule is template-bound).

### Accepted disable values (truthy-variant accept)

The env-var accepts **any** of these case-insensitive values as DISABLE:

```
0    false    no    off    disabled
```

Five values, case-insensitive. Anything else (unset, empty, `1`, `true`, `yes`, the literal string `enabled`, anything not in the disable list) means **ENABLED**. Default = ENABLED.

This convention is the **truthy-variant pattern** — exact-match with `AUTOVIBE_AUTOFIRE` (same 5 values; see `.claude/skills/autovibe/SKILL.md` § Phase 4.8). Authors do NOT invent a new dialect per hook. Symmetry is the whole point — and "exact match" means literally the same 5 values, no synonyms added per-hook.

### Safety-hook exclusion list — **NEVER** candidates

The convention does **NOT** apply to the following hooks. These are blocking safety guards; silently disabling them is a footgun (the failure mode is invisible — there is no error, no log, no warning; the hook simply never fires, and the next time the user runs a destructive operation, the guard isn't there):

| Hook | Why it must NEVER be env-var disable-able |
|---|---|
| `.claude/hooks/bash-guardian.sh` | Blocks destructive shell ops (`rm -rf /`, force-push to main, etc.) |
| `.claude/hooks/sql-guardian.sh` | Blocks `SELECT *`, unbounded UPDATE/DELETE without WHERE |
| `.claude/hooks/supabase-migration-guard.sh` | Gates RLS-touching migrations |
| `.claude/hooks/commit-guardian.sh` | Gates secrets in commit content |
| `.claude/hooks/worktree-guard.sh` | Enforces single-folder branch discipline |
| `.claude/hooks/dashboard-review-gate.sh` | Blocks hardcoded service-role keys + `dangerouslySetInnerHTML` (XSS) before commit |
| `.claude/hooks/dev-prod-deploy-guard.sh` | Blocks an autonomous (autovibe-active) production deploy lacking the `AUTOVIBE_PROD_DIRECT` staging-first override. Failure mode = silent prod deploy by an autonomous run. Only bypass is the documented override flag. Requires per-project config (`PROD_MCP_PATTERN`/`PROD_REF`). Coupled with the `dev-prod` skill. |
| any future hook whose failure mode is "data loss / production incident" | Disabling is a safety regression by definition |

These hooks may still have **maintenance modes** (e.g., `--allow-select-star` flags for a specific known-safe context), but those are explicit per-invocation overrides, NOT session-wide silent disables. If a user needs to bypass one of these for a specific operation, the bypass is documented in the hook itself, not surfaced via the convention.

If a future safety hook needs ANY form of disable (e.g., a known-broken regex causing false positives), the disable lives in the hook's own dedicated env var (e.g., `SQL_GUARDIAN_ALLOW_SELECT_STAR=1` for a single command), NOT this generic convention. Renaming a safety hook's bespoke disable into the `HOOK_*_DISABLED` convention is a regression — the convention's existence implies "this hook is safe to disable", and that's a lie about safety hooks.

### Session-start visibility — **MANDATORY** for retrofitted hooks

Every hook that adopts this convention MUST emit a one-line warning to stderr when its own disable env var is detected as active. The warning fires on every invocation of the hook (SessionStart, PreToolUse, UserPromptSubmit, whichever event triggers it) — it is NOT a one-time-per-session message. This prevents the silent-disable failure mode: a user who exports the env var in `.zshrc` and forgets sees the warning every session and remembers to unset it.

**Format**:

```
hook-name: DISABLED via HOOK_<NAME>=<value> — unset or set to 1/true/yes/enabled to re-enable
```

Example (from `.claude/hooks/framing-audit-activation.sh`):

```
framing-audit-activation: DISABLED via HOOK_FRAMING_AUDIT_ACTIVATION=0 — unset or set to 1/true/yes/enabled to re-enable
```

The warning goes to stderr (not stdout) so it does not pollute the hook's JSON-envelope output contract. Stderr is surfaced by the harness to the user as a visible message.

---

## Implementation pattern (the 3-line bash snippet)

The canonical retrofit, applied at the top of any hook script after `set -uo pipefail`:

```bash
HOOK_DISABLE_VAR="HOOK_FRAMING_AUDIT_ACTIVATION"  # match the algorithm (no _DISABLED suffix)
HOOK_DISABLE_VAL="$(printf '%s' "${!HOOK_DISABLE_VAR:-}" | tr '[:upper:]' '[:lower:]')"
case "$HOOK_DISABLE_VAL" in
  0|false|no|off|disabled)
    echo "framing-audit-activation: DISABLED via ${HOOK_DISABLE_VAR}=${!HOOK_DISABLE_VAR} — unset or set to 1/true/yes/enabled to re-enable" >&2
    exit 0
    ;;
esac
```

Three lines of logic (variable name + lowercased value + case). The early-return uses `exit 0` (never block a session) per Claude Code hook contract. The session-start warning is on the same `exit 0` path — fires every invocation of the disabled hook.

**Authors**: copy this snippet, substitute the hook name in three places (the env var, the warning string, and the comment). That's it.

**Python / Node hooks**: same shape, idiomatic to the language. The convention is bash-canonical because the majority of our hooks are bash, but the algorithm + accepted values + safety-hook exclusion list apply identically across languages.

---

## When this convention does NOT apply

- **Safety hooks** (see exclusion list above). Bespoke per-invocation flags instead.
- **Hooks whose disable would break a downstream contract** (e.g., a hook that writes session state required by a SessionEnd hook — disabling the writer breaks the reader's invariants). Document the contract dependency in the hook header.
- **Hooks the user never sees** (e.g., internal heartbeat hooks that compose with other hooks). If nobody would ever need to disable it, don't add the env var — YAGNI.

---

## Composition with `AUTOVIBE_AUTOFIRE` (the grandfathered seed precedent)

The autovibe Phase 4.8 kill-switch shipped first (2026-05-08) and used the exact same truthy-variant convention this rule generalises. Its name `AUTOVIBE_AUTOFIRE` is a perfect fit for this rule's algorithm in spirit (no `_DISABLED` suffix; feature-flag shape; `=0` means off) — only its prefix differs (`AUTOVIBE_` instead of `HOOK_`) because:

- `AUTOVIBE_AUTOFIRE` gates a **phase decision** ("should autovibe fire the autofire dispatch?"), not a hook invocation
- It predates this rule (the convention was invented inside autovibe, not yet generalised)
- It uses the `AUTOVIBE_` namespace for visibility in `.zshrc` (operator-facing setting documented in the autovibe skill)

So: `AUTOVIBE_AUTOFIRE` is the **seed precedent** — the working example that proved the truthy-variant feature-flag shape this rule generalises. Future autovibe phase decisions keep the `AUTOVIBE_<PURPOSE>` namespace (a phase decision, not a hook). Future HOOKS — autovibe-owned or otherwise — use this rule's `HOOK_<UPPER_STEM>` algorithm.

---

## Failure modes prevented by this convention

The 2026-05-22 5-agent council surfaced three failure modes this convention's strict shape prevents. Documented here so future authors who consider "loosening" the convention understand the cost.

1. **Silent disable of a safety hook (NSF-B1 — Reliability Engineer)**: without the safety-hook exclusion list, the convention is a ready-made silencer for `bash-guardian.sh`. A user exports `HOOK_BASH_GUARDIAN=0` once in `.zshrc` and the guard never fires again — until the next destructive operation. The exclusion list + the rule's explicit prohibition prevents this.

2. **Naming drift between independent authors (Capability Scout)**: without the precise derivation algorithm, two authors retrofitting two different hooks independently produce different env-var names for the same hook (`HOOK_FRAMING_AUDIT` vs `HOOK_FRAMING_AUDIT_ACTIVATION` — the former drops a stem segment). The algorithm is the single source of truth.

3. **Invisible disable state (NSF-B1, all 5 agents)**: without the session-start visibility mandate, a user who exports the env var in `.zshrc` and forgets sees nothing for weeks. The mandatory stderr warning ensures every session reminds the user that a hook is disabled.

---

## Decommission triggers

Retire this rule when ANY of:

1. Claude Code's hook harness ships a **native** per-hook profile/mode mechanism that replaces the env-var convention (e.g., `settings.local.json` adds a `disabled: true` field per matcher).
2. The convention produces ≥3 documented incidents of an accidental safety-hook disable (a sign the safety-hook exclusion list is not strong enough as a soft constraint and needs to be enforced by a `bash-guardian`-style check).
3. The agency's hook population drops to <5 (the convention's overhead exceeds the leverage at low population).

If decommission triggers fire: write a migration note that retros the convention's adopters to the new mechanism, then delete this rule.

---

## References

- `.claude/skills/autovibe/SKILL.md` § Phase 4.8 — the grandfathered seed precedent (`AUTOVIBE_AUTOFIRE`)
- `.claude/hooks/framing-audit-activation.sh` — the first worked retrofit (2026-05-22)
- `agency/memory/audit_ecc-2026-05-22.md` — the audit memo that justified this rule
- `~/.claude/plans/rosy-knitting-bengio.md` — the council-amended plan (v2)
- `.claude/skills/security-scan-agentshield/LOCAL-ADAPTATIONS.md` — Override 2 references this rule for the forward-compatibility kill-switch
- Upstream ECC source: `https://github.com/affaan-m/everything-claude-code/tree/main/hooks` (MIT — © 2026 Affaan Mustafa)
