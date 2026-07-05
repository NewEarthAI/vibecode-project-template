#!/bin/bash
# bin/vault-sync.sh
#
# Vault → Supabase knowledge_items sync (Layer 0 → KI substrate).
# Runs every 10 minutes via launchd (see bin/launchd/com.yourproject.vault-sync.plist).
#
# Closes council 2026-05-10 NS-2 (script existence + heartbeat + plist) plus
# advisories E1 (rebase-state guard) and R3 (loud-failure / heartbeat).
#
# Pipeline shape (full implementation lands in a follow-on session — see
# §"Upsert stub" below for the TODO contract):
#   1. Pre-flight: rebase guard, lock acquire, vault-path resolve.
#   2. Walk vault under shared/, daily/{user}/, personal/{user}/, 99 - Meta/,
#      00-07 numbered-prefix folders. Extract YAML front-matter + body + wikilinks.
#   3. Upsert into knowledge_items with source_type='vault_note',
#      source_kind ∈ {external, internal, personal}.
#   4. Touch heartbeat. Release lock. Exit 0.
#
# Failure visibility: every non-zero exit writes a one-line reason to stderr
# (captured by launchd StandardErrorPath) AND skips the heartbeat. Stale
# heartbeat (>30 min) is the signal monitoring keys off.

# Rebase guard MUST be line 1 of the executable body (closes E1) — running
# during a parent-repo rebase produces corrupt KI rows because the working
# tree contains conflict markers AND HEAD has been temporarily moved.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
if [ -d "$REPO_ROOT/.git/rebase-merge" ] || [ -d "$REPO_ROOT/.git/rebase-apply" ]; then
    echo "vault-sync: parent repo is rebasing — skipping run to protect KI integrity" >&2
    exit 0
fi

set -uo pipefail

# ── Portability shims (Amendment 10 / Edge #4) ─────────────────────────────
# macOS BSD `stat`/`shasum` vs GNU `stat`/`sha256sum` — BuyBox/Nirvana spokes
# may run on either. These shims keep the canonical script host-agnostic.
file_mtime() { stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0; }
hash256() { if command -v shasum >/dev/null 2>&1; then shasum -a 256; else sha256sum; fi; }

# ── Outcome counters (Amendment 5 / F1) — init early so early exits log 0s ──
INSERTS=0
CONFLICTS=0
FAILURES=0
SKIPPED_EMPTY=0
PYYAML_MISSING=0

# ── Paths ──────────────────────────────────────────────────────────────────
CONFIG_FILE="$REPO_ROOT/.claude/obsidian-second-brain.local.md"
# Lock + heartbeat namespaced per repo (Amendment 7 / Edge #1) — without this
# the hub and every spoke share one machine-global lock and the first runner
# silently starves the rest. REPO_TAG = first 8 hex of sha256(repo root).
REPO_TAG=$(printf '%s' "$REPO_ROOT" | hash256 | cut -c1-8)
LOCK_DIR="/tmp/vault-sync.lock.d.${REPO_TAG}"
HEARTBEAT_FILE="/tmp/vault-sync.heartbeat.${REPO_TAG}"
LOG_FILE="${HOME}/Library/Logs/vault-sync.log"
mkdir -p "$(dirname "$LOG_FILE")"

# ── Helpers ────────────────────────────────────────────────────────────────
log() { printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >> "$LOG_FILE"; }
fail() { log "FAIL: $*"; echo "vault-sync: $*" >&2; exit 1; }
heartbeat() { date -u +%Y-%m-%dT%H:%M:%SZ > "$HEARTBEAT_FILE"; }

# Lock release on any exit path — never leave stale locks
cleanup() { rmdir "$LOCK_DIR" 2>/dev/null || true; }
trap cleanup EXIT INT TERM

# ── Single-instance lock (mkdir-based, POSIX-atomic) ───────────────────────
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    # Stale-lock check — release if older than 25 min (less than the 10-min
    # cron cadence × 2.5, so we don't wedge ourselves on a single crash)
    if [ -d "$LOCK_DIR" ]; then
        LOCK_AGE=$(( $(date +%s) - $(file_mtime "$LOCK_DIR") ))
        if [ "$LOCK_AGE" -gt 1500 ]; then
            log "lock: stale lock ${LOCK_AGE}s old — forcing release"
            rmdir "$LOCK_DIR" 2>/dev/null || true
            mkdir "$LOCK_DIR" 2>/dev/null || fail "could not acquire lock after stale-release"
        else
            log "lock: held by another instance (${LOCK_AGE}s old) — skipping"
            exit 0
        fi
    fi
fi

# ── Credentials + F1 outcome hook (Amendment 5) ────────────────────────────
# Relocated above vault-path resolution so the F1 outcome row also covers the
# agency-path / 401 / writes-not-landing silent-failure classes.
#
# Endpoint + slug are derived FIRST (no credential needed), then write_outcome
# and the consolidated exit trap are installed BEFORE the Keychain read — so
# even a missing-JWT failure runs through on_exit and is made audible (it
# cannot POST a row without the key, but the silence itself is surfaced on
# stderr; stale-heartbeat + the F4 watchdog remain the backstops).
SUPABASE_URL="${SUPABASE_URL:?SUPABASE_URL env var required — set to https://YOUR-PROJECT-REF.supabase.co. If you run this via launchd, the plist MUST set this variable; activate-vault-autopilot.sh will fail-loud if missing.}"
OUTCOME_ENDPOINT="$SUPABASE_URL/rest/v1/vault_sync_log"
# repo_slug: lowercase, then collapse every non [a-z0-9] run to a single '-'
# and trim. Primary purpose: keep the value JSON-safe (a repo dir name can
# legally contain " or \ — sanitising kills the injection path into the
# printf-built POST body). For cross-machine slug STABILITY, pin
# VAULT_SYNC_REPO_SLUG in the launchd plist / spoke caller (the env override
# wins); the basename fallback is only for an un-pinned hub run, where the
# clone dir is "Agency-Main" → "agency-main".
REPO_SLUG="${VAULT_SYNC_REPO_SLUG:-$(basename "$REPO_ROOT" \
    | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//; s/-$//')}"

# Best-effort outcome row. MUST NOT block or change exit status. machine is
# sanitised to JSON-safe chars; counters are integers; err/note are fixed
# tokens — so the printf-built JSON cannot be injected.
write_outcome() {
    local rc note="" err="" mach oc
    rc=$(printf '%s' "${1:-0}" | tr -dc '0-9'); rc=${rc:-1}
    [ "$rc" -ne 0 ] && err="exit_${rc}"
    [ "${PYYAML_MISSING:-0}" = "1" ] && note="pyyaml_missing:frontmatter_discarded"
    mach=$(hostname 2>/dev/null | tr -cs 'A-Za-z0-9.-' '-' | sed 's/-*$//'); mach=${mach:-unknown}
    if [ -z "${SERVICE_KEY:-}" ]; then
        echo "vault-sync: outcome row SKIPPED — no SERVICE_KEY (exit=$rc); rely on stderr + stale-heartbeat + F4 watchdog" >&2
        return 0
    fi
    oc=$(curl -sS --max-time 10 -o /dev/null -w '%{http_code}' \
        -X POST "$OUTCOME_ENDPOINT" \
        -H "apikey: $SERVICE_KEY" \
        -H "Authorization: Bearer $SERVICE_KEY" \
        -H "Content-Type: application/json" \
        -H "Prefer: return=minimal" \
        --data-binary "{\"machine\":\"$mach\",\"repo_slug\":\"$REPO_SLUG\",\"rows_upserted\":${INSERTS:-0},\"rows_conflict\":${CONFLICTS:-0},\"rows_failed\":${FAILURES:-0},\"exit_code\":${rc},\"error_code\":$([ -n "$err" ] && printf '"%s"' "$err" || printf 'null'),\"note\":$([ -n "$note" ] && printf '"%s"' "$note" || printf 'null')}" \
        2>/dev/null || echo 000)
    case "$oc" in
        2[0-9][0-9]) ;;
        *) echo "vault-sync: outcome POST failed http=$oc — F1 row NOT written (exit=$rc)" >&2 ;;
    esac
    return 0
}

# Consolidated exit handler. Installed BEFORE the SERVICE_KEY read so every
# exit path is covered. Signals pass an explicit rc (bare $? on a signal can
# be the last command's 0 → a killed run would otherwise log as healthy).
# `trap - EXIT` before the final exit guarantees no re-entrancy.
on_exit() {
    local rc="${1:-$?}"
    trap - EXIT INT TERM
    write_outcome "$rc"
    rm -f "${BODY_TMP:-}" "${INVENTORY_TMP:-}" 2>/dev/null
    rmdir "$LOCK_DIR" 2>/dev/null || true
    exit "$rc"
}
trap 'on_exit $?' EXIT
trap 'on_exit 130' INT
trap 'on_exit 143' TERM

SERVICE_KEY=$(security find-generic-password -s "project-supabase-service-role-jwt" -a "service_role" -w 2>/dev/null)
[ -n "$SERVICE_KEY" ] || fail "service_role JWT missing from Keychain — add it once with: security add-generic-password -s project-supabase-service-role-jwt -a service_role -w YOUR_SERVICE_ROLE_JWT"

# ── Vault path resolution ──────────────────────────────────────────────────
if [ ! -f "$CONFIG_FILE" ]; then
    fail "config missing: $CONFIG_FILE"
fi
VAULT_PATH=$(awk '/^---$/{if(++c==2) exit} c==1 && /vault_path:/{gsub(/.*vault_path:[[:space:]]*"?/,""); gsub(/"[[:space:]]*$/,""); print}' "$CONFIG_FILE")
[ -n "$VAULT_PATH" ] || fail "no vault_path in $CONFIG_FILE"
[ -d "$VAULT_PATH" ] || fail "vault path not found: $VAULT_PATH"

# ── Vault-owning-repo rebase guard (Amendment 13 / Edge #12) ───────────────
# The line-1 guard covers THIS repo rebasing. But a spoke can point its
# vault_path at a DIFFERENT repo's vault (cross-repo symlink); if THAT repo is
# mid-rebase the vault tree has conflict markers. Guard the vault owner too.
VAULT_OWNER_ROOT=$(cd "$VAULT_PATH" && git rev-parse --show-toplevel 2>/dev/null || echo "")
if [ -n "$VAULT_OWNER_ROOT" ] && { [ -d "$VAULT_OWNER_ROOT/.git/rebase-merge" ] || [ -d "$VAULT_OWNER_ROOT/.git/rebase-apply" ]; }; then
    log "vault-owner repo ($VAULT_OWNER_ROOT) rebasing — skip to protect KI integrity"
    echo "vault-sync: vault-owning repo rebasing — skipped" >&2
    exit 0
fi

log "start: vault=$VAULT_PATH user=${USER:-unknown}"

# ── PyYAML probe (Amendment 9 / Edge #3) ───────────────────────────────────
# Without PyYAML, frontmatter_to_json() silently returns {} for EVERY note —
# all tags/aliases/dates lost with zero signal. Probe once, loudly, and carry
# the degraded state into the F1 outcome row.
if ! python3 -c "import yaml" 2>/dev/null; then
    log "WARN: PyYAML not importable — ALL frontmatter discarded ({}) this run. Fix: pip3 install pyyaml. Body-only ingest continues (degraded, not silent)."
    echo "vault-sync: WARN PyYAML missing — frontmatter discarded" >&2
    PYYAML_MISSING=1
else
    PYYAML_MISSING=0
fi

# ── TCC self-diagnosis (macOS Privacy & Security) ──────────────────────────
# When launchd runs this on macOS and ~/Documents/ is in the path, macOS TCC
# may silently deny filesystem reads (find returns empty, no error). This
# probe surfaces the denial loudly instead of debugging blind.
TCC_PROBE_DIR=""
for d in "${VAULT_PATH}"/*/; do TCC_PROBE_DIR="$d"; break; done
if [ -n "$TCC_PROBE_DIR" ] && ! ls -1 "$TCC_PROBE_DIR" >/dev/null 2>&1; then
    log "tcc-probe FAIL: cannot list $TCC_PROBE_DIR — macOS TCC likely denying access. Fix: System Settings → Privacy & Security → Full Disk Access → add $0 (the script itself, not /bin/bash; SIP ignores grants to system binaries)."
fi

# ── L1 ALLOWLIST (NS-6 from 2026-05-15 extended council) ───────────────────
# Edge Case Finder surfaced 3 BLOCKING failure modes if we walk-from-root:
#   1. _claude-memory symlink → 72 memory files ingested as "vault notes"
#   2. personal/{user}/legacy-import-*/ (git-ignored but on-disk) → privacy breach
#   3. _agency-main, _{venture-1}, _{client-1}, _template, _{ops-repo} cross-repo
#      symlinks → BuyBox/Nirvana/template specs polluting knowledge_items
#
# Structural fix: explicit DIRECTORY ALLOWLIST. We only walk the dirs that
# legitimately contain agency-curated vault content. Symlinks at boundaries
# (the _*-prefixed alias folders) are skipped via -not -type l at the
# top-level + an explicit ALLOWLIST that doesn't name them.
#
# To add a vault subfolder to the L1 ingest: append it here. Do NOT add any
# _*-prefixed folder (those are cross-repo or symlink aliases by convention).

L1_ALLOWLIST=(
    "00 - MOCs"
    "01 - Projects"
    "02 - Areas"
    "03 - Resources"
    "04 - Permanent"
    "05 - Fleeting"
    "07 - Archives"
    "99 - Meta"
    "shared"
    "daily"
    # NOTE: personal/ is INTENTIONALLY excluded — Privacy Gate (NS-3).
    # personal/{user}/ files never land in shared knowledge_items.
)

# ── Inventory walk (allowlist-aware) ───────────────────────────────────────
# Use a tmpfile for find output to avoid pipe-eats-exit-code trap per
# .claude/rules/shell-portability.md rule 1.

INVENTORY_TMP="/tmp/vault-sync.inventory.$$"
: > "$INVENTORY_TMP"
# (tmpfile teardown is handled by the consolidated on_exit trap set earlier —
# do NOT re-trap here or write_outcome is lost on exit.)

for dir in "${L1_ALLOWLIST[@]}"; do
    full="$VAULT_PATH/$dir"
    # Skip if missing — not every vault has every folder yet
    [ -d "$full" ] || continue
    # Skip if it's itself a symlink (defence-in-depth — allowlist should not
    # contain symlinks by convention, but guard anyway)
    if [ -L "$full" ]; then
        log "skip-symlink: $dir is a symlink at top-level — excluded"
        continue
    fi
    find "$full" \
        -not -path "*/.obsidian/*" \
        -not -path "*/.git/*" \
        -not -type l \
        -name "*.md" -type f \
        -size +0 \
        -print >> "$INVENTORY_TMP" 2>/dev/null
done

NOTE_COUNT=$(wc -l < "$INVENTORY_TMP" | tr -d ' ')
log "inventory: $NOTE_COUNT notes total (allowlist)"

# ── L1 extract+upsert pipeline (SHIPPED 2026-05-15) ────────────────────────
#
# Per 2026-05-15 extended council + L1 fresh-session execution:
#
#   - source_type = 'vault_note'
#   - source_path = path RELATIVE to vault root
#   - content_hash = SHA-256 over body (after frontmatter parse)
#   - job_id = 'vault-sync:'||source_path||':'||left(hash,12)
#       Uses the EXISTING UNIQUE index `knowledge_items_job_id_key`
#       as the natural conflict target. Same content → same job_id → no-op.
#       New content → new job_id → second row (preserves audit trail).
#   - Conflict resolution: PostgREST `Prefer: resolution=ignore-duplicates`
#       → ON CONFLICT (job_id) DO NOTHING (per Reliability Engineer NS-7).
#   - NS-5 canary: after batch, if INSERTS > 0 but kg_vault_canary_recent_writes()
#       returns 0 → exit non-zero (writes-not-landing failure).
#
# Schema mapping (actual column names per pre-flight, NOT the continuation's
# generic title/content/metadata):
#   title    → source_title        raw_content   → raw_content
#   metadata → source_metadata     source_path   → source_path (NEW)
#   hash     → content_hash (NEW)  status        → 'ready'
#   kind     → 'internal'          submitted_via → 'vault_sync'
#
# Credential SERVICE_KEY + SUPABASE_URL are resolved earlier (after lock
# acquisition, alongside the F1 outcome hook). Only the derived endpoints
# remain here.
UPSERT_ENDPOINT="$SUPABASE_URL/rest/v1/knowledge_items"
RPC_CANARY_ENDPOINT="$SUPABASE_URL/rest/v1/rpc/kg_vault_canary_recent_writes"

# ── L1 helper functions ────────────────────────────────────────────────────

# Extract YAML frontmatter (between two leading --- markers). Empty if absent.
frontmatter_parse() {
    awk '
        BEGIN { in_fm = 0 }
        NR == 1 && /^---$/ { in_fm = 1; next }
        NR == 1            { exit }
        in_fm && /^---$/   { exit }
        in_fm              { print }
    ' "$1"
}

# Extract body: everything after closing --- of frontmatter, or whole file.
body_extract() {
    awk '
        BEGIN { in_fm = 0; past_fm = 0 }
        NR == 1 && /^---$/ { in_fm = 1; next }
        NR == 1            { past_fm = 1; print; next }
        in_fm && /^---$/   { in_fm = 0; past_fm = 1; next }
        in_fm              { next }
        past_fm            { print }
    ' "$1"
}

# Convert YAML frontmatter to JSON one-liner. '{}' on parse fail or empty.
frontmatter_to_json() {
    local fm="$1"
    [ -n "$fm" ] || { printf '{}'; return; }
    printf '%s' "$fm" | python3 -c "
import sys, json
try:
    import yaml
    d = yaml.safe_load(sys.stdin) or {}
    if not isinstance(d, dict):
        d = {'_frontmatter_raw': str(d)}
    print(json.dumps(d, default=str, separators=(',', ':')))
except Exception:
    print('{}')
" 2>/dev/null || printf '{}'
}

# Title: frontmatter `title:` if present, else filename stem.
title_resolve() {
    local fm_json="$1" file="$2" fm_title
    fm_title=$(printf '%s' "$fm_json" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('title','') if isinstance(d, dict) else '')
except Exception:
    print('')
" 2>/dev/null)
    if [ -n "$fm_title" ]; then printf '%s' "$fm_title"
    else basename "$file" .md
    fi
}

# ── Upsert loop (process all inventory; ON CONFLICT (job_id) DO NOTHING) ───
# (counters are initialised once at the top, after `set -uo pipefail`, so an
# early exit logs zeros — do NOT re-zero them here.)

# Body tmpfile reused per iteration to avoid env-var size limits on large notes.
BODY_TMP="/tmp/vault-sync.body.$$"
# (BODY_TMP teardown is handled by the consolidated on_exit trap set earlier.)

while IFS= read -r file; do
    [ -f "$file" ] || continue
    rel_path="${file#$VAULT_PATH/}"

    body_extract "$file" > "$BODY_TMP"
    if [ ! -s "$BODY_TMP" ]; then
        SKIPPED_EMPTY=$((SKIPPED_EMPTY + 1))
        continue
    fi

    content_hash=$(hash256 < "$BODY_TMP" | awk '{print $1}')
    fm_yaml=$(frontmatter_parse "$file")
    fm_json=$(frontmatter_to_json "$fm_yaml")
    title=$(title_resolve "$fm_json" "$file")
    job_id="vault-sync:${rel_path}:${content_hash:0:12}"

    # Build POST body via python (handles all escaping; reads body from tmpfile).
    payload=$(REL_PATH="$rel_path" CONTENT_HASH="$content_hash" \
              JOB_ID="$job_id" TITLE="$title" FM_JSON="$fm_json" \
              BODY_FILE="$BODY_TMP" \
              python3 -c '
import os, json
with open(os.environ["BODY_FILE"], "r", encoding="utf-8", errors="replace") as f:
    body = f.read()
try:
    fm = json.loads(os.environ["FM_JSON"])
except Exception:
    fm = {}
title = (os.environ.get("TITLE") or os.environ["REL_PATH"])[:500]
print(json.dumps({
    "job_id":          os.environ["JOB_ID"],
    "source_type":     "vault_note",
    "source_path":     os.environ["REL_PATH"],
    "content_hash":    os.environ["CONTENT_HASH"],
    "source_title":    title,
    "raw_content":     body,
    "source_metadata": fm if isinstance(fm, dict) else {},
    "source_kind":     "internal",
    "status":          "ready",
    "submitted_via":   "vault_sync",
    "is_current":      True,
}))
') || { FAILURES=$((FAILURES+1)); log "FAIL-payload: $rel_path"; continue; }

    http_code=$(printf '%s' "$payload" | curl -sS -o /dev/null -w '%{http_code}' \
        -X POST "$UPSERT_ENDPOINT" \
        -H "apikey: $SERVICE_KEY" \
        -H "Authorization: Bearer $SERVICE_KEY" \
        -H "Content-Type: application/json" \
        -H "Prefer: resolution=ignore-duplicates,return=minimal" \
        --data-binary @- 2>/dev/null)
    http_code=${http_code:-000}

    case "$http_code" in
        201)     INSERTS=$((INSERTS+1));   log "insert: $rel_path (hash=${content_hash:0:8})" ;;
        200|409) CONFLICTS=$((CONFLICTS+1)) ;;
        *)       FAILURES=$((FAILURES+1)); log "FAIL[$http_code]: $rel_path" ;;
    esac
done < "$INVENTORY_TMP"

rm -f "$BODY_TMP"

log "batch: inserts=$INSERTS conflicts=$CONFLICTS failures=$FAILURES skipped_empty=$SKIPPED_EMPTY"

# ── NS-5 canary (Reliability Engineer day-one requirement) ─────────────────
if [ "$INSERTS" -gt 0 ]; then
    canary_raw=$(curl -sS -X POST "$RPC_CANARY_ENDPOINT" \
        -H "apikey: $SERVICE_KEY" \
        -H "Authorization: Bearer $SERVICE_KEY" \
        -H "Content-Type: application/json" \
        --data '{}' 2>/dev/null)
    canary_num=$(printf '%s' "$canary_raw" | tr -dc '0-9' | head -c 6)
    canary_num=${canary_num:-0}
    if [ "$canary_num" -eq 0 ]; then
        fail "NS-5 canary FAILED: $INSERTS inserts attempted but canary returned 0 (canary_raw=$canary_raw)"
    fi
    log "NS-5 canary OK: $canary_num vault_note rows updated in last 10 min"
fi

if [ "$FAILURES" -gt 0 ]; then
    fail "$FAILURES upsert calls failed — see log for HTTP codes"
fi

heartbeat
log "ok: heartbeat written"
exit 0
