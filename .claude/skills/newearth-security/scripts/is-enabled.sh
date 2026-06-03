#!/usr/bin/env bash
# newearth-security — toggle gate
#
# Per council 2026-05-22 Amendments 3, 4, 5, 6, 14, 15.
# (Amendment 11 lives in SKILL.md body — Tier 1 grep `--exclude-dir=.claude` — not this script.)
# V1.1 refactor (code-council 2026-05-22 backlog A, B, F, G, M):
#   A — Layer 3 parses settings.local.json via jq (the SessionStart hook already
#       depends on jq), replacing the python3 + grep fallback. The jq `//` operator
#       is deliberately AVOIDED: `false // "absent"` returns "absent" in jq, which
#       would silently miss a `false` disable. We use `has()` instead.
#   B — repo root resolved via `git rev-parse --show-toplevel` (CWD-relative),
#       script-dir walk-up kept only as a fallback for non-git invocations.
#   F — exit 2 (value-unknown / indeterminate) split from exit 3 (installation
#       broken: jq missing, invalid JSON, repo root unresolvable).
#   G — each layer is a named function (check_env / check_fs / check_settings) that
#       emits one token. Precedence is applied in main() — invariant-by-construction.
#   M — every disable (exit 1) appends an audit line to .claude/security-toggle-audit.log.
#
# Precedence (most ephemeral wins): env var > filesystem flag > settings.local.json
#
# Exit codes (Amendment 4 + backlog F):
#   0 = ENABLED   (default — no explicit signal OR explicit enable signal)
#   1 = DISABLED  (explicit, via one of the three layers)
#   2 = INDETERMINATE — a toggle value is set but unrecognised. Caller MUST HALT
#       (Amendment 5: NO silent bypass on a misconfigured value).
#   3 = INSTALLATION BROKEN — jq missing, settings.local.json unparseable, or the
#       repo root could not be resolved. Caller MUST HALT (distinct from a bad value;
#       this is an environment problem, not an operator typo).
#
# Disabled value = one of: 0 false no off disabled  (case-insensitive)
# Enabled  value = one of: 1 true  yes on enabled   (case-insensitive)
# Any other set value = indeterminate → exit 2. Layers 1 and 3 share this grammar,
# so a quoted `"false"` in settings disables exactly as a bare `false` does — an
# operator's disable intent is never silently dropped over a quoting choice.

set -uo pipefail

readonly DISABLE_RE='^(0|false|no|off|disabled)$'
readonly ENABLE_RE='^(1|true|yes|on|enabled)$'

# REPO_ROOT is resolved once at startup; check_fs and audit_disable both read it.
REPO_ROOT=""

# ---- Resolve repo root (backlog B) -------------------------------------------
# Prefer the current git toplevel (CWD-relative — honours the repo the operator is
# actually working in). Fall back to walking up from the script's own directory for
# non-git invocations. Empty result = unresolvable.
resolve_repo_root() {
  local root
  if root="$(git rev-parse --show-toplevel 2>/dev/null)" && [ -n "$root" ]; then
    printf '%s' "$root"
    return 0
  fi
  local d
  d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null)" || return 1
  while [ -n "$d" ] && [ "$d" != "/" ]; do
    if [ -d "$d/.claude" ]; then
      printf '%s' "$d"
      return 0
    fi
    d="$(dirname "$d")"
  done
  return 1
}

# ---- Match a normalised value against the shared grammar ---------------------
# Emits: enabled | disabled | indeterminate
classify_value() {
  local v
  v="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
  if [[ "$v" =~ $DISABLE_RE ]]; then
    echo disabled
  elif [[ "$v" =~ $ENABLE_RE ]]; then
    echo enabled
  else
    echo indeterminate
  fi
}

# ---- Layer 1 — env var (highest precedence) ----------------------------------
# Emits: enabled | disabled | indeterminate | absent
check_env() {
  # The empty-guard is LOAD-BEARING, not redundant: classify_value normalises with
  # `tr -d '[:space:]'`, so a set-but-empty var (NEWEARTH_SECURITY_ENABLED="", common in
  # shell profiles) would normalise to "" and classify as indeterminate (exit 2 HALT).
  # We want set-but-empty to mean "absent" (fall through to next layer), NOT a HALT.
  # Do not fold this guard into classify_value.
  if [ -z "${NEWEARTH_SECURITY_ENABLED:-}" ]; then
    echo absent
    return
  fi
  classify_value "${NEWEARTH_SECURITY_ENABLED}"
}

# ---- Layer 2 — filesystem flag -----------------------------------------------
# Emits: disabled | absent | broken
# .claude/newearth-security.disabled (file exists → disabled), resolved against the
# repo root. broken = repo root unresolvable, so a project-level flag CANNOT be
# honoured — fail loud rather than silently ignore a possible disable.
check_fs() {
  if [ -z "$REPO_ROOT" ]; then
    echo broken
    return
  fi
  if [ -f "$REPO_ROOT/.claude/newearth-security.disabled" ]; then
    echo disabled
  else
    echo absent
  fi
}

# ---- Layer 3 — settings.local.json -------------------------------------------
# Emits: enabled | disabled | indeterminate | absent | broken
# Parses with jq. has() distinguishes "key absent" from "key is false" — the jq
# `//` operator cannot, because `false // x` evaluates to x. The value runs through
# the SAME grammar as Layer 1, so boolean `false` and string `"false"` both disable.
check_settings() {
  local f="$HOME/.claude/settings.local.json"
  if [ ! -f "$f" ]; then
    echo absent
    return
  fi
  if ! command -v jq >/dev/null 2>&1; then
    echo broken
    return
  fi
  local raw
  if ! raw="$(jq -r 'if has("newearth_security_enabled") then (.newearth_security_enabled | tostring) else "__absent__" end' "$f" 2>/dev/null)"; then
    echo broken
    return
  fi
  # Treat all "no usable value" cases as absent (→ fall through → enabled default):
  #   __absent__ = key not present;  "" = empty/whitespace-only settings file (jq emits
  #   nothing);  "null" = key present with JSON null. None is a disable signal, so none
  #   should HALT — they mean "no Layer-3 opinion".
  if [ "$raw" = "__absent__" ] || [ -z "$raw" ] || [ "$raw" = "null" ]; then
    echo absent
    return
  fi
  classify_value "$raw"
}

# ---- Audit log on disable (backlog M) ----------------------------------------
audit_disable() {
  local layer="$1"
  [ -n "$REPO_ROOT" ] || return 0
  local logf="$REPO_ROOT/.claude/security-toggle-audit.log"
  printf '%s\tdisabled\tlayer=%s\tcwd=%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$layer" "$(pwd 2>/dev/null || echo '?')" \
    >> "$logf" 2>/dev/null || true
}

# ---- Precedence resolution (backlog G) ---------------------------------------
main() {
  REPO_ROOT="$(resolve_repo_root || true)"

  # Layer 1 — env var.
  # The `*)` arm makes exhaustiveness invariant-by-construction (backlog G): if a check
  # function ever emits a token outside its declared alphabet, HALT loudly (exit 3) rather
  # than silently falling through to the next layer — for a security gate, a silent
  # default-to-enabled on an unexpected token is the worst failure mode.
  case "$(check_env)" in
    disabled)      audit_disable env; exit 1 ;;
    enabled)       exit 0 ;;
    indeterminate)
      echo "is-enabled.sh: NEWEARTH_SECURITY_ENABLED=${NEWEARTH_SECURITY_ENABLED} is not one of {1,true,yes,on,enabled,0,false,no,off,disabled}" >&2
      exit 2 ;;
    absent) ;;  # fall through
    *) echo "is-enabled.sh: check_env emitted an unexpected token — installation broken, HALTING" >&2; exit 3 ;;
  esac

  # Layer 2 — filesystem flag.
  case "$(check_fs)" in
    disabled) audit_disable fs; exit 1 ;;
    broken)
      echo "is-enabled.sh: cannot resolve repo root — Layer 2 filesystem flag cannot be honoured (HALTING per Amendment 5)" >&2
      exit 3 ;;
    absent) ;;  # fall through
    *) echo "is-enabled.sh: check_fs emitted an unexpected token — installation broken, HALTING" >&2; exit 3 ;;
  esac

  # Layer 3 — settings.local.json.
  case "$(check_settings)" in
    disabled) audit_disable settings; exit 1 ;;
    enabled)  exit 0 ;;
    indeterminate)
      echo "is-enabled.sh: newearth_security_enabled in $HOME/.claude/settings.local.json is set but unrecognised — HALTING per Amendment 5" >&2
      exit 2 ;;
    broken)
      echo "is-enabled.sh: cannot parse $HOME/.claude/settings.local.json (jq missing or invalid JSON) — HALTING per Amendment 5" >&2
      exit 3 ;;
    absent) ;;  # fall through
    *) echo "is-enabled.sh: check_settings emitted an unexpected token — installation broken, HALTING" >&2; exit 3 ;;
  esac

  # No signal anywhere → ENABLED.
  exit 0
}

main
