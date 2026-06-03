#!/bin/bash
# layman-reinjector.sh — UserPromptSubmit hook
#
# Re-injects a compact layman-voice reminder on every user turn so the rule
# stays top-of-mind across long sessions where context drift erodes adherence.
#
# Triple-gated for token efficiency (per .claude/rules/hook-efficiency.md):
#   Gate 1: registered for UserPromptSubmit only — narrow event scope
#   Gate 2: bash-native fast-path — raw substring scan for "/dev" off-switch
#   Gate 3: conditional inject — silent on /dev (one-shot dev-mode), else inject
#
# Cost on /dev turns:    ~0 tokens output, <5ms
# Cost on normal turns:  ~50 tokens injected, <30ms
# Latency budget:        <50ms total (well under 5s timeout)
#
# Self-test:
#   echo '{"prompt":"hello"}' | bash layman-reinjector.sh   # expects context injection
#   echo '{"prompt":"/dev show me logs"}' | bash layman-reinjector.sh  # expects {}

set -uo pipefail

input=$(cat 2>/dev/null || echo "{}")

# Gate 2: bash-native fast-path — raw substring scan for /dev token.
# Only invoke python3 to disambiguate when /dev appears in the input
# (avoids ~30ms python startup on every clean turn).
case "$input" in
  *'/dev'*)
    is_dev=$(printf '%s' "$input" | python3 -c '
import json, sys
try:
    d = json.loads(sys.stdin.read())
    p = (d.get("prompt") or "").lstrip()
    # /dev must be standalone first token (banned: URLs containing /dev)
    if p.startswith("/dev") and (len(p) == 4 or p[4] in " \n\t"):
        print("Y")
    else:
        print("N")
except Exception:
    print("N")
' 2>/dev/null)
    if [ "$is_dev" = "Y" ]; then
      echo '{}'
      exit 0
    fi
    ;;
esac

# Gate 3: inject compact layman reminder.
# ~50 tokens — a distillation of .claude/rules/layman-mode.md (already loaded
# at SessionStart). Purpose: freshness nudge against context drift, not full
# re-load.
cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"LAYMAN VOICE — every reply: define jargon inline first use · shortest answer that fully addresses · decide-don't-menu (banned: \"Three options: A/B/C\") · Commonwealth spelling in prose (colour/organise/realise/behaviour) · numbers stay precise · no raw paths/globs/bare-CLI as user-facing labels — use prose + 📁📄 icons. Carve-outs (technical OK): code, SQL, sub-agent prompts, rule/memory/continuation files, code-council outputs."}}
EOF
