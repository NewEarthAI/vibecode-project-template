# `/newearth-security` Toggle Mechanism

**Locked by council 2026-05-22 — Amendments 3, 4, 5, 6, 14, 15.**

## Why a toggle exists

A confidence-calibrated security skill that fires inappropriately (during a docs-only session, during a hotfix-class incident where the operator has temporary judgement on a risk) is friction, not protection. The toggle lets the operator suppress this skill for a session, a project, or globally — **without** silently degrading other security skills (`security-threat-model`, `security-scan-agentshield`) which remain independent.

## The three layers (precedence: most ephemeral wins)

| Layer | Mechanism | Scope | When to use |
|---|---|---|---|
| 1 | **Env var**: `NEWEARTH_SECURITY_ENABLED` | This shell / this Claude session | Quick session-level toggle for the operator working directly in the terminal |
| 2 | **Filesystem flag**: `.claude/newearth-security.disabled` (file exists → disabled) | This repo / all sessions / **all sub-agents** | Sub-agent propagation; project-level mute |
| 3 | **Settings**: `~/.claude/settings.local.json` key `"newearth_security_enabled": false` | All projects on this machine | Per-Mac default for the operator |

**Precedence rule**: Layer 1 overrides Layer 2 overrides Layer 3. Most ephemeral wins. The intent is that operator intent in the moment trumps long-running defaults.

## Accepted values (Layers 1 AND 3 share this grammar — case-insensitive)

| Value | Meaning |
|---|---|
| `1` `true` `yes` `on` `enabled` | ENABLED (explicit) |
| `0` `false` `no` `off` `disabled` | DISABLED |
| (anything else, e.g. `maybe`) | **INDETERMINATE — caller HALTS** (exit 2). Per Amendment 5: no silent bypass on a misconfigured toggle. |

**Layer 3 (settings.local.json) shares this exact grammar** (V1.1 unification). A boolean
`false`, a string `"false"`, or a string `"off"` all DISABLE — an operator's disable intent is
honoured regardless of JSON quoting. An unrecognised string (e.g. `"maybe"`) triggers exit 2
(INDETERMINATE) just as in Layer 1. A missing key, JSON `null`, or an empty file = no Layer-3
opinion → falls through (no signal → enabled default).

## Exit codes (Amendment 4)

| `is-enabled.sh` exit | Caller behaviour |
|---|---|
| **0** = ENABLED | Proceed with the security review |
| **1** = DISABLED | Emit re-enable banner; exit 0 |
| **2** = INDETERMINATE value | **HALT with banner**. A toggle value is set but unrecognised (operator typo). Do NOT silently bypass. Fix the value. |
| **3** = INSTALLATION BROKEN | **HALT with banner**. jq missing, `settings.local.json` is invalid JSON, or the repo root could not be resolved. Distinct from exit 2 — this is an environment problem, not an operator typo. Fix the install. |

> **V1.1 split (code-council item F)**: exit 2 (a bad *value*) and exit 3 (a broken *install*) were
> separated so the operator knows whether to fix their toggle setting or their environment. Both HALT —
> a security skill that cannot determine its own state never silently proceeds (Amendment 5).

## Sub-agent toggle propagation (Amendment 14)

**Important**: env vars (Layer 1) do **NOT** propagate to sub-agents spawned via the Agent tool. A sub-agent invoked from `/code-council` or `/code-forge` will see Layer 2 + Layer 3 but **not** Layer 1 unless the parent shell exported the var into the spawn environment.

→ **To suppress `/newearth-security` for an entire `/code-council` security pass, use the filesystem flag** (Layer 2):

```bash
touch .claude/newearth-security.disabled
# run /code-council — security agent in the council finds the flag, exits 0
rm .claude/newearth-security.disabled  # restore default
```

The filesystem flag is visible to every sub-agent because it's part of the working tree, not the process environment.

## How to enable / disable — concrete commands

### Disable for this session only (Layer 1):
```bash
export NEWEARTH_SECURITY_ENABLED=0
```

### Disable for this repo across all sessions + sub-agents (Layer 2):
```bash
touch .claude/newearth-security.disabled
```

### Disable on this Mac across all repos (Layer 3):
```jsonc
// ~/.claude/settings.local.json
{
  "newearth_security_enabled": false
}
```

### Re-enable (any layer):
```bash
unset NEWEARTH_SECURITY_ENABLED                       # Layer 1
rm .claude/newearth-security.disabled                 # Layer 2
# Layer 3: remove the key or set true in settings.local.json
```

## SessionStart banner (V1.0 status)

V1.0 wires a SessionStart banner via `.claude/hooks/sessionstart-context-aggregator.sh`. If ANY of the 3 layers signals disabled, the SessionStart context emits an H3 heading + a re-enable bullet list (the actual format is multi-line, not the single line shown here — this is the gist, not a verbatim copy):

> ### 🔒 newearth-security DISABLED
> Re-enable via `unset NEWEARTH_SECURITY_ENABLED` OR `rm .claude/newearth-security.disabled` OR remove the `newearth_security_enabled: false` key from `~/.claude/settings.local.json`.

This is a visibility guard against the silent-disable failure mode flagged by Reliability Engineer in council 2026-05-22.

## Trust model (code-council item E)

The toggle trusts exactly the same surfaces the rest of Claude Code config trusts — no more, no less. It is **not** a security boundary against a hostile local actor; it is a convenience switch for the operator.

| Surface | Trusted to the same degree as | Implication |
|---|---|---|
| **Env var** (`NEWEARTH_SECURITY_ENABLED`) | the operator's shell environment | anyone who can set env vars in your shell can disable the skill — same as anyone who can run any command |
| **Filesystem flag** (`.claude/newearth-security.disabled`) | the working tree / repo contents | anyone who can write to the repo can disable the skill — same trust as anyone who can edit `.claude/settings.json`, hooks, or skills |
| **settings.local.json** | the operator's `~/.claude/` config | machine-level config, same trust as every other Claude Code setting |

**What this means**: the toggle does NOT defend against an attacker who already has write access to your repo or shell — such an attacker can disable far more than this one skill. The toggle's job is to let the *legitimate operator* mute the skill cleanly, with an audit trail (`.claude/security-toggle-audit.log`, item M) and a visible SessionStart banner so a forgotten disable is never silent. Treat a disabled toggle as an operator decision, not as evidence of compromise — but the audit log + banner make a *surprising* disable investigable.

## Filesystem-flag scope (code-council item H)

**V1.1 resolution change (backlog item B)**: Layer 2 resolves the repo root via
`git rev-parse --show-toplevel` first — so the `.claude/newearth-security.disabled` flag is read from
**the git repo the operator is currently working in** (CWD-relative), not hard-locked to the skill's
install directory. If the invocation is outside any git repo, it falls back to walking up from the
script's own directory.

Practical implications:
- In a normal single-repo session, CWD-repo and install-repo are the same — no behavioural difference.
- In a multi-repo / worktree session, the flag honours **the repo you're in**, which is the intuitive
  scope (disable security review for *this* project).
- If the repo root cannot be resolved at all (non-git invocation where the script-dir fallback also
  fails), `is-enabled.sh` returns exit 3 (installation broken) and the caller HALTS — it does NOT
  silently ignore a possibly-present flag.

## Decommission trigger

Per plan v2 §8 #3: if the toggle is never used in 90 days (no `is-enabled.sh` exit 1 across all sessions), simplify by removing one or more layers. Until then, all three layers stay.
