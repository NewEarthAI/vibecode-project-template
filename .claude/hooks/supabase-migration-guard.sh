#!/usr/bin/env bash
# supabase-migration-guard.sh — PreToolUse hook
# Matcher: mcp__*supabase*__(execute_sql|apply_migration) (registered in settings.local.json)
#
# Gates for Supabase MCP mutations:
#   1. Branch+pull guard — only from main or hotfix/*
#   2. Migration-lock — atomic mkdir (session-scoped via $PPID)
#   3. SQL pattern rules R1/R2/R3 — known incident classes
#
# EFFICIENCY CONTRACT (per .claude/rules/hook-efficiency.md triple-gate):
#   - Gate 1: settings matcher narrows to Supabase tools
#   - Gate 2: RAW-STRING substring bail BEFORE jq (<2ms on 95% of calls)
#   - Gate 3: jq + regex only if Gate 2 indicates possible mutation
#
# Code-council hardened (4-agent review) — known gotchas baked in:
#   - jq called BEFORE substring bail violates hook-efficiency §2 triple-gate
#   - R3 regex MUST be applied on newline-collapsed SQL (tr '\n' ' ')
#     otherwise UPDATE ... IS NULL across multiple lines silently fails
#   - \S+ non-portable on BSD grep; use [^[:space:]]+ in POSIX classes
#   - numeric normalization required per shell-portability.md §6
#   - SESSION_ID formula MUST match supabase-migration-release.sh exactly
#   - Bash 3.2 case-pattern bug: avoid embedded double quotes in patterns

set -euo pipefail

input=$(cat)

# =========================================================================
# GATE 2 — RAW-STRING FAST PATH (no jq, <2ms on 95% of calls)
# =========================================================================
# Bail immediately if input contains no mutation signal. Each `case` on a
# bash string is a ~microsecond substring check; jq spawns cost 20-50ms.
# Note: matching on `__execute_sql` (underscores anchor the tool-name suffix)
# is sufficient — tool names always have format `mcp__server__action`. Using
# unquoted substring avoids bash 3.2 case-pattern bug with embedded quotes.
case "$input" in
  *__apply_migration*) ;;  # always mutation — fall through to slow path
  *__execute_sql*)
    # For execute_sql, must contain at least one mutation keyword to proceed.
    # POSIX character classes ONLY — BSD grep \b is unreliable (shell-portability §1).
    case "$input" in
      *CREATE*|*create*|*Create*) ;;
      *ALTER*|*alter*|*Alter*) ;;
      *DROP*|*drop*|*Drop*) ;;
      *UPDATE*|*update*|*Update*) ;;
      *DELETE*|*delete*|*Delete*) ;;
      *INSERT*|*insert*|*Insert*) ;;
      *GRANT*|*grant*|*Grant*) ;;
      *REVOKE*|*revoke*|*Revoke*) ;;
      *TRUNCATE*|*truncate*|*Truncate*) ;;
      *) echo '{}'; exit 0 ;;  # definitely read-only — 95% of calls exit here
    esac
    ;;
  *)
    # Not apply_migration or execute_sql → not our concern
    echo '{}'; exit 0 ;;
esac

# =========================================================================
# GATE 3 — SLOW PATH: jq parse + full checks
# =========================================================================
tool_name=$(echo "$input" | jq -r '.tool_name // ""')
query=$(echo "$input" | jq -r '.tool_input.query // .tool_input.name // ""')

# Final mutation check — Gate 2 is conservative; double-check via regex
# with POSIX boundary (no \b — shell-portability §1).
is_mutation=0
case "$tool_name" in
  *apply_migration) is_mutation=1 ;;
  *execute_sql)
    if echo "$query" | grep -qiE '(^|[[:space:]])(CREATE|ALTER|DROP|UPDATE|DELETE|INSERT|GRANT|REVOKE|TRUNCATE)([[:space:]]|;|\()'; then
      is_mutation=1
    fi
    ;;
esac

if [ "$is_mutation" -eq 0 ]; then
  echo '{}'; exit 0
fi

# Lowercase once for substring + collapse newlines for multi-line regex (R3 fix)
sql_lower=$(echo "$query" | tr '[:upper:]' '[:lower:]')
sql_oneline=$(echo "$sql_lower" | tr '\n' ' ')

# Tier classification by cheap substring match
tier="STANDARD"
case "$sql_lower" in
  *security_invoker*)                                     tier="HIGH_VIEW" ;;
  *"create policy"*|*"alter policy"*|*"drop policy"*)     tier="HIGH_POLICY" ;;
  *"security definer"*)                                   tier="HIGH_SECDEF" ;;
  *"create table"*)                                       tier="MEDIUM_TABLE" ;;
esac

reasons=()

# -------------------------------------------------------------------------
# R1 (security_invoker): require -- policies-checked: comment
# NOTE: [^[:space:]]+ for BSD grep portability (NOT \S+ per shell-portability §1)
# -------------------------------------------------------------------------
if [ "$tier" = "HIGH_VIEW" ]; then
  if ! echo "$query" | grep -qE '^[[:space:]]*--[[:space:]]*policies-checked[[:space:]]*:[[:space:]]*[^[:space:]]+'; then
    reasons+=("R1 (security_invoker): migration sets security_invoker=true but lacks required '-- policies-checked: <comma-separated-tables>' comment. Query pg_policies for each joined base table first, confirm 'authenticated' role has qualifying SELECT policy, then add the comment enumerating the checked tables. Reference: .claude/rules/supabase-safety.md Rule 1b.")
  fi
fi

# -------------------------------------------------------------------------
# R2 (CREATE TABLE RLS): table must enable RLS in same migration
# -------------------------------------------------------------------------
if [ "$tier" = "MEDIUM_TABLE" ]; then
  # Skip TEMPORARY tables — they cannot have RLS (Postgres constraint)
  if echo "$sql_lower" | grep -qE 'create[[:space:]]+(temporary|temp)[[:space:]]+table'; then
    : # temp table — RLS not applicable
  elif ! echo "$sql_oneline" | grep -qE 'enable[[:space:]]+row[[:space:]]+level[[:space:]]+security' && \
       ! echo "$query"       | grep -qE '^[[:space:]]*--[[:space:]]*rls-exempt[[:space:]]*:[[:space:]]*[^[:space:]]+'; then
    reasons+=("R2 (RLS): CREATE TABLE detected but no 'ALTER TABLE ... ENABLE ROW LEVEL SECURITY' found in the same migration, and no '-- rls-exempt: <reason>' escape comment. Multi-tenant tables require RLS. If the table is genuinely public (static config/lookups), add '-- rls-exempt: <reason>' as first-line comment explaining why.")
  fi
fi

# -------------------------------------------------------------------------
# R3 (backfill + forward trigger): UPDATE ... WHERE ... IS NULL needs trigger
# FIX: use $sql_oneline (collapsed newlines) so real multi-line migrations
# match. Tightened: require WHERE before IS NULL (reduces CASE-WHEN false positive).
# -------------------------------------------------------------------------
if echo "$sql_oneline" | grep -qE 'update[[:space:]]+[a-z_0-9.]+.*[[:space:]]set[[:space:]].*[[:space:]]where[[:space:]].*[[:space:]]is[[:space:]]+null'; then
  if ! echo "$sql_oneline" | grep -qE 'create[[:space:]]+(or[[:space:]]+replace[[:space:]]+)?trigger' && \
     ! echo "$query"       | grep -qE '^[[:space:]]*--[[:space:]]*backfill-only-see[[:space:]]*:[[:space:]]*[^[:space:]]+'; then
    reasons+=("R3 (backfill + forward trigger): 'UPDATE ... SET ... WHERE ... IS NULL' detected but no CREATE TRIGGER in same migration, and no '-- backfill-only-see: <trigger-name>' escape comment pointing to an existing forward trigger. Backfills leak without pairing. Reference: .claude/rules/supabase-safety.md Rule 1c.")
  fi
fi

# -------------------------------------------------------------------------
# B1: Branch must be main (or explicit hotfix/*)
# -------------------------------------------------------------------------
cd "${CLAUDE_PROJECT_DIR:-$(pwd)}" 2>/dev/null || true
branch=$(git branch --show-current 2>/dev/null || echo "unknown")
case "$branch" in
  main|hotfix/*) ;;  # allowed
  *) reasons+=("B1 (branch): current branch is '$branch' — production DB mutations only from 'main' or 'hotfix/*'. Run: git checkout main && git pull origin main") ;;
esac

# -------------------------------------------------------------------------
# B2: Must be up-to-date with origin/main
# -------------------------------------------------------------------------
if [ "$branch" = "main" ]; then
  (git fetch origin main 2>/dev/null || true) &
  fetch_pid=$!
  elapsed=0
  while kill -0 "$fetch_pid" 2>/dev/null; do
    sleep 1
    elapsed=$((elapsed+1))
    if [ "$elapsed" -ge 3 ]; then
      kill "$fetch_pid" 2>/dev/null || true
      break
    fi
  done
  wait "$fetch_pid" 2>/dev/null || true

  # Numeric normalization — shell-portability §6 (defend against empty/non-integer)
  behind_raw=$(git rev-list --count HEAD..origin/main 2>/dev/null || echo 0)
  behind=$(printf '%s' "$behind_raw" | tr -dc '0-9' | head -c 10)
  behind=${behind:-0}

  if [ "$behind" -gt 0 ] 2>/dev/null; then
    recent=$(git log --oneline HEAD..origin/main 2>/dev/null | head -5)
    reasons+=("B2 (up-to-date): local main is $behind commits behind origin/main — parallel session may have shipped conflicting work. Pull first: git pull origin main. Recent commits on origin/main not local:
$recent")
  fi
fi

# =========================================================================
# BLOCK IF ANY REASON FAILED (before acquiring lock)
# =========================================================================
if [ ${#reasons[@]} -gt 0 ]; then
  {
    echo "🚨 Supabase migration guard BLOCKED this mutation (tier: $tier):"
    echo ""
    for r in "${reasons[@]}"; do
      echo "  • $r"
      echo ""
    done
    echo "Override only if genuinely bypassable (e.g., false-positive in regex):"
    echo "  disable this hook in .claude/settings.local.json, or refine the pattern"
  } >&2
  exit 2
fi

# =========================================================================
# B3: Migration-lock primitive (ONLY acquired if all checks passed)
# SESSION_ID formula MUST match supabase-migration-release.sh EXACTLY
# =========================================================================
LOCK_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}/.claude/.supabase-migration-lock"
METADATA_FILE="$LOCK_DIR/metadata.json"
SESSION_ID="${CLAUDE_SESSION_ID:-claude-ppid-$PPID}"
NOW_EPOCH=$(date +%s)
TTL_SECONDS=600

if mkdir "$LOCK_DIR" 2>/dev/null; then
  cat > "$METADATA_FILE" <<EOF
{
  "session_id": "$SESSION_ID",
  "tool_name": "$tool_name",
  "acquired_at": "$NOW_EPOCH",
  "acquired_iso": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "intent_preview": $(echo "$query" | head -c 200 | jq -Rs .),
  "tier": "$tier"
}
EOF
else
  if [ -f "$METADATA_FILE" ]; then
    holder_session=$(jq -r '.session_id // "unknown"' "$METADATA_FILE" 2>/dev/null || echo "unknown")
    # Numeric normalization — shell-portability §6
    holder_acquired_raw=$(jq -r '.acquired_at // 0' "$METADATA_FILE" 2>/dev/null || echo 0)
    holder_acquired=$(printf '%s' "$holder_acquired_raw" | tr -dc '0-9' | head -c 12)
    holder_acquired=${holder_acquired:-0}
    holder_intent=$(jq -r '.intent_preview // "unknown"' "$METADATA_FILE" 2>/dev/null || echo "unknown")
    age=$((NOW_EPOCH - holder_acquired))

    if [ "$holder_session" = "$SESSION_ID" ]; then
      :  # same session re-entering
    elif [ "$age" -gt "$TTL_SECONDS" ]; then
      # Stale — force-release + re-acquire
      rm -f "$METADATA_FILE" 2>/dev/null || true
      rmdir "$LOCK_DIR" 2>/dev/null || true
      if mkdir "$LOCK_DIR" 2>/dev/null; then
        cat > "$METADATA_FILE" <<EOF
{
  "session_id": "$SESSION_ID",
  "tool_name": "$tool_name",
  "acquired_at": "$NOW_EPOCH",
  "acquired_iso": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "intent_preview": $(echo "$query" | head -c 200 | jq -Rs .),
  "tier": "$tier",
  "note": "force-released stale lock held for ${age}s by $holder_session"
}
EOF
      else
        # Another session won the race — treat as legitimate collision
        echo "🚨 Supabase migration-lock race during stale-release recovery — retry in a few seconds." >&2
        exit 2
      fi
    else
      {
        echo "🚨 Supabase migration-lock held by another session '$holder_session' (age ${age}s, TTL ${TTL_SECONDS}s)."
        echo "Their intent: $holder_intent"
        echo "Wait for them to finish — parallel-session collision is a documented failure mode."
      } >&2
      exit 2
    fi
  fi
fi

# All green — emit empty JSON, proceed with tool call
echo '{}'
exit 0
