#!/usr/bin/env bash
# make-safe-baseline-postgres.sh — automates the brittle Postgres/Supabase baseline edits.
#
# Codifies the proven recipe (references/db-adapters/postgres-supabase.md). It automates the parts
# that were error-prone by hand on the first real run (2026-06-24): the 3 hardening edits
# (steps 2-4), the freshness assertion (step 3), the path-reader rescan (step 5), and a freeze-check
# wrapper (step 0). The credentialed pg_dump (step 1) and the ledger reconcile (step 6) stay
# operator actions — this script never touches a live database except the read-only freeze-check.
#
# Portability: no `sed -i` (differs BSD vs GNU) — all transforms go through a temp file then mv.
#
# Usage:
#   make-safe-baseline-postgres.sh harden <dump.sql> [--extensions a,b,c] [--assert-present TOKEN]
#   make-safe-baseline-postgres.sh path-rescan <baseline_basename> [path ...]
#   make-safe-baseline-postgres.sh freeze-check [--project-ref REF] [--wait SECONDS]
#   make-safe-baseline-postgres.sh --self-test
#
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }
info() { echo "[make-safe-baseline] $*" >&2; }

# --- Step 2-4: harden a dump into an idempotent, replay-safe baseline -------------------------
harden() {
  local dump="${1:-}"; shift || true
  [ -n "$dump" ] && [ -f "$dump" ] || die "harden: dump file not found: '$dump'"
  local extensions="" assert_token=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --extensions) extensions="${2:-}"; shift 2 ;;
      --assert-present) assert_token="${2:-}"; shift 2 ;;
      *) die "harden: unknown arg '$1'" ;;
    esac
  done

  # Step 3 freshness assertion FIRST — refuse to harden a stale dump.
  if [ -n "$assert_token" ]; then
    grep -qF "$assert_token" "$dump" \
      || die "freshness assertion FAILED: '$assert_token' absent from dump — a migration landed mid-dump (freeze failed). Re-freeze + re-dump."
    info "freshness OK: '$assert_token' present"
  fi

  cp "$dump" "${dump}.bak"
  local tmp; tmp="$(mktemp)"

  # Step 2: strip psql-only \restrict / \unrestrict wrapper lines.
  grep -vE '^\\(un)?restrict([[:space:]]|$)' "$dump" > "$tmp"

  # Step 4: CREATE SCHEMA x -> CREATE SCHEMA IF NOT EXISTS x  (skip lines already idempotent).
  awk '
    /CREATE SCHEMA / && !/IF NOT EXISTS/ { sub(/CREATE SCHEMA /, "CREATE SCHEMA IF NOT EXISTS ") }
    { print }
  ' "$tmp" > "${tmp}.2" && mv "${tmp}.2" "$tmp"

  # Step 3: inject add-on extensions after the first idempotent public-schema create.
  if [ -n "$extensions" ]; then
    local inject=""
    local IFS=','
    for ext in $extensions; do
      ext="$(echo "$ext" | tr -d '[:space:]')"
      [ -n "$ext" ] || continue
      if grep -qiE "CREATE EXTENSION IF NOT EXISTS[[:space:]]+\"?${ext}\"?" "$tmp"; then
        info "extension '$ext' already present — skipping injection"
        continue
      fi
      inject="${inject}CREATE EXTENSION IF NOT EXISTS ${ext} WITH SCHEMA public;\n"
    done
    if [ -n "$inject" ]; then
      awk -v inj="$inject" '
        !done && /CREATE SCHEMA IF NOT EXISTS public;/ { print; printf "%s", inj; done=1; next }
        { print }
        END { if (!done) { print "MAKE_SAFE_BASELINE_NO_PUBLIC_SCHEMA_ANCHOR" > "/dev/stderr" } }
      ' "$tmp" > "${tmp}.3" 2>"${tmp}.warn" && mv "${tmp}.3" "$tmp"
      if grep -q NO_PUBLIC_SCHEMA_ANCHOR "${tmp}.warn" 2>/dev/null; then
        rm -f "$tmp" "${tmp}.warn"
        die "could not find 'CREATE SCHEMA IF NOT EXISTS public;' anchor to inject extensions after — inspect the dump"
      fi
      rm -f "${tmp}.warn"
    fi
  fi

  mv "$tmp" "$dump"
  info "hardened: $dump  (original at ${dump}.bak)"
}

# --- Step 5: path-reader rescan — refuse to declare "clear to archive" if readers remain -------
path_rescan() {
  local baseline="${1:-}"; shift || true
  [ -n "$baseline" ] || die "path-rescan: pass the baseline file basename (excluded from the scan)"
  local paths=("$@"); [ ${#paths[@]} -gt 0 ] || paths=(src supabase tests scripts)
  local existing=(); for p in "${paths[@]}"; do [ -e "$p" ] && existing+=("$p"); done
  [ ${#existing[@]} -gt 0 ] || { info "path-rescan: none of the scan paths exist here — nothing to scan"; return 0; }

  local hits
  hits="$(grep -rEn 'migrations/[0-9]{14}|migrations-archive|supabase/migrations/' \
      "${existing[@]}" \
      --include='*.ts' --include='*.tsx' --include='*.js' --include='*.sql' 2>/dev/null \
      | grep -vF "$baseline" || true)"
  if [ -n "$hits" ]; then
    echo "$hits" >&2
    die "path-rescan: $(echo "$hits" | wc -l | tr -d ' ') migration-path reader(s) remain — re-point them at the archive BEFORE archiving (lesson #2). NOT clear to archive."
  fi
  info "path-rescan CLEAR: no migration-path readers remain (safe to archive)"
}

# --- Step 0: freeze-check — refuse if the ledger moves across the window -----------------------
freeze_check() {
  local ref="" wait_s=60
  while [ $# -gt 0 ]; do
    case "$1" in
      --project-ref) ref="${2:-}"; shift 2 ;;
      --wait) wait_s="${2:-}"; shift 2 ;;
      *) die "freeze-check: unknown arg '$1'" ;;
    esac
  done
  command -v supabase >/dev/null 2>&1 || die "freeze-check needs the Supabase CLI linked; not found. (Or read supabase_migrations.schema_migrations count twice ~${wait_s}s apart via MCP and compare manually.)"
  info "freeze-check: reading ledger, waiting ${wait_s}s, re-reading…"
  local a b
  a="$(supabase migration list 2>/dev/null | wc -l | tr -d ' ')"
  sleep "$wait_s"
  b="$(supabase migration list 2>/dev/null | wc -l | tr -d ' ')"
  [ "$a" = "$b" ] || die "freeze-check FAILED: ledger moved ($a -> $b) — a parallel session is shipping migrations. Wait for a quiet window (lesson #1)."
  info "freeze-check OK: ledger stable at $a entries across ${wait_s}s — quiet window confirmed"
}

# --- self-test: offline, deterministic, no network/credentials --------------------------------
self_test() {
  local dir; dir="$(mktemp -d)"; trap "rm -rf '$dir'" EXIT
  local d="$dir/dump.sql"
  cat > "$d" <<'EOF'
\restrict aBcD123
CREATE SCHEMA public;
CREATE SCHEMA custom_schema;
CREATE SCHEMA IF NOT EXISTS already_fine;
CREATE TABLE public.widget (id int, newest_col_marker text);
\unrestrict aBcD123
EOF
  local fail=0

  # 1. harden applies all 3 edits + freshness passes for present token
  ( cd "$dir" && bash "$SELF" harden dump.sql --extensions "citext, pg_trgm" --assert-present "newest_col_marker" ) >/dev/null 2>&1 || { echo "FAIL: harden exited non-zero on valid input"; fail=1; }
  grep -qE '^\\(un)?restrict' "$d" && { echo "FAIL: \\restrict wrapper not stripped"; fail=1; } || echo "ok: wrapper stripped"
  grep -q 'CREATE SCHEMA IF NOT EXISTS public;' "$d" && echo "ok: public schema idempotent" || { echo "FAIL: public schema not made idempotent"; fail=1; }
  grep -q 'CREATE SCHEMA IF NOT EXISTS custom_schema;' "$d" && echo "ok: custom schema idempotent" || { echo "FAIL: custom_schema not made idempotent"; fail=1; }
  [ "$(grep -c 'CREATE SCHEMA IF NOT EXISTS already_fine' "$d")" = "1" ] && echo "ok: already-idempotent schema not double-edited" || { echo "FAIL: double-edited an already-idempotent schema"; fail=1; }
  grep -q 'CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;' "$d" && echo "ok: citext injected" || { echo "FAIL: citext not injected"; fail=1; }
  grep -q 'CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;' "$d" && echo "ok: pg_trgm injected" || { echo "FAIL: pg_trgm not injected"; fail=1; }
  # extensions injected immediately after the public anchor (replay order)
  grep -n 'public' "$d" | head -1 >/dev/null
  [ -f "$d.bak" ] && echo "ok: .bak preserved" || { echo "FAIL: no .bak backup"; fail=1; }

  # 2. re-running harden is idempotent (no double-injection)
  ( cd "$dir" && bash "$SELF" harden dump.sql --extensions "citext" ) >/dev/null 2>&1
  [ "$(grep -c 'CREATE EXTENSION IF NOT EXISTS citext' "$d")" = "1" ] && echo "ok: harden idempotent (no double-inject)" || { echo "FAIL: re-harden double-injected citext"; fail=1; }

  # 3. freshness assertion FAILS for an absent token
  if ( cd "$dir" && bash "$SELF" harden dump.sql --assert-present "TOKEN_THAT_IS_ABSENT" ) >/dev/null 2>&1; then
    echo "FAIL: freshness assertion passed for an absent token"; fail=1
  else
    echo "ok: freshness assertion fails for absent token"
  fi

  # 4. path-rescan FLAGS a planted migration-path reader, PASSES when clean
  mkdir -p "$dir/src"
  echo "const p = 'supabase/migrations/20260101000000_old.sql';" > "$dir/src/reader.ts"
  if ( cd "$dir" && bash "$SELF" path-rescan "20250910071820_baseline_prod_schema.sql" src ) >/dev/null 2>&1; then
    echo "FAIL: path-rescan did not flag a planted reader"; fail=1
  else
    echo "ok: path-rescan flags a planted migration-path reader"
  fi
  rm -f "$dir/src/reader.ts"
  echo "const x = 1;" > "$dir/src/clean.ts"
  ( cd "$dir" && bash "$SELF" path-rescan "20250910071820_baseline_prod_schema.sql" src ) >/dev/null 2>&1 && echo "ok: path-rescan passes when clean" || { echo "FAIL: path-rescan failed on clean tree"; fail=1; }

  echo "---"
  [ "$fail" = "0" ] && { echo "SELF-TEST: PASS"; return 0; } || { echo "SELF-TEST: FAIL"; return 1; }
}

SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
cmd="${1:-}"; shift || true
case "$cmd" in
  harden)       harden "$@" ;;
  path-rescan)  path_rescan "$@" ;;
  freeze-check) freeze_check "$@" ;;
  --self-test)  self_test ;;
  *) die "usage: $(basename "$0") {harden <dump.sql> [--extensions a,b,c] [--assert-present TOKEN] | path-rescan <baseline_basename> [path...] | freeze-check [--project-ref REF] [--wait N] | --self-test}" ;;
esac
