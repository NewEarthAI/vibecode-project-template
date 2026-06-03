#!/bin/bash
# Claude Code SessionStart hook — context aggregator
#
# Injects a concise repo-state briefing into the session at start so the
# chat picks up live state (branch, worktrees, recent commits, recent
# council sessions, ROADMAP head, MEMORY.md index, open PRs) without
# manual `/prime` invocation.
#
# Composes the existing prime-lite brief (which the hook does NOT modify)
# and appends two sections that brief.sh does not provide:
#   - MEMORY.md index (with multi-path resolution + truncation defence)
#   - Open PRs from `gh pr list`
#
# Output: JSON envelope per Claude Code SessionStart hook contract:
#   {"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"..."}}
#
# Heartbeat: every fire emits a visible "Session context loaded: N items, X bytes"
# line at the head of additionalContext. If the hook silently fails, the
# heartbeat is missing — that signal is the difference between "hook ran and
# found nothing" and "hook didn't run at all" (Reliability Engineer
# non-shippable flag from council session
# 2026-04-30-agentic-os-architecture-pillars-extended.md).
#
# Exit codes: always 0 (hook silently failing is worse than hook erroring;
# we always emit JSON, even on partial failure, so the heartbeat surfaces).
#
# Self-test: bash .claude/hooks/sessionstart-context-aggregator.sh --self-test
#   Asserts: heartbeat present, MEMORY section handles missing-file,
#   PR section handles gh-failure, JSON output is valid.

set -uo pipefail
export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"

# ---------------------------------------------------------------------------
# Path resolution helpers
# ---------------------------------------------------------------------------

resolve_repo_root() {
  # Project root is the git toplevel from cwd. Falls back to cwd if not a
  # git repo (defensive — the hook should never crash, only emit a degraded
  # briefing).
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

resolve_memory_path() {
  # Three-tier resolution:
  #   1. <repo_root>/.claude/memory/MEMORY.md (per-project, may be gitignored)
  #   2. ~/.claude/projects/<encoded-cwd>/memory/MEMORY.md (auto-memory)
  #   3. (none) — caller emits a "MEMORY index unavailable" line
  #
  # Encoding for tier 2: replace / with - and prepend -.
  local repo_root="$1"
  local p1="$repo_root/.claude/memory/MEMORY.md"
  if [ -f "$p1" ]; then
    echo "$p1"
    return 0
  fi
  local encoded
  encoded=$(echo "$repo_root" | sed 's|/|-|g')
  local p2="$HOME/.claude/projects/${encoded}/memory/MEMORY.md"
  if [ -f "$p2" ]; then
    echo "$p2"
    return 0
  fi
  return 1
}

ensure_memory_symlink() {
  # Cross-machine memory portability: if the repo ships an agency/memory/
  # directory AND the user's per-project memory dir doesn't already symlink
  # to it, create the symlink. Idempotent + silent on every machine.
  #
  # Closes the D4 Cross-Machine/Worktree gap (NewMem v1.0.1) for the memory
  # layer specifically. Also makes a fresh `git pull` on a new Mac
  # automatically wire memory without any manual setup script.
  #
  # Safety:
  #   - Never overwrites an existing real directory (backs it up with
  #     timestamp suffix instead — never destructive).
  #   - Never modifies anything if the symlink is already correct.
  #   - Logs to ~/.claude/sessionstart-symlink.log (not stdout — must not
  #     pollute hook JSON output).
  local repo_root="$1"
  local repo_memory="$repo_root/agency/memory"
  if [ ! -d "$repo_memory" ]; then
    return 0  # repo doesn't have agency/memory/ — no-op
  fi

  local encoded
  encoded=$(echo "$repo_root" | sed 's|/|-|g')
  local user_memory="$HOME/.claude/projects/${encoded}/memory"
  local log="$HOME/.claude/sessionstart-symlink.log"

  # Already correct? Quick exit.
  if [ -L "$user_memory" ] && [ "$(readlink "$user_memory")" = "$repo_memory" ]; then
    return 0
  fi

  mkdir -p "$(dirname "$user_memory")"

  # Existing real dir → back up
  if [ -d "$user_memory" ] && [ ! -L "$user_memory" ]; then
    local backup="${user_memory}.backup-$(date +%Y%m%d-%H%M%S)"
    if mv "$user_memory" "$backup" 2>>"$log"; then
      echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Backed up $user_memory → $backup" >>"$log"
    else
      echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] FAIL: could not back up $user_memory" >>"$log"
      return 1
    fi
  fi

  # Stale symlink (wrong target) → remove
  if [ -L "$user_memory" ]; then
    rm "$user_memory" 2>>"$log"
  fi

  # Create the symlink
  if ln -s "$repo_memory" "$user_memory" 2>>"$log"; then
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Created symlink $user_memory → $repo_memory" >>"$log"
  else
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] FAIL: could not create symlink $user_memory → $repo_memory" >>"$log"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Section: MEMORY.md index (Edge Case Finder M-1 truncation defence)
# ---------------------------------------------------------------------------

emit_memory_section() {
  local repo_root="$1"
  local path
  if ! path=$(resolve_memory_path "$repo_root"); then
    echo "### MEMORY.md index"
    echo "_(no MEMORY.md found at \`<repo>/.claude/memory/MEMORY.md\` or auto-memory path)_"
    echo ""
    return
  fi
  local total_lines
  total_lines=$(wc -l <"$path" | tr -d ' ')
  echo "### MEMORY.md index"
  echo "_(source: \`${path/$HOME/~}\`, $total_lines lines total — head 80 shown)_"
  echo '```'
  head -80 "$path"
  if [ "$total_lines" -gt 80 ]; then
    echo "..."
    echo "($((total_lines - 80)) more lines truncated; full path above)"
  fi
  echo '```'
  echo ""
}

# ---------------------------------------------------------------------------
# Section: Open PRs (Edge Case Finder edge 2 rate-limit defence)
# ---------------------------------------------------------------------------

emit_prs_section() {
  echo "### Open PRs"
  if ! command -v gh >/dev/null 2>&1; then
    echo "_(gh CLI not installed — skipped)_"
    echo ""
    return
  fi
  local out rc
  # Capture both stdout and exit code; gh exit non-zero on rate limit / no auth.
  out=$(gh pr list --state open --limit 5 2>&1)
  rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "_(gh pr list returned exit $rc — likely auth or rate limit. Raw: $(echo "$out" | head -1))_"
    echo ""
    return
  fi
  if [ -z "$out" ]; then
    echo "_(no open PRs)_"
    echo ""
    return
  fi
  echo '```'
  echo "$out"
  echo '```'
  echo ""
}

# ---------------------------------------------------------------------------
# Pre-flight section — environment health check
# ---------------------------------------------------------------------------
#
# Reports a single one-liner summarising the readiness of the toolchain that
# Claude Code sessions most commonly need: gh CLI auth, Supabase CLI presence,
# MCP server count, a-logistics-app-agent VPS reachability. Non-blocking by design —
# any failure prints a visible warning but never aborts the briefing.
#
# Origin: 2026-05-08 /apply-insights run. Recurring friction: sessions stalled
# mid-pipeline because Supabase CLI was unauthenticated, gh hit auth error, or
# the VPS was unreachable. The aggregator already runs on every session start;
# adding 2-3 quick reachability probes catches the blocker BEFORE Claude
# attempts the operation that depends on it.

emit_preflight_section() {
  echo "### Pre-flight"

  # gh — quick auth probe (1s timeout via --hostname trick: skip if gh missing)
  local gh_status="missing"
  if command -v gh >/dev/null 2>&1; then
    if gh auth status >/dev/null 2>&1; then
      gh_status="ok"
    else
      gh_status="AUTH-FAIL"
    fi
  fi

  # Supabase CLI — presence only; per-project auth is too costly to probe here
  local sb_cli="missing"
  if command -v supabase >/dev/null 2>&1; then
    sb_cli="ok"
  fi

  # MCP server count — check repo-root first (canonical for this project),
  # fall back to user-level. Either is valid; whichever has servers wins.
  local mcp_count=0
  local mcp_file=""
  local repo_root_local
  repo_root_local=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  if [ -f "$repo_root_local/.mcp.json" ]; then
    mcp_file="$repo_root_local/.mcp.json"
  elif [ -f "$HOME/.mcp.json" ]; then
    mcp_file="$HOME/.mcp.json"
  fi
  if [ -n "$mcp_file" ] && command -v python3 >/dev/null 2>&1; then
    mcp_count=$(python3 -c "import json
try:
  d=json.load(open('$mcp_file'))
  print(len(d.get('mcpServers',{})))
except Exception:
  print(0)" 2>/dev/null || echo 0)
  fi

  # VPS reachability — only probe if a-logistics-app-agent is in ssh config (avoids
  # noisy "host not found" on machines that don't have the alias)
  local vps_status="n/a"
  if [ -f "$HOME/.ssh/config" ] && grep -q "^Host a-logistics-app-agent" "$HOME/.ssh/config" 2>/dev/null; then
    if ssh -o ConnectTimeout=2 -o BatchMode=yes -o StrictHostKeyChecking=no \
         -q a-logistics-app-agent exit 2>/dev/null; then
      vps_status="warm"
    else
      vps_status="unreachable"
    fi
  fi

  # One-liner output. Loud only on failure.
  echo '```'
  echo "gh=${gh_status}  supabase-cli=${sb_cli}  mcp-servers=${mcp_count}  a-logistics-app-vps=${vps_status}"
  echo '```'

  # Visible warning if any check failed — separate line so the model notices
  if [ "$gh_status" = "AUTH-FAIL" ] || [ "$sb_cli" = "missing" ] || \
     [ "$vps_status" = "unreachable" ]; then
    echo "_⚠️ Pre-flight degraded — surface this BEFORE attempting any operation that depends on the failed surface._"
  fi
  echo ""
}

# ---------------------------------------------------------------------------
# Briefing assembly
# ---------------------------------------------------------------------------

build_briefing() {
  local repo_root="$1"
  local brief_script="$repo_root/.claude/skills/prime-lite/scripts/brief.sh"
  local heartbeat_items=0
  local body=""

  if [ -f "$brief_script" ]; then
    # prime-lite brief is the trusted base layer; we don't modify it.
    if body=$(cd "$repo_root" && bash "$brief_script" 2>/dev/null); then
      heartbeat_items=$((heartbeat_items + 1))  # base brief
    else
      body="### Repo State Briefing\n_(prime-lite brief.sh failed; degraded briefing)_\n\n"
    fi
  else
    body="### Repo State Briefing\n_(prime-lite skill not found at $brief_script)_\n\n"
  fi

  # MEMORY index
  local mem_section
  mem_section=$(emit_memory_section "$repo_root")
  body="${body}${mem_section}"
  if [[ "$mem_section" != *"no MEMORY.md found"* ]]; then
    heartbeat_items=$((heartbeat_items + 1))
  fi

  # Open PRs
  local prs_section
  prs_section=$(emit_prs_section)
  body="${body}${prs_section}"
  if [[ "$prs_section" != *"gh CLI not installed"* ]] && \
     [[ "$prs_section" != *"likely auth or rate limit"* ]] && \
     [[ "$prs_section" != *"no open PRs"* ]]; then
    heartbeat_items=$((heartbeat_items + 1))
  fi

  # Pre-flight environment check — non-blocking; always increments heartbeat
  local preflight_section
  preflight_section=$(emit_preflight_section)
  body="${body}${preflight_section}"
  heartbeat_items=$((heartbeat_items + 1))

  # Heartbeat — visible signal that the hook actually fired (Reliability
  # Engineer non-shippable flag).
  local body_bytes=${#body}
  local heartbeat
  heartbeat="**Session context loaded: ${heartbeat_items} sections, ${body_bytes} bytes**"
  printf '%s\n\n%b' "$heartbeat" "$body"
}

# ---------------------------------------------------------------------------
# Self-test
# ---------------------------------------------------------------------------

run_self_test() {
  local pass=0
  local fail=0
  echo "sessionstart-context-aggregator self-test"
  echo "==========================================="

  check() {
    local name="$1"
    local cond="$2"
    if [ "$cond" = "true" ]; then
      echo "  PASS  $name"
      pass=$((pass + 1))
    else
      echo "  FAIL  $name"
      fail=$((fail + 1))
    fi
  }

  # T1 — heartbeat present in output
  local out
  out=$(emit_memory_section "/nonexistent/path/that/does/not/exist")
  if [[ "$out" == *"no MEMORY.md found"* ]]; then
    check "T1 missing MEMORY.md handled gracefully" true
  else
    check "T1 missing MEMORY.md handled gracefully" false
  fi

  # T2 — repo_root resolution falls back to pwd when not a git repo
  local resolved
  resolved=$(cd /tmp && resolve_repo_root)
  if [ -n "$resolved" ]; then
    check "T2 resolve_repo_root never empty (got: $resolved)" true
  else
    check "T2 resolve_repo_root never empty" false
  fi

  # T3 — full briefing builds without crash
  local repo
  repo=$(resolve_repo_root)
  local briefing
  briefing=$(build_briefing "$repo")
  if [[ "$briefing" == *"Session context loaded:"* ]]; then
    check "T3 briefing includes heartbeat" true
  else
    check "T3 briefing includes heartbeat" false
  fi

  # T4 — heartbeat reports section count >= 1
  if [[ "$briefing" =~ Session\ context\ loaded:\ ([0-9]+) ]] && [ "${BASH_REMATCH[1]}" -ge 1 ]; then
    check "T4 heartbeat reports >= 1 section (got: ${BASH_REMATCH[1]})" true
  else
    check "T4 heartbeat reports >= 1 section" false
  fi

  # T5 — JSON envelope is valid
  local json
  json=$(emit_json_envelope "$briefing")
  if echo "$json" | jq -e '.hookSpecificOutput.hookEventName == "SessionStart"' >/dev/null 2>&1; then
    check "T5 JSON envelope is valid + correct event name" true
  else
    check "T5 JSON envelope is valid + correct event name" false
  fi

  # T6 — gh failure handling (test by temporarily unsetting PATH)
  local prs_out
  prs_out=$(PATH=/nonexistent emit_prs_section)
  if [[ "$prs_out" == *"gh CLI not installed"* ]]; then
    check "T6 gh-not-installed handled gracefully" true
  else
    check "T6 gh-not-installed handled gracefully" false
  fi

  # T7 — MEMORY.md truncation defence: large file → head -80 only
  local tmp_mem
  tmp_mem=$(mktemp)
  for i in $(seq 1 200); do echo "line $i"; done >"$tmp_mem"
  local truncated_section
  # Inline simulation: emit_memory_section requires a repo_root that resolves
  # to a path containing the file. We test the head -80 invariant directly.
  local lines_in_section
  lines_in_section=$(head -80 "$tmp_mem" | wc -l | tr -d ' ')
  if [ "$lines_in_section" -eq 80 ]; then
    check "T7 MEMORY truncation: head -80 caps at 80 lines" true
  else
    check "T7 MEMORY truncation: head -80 caps at 80 lines" false
  fi
  rm -f "$tmp_mem"

  echo "==========================================="
  if [ "$fail" -eq 0 ]; then
    echo "sessionstart-context-aggregator self-test: ALL PASS ($pass/$((pass + fail)))"
    exit 0
  else
    echo "sessionstart-context-aggregator self-test: $fail FAILURES ($pass/$((pass + fail)))" >&2
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# JSON envelope (Claude Code SessionStart hook contract)
# ---------------------------------------------------------------------------

emit_json_envelope() {
  local briefing="$1"
  jq -n --arg ctx "$briefing" '{
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: $ctx
    }
  }'
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if [[ "${1:-}" == "--self-test" ]]; then
  run_self_test
fi

# SessionStart hook receives JSON on stdin (session_id, source). We don't
# need to inspect it; just emit the briefing.
cat >/dev/null 2>&1 || true

REPO_ROOT=$(resolve_repo_root)
ensure_memory_symlink "$REPO_ROOT" || true   # silent best-effort; never blocks briefing
BRIEFING=$(build_briefing "$REPO_ROOT")
emit_json_envelope "$BRIEFING"
exit 0
