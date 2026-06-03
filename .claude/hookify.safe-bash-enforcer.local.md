---
name: safe-bash-enforcer
enabled: true
event: PreToolUse
tool_matcher: Bash
action: block
conditions:
  - field: command
    operator: regex
    pattern: rm\s+-rf\s+[/~.]|dd\s+if=|mkfs|chmod\s+-?R?\s*777|eval\s|exec\s|:\(\)\{|nc\s+-l|ncat\s+-l|socat\s+TCP-LISTEN
---

**BLOCKED**: Catastrophic shell pattern detected (rm -rf /, dd, mkfs, chmod 777, eval, exec, fork bombs, netcat listeners). Use safe-bash task scripts for privileged workflows. Also enforced by bash-guardian.sh (exit 2).
