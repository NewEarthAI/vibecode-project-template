#!/bin/bash
# .claude/hooks/newvibe-precompact-handoff.sh
#
# NewVibe context-budget handoff — PreCompact hook entry point (Gate A fix,
# 2026-05-17). Replaces the conversational SKILL.md "Phase 4.6 — Context-Budget
# Gate" prose, which depended on the model noticing it had crossed a guessed
# 40% threshold.
#
# Registered on the Claude Code `PreCompact` event. PreCompact fires when the
# harness is about to compact the context window — a precise system signal that
# context is genuinely full, strictly better than a self-estimated percentage.
#
# Behaviour:
#   1. Best-effort: run post-handoff-writer.sh so a DRAFT continuation floor
#      exists for the next session even if conversational Phase 4.7 never ran.
#   2. If a rich AUTOVIBE-*-MASTER.md continuation exists, hand it off via the
#      gated dispatch (nv_autofire).
#
# Known Phase-1 limitation (raised for code-council): post-handoff-writer.sh
# produces a DRAFT; autofire dispatches a MASTER. If only a DRAFT exists, this
# hook writes the floor but does not dispatch — fail-safe, but the context-budget
# handoff is then a written artefact only, not an auto-dispatched one.
#
# All safety gates live in newvibe-dispatch-lib.sh. Always exits 0.

set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$HOOK_DIR/../.." && pwd)"
LIB="$PROJECT_ROOT/.claude/skills/autovibe/scripts/newvibe-dispatch-lib.sh"

[ -f "$LIB" ] || exit 0

# Pass the repo root so the library skips its source-time path-discovery subshells.
# A pre-set value (test harness) is respected; production defaults to the repo.
export NEWVIBE_ROOT_OVERRIDE="${NEWVIBE_ROOT_OVERRIDE:-$PROJECT_ROOT}"

# shellcheck source=/dev/null
source "$LIB" || exit 0

# Step 1 — best-effort DRAFT continuation floor. post-handoff-writer.sh skips
# cleanly (logs to stderr) when there is no autovibe-state.json or no rich
# MASTER to supersede; it never blocks.
if [ -x "$NV_HANDOFF_WRITER" ]; then
  bash "$NV_HANDOFF_WRITER" 0 clean >/dev/null 2>&1 || true
fi

# Step 2 — dispatch the latest rich MASTER continuation, if one exists.
CANONICAL="$(nv_find_latest_continuation 2>/dev/null)" || exit 0
[ -n "$CANONICAL" ] || exit 0

nv_autofire "$CANONICAL" "precompact" || true

exit 0
