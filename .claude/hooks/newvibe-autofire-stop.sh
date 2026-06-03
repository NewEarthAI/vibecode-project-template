#!/bin/bash
# .claude/hooks/newvibe-autofire-stop.sh
#
# NewVibe autofire — Stop hook entry point (Gate A fix, 2026-05-17).
#
# Registered on the Claude Code `Stop` event. This is the shell-enforced trigger
# that replaces the conversational SKILL.md Phase 4.8 prose: autofire now fires
# from a hook, never from a chat remembering to run it.
#
# A Stop hook fires after EVERY assistant turn, so this script's default path is
# a fast, silent no-op. It dispatches ONLY when nv_detect_ship_completion (in the
# dispatch library) confirms a genuinely clean ship completed, a fresh master
# continuation exists, and that continuation has not already been autofired.
#
# All real safety (runaway cap, kill-switch, arm flag, daytime gate, verifier,
# lock, sha re-check) lives in newvibe-dispatch-lib.sh. This file only wires the
# event to the library. It always exits 0 — a Stop hook must never block.

set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$HOOK_DIR/../.." && pwd)"
LIB="$PROJECT_ROOT/.claude/skills/autovibe/scripts/newvibe-dispatch-lib.sh"

# Library missing (e.g. skill not installed on this repo) -> silent no-op.
[ -f "$LIB" ] || exit 0

# Pass the repo root so the library skips its source-time path-discovery
# subshells (this hook fires every turn — keep the no-op path cheap). A
# pre-set value (test harness) is respected; production defaults to the repo.
export NEWVIBE_ROOT_OVERRIDE="${NEWVIBE_ROOT_OVERRIDE:-$PROJECT_ROOT}"

# shellcheck source=/dev/null
source "$LIB" || exit 0

# Fast path: no clean-ship completion signal -> silent no-op (the common case,
# every non-ship turn). nv_detect_ship_completion returns 1 the moment
# .claude/ship-state.json is absent, so this is near-instant on most turns.
CANONICAL="$(nv_detect_ship_completion 2>/dev/null)" || exit 0
[ -n "$CANONICAL" ] || exit 0

# A clean ship completed, a fresh master continuation exists, and it has not yet
# been autofired -> hand off to the gated dispatch. nv_autofire runs every gate
# and (unless armed) only logs a would-dispatch entry.
nv_autofire "$CANONICAL" "stop" || true

exit 0
