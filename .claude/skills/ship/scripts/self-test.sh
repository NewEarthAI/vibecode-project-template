#!/usr/bin/env bash
# self-test.sh — /ship canary for the typecheck guard.
#
# Why this exists: a gate that passes without checking anything is worse than no gate.
# `npx tsc --noEmit` against a root tsconfig with `"files": []` + project references
# returns exit 0 while checking literally zero files — a silent no-op. This canary
# proves the typecheck guard is actually checking files and catching errors.
#
# Two canaries run in sequence:
#   1. File-inclusion: `tsc -p tsconfig.app.json --listFilesOnly --noEmit` must
#      list ≥20 .ts/.tsx files. A broken "files: []" config lists 0-1.
#   2. Semantic-check: run `tsc --noEmit --strict` on a temp file containing a
#      deliberate type error (const x: string = 42). tsc must REJECT. If it
#      accepts, the type checker is broken.
#
# Exit codes:
#   0 — both canaries passed; typecheck guard is functional
#   1 — at least one canary failed; guard is broken; /ship must halt
#   2 — environment bootstrap issue (npx missing, tsconfig missing, no node_modules);
#       non-fatal — CI job will re-validate after `npm ci`
#
# Modes:
#   (no args)  — full canary run (default; invoked by preflight)
#   --canary   — same as default, plus verbose output for manual diagnostics

set -uo pipefail

VERBOSE=0
case "${1:-}" in
  --canary) VERBOSE=1 ;;
  "") : ;;
  *) echo "self-test: unknown arg '$1' (expected --canary or no args)" >&2; exit 1 ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Walk up to project root — self-test.sh lives in .claude/skills/ship/scripts/
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

say() { [ "$VERBOSE" = 1 ] && echo "$@" >&2; }

# --- Environment bootstrap ---
if ! command -v npx >/dev/null 2>&1; then
  echo "self-test: SKIP — npx not found (dev env not bootstrapped)" >&2
  exit 2
fi

# Prefer tsconfig.app.json (Vite+React project-references pattern) but fall back
# to tsconfig.json for older/simpler project layouts.
TSCONFIG=""
for candidate in "tsconfig.app.json" "tsconfig.json"; do
  if [ -f "$PROJECT_ROOT/$candidate" ]; then
    TSCONFIG="$candidate"
    break
  fi
done

if [ -z "$TSCONFIG" ]; then
  echo "self-test: SKIP — no tsconfig.app.json or tsconfig.json at $PROJECT_ROOT" >&2
  exit 2
fi

# Skip when node_modules missing — fresh worktree, pre-`npm install` state.
# The canary uses `npx --no-install` which would fail spuriously without this.
# CI handles the real validation after `npm ci`.
if [ ! -x "$PROJECT_ROOT/node_modules/.bin/tsc" ]; then
  echo "self-test: SKIP — node_modules/.bin/tsc not found (run 'npm install' first)" >&2
  exit 2
fi

say "self-test: PROJECT_ROOT=$PROJECT_ROOT TSCONFIG=$TSCONFIG"

# --- Canary 1: file-inclusion (tsconfig must include real files) ---
say "self-test: canary 1 — listing files tsc would check..."
FILE_COUNT=$(
  cd "$PROJECT_ROOT"
  npx --no-install tsc -p "$TSCONFIG" --listFilesOnly --noEmit 2>/dev/null \
    | grep -cE '\.(ts|tsx)$' \
    | tr -dc '0-9'
)
FILE_COUNT=${FILE_COUNT:-0}

if [ "$FILE_COUNT" -lt 20 ]; then
  echo "self-test: FAIL — typecheck guard lists only $FILE_COUNT files (expected ≥20)" >&2
  echo "  The $TSCONFIG config is broken — check 'include' / 'files' / 'references' fields." >&2
  echo "  See .claude/rules/typecheck-and-review-gates.md for the silent-no-op failure mode." >&2
  exit 1
fi
say "self-test: canary 1 PASS — $FILE_COUNT files in config"

# --- Canary 2: semantic-check (tsc must reject a known type error) ---
say "self-test: canary 2 — injecting deliberate type error and verifying tsc rejects..."
CANARY_DIR=$(mktemp -d -t ship-self-test.XXXXXX 2>/dev/null || echo "/tmp/ship-self-test.$$")
[ -d "$CANARY_DIR" ] || mkdir -p "$CANARY_DIR"
trap "rm -rf '$CANARY_DIR' 2>/dev/null || true" EXIT

CANARY_FILE="$CANARY_DIR/canary.ts"
cat > "$CANARY_FILE" <<'TSCANARY'
// Deliberate type error — tsc --noEmit --strict MUST reject this.
// If tsc returns 0 here, the semantic checker is broken.
const canaryError: string = 42;
export { canaryError };
TSCANARY

if (cd "$PROJECT_ROOT" && npx --no-install tsc --noEmit --strict "$CANARY_FILE" >/dev/null 2>&1); then
  echo "self-test: FAIL — tsc accepted a file with a deliberate type error" >&2
  echo "  The semantic type checker is broken. Guard would miss real bugs." >&2
  echo "  Canary was: 'const canaryError: string = 42;'" >&2
  exit 1
fi
say "self-test: canary 2 PASS — tsc rejected deliberate type error"

echo "self-test: PASS — typecheck guard functional ($FILE_COUNT files, semantic-check working)"
exit 0
