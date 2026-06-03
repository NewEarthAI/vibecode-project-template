#!/bin/bash
# Claude Code PreToolUse hook — SQL content guardian
# Blocks destructive SQL patterns that hookify tool_matcher cannot catch
# (hookify can only match tool NAMES, not query content)
#
# Exit codes:
#   0 = permit (proceed normally)
#   2 = block (hard stop — Claude Code will not execute the tool)
#
# Usage: registered in .claude/settings.local.json under hooks.PreToolUse

set -euo pipefail

# Read tool input from stdin (Claude Code passes full tool call as JSON)
TOOL_INPUT=$(cat)

# Extract tool name and query
TOOL_NAME=$(echo "$TOOL_INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)
QUERY=$(echo "$TOOL_INPUT" | jq -r '.tool_input.query // empty' 2>/dev/null | tr '[:lower:]' '[:upper:]' || true)

# Only inspect Supabase SQL execute calls (matches any project's Supabase MCP server)
if ! [[ "$TOOL_NAME" == *"execute_sql"* ]]; then
  exit 0
fi

# Skip empty queries
if [[ -z "$QUERY" ]]; then
  exit 0
fi

# BLOCK: SELECT * (fetch all columns wastes tokens on wide/JSONB tables)
# Permit: SELECT *, count(*) — aggregate context is fine
# Permit: SELECT * inside EXISTS(SELECT * ...) — boolean check
# Permit: SELECT * inside CTE/subquery after WITH
if echo "$QUERY" | grep -qE "SELECT[[:space:]]+\*[[:space:]]+(FROM|,)" && \
   ! echo "$QUERY" | grep -qE "COUNT[[:space:]]*\(\*\)" && \
   ! echo "$QUERY" | grep -qE "EXISTS[[:space:]]*\([[:space:]]*SELECT"; then
  echo '{"decision":"block","reason":"SELECT * blocked. Specify only the columns you need — wide tables with JSONB columns waste 5K+ tokens per row. Use: SELECT col1, col2 FROM table."}'
  exit 2
fi

# BLOCK: DELETE without WHERE clause
# Permit DELETE with WHERE (targeted deletion is OK)
if echo "$QUERY" | grep -q "DELETE FROM" && ! echo "$QUERY" | grep -q " WHERE "; then
  echo '{"decision":"block","reason":"DELETE without WHERE clause blocked. This would wipe the entire table. Add a WHERE clause. To override, use the database dashboard directly."}'
  exit 2
fi

# BLOCK: DELETE with tautological WHERE (council Critical #2 — 2026-04-11)
# WHERE 1=1, WHERE TRUE, WHERE 't' — functionally a full-table wipe
if echo "$QUERY" | grep -q "DELETE FROM" && echo "$QUERY" | grep -qE "WHERE[[:space:]]+(1[[:space:]]*=[[:space:]]*1|TRUE|'T'|'1'|\(1[[:space:]]*=[[:space:]]*1\))"; then
  echo '{"decision":"block","reason":"DELETE with tautological WHERE blocked. WHERE 1=1 (or TRUE, or '\''t'\'') matches every row — functionally a full-table wipe. Use a real row filter or run from the database dashboard."}'
  exit 2
fi

# BLOCK: DELETE with self-referencing subquery — WHERE id IN (SELECT id FROM <same_table>)
if echo "$QUERY" | grep -qE "DELETE FROM[[:space:]]+[A-Z_][A-Z0-9_.]*"; then
  TABLE=$(echo "$QUERY" | grep -oE "DELETE FROM[[:space:]]+[A-Z_][A-Z0-9_.]*" | head -1 | awk '{print $3}')
  if [[ -n "$TABLE" ]] && echo "$QUERY" | grep -qE "IN[[:space:]]*\([[:space:]]*SELECT[[:space:]]+[A-Z_][A-Z0-9_]*[[:space:]]+FROM[[:space:]]+${TABLE}[[:space:]]*\)"; then
    echo '{"decision":"block","reason":"DELETE with self-referencing subquery blocked. WHERE id IN (SELECT id FROM <same_table>) matches every row."}'
    exit 2
  fi
fi

# WARN: PL/pgSQL dynamic SQL — DO $$ blocks and EXECUTE FORMAT patterns
# These can construct destructive SQL at runtime. Warn but allow (user pre-approved autonomous DDL).
if echo "$QUERY" | grep -qE "DO[[:space:]]+\\\$\\\$|EXECUTE[[:space:]]+FORMAT|EXECUTE[[:space:]]+'"; then
  # Check for destructive keywords inside the dynamic SQL
  if echo "$QUERY" | grep -qE "DROP[[:space:]]+TABLE|TRUNCATE|DELETE[[:space:]]+FROM"; then
    echo '{"decision":"block","reason":"PL/pgSQL dynamic SQL with destructive operation (DROP TABLE/TRUNCATE/DELETE) blocked. Run from Supabase dashboard."}'
    exit 2
  fi
  # Non-destructive dynamic SQL (view rebuilds, CREATE OR REPLACE, etc.) — permit with context
  echo '{"decision":"allow","hookSpecificOutput":{"additionalContext":"Dynamic SQL detected (DO $$ block). Verify the operation is non-destructive before proceeding."}}'
  exit 0
fi

# BLOCK: TRUNCATE (always irreversible, no row-level recovery)
if echo "$QUERY" | grep -qE "TRUNCATE[[:space:]]"; then
  echo '{"decision":"block","reason":"TRUNCATE blocked. It is irreversible with no row-level recovery. Use DELETE with WHERE instead."}'
  exit 2
fi

# BLOCK: DROP TABLE (destroys schema + all data)
if echo "$QUERY" | grep -qE "DROP[[:space:]]+TABLE"; then
  echo '{"decision":"block","reason":"DROP TABLE blocked. Schema destruction is not permitted from agent context. Use the database dashboard or a reviewed migration."}'
  exit 2
fi

# BLOCK: DROP FUNCTION (may break RPC-dependent integrations)
if echo "$QUERY" | grep -qE "DROP[[:space:]]+FUNCTION"; then
  echo '{"decision":"block","reason":"DROP FUNCTION blocked. Dropping RPCs can silently break integrations and workflows. Requires explicit user approval."}'
  exit 2
fi

# WARN: DROP VIEW — allow with context (views are recreatable, not destructive like DROP TABLE)
if echo "$QUERY" | grep -qE "DROP[[:space:]]+VIEW"; then
  echo '{"decision":"allow","hookSpecificOutput":{"additionalContext":"DROP VIEW detected. Views are recreatable but verify no other views depend on this one before proceeding."}}'
  exit 0
fi

# PERMIT: everything else
exit 0
