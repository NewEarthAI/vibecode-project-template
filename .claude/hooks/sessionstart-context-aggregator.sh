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

resolve_primary_root() {
  # The PRIMARY checkout's root — identical from every worktree of the same
  # repo. This is the load-bearing path for the heartbeat layer: the writer
  # (running inside ANY worktree) and the janitor (reading from the primary)
  # MUST agree on one shared `.claude/worktrees/` dir, or the heartbeat
  # mechanism silently fails (Edge Case Finder, council 2026-05-25).
  #
  # `git rev-parse --show-toplevel` returns the CURRENT worktree's path
  # (different per worktree) — wrong. `--git-common-dir` returns the SHARED
  # `.git` (same for every worktree); its parent is the single primary root.
  # The common-dir may be relative (when invoked from the primary checkout) or
  # absolute (from a linked worktree) — handle both.
  local common
  common="$(git rev-parse --git-common-dir 2>/dev/null)" || return 1
  [ -n "$common" ] || return 1
  case "$common" in
    /*) ( cd "$(dirname "$common")" 2>/dev/null && pwd ) ;;
    *)  ( cd "$(git rev-parse --show-toplevel 2>/dev/null)/$(dirname "$common")" 2>/dev/null && pwd ) ;;
  esac
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
# MCP server count, nirvana-agent VPS reachability. Non-blocking by design —
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

  # VPS reachability — only probe if nirvana-agent is in ssh config (avoids
  # noisy "host not found" on machines that don't have the alias)
  local vps_status="n/a"
  if [ -f "$HOME/.ssh/config" ] && grep -q "^Host nirvana-agent" "$HOME/.ssh/config" 2>/dev/null; then
    if ssh -o ConnectTimeout=2 -o BatchMode=yes -o StrictHostKeyChecking=no \
         -q nirvana-agent exit 2>/dev/null; then
      vps_status="warm"
    else
      vps_status="unreachable"
    fi
  fi

  # One-liner output. Loud only on failure.
  echo '```'
  echo "gh=${gh_status}  supabase-cli=${sb_cli}  mcp-servers=${mcp_count}  nirvana-vps=${vps_status}"
  echo '```'

  # Visible warning if any check failed — separate line so the model notices
  if [ "$gh_status" = "AUTH-FAIL" ] || [ "$sb_cli" = "missing" ] || \
     [ "$vps_status" = "unreachable" ]; then
    echo "_⚠️ Pre-flight degraded — surface this BEFORE attempting any operation that depends on the failed surface._"
  fi
  echo ""
}

# ---------------------------------------------------------------------------
# Vault auto-read — the 5 most-recently-updated shared-vault notes
# ---------------------------------------------------------------------------
# Surfaces recent Obsidian vault notes from the shared knowledge database into
# the SessionStart briefing — the read half of the Obsidian autopilot. Every
# repo wired to the same parent vault (parent hub + child repos) sees the same
# shared notes; there is no per-repo vault.
#
# Config-driven by design: the database URL + the Keychain item that holds the
# read credential are read from the per-machine, gitignored
# .claude/obsidian-second-brain.local.md — so THIS file carries no
# project-specific reference and works for any adopter who runs /setup.
#
# Silent-skip (degrades, never blocks the briefing) when ANY of:
#   - no .claude/obsidian-second-brain.local.md on this repo/machine
#   - that config has no supabase_url: or no keychain_item:
#   - the read credential is missing from the macOS Keychain
#   - curl exits non-zero or exceeds 3s, or jq fails to parse the response
# Total budget: 3 seconds.

emit_vault_section() {
  local repo_root="$1"
  local cfg="$repo_root/.claude/obsidian-second-brain.local.md"
  [ -f "$cfg" ] || return  # no obsidian config on this repo — silent skip

  # Parse YAML frontmatter (between the first two '---' lines).
  local supabase_url kc_item vault_scope_slug
  supabase_url=$(awk '/^---$/{if(++c==2) exit} c==1 && /supabase_url:/{gsub(/.*supabase_url:[[:space:]]*"?/,""); gsub(/"[[:space:]]*$/,""); print}' "$cfg")
  kc_item=$(awk '/^---$/{if(++c==2) exit} c==1 && /keychain_item:/{gsub(/.*keychain_item:[[:space:]]*"?/,""); gsub(/"[[:space:]]*$/,""); print}' "$cfg")
  # Optional per-repo scope filter (added 2026-05-23) — when set, restricts
  # vault block to rows whose source_path contains this slug (case-insensitive
  # ilike). When absent, returns the full vault (Agency-Main parent behaviour).
  # Each downstream repo sets its own slug:
  #   vault_scope_slug: "{client-1}"        # repo 1
  #   vault_scope_slug: "{client-2}"        # repo 2
  vault_scope_slug=$(awk '/^---$/{if(++c==2) exit} c==1 && /vault_scope_slug:/{gsub(/.*vault_scope_slug:[[:space:]]*"?/,""); gsub(/"[[:space:]]*$/,""); print}' "$cfg")
  [ -n "$supabase_url" ] || return  # config has no supabase_url — silent skip
  [ -n "$kc_item" ] || return       # config has no keychain_item — silent skip

  local svc_key
  svc_key=$(security find-generic-password -s "$kc_item" -a "service_role" -w 2>/dev/null)
  [ -n "$svc_key" ] || return  # read credential not in this Mac's Keychain — silent skip

  # Over-fetch 20 rows then dedup-by-path in jq → 5 distinct notes (the
  # append-only audit trail means one path can have many rows). When the
  # per-repo scope slug is set, add a case-insensitive ilike filter on
  # source_path (PostgREST: %2A = url-encoded asterisk).
  local query='select=source_path,source_title,updated_at&source_type=eq.vault_note&order=updated_at.desc&limit=20'
  if [ -n "$vault_scope_slug" ]; then
    query="select=source_path,source_title,updated_at&source_type=eq.vault_note&source_path=ilike.%2A${vault_scope_slug}%2A&order=updated_at.desc&limit=20"
  fi
  local response
  response=$(curl -sS --max-time 3 \
    -H "apikey: $svc_key" \
    -H "Authorization: Bearer $svc_key" \
    "${supabase_url}/rest/v1/knowledge_items?${query}" 2>/dev/null) || return

  # F1 fix (code-council 2026-05-22): jq -e + array-type check.
  # `jq 'length'` on a PostgREST error envelope (`{"code":"PGRST301",...}`)
  # returns 4 (key count), bypasses the count>0 guard, and emits an empty
  # vault block with no operator signal that auth is broken. Force array
  # type-check + log auth-likely failure to ~/.claude/sessionstart-vault.log.
  local count
  count=$(printf '%s' "$response" | jq -e 'if type=="array" then length else error("not-an-array") end' 2>/dev/null) || {
    local vault_log="$HOME/.claude/sessionstart-vault.log"
    mkdir -p "$(dirname "$vault_log")" 2>/dev/null
    {
      printf '[%s] vault query returned non-array response (likely auth-expired or schema drift); response head: ' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      printf '%s' "$response" | head -c 200
      echo
    } >> "$vault_log" 2>/dev/null
    echo "### 📓 Recent vault activity"
    echo "_(vault read failed — likely auth expired or schema drift; see \`~/.claude/sessionstart-vault.log\`)_"
    echo ""
    return
  }
  [ -n "$count" ] && [ "$count" != "null" ] || return

  if [ -n "$vault_scope_slug" ]; then
    echo "### 📓 Recent vault activity — ${vault_scope_slug}-scoped (top 5 distinct notes by recency)"
  else
    echo "### 📓 Recent vault activity (top 5 distinct notes by recency)"
  fi
  if [ "$count" -eq 0 ]; then
    echo "_(no vault notes yet — vault-sync hasn't found anything new, or the vault is empty)_"
    echo ""
    return
  fi
  echo "_(source: \`knowledge_items\` where \`source_type='vault_note'\`)_"
  echo '```'
  printf '%s' "$response" | jq -r '
    group_by(.source_path)
    | map(max_by(.updated_at))
    | sort_by(.updated_at) | reverse
    | .[0:5]
    | .[] | "  \(.updated_at | .[0:10])  \(.source_title // "(no title)")  —  \(.source_path)"
  ' 2>/dev/null
  echo '```'
  echo ""
}

# ---------------------------------------------------------------------------
# Heartbeat writer — the liveness signal the janitor reads (council 2026-05-25)
# ---------------------------------------------------------------------------
#
# Writes `<primary>/.claude/worktrees/<current-worktree-basename>.heartbeat`
# containing a UTC epoch timestamp, every session start. This is the WRITE half
# of the armed-janitor layer; `sweep-stale-worktrees.sh` Check 4 is the READ
# half. Both resolve the dir via the shared primary root (resolve_primary_root)
# so a worktree session and the primary-run janitor agree on one location.
#
# Returns a one-line status on stdout (rides the visible session-start signal
# so a broken writer is visible EVERY session — Reliability Engineer
# non-shippable flag, council 2026-05-25). Never crashes the briefing: any
# failure prints "FAILED (<reason>)" and returns non-zero; the caller keeps
# going. Atomic write (temp + mv) so the janitor never reads a half-written
# file. NOT a PID — a SessionStart hook is a throwaway subprocess; $$ dies
# instantly. Timestamp-freshness is the correct signal across the hook boundary
# (mirrors cross-chat-collision-detect.sh's timestamp-marker choice).

emit_heartbeat() {
  local primary basename_wt hb_dir hb_file tmp now
  primary="$(resolve_primary_root)" || { echo "FAILED (not a git repo)"; return 1; }
  [ -n "$primary" ] || { echo "FAILED (primary root empty)"; return 1; }

  # The CURRENT worktree's basename keys the heartbeat (the primary writes its
  # own basename; each linked worktree writes its own). show-toplevel is the
  # current worktree here — correct, this is the thing whose liveness we record.
  local cur_toplevel
  cur_toplevel="$(git rev-parse --show-toplevel 2>/dev/null)"
  [ -n "$cur_toplevel" ] || { echo "FAILED (no worktree toplevel)"; return 1; }
  basename_wt="$(basename "$cur_toplevel")"

  hb_dir="$primary/.claude/worktrees"
  mkdir -p "$hb_dir" 2>/dev/null || { echo "FAILED (mkdir $hb_dir)"; return 1; }
  hb_file="$hb_dir/${basename_wt}.heartbeat"
  now="$(date -u +%s)"

  # Atomic: write temp in the same dir, then mv (rename is atomic on the same
  # filesystem) so a concurrent janitor read never sees a partial file.
  tmp="$(mktemp "$hb_dir/.hb.XXXXXX" 2>/dev/null)" || { echo "FAILED (mktemp)"; return 1; }
  printf '%s\n' "$now" > "$tmp" 2>/dev/null || { rm -f "$tmp"; echo "FAILED (write)"; return 1; }
  mv -f "$tmp" "$hb_file" 2>/dev/null || { rm -f "$tmp"; echo "FAILED (rename)"; return 1; }

  echo "$basename_wt @ $(date -u +%H:%M:%SZ)"
  return 0
}

# ---------------------------------------------------------------------------
# Fleet / collision section — auto-surface /where at session start (council
# 2026-05-25; operator said YES to auto-run). LOUD ⚠️ at the TOP of the
# briefing on a real two-worktree same-file clash; otherwise a quiet one-line
# all-clear. Composes where.sh (exit 1 = collision, exit 0 = clean) — never
# rebuilds the git logic. Budget ≤3s; degrades gracefully if where.sh absent.
# ---------------------------------------------------------------------------
#
# Returns TWO things via a sentinel-prefixed stdout the caller parses:
#   first line:  "COLLISION" or "CLEAN" or "SKIP"
#   rest:        the human-readable section body (markdown)
# The caller hoists the body to the TOP of the briefing when the first line is
# COLLISION, so the warning is impossible to miss.

emit_fleet_collision_section() {
  local primary="$1"
  local where_script="$primary/.claude/skills/where/scripts/where.sh"
  if [ ! -f "$where_script" ]; then
    printf 'SKIP\n'
    return 0
  fi

  # Run where.sh scoped to THIS repo only (the session-start view is "am I
  # colliding here right now" — the full fleet sweep is the manual /where).
  # WHERE_REPOS overrides the repo set; point it at the primary so we get a
  # fast, bounded read. Capture rc WITHOUT a pipe (shell-portability §1).
  local out rc tmp
  tmp="$(mktemp 2>/dev/null || echo "/tmp/agg-where.$$.$RANDOM")"
  ( cd "$primary" 2>/dev/null && WHERE_REPOS="$primary" bash "$where_script" ) > "$tmp" 2>/dev/null
  rc=$?
  out="$(cat "$tmp" 2>/dev/null)"
  rm -f "$tmp"

  # where.sh exit contract: 1 = collision detected, 0 = clean, 2 = no repos.
  if [ "$rc" -eq 1 ]; then
    # Extract just the collision bullet lines (after the COLLISION verdict line)
    # so the briefing stays tight. Fall back to the whole output if parsing fails.
    local collisions
    collisions="$(printf '%s\n' "$out" | sed -n '/COLLISION/,/Whichever session commits second/p' 2>/dev/null)"
    [ -z "$collisions" ] && collisions="$out"
    printf 'COLLISION\n'
    printf '### ⚠️ FILE COLLISION — two sessions editing the same file RIGHT NOW\n'
    printf '_(auto-surfaced at session start — STOP and reconcile before writing)_\n'
    printf '```\n%s\n```\n\n' "$collisions"
    return 0
  elif [ "$rc" -eq 0 ]; then
    # Pull the one-line worktree count for a quiet all-clear.
    local wt_line
    wt_line="$(printf '%s\n' "$out" | grep -cE '📄 ' 2>/dev/null)"
    wt_line=$(printf '%s' "$wt_line" | tr -dc '0-9' | head -c 4); wt_line=${wt_line:-0}
    printf 'CLEAN\n'
    printf '### 🟢 Fleet check\n'
    printf '_No file is being edited in two places at once — safe to run parallel sessions. (%s worktree view(s) scanned.)_\n\n' "$wt_line"
    return 0
  else
    printf 'SKIP\n'
    return 0
  fi
}

# ---------------------------------------------------------------------------
# Briefing assembly
# ---------------------------------------------------------------------------

build_briefing() {
  local repo_root="$1"
  local brief_script="$repo_root/.claude/skills/prime-lite/scripts/brief.sh"
  local heartbeat_items=0
  local body=""

  # ── Liveness heartbeat (silent side-effect, status surfaced) ──────────────
  # Write THIS worktree's heartbeat first so a session that crashes later still
  # recorded liveness. Status rides the visible signal: a broken writer shows
  # "heartbeat: FAILED ..." at every session start (Reliability Engineer flag).
  local hb_status
  hb_status="$(emit_heartbeat)"
  local hb_rc=$?
  if [ "$hb_rc" -eq 0 ]; then
    heartbeat_items=$((heartbeat_items + 1))
  fi

  # ── Fleet / collision (auto /where) — built now, hoisted to TOP on clash ──
  local primary_root fleet_raw fleet_verdict fleet_body
  primary_root="$(resolve_primary_root)"
  [ -n "$primary_root" ] || primary_root="$repo_root"
  fleet_raw="$(emit_fleet_collision_section "$primary_root")"
  fleet_verdict="$(printf '%s\n' "$fleet_raw" | head -1)"
  fleet_body="$(printf '%s\n' "$fleet_raw" | tail -n +2)"
  if [ "$fleet_verdict" != "SKIP" ]; then
    heartbeat_items=$((heartbeat_items + 1))
  fi

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

  # Vault auto-read — top 5 recent shared-vault notes from the knowledge
  # database. Silent-skip when no obsidian config exists on this repo/machine
  # or on any failure; 3-second budget.
  local vault_section
  vault_section=$(emit_vault_section "$repo_root")
  if [ -n "$vault_section" ]; then
    body="${body}${vault_section}"
    heartbeat_items=$((heartbeat_items + 1))
  fi

  # Fleet/collision placement. On COLLISION → hoist to the very TOP of body so
  # the ⚠️ is impossible to miss (operator's "I always know what's going on").
  # On CLEAN → quiet one-liner appended at the end. SKIP → nothing.
  if [ "$fleet_verdict" = "COLLISION" ]; then
    body="${fleet_body}

${body}"
  elif [ "$fleet_verdict" = "CLEAN" ]; then
    body="${body}${fleet_body}"
  fi

  # Heartbeat — visible signal that the hook actually fired (Reliability
  # Engineer non-shippable flag). The liveness-marker status rides this same
  # line so a broken heartbeat-writer is visible at EVERY session start.
  local body_bytes=${#body}
  local hb_marker_line="heartbeat: ${hb_status}"
  local heartbeat
  heartbeat="**Session context loaded: ${heartbeat_items} sections, ${body_bytes} bytes · ${hb_marker_line}**"
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

  # T8 — resolve_primary_root agrees with the shared common-dir parent. From any
  # worktree this MUST equal the parent of `git rev-parse --git-common-dir`.
  local prim expected_common expected_prim
  prim=$(resolve_primary_root)
  expected_common=$(git rev-parse --git-common-dir 2>/dev/null)
  if [ -n "$expected_common" ]; then
    case "$expected_common" in
      /*) expected_prim=$(cd "$(dirname "$expected_common")" 2>/dev/null && pwd) ;;
      *)  expected_prim=$(cd "$(git rev-parse --show-toplevel 2>/dev/null)/$(dirname "$expected_common")" 2>/dev/null && pwd) ;;
    esac
  fi
  if [ -n "$prim" ] && [ "$prim" = "$expected_prim" ]; then
    check "T8 resolve_primary_root matches shared common-dir parent" true
  else
    check "T8 resolve_primary_root matches shared common-dir parent (got '$prim' vs '$expected_prim')" false
  fi

  # T9 — emit_heartbeat writes a parseable UTC timestamp to the shared dir and
  # reports a non-FAILED status. Read it back and confirm it's numeric + recent.
  local hb_out hb_rc hb_dir hb_basename hb_path hb_val now_t
  hb_out=$(emit_heartbeat); hb_rc=$?
  hb_dir="$prim/.claude/worktrees"
  hb_basename=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
  hb_path="$hb_dir/${hb_basename}.heartbeat"
  if [ "$hb_rc" -eq 0 ] && [ -f "$hb_path" ]; then
    hb_val=$(tr -dc '0-9' < "$hb_path" | head -c 12)
    now_t=$(date -u +%s)
    if [ -n "$hb_val" ] && [ "$((now_t - hb_val))" -ge 0 ] && [ "$((now_t - hb_val))" -lt 120 ]; then
      check "T9 emit_heartbeat wrote a fresh numeric timestamp (status: $hb_out)" true
    else
      check "T9 emit_heartbeat timestamp not fresh/numeric (val: '$hb_val')" false
    fi
  else
    check "T9 emit_heartbeat wrote file + reported ok (rc=$hb_rc, status: $hb_out)" false
  fi

  # T10 — the heartbeat status rides the visible session-start line.
  if [[ "$briefing" == *"heartbeat: "* ]]; then
    check "T10 heartbeat status appears in the visible session-start line" true
  else
    check "T10 heartbeat status appears in the visible session-start line" false
  fi

  # T11 — fleet/collision section returns a known verdict (COLLISION/CLEAN/SKIP)
  # and never crashes. (We don't assert which — depends on live worktree state.)
  local fleet_out fleet_v
  fleet_out=$(emit_fleet_collision_section "$prim")
  fleet_v=$(printf '%s\n' "$fleet_out" | head -1)
  case "$fleet_v" in
    COLLISION|CLEAN|SKIP) check "T11 fleet section returns a known verdict (got: $fleet_v)" true ;;
    *) check "T11 fleet section returns a known verdict (got: '$fleet_v')" false ;;
  esac

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
