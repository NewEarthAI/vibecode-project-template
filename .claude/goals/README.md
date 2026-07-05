# Goal-Ledger — `.claude/goals/`

The cross-session record of every autonomously-spawned chain's intended end, lineage,
constraints, touched surfaces, and status. **Managed ONLY by**
`.claude/skills/_shared/goals.sh` — do **not** hand-edit the per-thread frontmatter; the
helper is the sole writer and enforces the frozen schema.

Programme: Goal-Ledger Build Programme (`specs/12_GOAL_LEDGER_BUILD_PROGRAMME.md`).
This directory is provisioned at /setup time and houses per-thread goal records
(Session 4 kickoff). The expected runtime callers are the newvibe Stop / PreCompact hooks
(Session 4 wires them) and the master-continuation-prompt §5C reaper handshake.

---

## File shape

One file per goal thread: `goal-<slug>-<8hex>.md`.

Frontmatter is JSON-encoded YAML (every value is a JSON scalar/array/null; YAML 1.2 is a
JSON superset so the block parses both ways). The **FROZEN** 11-key schema (spec §4):

```yaml
goal_id: <slug>-<8hex>            # globally unique; immutable
intended_end: <string>            # a /goal-style tool-verifiable condition OR a DESTINATION.md pointer
roadmap_ref: <milestone-id>       # a STABLE ROADMAP.md milestone id — NEVER a display name; null only at open
parent_goal_id: <goal_id|null>    # the chain this descends from
constraints: [<string>]           # what must NOT change; carried forward from parent at write
declared_touches: [<path>]        # files this goal expects to modify
actual_touches: [<path>]          # written post-achievement from `git diff --name-only`
status: active | achieved | abandoned | paused
owning_artefact: <path>           # the continuation / spec / DESTINATION.md driving this goal
created_at / updated_at: <ISO 8601>
```

**Non-negotiables** (spec §4):

- One file per thread — never a single shared file (eliminates the concurrent-write corruption class).
- `goal_id` is also stamped into the owning continuation's §5A frontmatter
  (`<!-- goal_id: ... -->`) so the next session's reaper recovers it from disk after compaction.
- A goal with no `roadmap_ref` MAY spawn (warn) but MAY NOT reach `status: achieved` —
  the helper hard-refuses with exit 3 until `roadmap_ref` is set.
- Contradiction detection (Stage 3) uses `declared_touches` overlap as the deterministic
  PRIMARY gate (always computed) and a conservative semantic comparison as the SECOND
  layer; BLOCK outranks WARN at verdict time.

## Helper subcommands

The helper is `.claude/skills/_shared/goals.sh`. All subcommands are run as
`bash .claude/skills/_shared/goals.sh <subcommand> ...`.

### Open / read / mutate

- `new <slug> <intended_end> <owning_artefact> [parent_goal_id] [declared_touches_json]`
  → prints the goal_id on stdout. **Unguarded** — no collision check; use this only when
  collision safety is otherwise guaranteed (e.g. the master-continuation-prompt §5C
  handshake, which precedes the new with its own reaper close).
- `read <goal_id> [field]` → full JSON record, or a single field's raw value.
- `set <goal_id> <field> <value>` → atomic scalar update (schema-locked; `goal_id` and
  `created_at` are immutable; `status` cannot be set to `achieved` via `set` — that
  bypass-attempt is rejected, use `achieve`).
- `set-list <goal_id> <field> <json-array>` → atomic list update for `constraints` /
  `declared_touches` / `actual_touches`.
- `achieve <goal_id>` → transition to `achieved`. Hard-refuses (exit 3) without a
  `roadmap_ref`. Computes `actual_touches` from `git diff --name-only`.
- `abandon <goal_id>` / `reap <prior_goal_id>` → transition to `abandoned`. Idempotent;
  salvages a corrupt-but-present entry rather than leaking a phantom `active`.
- `list [status]` → newline-separated `<goal_id>\t<status>` lines; corrupt files row out
  as `<filename>\tCORRUPT`.

### Walk / collision-check / atomic spawn (Stage 3 — Session 3)

- `lineage <goal_id>` → JSON array from self to root. Cycle-guarded (visited-set) +
  depth-capped (100). A missing/corrupt ancestor stops the walk with a stderr warning
  rather than failing.
- `check-collision <intended_end> [declared_touches_json] [parent_goal_id]` →
  **advisory** (lock-free) verdict. Exits 0 clean, 10 warn (file overlap → emits the
  pause banner deferring to `continuation-collision-safety.md`), 11 block (contradiction
  → escalate to operator). Never writes.
- `spawn-check <slug> <intended_end> <owning_artefact> [parent_goal_id] [declared_touches_json]`
  → **atomic** collision-check-THEN-create under the ledger-wide lock. On clean, prints
  the new goal_id (exit 0). On WARN/BLOCK, prints the verdict on stdout and creates
  **nothing** (exit 10/11). This is the guarded analogue of `new`; the newvibe spawn
  path is wired to this in Session 4.

### Roadmap-addition gate (Stage 4 — Session 3)

- `roadmap-gate "<proposed addition>"` → prints the ready-to-run two-skill gate block.
  Full procedure: `.claude/skills/_shared/roadmap-addition-gate.md`. Operator-authored
  ROADMAP edits are EXEMPT — the gate fires only on goal-triggered automatic additions.

## Exit codes

| Code | Meaning |
|------|---------|
| 0  | ok |
| 2  | usage / bad arg / invalid goal_id |
| 3  | `achieve` refused — missing `roadmap_ref` |
| 4  | goal not found |
| 5  | lock held after retry (~5s) |
| 6  | corrupt record / jq missing / write failed |
| 10 | collision WARN — `declared_touches` overlap; defer to `continuation-collision-safety.md` |
| 11 | collision BLOCK — contradictory `intended_end`; escalate to operator; no entry created |

## Concurrency model

- **Per-id lock** (`.lock-<goal_id>`): serialises same-id read-modify-write (set / achieve / close).
  Mkdir-atomic, TTL 30 min, future-skew tolerance 60 min, bounded retry (~5 s) — mirrors
  `state.sh`.
- **Ledger-wide lock** (`.lock-.ledger`): serialises `spawn-check` vs `spawn-check` only.
  Bare `new` does NOT take this lock — it is the unguarded legacy path; Session 4 routes
  the newvibe spawn path through `spawn-check` so the unguarded `new` is off the
  autonomous path.

## Integration points

- `/master-continuation-prompt` §5A — stamps `goal_id` into the continuation frontmatter.
- `/master-continuation-prompt` §5C — runs the reaper handshake (`reap` prior + `new` next).
- `/prompt-forge` Component 9 — stamps `goal_id` + `intended_end` into a forged prompt.
- `/autovibe` — writes `goal_id` into `autovibe-state.json` via `state.sh write goal_id`
  (top-level field — see Session 2's operator-settled deviation).
- newvibe hooks (Session 4) — read the ledger on Stop / PreCompact; spawn-path uses
  `spawn-check`.

## References

- 📄 Helper: `.claude/skills/_shared/goals.sh`
- 📄 Recovery runbook: `.claude/skills/autovibe/references/goal-ledger-recovery-runbook.md` — operator paths for stuck lock / corrupt record / phantom active entries
- 📄 Programme spec: `specs/12_GOAL_LEDGER_BUILD_PROGRAMME.md`
- 📄 Alignment contract: `.claude/rules/goal-ledger-programme-alignment.md`
- 📄 Roadmap gate procedure: `.claude/skills/_shared/roadmap-addition-gate.md`
- 📄 Collision-safety doctrine: `.claude/rules/continuation-collision-safety.md`
- 📄 Concurrency primitive: `.claude/rules/shell-portability.md` §4 (mkdir-lock)
