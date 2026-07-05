#!/usr/bin/env bash
# dev-prod-deploy-guard.sh — PreToolUse hook
#
# Hardens the dev/prod Phase 5.5 staging-first gate from "honoured" to "enforced" for the
# AUTONOMY path: turns "an autonomous agent SHOULD NOT reach prod directly" into "CANNOT".
#
# Behaviour:
#   - Production-deploy action detected?            no  -> silent allow (fast exit)
#   - AUTOVIBE_PROD_DIRECT truthy (the override)?   yes -> allow (documented escape hatch)
#   - An autovibe run is ACTIVE (autonomous)?       yes + no flag -> DENY
#   - Otherwise (manual human deploy)?              warn via additionalContext, allow
#
# DESIGN — FAIL CLOSED. Every uncertainty resolves toward DENY, never toward allow, because the
# dangerous direction for a safety gate is under-blocking (a silent prod deploy). Specifically:
#   * parser unavailable/failed BUT a prod-deploy signature is present in the raw input -> treat
#     as prod deploy;
#   * state file present but unparseable/corrupt -> treat as an ACTIVE autonomous run;
#   * stat() failure on the state file -> treat as fresh (active), not stale.
#
# Override note: this hook enforces ONLY the flag half of the gate contract. The second half —
# the externally-attributed, write-then-read-back-verified override RECORD — is the orchestrator's
# job (autovibe Phase 5.5 / dev-prod skill). An env flag is agent-settable; the record is the real
# attestation. The hook is the flag layer; the record layer lives upstream. See
# .claude/skills/dev-prod/references/autovibe-gate-wiring.md.
#
# SAFETY hook — on the never-disable exclusion list (.claude/rules/hook-profile-gating.md). No
# HOOK_* kill-switch. The only documented way past is the override flag.
# Self-test:  bash .claude/hooks/dev-prod-deploy-guard.sh --self-test

set -uo pipefail

# ── PROJECT CONFIG — REPLACE 'EXAMPLE' + 'EXAMPLEPRODREF0000000' with your real prod values ──
PROD_MCP_PATTERN='mcp__supabase-EXAMPLE__'   # this MCP points ONLY at prod; staging is off-MCP
PROD_REF='EXAMPLEPRODREF0000000'                  # prod project ref (literal Bash-string match)
STALE_HOURS=24                                   # generous backstop: a run quiet >24h is abandoned
# Set to 1 ONLY in repos where `git push origin main` auto-deploys production (e.g. a Vercel app).
# Default 0: a main push deploys nothing (hub/template/library repos) — so the git-push heuristic
# stays OFF and does not false-fire on routine main pushes. The precise MCP detection is unaffected.
MAIN_IS_PROD="${MAIN_IS_PROD:-0}"
# ────────────────────────────────────────────────────────────────────────────────

# Resolve repo root from THIS script's location (BASH_SOURCE-relative — cwd-independent), so the
# state file is found regardless of the harness's working directory.
SELF="${BASH_SOURCE[0]}"
HOOK_DIR="$(cd "$(dirname "$SELF")" 2>/dev/null && pwd)"
REPO_ROOT="$(cd "$HOOK_DIR/../.." 2>/dev/null && pwd)"
STATE_FILE="${REPO_ROOT:-.}/.claude/autovibe-state.json"

deny() {
  # $1 = reason. PreToolUse deny contract (matches worktree-guard.sh canonical shape).
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}\n' \
    "$(printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || printf '"%s"' "blocked")"
}

# ---------- self-test ----------
if [ "${1:-}" = "--self-test" ]; then
  pass=0; fail=0
  TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
  # run the hook as a CHILD process (per shell-portability rule 7 — never test in-shell).
  # args: $1 json  $2 flag|noflag  $3 statejson|""  $4 mainprod|"" (sets MAIN_IS_PROD=1 in child)
  run() {
    local json="$1" flagmode="$2" statejson="${3:-}" mainprod="${4:-}"
    local repo="$TMP/repo"; rm -rf "$repo"; mkdir -p "$repo/.claude/hooks"
    cp "$SELF" "$repo/.claude/hooks/$(basename "$SELF")"
    [ -n "$statejson" ] && printf '%s' "$statejson" > "$repo/.claude/autovibe-state.json"
    local mp=0; [ "$mainprod" = "mainprod" ] && mp=1
    local hook="$repo/.claude/hooks/$(basename "$SELF")"
    if [ "$flagmode" = "flag" ]; then
      printf '%s' "$json" | MAIN_IS_PROD="$mp" AUTOVIBE_PROD_DIRECT=1 bash "$hook" 2>/dev/null
    else
      printf '%s' "$json" | MAIN_IS_PROD="$mp" env -u AUTOVIBE_PROD_DIRECT bash "$hook" 2>/dev/null
    fi
  }
  is_deny() { grep -q '"permissionDecision":[[:space:]]*"deny"'; }
  assert_deny()    { if run "$1" "$2" "$3" "${5:-}" | is_deny; then echo "  ok  DENY:  $4"; pass=$((pass+1)); else echo " FAIL  expected DENY:  $4"; fail=$((fail+1)); fi; }
  assert_allow()   { if run "$1" "$2" "$3" "${5:-}" | is_deny; then echo " FAIL  expected ALLOW: $4"; fail=$((fail+1)); else echo "  ok  allow: $4"; pass=$((pass+1)); fi; }

  ACTIVE='{"phase":"running","current_step":"execute_pending","completed_at":null,"exit_code":null}'
  TERMINAL='{"phase":"running","current_step":"complete","completed_at":"2026-06-02T10:00:00Z","exit_code":0}'
  CORRUPT='{"phase":"runni'   # truncated / unparseable

  echo "dev-prod-deploy-guard self-test (real autovibe schema: phase + completed_at/exit_code)"
  # 1. non-deploy -> allow
  assert_allow '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}' noflag "$ACTIVE" "plain ls is not a deploy"
  # 2. prod MCP migration, ACTIVE run, no flag -> DENY  (the core case the schema bug broke)
  assert_deny  '{"tool_name":"mcp__supabase-EXAMPLE__apply_migration","tool_input":{"name":"x"}}' noflag "$ACTIVE" "prod MCP migration during ACTIVE autovibe (phase=running, not terminal)"
  # 3. same + override flag -> allow
  assert_allow '{"tool_name":"mcp__supabase-EXAMPLE__apply_migration","tool_input":{"name":"x"}}' flag "$ACTIVE" "override flag set -> allowed"
  # 4. prod MCP deploy, TERMINAL state (manual) -> warn+allow
  assert_allow '{"tool_name":"mcp__supabase-EXAMPLE__deploy_edge_function","tool_input":{}}' noflag "$TERMINAL" "manual prod deploy (run terminal) -> warn not deny"
  # 5. prod MCP deploy, NO state file (manual) -> warn+allow
  assert_allow '{"tool_name":"mcp__supabase-EXAMPLE__deploy_edge_function","tool_input":{}}' noflag "" "manual prod deploy (no state file) -> warn not deny"
  # 6. prod MCP deploy, CORRUPT state file -> FAIL CLOSED -> DENY
  assert_deny  '{"tool_name":"mcp__supabase-EXAMPLE__apply_migration","tool_input":{"name":"x"}}' noflag "$CORRUPT" "corrupt state file fails CLOSED (treated as active)"
  # 7. git push to main, ACTIVE, no flag, MAIN_IS_PROD=1 -> DENY
  assert_deny  '{"tool_name":"Bash","tool_input":{"command":"git push origin main"}}' noflag "$ACTIVE" "git push origin main during ACTIVE autovibe (MAIN_IS_PROD=1)" mainprod
  # 8. execute_sql with MERGE (DML), ACTIVE, no flag -> DENY (was a detection gap)
  assert_deny  '{"tool_name":"mcp__supabase-EXAMPLE__execute_sql","tool_input":{"command":"MERGE INTO t USING s ON t.id=s.id WHEN MATCHED THEN UPDATE SET a=1"}}' noflag "$ACTIVE" "MERGE via execute_sql detected as a write"
  # 9. execute_sql pure SELECT (read), ACTIVE -> allow (not a deploy)
  assert_allow '{"tool_name":"mcp__supabase-EXAMPLE__execute_sql","tool_input":{"command":"select count(*) from t"}}' noflag "$ACTIVE" "pure SELECT is not a deploy"
  # 10. non-prod MCP server -> allow (out of scope)
  assert_allow '{"tool_name":"mcp__supabase-OTHERPROJECT__apply_migration","tool_input":{}}' noflag "$ACTIVE" "non-prod MCP server out of scope"
  # 11. prod ref in a curl (Management API), ACTIVE -> DENY
  assert_deny  '{"tool_name":"Bash","tool_input":{"command":"curl -X POST https://api.supabase.com/v1/projects/EXAMPLEPRODREF0000000/database/query -d @q.json"}}' noflag "$ACTIVE" "raw curl to prod ref Management API detected"
  # 12. commit MESSAGE that merely MENTIONS deploy words (quoted) during ACTIVE -> allow (quote-strip)
  assert_allow '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"feat: apply_migration + deploy_edge_function to main EXAMPLEPRODREF0000000\""}}' noflag "$ACTIVE" "commit message mentioning deploy words is NOT a deploy (quotes stripped)"
  # 13. compound commit-then-push-to-main during ACTIVE, MAIN_IS_PROD=1 -> DENY (real push survives quote-strip)
  assert_deny  '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"safe message\" && git push origin main"}}' noflag "$ACTIVE" "compound commit + real push to main still detected (MAIN_IS_PROD=1)" mainprod
  # 14. MULTI-LINE commit message mentioning deploy words during ACTIVE -> allow (newline-collapse + quote-strip)
  assert_allow '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"line1 apply_migration\nline2 deploy to main\nline3 supabase db push\" && git push -u origin feat/x"}}' noflag "$ACTIVE" "multi-line commit message mentioning deploy words is NOT a deploy"
  # 15. git push to main, ACTIVE, but MAIN_IS_PROD=0 (default — hub/template repo) -> allow (heuristic disarmed)
  assert_allow '{"tool_name":"Bash","tool_input":{"command":"git push origin main"}}' noflag "$ACTIVE" "git push main is NOT a prod deploy when MAIN_IS_PROD=0 (default)"

  echo "----"; echo "PASS=$pass FAIL=$fail"
  [ "$fail" -eq 0 ] && exit 0 || exit 1
fi

# ---------- runtime ----------
INPUT="$(cat)"

# Parse tool_name + command. python3 first; grep/sed fallback if python3 is unavailable so the
# critical path does NOT depend on python3 being present.
parse_py() {
  printf '%s' "$INPUT" | python3 -c "
import sys, json
try: d = json.load(sys.stdin)
except Exception: sys.exit(3)
ti = d.get('tool_input') or {}
print(d.get('tool_name',''))
print(ti.get('command','') if isinstance(ti, dict) else '')
" 2>/dev/null
}
PARSED="$(parse_py)"; PARSE_RC=$?
if [ "$PARSE_RC" -eq 0 ] && [ -n "$PARSED" ]; then
  TOOL_NAME="$(printf '%s' "$PARSED" | sed -n '1p')"
  COMMAND="$(printf '%s' "$PARSED" | sed -n '2,$p')"
  PARSE_OK=1
else
  # Fallback: best-effort grep extraction (no python3). Mark parse as degraded.
  TOOL_NAME="$(printf '%s' "$INPUT" | grep -oE '"tool_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*"tool_name"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')"
  COMMAND="$(printf '%s' "$INPUT" | grep -oE '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*"command"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')"
  PARSE_OK=0
fi

# Blank out quoted substrings BEFORE scanning Bash commands, so a commit message / echo string
# that merely MENTIONS deploy words (e.g. `git commit -m "deploy to main"`) does not false-trigger.
# Real operations live OUTSIDE quotes: `git push origin main`, `supabase db push`, an unquoted
# prod ref in a curl URL, and SQL keywords (which sit outside any string literals) all survive.
COMMAND_SCAN="$(printf '%s' "$COMMAND" | tr '\n' ' ' | sed -e "s/\"[^\"]*\"//g" -e "s/'[^']*'//g")"

# 1. Is this a PRODUCTION-DEPLOY action?
is_prod_deploy=0
case "$TOOL_NAME" in
  ${PROD_MCP_PATTERN}apply_migration|${PROD_MCP_PATTERN}deploy_edge_function) is_prod_deploy=1 ;;
  ${PROD_MCP_PATTERN}execute_sql)
    # writes only (DDL/DML). Added call/merge/copy over the original set.
    printf '%s' "$COMMAND_SCAN" | grep -qiE '(create|alter|drop|insert|update|delete|truncate|grant|revoke|merge|call|copy)([[:space:]]|$|\()' && is_prod_deploy=1 ;;
esac
if [ "$is_prod_deploy" -eq 0 ] && [ -n "$COMMAND_SCAN" ]; then
  printf '%s' "$COMMAND_SCAN" | grep -qE "$PROD_REF" && is_prod_deploy=1
  printf '%s' "$COMMAND_SCAN" | grep -qiE 'supabase[[:space:]]+(db[[:space:]]+(push|execute)|functions[[:space:]]+deploy)' && is_prod_deploy=1
  # git push that can reach main: explicit main target, OR url:main, OR bare push while on main.
  # Only armed when MAIN_IS_PROD=1 (a main push actually auto-deploys production in this repo).
  if [ "$MAIN_IS_PROD" = "1" ] && printf '%s' "$COMMAND_SCAN" | grep -qiE 'git[[:space:]]+push'; then
    if printf '%s' "$COMMAND_SCAN" | grep -qiE '(:main|[[:space:]]main([[:space:]]|$))'; then
      is_prod_deploy=1
    elif printf '%s' "$COMMAND_SCAN" | grep -qiE 'git[[:space:]]+push([[:space:]]+[^[:space:]]+)?[[:space:]]*$'; then
      # bare `git push` / `git push origin` — reaches main only if the current branch IS main
      cur="$(cd "${REPO_ROOT:-.}" 2>/dev/null && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')"
      [ "$cur" = "main" ] && is_prod_deploy=1
    fi
  fi
fi
# Fail-closed parse guard: if we could NOT parse AND the raw input smells like a prod deploy,
# treat it as one rather than silently allowing.
if [ "$is_prod_deploy" -eq 0 ] && [ "$PARSE_OK" -eq 0 ]; then
  if printf '%s' "$INPUT" | grep -qE "${PROD_MCP_PATTERN}(apply_migration|deploy_edge_function|execute_sql)|$PROD_REF"; then
    is_prod_deploy=1
  fi
fi
[ "$is_prod_deploy" -eq 0 ] && exit 0   # not a prod deploy — silent allow

# 2. Documented override present?
flag="$(printf '%s' "${AUTOVIBE_PROD_DIRECT:-}" | tr '[:upper:]' '[:lower:]')"
case "$flag" in 1|true|yes|enabled) exit 0 ;; esac   # explicit override (record-verify is the orchestrator's job)

# 3. Is an autovibe run ACTIVE? (fail CLOSED on uncertainty)
autonomous=0
if [ -f "$STATE_FILE" ]; then
  terminal="$(printf '%s' "$(cat "$STATE_FILE" 2>/dev/null)" | python3 -c "
import sys, json
try: d = json.load(sys.stdin)
except Exception: print('CORRUPT'); sys.exit(0)
print('TERMINAL' if (d.get('completed_at') or d.get('exit_code') is not None) else 'ACTIVE')
" 2>/dev/null)"
  case "$terminal" in
    TERMINAL) autonomous=0 ;;                              # cleanly finished run = manual context
    ACTIVE|CORRUPT|'')                                     # active OR unparseable -> fail closed
      autonomous=1
      # staleness backstop: a run quiet > STALE_HOURS is abandoned -> downgrade to manual.
      mtime="$(stat -f %m "$STATE_FILE" 2>/dev/null || stat -c %Y "$STATE_FILE" 2>/dev/null || echo '')"
      if [ -n "$mtime" ]; then
        now="$(date +%s)"; age_h=$(( (now - mtime) / 3600 ))
        [ "$age_h" -ge "$STALE_HOURS" ] && autonomous=0
      fi ;;                                                # stat failed (mtime empty) -> stay active
  esac
fi

if [ "$autonomous" -eq 1 ]; then
  deny "dev-prod gate (Phase 5.5): BLOCKED. An autonomous /autovibe run is attempting a PRODUCTION deploy without the staging-first override. Default path is staging. To go production-direct: (1) pass the dev-prod pre-promotion checklist, (2) set AUTOVIBE_PROD_DIRECT=1, AND (3) write the externally-attributed override record (orchestrator/Phase 5.5). If this was meant for STAGING, target the staging surface instead. See .claude/skills/dev-prod/."
  exit 0
fi

# 4. Manual deploy (no active autovibe run) — warn, allow.
printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"dev-prod reminder: this is a PRODUCTION deploy and no active autovibe run was detected (manual context), so it is allowed. Confirm it ran in staging and passed the pre-promotion checklist first (.claude/skills/dev-prod/). The existing confirm-before-prod guard still applies."}}'
exit 0
