# Goal-Ledger Recovery Runbook

**Audience**: operator (no code-reading required for routine paths).
**Scope**: three operator-side recovery paths the `goals.sh` helper already handles internally; this document names the symptoms, the inspection steps, and the manual interventions when the helper's automatic salvage is insufficient.
**Pairs with**: `.claude/goals/README.md` (FROZEN §4 schema + subcommand reference).

---

## 1. Stuck ledger lock (`goals.sh` exit 5)

**Symptom**: `goals.sh spawn-check` or `goals.sh new` exits 5 with `goals.sh: ledger lock held — refusing to proceed`. A subsequent retry within the same session also exits 5.

**Inspection** (no destructive ops):

```bash
ls -la .claude/goals/.lock-.ledger/                    # is the dir present?
cat .claude/goals/.lock-.ledger/acquired_epoch 2>/dev/null  # who took it + when
date +%s                                                # current epoch
```

The lock's `acquired_epoch` is the Unix timestamp when the lock was taken. The helper's TTL is 30 minutes — locks older than that are automatically broken on the next spawn-check attempt.

**Recovery — auto** (the common case): wait 30 seconds and retry. If `acquired_epoch` is older than 30 minutes, the next `spawn-check` will break the stale lock and proceed.

**Recovery — manual** (when the helper refuses to auto-break, typically because clock-skew makes the lock appear future-dated): inspect the lock dir contents to confirm no live writer is present. If empty or stale, manually clear:

```bash
rmdir .claude/goals/.lock-.ledger    # POSIX-atomic; fails if dir not empty
```

If `rmdir` fails because the dir contains a metadata file, inspect it first — a present-and-fresh metadata file means another session is in flight. Wait. A present-but-stale metadata file (older than 30 minutes) can be removed: `rm .claude/goals/.lock-.ledger/* && rmdir .claude/goals/.lock-.ledger`.

---

## 2. Reaper failure on a salvageable corrupt entry (`goals.sh` exit 6)

**Symptom**: `goals.sh achieve <id>` or `goals.sh reap <id>` exits 6 with `enumeration-failure` or `corrupt-record`. The goal file exists at `.claude/goals/goal-<id>.md` but its frontmatter is malformed (manual edit gone wrong, partial write, mid-flight crash).

**Inspection**:

```bash
cat .claude/goals/goal-<id>.md | head -20         # see the frontmatter
goals.sh read <id> 2>&1                           # see the helper's error
ls .claude/goals/*.corrupt-*.md 2>/dev/null       # any prior salvage records
```

**Recovery — auto**: when `cmd_close` (called by `achieve`/`abandon`/`reap`) detects an un-parseable frontmatter, it moves the corrupt file aside to `goal-<id>.corrupt-<unix-epoch>.md` and writes a salvage record at the original path stamping `status: abandoned` with `salvage_reason`. The ledger is then in a consistent state.

**Recovery — manual** (when the salvage record itself is malformed, or the original file's content is needed for forensic reconstruction):

1. Inspect the `.corrupt-<epoch>.md` aside file — its raw content reveals the failed write.
2. If the goal's intent is recoverable, hand-author a fresh record at `.claude/goals/goal-<recovered-id>.md` matching the FROZEN §4 schema (11 keys, see README). Use a new id slug — DO NOT re-use the corrupt one.
3. Mark the corrupt file `status: abandoned` and add a one-line `salvage_reason` pointing to the new record.

The 11-key schema is FROZEN — any hand-authored record must match exactly. Reference `.claude/goals/README.md` §4 for the keys + types.

---

## 3. Phantom `active` entry (handshake didn't fire)

**Symptom**: `goals.sh list active` shows a goal that should have been closed. The owning continuation has been superseded but the `master-continuation-prompt` §5C reaper handshake didn't run (the next chain crashed before the reaper, OR the operator ran `/master-continuation-prompt` outside the §5C flow).

**Inspection**:

```bash
goals.sh list active                              # find the phantom id
goals.sh read <id> owning_artefact                # which continuation owns it
ls continuations/$(goals.sh read <id> owning_artefact)  # does the owning file still exist?
```

If the owning continuation no longer exists (or has been completed and replaced), the entry is genuinely orphaned.

**Recovery — manual** (the only path; there is no auto-salvage for phantom-active entries):

```bash
# Option A — if the work the goal tracked was completed:
goals.sh set <id> roadmap_ref <ROADMAP item this advanced>
goals.sh achieve <id>

# Option B — if the work was abandoned or superseded:
goals.sh abandon <id> "phantom-active recovery — owning continuation superseded without §5C reaper"
```

Option A requires a `roadmap_ref` (the FROZEN §4 schema; `achieve` exits 3 without one — that exit code is specifically the absent-roadmap-ref guard). Option B does not — `abandon` accepts any reason string.

---

## Exit-code cheat sheet

| Exit | Meaning | Operator response |
|---|---|---|
| 0 | OK | proceed |
| 2 | Invalid argument (wrong id format, missing required arg) | fix the call site |
| 3 | `achieve` without `roadmap_ref` set | run `goals.sh set <id> roadmap_ref <slug>` first |
| 5 | Lock stuck | wait 30s; if persistent, see §1 |
| 6 | Enumeration failure / corrupt record | see §2 |
| 10 | Collision WARN (semantic contradiction with active peer) | inspect the colliding peer; per `continuation-collision-safety.md`, write the pause banner; do NOT spawn |
| 11 | Collision BLOCK (declared_touches overlap with active peer) | hard stop — surface BOTH goal_ids + both intended_ends to the operator; do NOT auto-resolve |

---

## When the runbook is NOT sufficient

If a recovery path falls outside §1–§3 (e.g., the ledger directory is missing entirely; the `goals.sh` helper itself is corrupt; the `.claude/skills/_shared/` directory is inaccessible) — escalate. The system is filesystem-only by design; full ledger loss requires re-deriving active goals from continuation frontmatter (`grep -rn '<!-- goal_id: ' continuations/`) and re-creating entries via `goals.sh new` with explicit human-judged status fields. This is a programme-level recovery, not a routine one.
