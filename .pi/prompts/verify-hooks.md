# /verify-hooks

Comprehensive 8-phase audit of all enforcement layers. Catches escape hatches, enforcement gaps, token waste, missing deny coverage, and silent hookify failures. Template-portable — works in any project after `/update-latest`.

**Goal**: Every HARD STOP item must have hard enforcement (settings.local.json deny OR shell hook exit 2 OR hookify block). Behavioral guidance (warn/addContext) is NOT enforcement. Token efficiency must be maximized (0-token layers preferred over high-token layers for the same outcome).

---

## Phase 1: Environment Discovery

```
Read .claude/template-source.md → template_repo, last_sync
Read .mcp.json → all configured MCP server names
```

Derive flags:
- `has_supabase` — any server name containing `supabase`
- `has_n8n` — any server name containing `n8n`
- `has_wassenger` — any server name containing `wassenger`
- `has_playwright` — any server name containing `playwright`
- `has_chrome` — any server name containing `chrome`
- `has_redis` — any server name containing `redis`
- `has_github` — any server name containing `github`
- `mcp_servers[]` — full list of server names

Report:
```
ENVIRONMENT
━━━━━━━━━━━
Template:    {repo URL} (last sync: {date})
MCP Servers: {list} ({N} total)
Flags:       supabase={Y/N} n8n={Y/N} wassenger={Y/N} playwright={Y/N} redis={Y/N} github={Y/N}
```

---

## Phase 2: Layer 1 — settings.local.json Audit

Read `.claude/settings.local.json`.

### 2a. Escape Hatch Detection (CRITICAL)

Scan `permissions.allow[]` for overly broad patterns that bypass all other guards:

| Dangerous Pattern | Risk | Why |
|-------------------|------|-----|
| `Bash(*)` | Allows ANY bash command | Bypasses bash-guardian.sh |
| `Bash(bash:*)` | Allows `bash -c "anything"` | Same — wraps any command |
| `Bash(bash -c:*)` | Allows `bash -c "anything"` | Escape hatch for destructive commands |
| `Bash(sh:*)` | Allows `sh -c "anything"` | Same escape via sh |
| `Bash(sudo:*)` | Allows sudo anything | Privilege escalation |
| `mcp__*` (bare wildcard) | Allows ALL MCP tools | Bypasses deny list |
| Any pattern that is a prefix of a denied tool | Contradiction | Allow wins over deny |

For each found: **FLAG AS CRITICAL**.

### 2b. Deny List Coverage

For each MCP server detected, verify these HARD STOP items are in `permissions.deny[]`:

| Server | Required Deny Entries |
|--------|----------------------|
| supabase-* | `deploy_edge_function`, `create_branch`, `merge_branch`, `delete_branch` |
| wassenger | `send_whatsapp_message`, `manage_whatsapp_message_interactions`, `manage_whatsapp_campaigns`, `manage_whatsapp_campaign_contacts`, `manage_whatsapp_queue` |

### 2c. Allow List Quality

Check for useful patterns that SHOULD be allowed (reduces permission prompts):
- Safe git: `Bash(git status:*)`, `Bash(git log:*)`, `Bash(git diff:*)`, `Bash(git add:*)`, `Bash(git commit:*)`
- Safe bash: `Bash(ls:*)`, `Bash(wc:*)`, `Bash(mkdir:*)`, `Bash(cp:*)`
- Skills: `Skill(*)`
- MCP reads per server: `list_*`, `get_*`, `search_*`, `execute_sql` (for supabase)

Note: File tools (Read, Write, Edit, Glob, Grep) are auto-allowed by Claude Code defaults — don't need explicit entries.

### 2d. Allow/Deny Contradiction Check

Verify no tool appears in BOTH allow and deny. If it does, allow wins — flag as contradiction.

Report:
```
LAYER 1: settings.local.json
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Escape hatches:     {N found — list each}
Deny coverage:      {N}/{M} HARD STOP items covered
Allow patterns:     {N} total, {M} useful missing
Contradictions:     {N found}
Token cost:         0 per session (settings = free enforcement)
```

---

## Phase 3: Layer 2 — Shell Hooks Audit

### 3a. File Discovery

```bash
ls -la .claude/hooks/*.sh 2>/dev/null
```

Expected shell hooks:

| Hook | Matcher | Purpose |
|------|---------|---------|
| `sql-guardian.sh` | `execute_sql` | Blocks DELETE without WHERE, TRUNCATE, DROP TABLE/FUNCTION/VIEW |
| `bash-guardian.sh` | `Bash` | Blocks recursive force delete, git push force, git reset hard, git clean, kill -9, pkill, .env mods, docker rm force, chmod 777 |
| `session-summarizer.sh` | Stop event | Writes session summary to `.claude/sessions/` |

### 3b. Executable + Registration Check

```bash
for f in .claude/hooks/*.sh; do
  test -x "$f" && echo "OK: $f" || echo "FAIL: $f (not executable)"
done
```

Read `.claude/settings.local.json` → verify each hook appears in `hooks.PreToolUse[]` or `hooks.Stop[]` with correct matcher.

### 3c. Content Validation (catches stale/incomplete hooks)

For each shell hook, grep for expected block patterns:

**sql-guardian.sh** must block: `DELETE FROM` (no WHERE), `TRUNCATE`, `DROP TABLE`, `DROP FUNCTION`, `DROP VIEW`

**bash-guardian.sh** must block: recursive force delete, `git push --force` / `git push -f`, `git reset --hard`, `git clean -f`, `kill -9`, `pkill`/`killall`, `.env` modification, `docker rm -f`, `chmod 777`

Flag any missing patterns.

Report:
```
LAYER 2: Shell Hooks
━━━━━━━━━━━━━━━━━━━━
Found: {N} hooks | Expected: {M}
{hook}: {EXISTS/MISSING} | {EXECUTABLE/not} | {REGISTERED/not}
Content: sql-guardian {5/5} | bash-guardian {9/9}
Token cost: 0 per match (free enforcement)
```

---

## Phase 4: Layer 3 — Hookify Rules Audit

### 4a. Rule Discovery + Classification

For each `.claude/hookify.*.local.md`, extract frontmatter and classify by enforcement power:

| Action | Enforcement? | Token Cost | Mechanism |
|--------|-------------|------------|-----------|
| `block` | YES — hard deny via `permissionDecision: "deny"` | ~50 tok/block | Hookify plugin |
| `warn` | NO — injects guidance text | ~200-400 tok/match | Claude may ignore |
| `addContext` | NO — injects context | ~200-400 tok/match | No enforcement |

### 4b. Safety-Critical Warn Rules

For each `warn` on a safety-critical operation, check for shell hook backup:

- `filesystem-safety` (warn) + `bash-guardian.sh` → OK (hard backup exists)
- `supabase-destructive-sql` (warn) + `sql-guardian.sh` → OK (hard backup exists)
- `supabase-migration-safety` (warn) + no shell hook → NOTE (guidance only, acceptable)
- `n8n-update-safety` (warn) + no shell hook → NOTE (guidance only, acceptable)
- Token-optimization warns → OK (guidance is appropriate, not safety)

Flag safety warns WITHOUT hard backup that cover destructive operations.

### 4c. Expected Minimum Set

| Rule | Required If | Action |
|------|-------------|--------|
| `confident-mode` | Always | addContext |
| `auto-rules` | Always | addContext |
| `filesystem-safety` | Always | warn |
| `progress-logger` | Always | addContext |
| `plan-mode-enforcer` | Always | addContext |
| `plan-mode-exit-gate` | Always | addContext |
| `roadmap-freshness` | Always | addContext |
| `completion-verifier` | Always | addContext |
| `task-context-injector` | Always | addContext |
| `github-file-contents` | has_github | warn |
| `mcp-server-guard` | Always | block |
| `supabase-destructive-sql` | has_supabase | warn |
| `supabase-migration-safety` | has_supabase | warn |
| `supabase-auto-load` | has_supabase | addContext |
| `supabase-select-star` | has_supabase | block |
| `supabase-smart-query` | has_supabase | warn |
| `supabase-list-tables-warn` | has_supabase | block |
| `n8n-workflow-delete-block` | has_n8n | block |
| `n8n-auto-load` | has_n8n | addContext |
| `n8n-fetch-blocker` | has_n8n | block |
| `n8n-update-safety` | has_n8n | warn |
| `n8n-use-essentials` | has_n8n | block |
| `n8n-executions-full` | has_n8n | block |
| `playwright-full-page` | has_playwright | block |

Flag missing and disabled rules.

Report:
```
LAYER 3: Hookify Rules
━━━━━━━━━━━━━━━━━━━━━━
Found: {N} ({E} enabled, {D} disabled) | Expected: {M}
BLOCK: {N} | WARN: {N} | ADDCONTEXT: {N}
Safety warns without hard backup: {list or "None"}
Missing: {list} | Disabled: {list}
```

---

## Phase 5: Hookify Runtime Verification (catches silent failures)

**Why this phase exists**: The hookify plugin v0.1.0 had 7 bugs that caused all hooks to silently fail (exit 0, empty JSON). File-level checks pass but rules never fire. This catches that.

Write a verification script to `/tmp/verify_hookify_runtime.py` and run it:

```bash
cat > /tmp/verify_hookify_runtime.py << 'PYEOF'
#!/usr/bin/env python3
"""Hookify runtime verification — tests that rules actually load and evaluate."""
import sys, os, json

cache = os.path.expanduser('~/.claude/plugins/cache/claude-code-plugins/hookify')
if not os.path.isdir(cache):
    print("FAIL: Hookify plugin not installed at", cache)
    sys.exit(1)

versions = [v for v in os.listdir(cache) if not v.startswith('.')]
if not versions:
    print("FAIL: No hookify versions found")
    sys.exit(1)

plugin_root = os.path.join(cache, versions[0])
sys.path.insert(0, plugin_root)

try:
    from core.config_loader import load_rules
    from core.rule_engine import RuleEngine
    print("PASS: Imports work")
except ImportError as e:
    print(f"FAIL: Import error — {e}")
    sys.exit(1)

engine = RuleEngine()
results = {"pass": 0, "fail": 0, "skip": 0}

def check(label, actual, expected):
    ok = actual == expected
    results["pass" if ok else "fail"] += 1
    print(f"  {'PASS' if ok else 'FAIL'}: {label}" + ("" if ok else f" (got={actual!r})"))

# SessionStart
print("\n=== SessionStart ===")
ss = load_rules(events=['SessionStart'])
check(f"SessionStart rules loaded ({len(ss)})", len(ss) >= 1, True)

# PreToolUse
print("\n=== PreToolUse ===")
ptu = load_rules(events=['PreToolUse'])
check(f"PreToolUse rules loaded ({len(ptu)})", len(ptu) >= 1, True)

# Block rules deny
print("\n=== Block Rule Evaluation ===")
for rule in ptu:
    if rule.action == 'block' and rule.enabled:
        test_input = {'hook_event_name': 'PreToolUse', 'tool_name': '', 'tool_input': {}}
        if rule.name == 'mcp-server-guard':
            test_input['tool_name'] = 'supabase-testproject_execute_sql'
        elif 'n8n' in rule.name and 'delete' in rule.name:
            test_input['tool_name'] = 'n8n-mcp-test_n8n_delete_workflow'
            test_input['tool_input'] = {'id': 'test'}
        elif rule.name == 'playwright-full-page':
            test_input['tool_name'] = 'playwright_browser_take_screenshot'
            test_input['tool_input'] = {'fullPage': 'true'}
        elif rule.name == 'n8n-use-essentials':
            test_input['tool_name'] = 'n8n-mcp-test_get_node_info'
        elif rule.name == 'n8n-fetch-blocker':
            test_input['tool_name'] = 'n8n-mcp-test_n8n_get_workflow'
            test_input['tool_input'] = {'mode': 'full', 'id': 'test'}
        elif rule.name == 'n8n-executions-full':
            test_input['tool_name'] = 'n8n-mcp-test_n8n_executions'
            test_input['tool_input'] = {'action': 'get', 'mode': 'full', 'id': 'test'}
        else:
            results["skip"] += 1
            print(f"  SKIP: {rule.name} (no test case)")
            continue
        res = engine.evaluate_rules([rule], test_input)
        decision = res.get('hookSpecificOutput', {}).get('permissionDecision')
        check(f"{rule.name} → deny", decision, 'deny')

# Warn rules produce systemMessage
print("\n=== Warn Rule Evaluation ===")
for rule in ptu:
    if rule.action == 'warn' and rule.enabled:
        test_input = {'hook_event_name': 'PreToolUse', 'tool_name': '', 'tool_input': {}}
        if 'destructive-sql' in rule.name:
            test_input['tool_name'] = 'supabase-test_execute_sql'
            test_input['tool_input'] = {'query': 'DROP TABLE test'}
        elif 'migration-safety' in rule.name:
            test_input['tool_name'] = 'supabase-test_apply_migration'
            test_input['tool_input'] = {'name': 'test', 'query': 'ALTER TABLE t ADD c TEXT'}
        elif 'filesystem-safety' in rule.name:
            test_input['tool_name'] = 'Bash'
            test_input['tool_input'] = {'command': 'mv /tmp/a /tmp/b'}
        elif 'github' in rule.name and 'file-contents' in rule.name:
            test_input['tool_name'] = 'github_get_file_contents'
            test_input['tool_input'] = {'owner': 'test', 'repo': 'test', 'path': 'README.md'}
        else:
            results["skip"] += 1
            print(f"  SKIP: {rule.name} (no test case)")
            continue
        res = engine.evaluate_rules([rule], test_input)
        has_msg = bool(res.get('systemMessage'))
        no_deny = res.get('hookSpecificOutput', {}).get('permissionDecision') != 'deny'
        check(f"{rule.name} → systemMessage (not deny)", has_msg and no_deny, True)

# Context rules have content
print("\n=== Context Rules ===")
for rule in ptu:
    if rule.action == 'addContext' and rule.enabled:
        check(f"{rule.name} has content", len(rule.message) > 20, True)

# Engine wildcards
print("\n=== Engine Capabilities ===")
check("Wildcard matching", engine._matches_tool('mcp__n8n-mcp-*__*', 'n8n-mcp-test_n8n_get_workflow'), True)
check("Exact match", engine._matches_tool('Bash', 'Bash'), True)
check("Non-match", engine._matches_tool('Bash', 'Read'), False)

total = results["pass"] + results["fail"]
print(f"\n{'='*50}")
print(f"RUNTIME: {results['pass']}/{total} passed, {results['fail']} failed, {results['skip']} skipped")
sys.exit(0 if results["fail"] == 0 else 1)
PYEOF
python3 /tmp/verify_hookify_runtime.py
```

If FAIL: copy fixed plugin from `plugins/hookify/` to cache.

---

## Phase 6: Cross-Layer Coverage Matrix

Build matrix of ALL HARD STOP operations vs enforcement layers:

```
HARD STOP COVERAGE MATRIX
━━━━━━━━━━━━━━━━━━━━━━━━━
Operation                 settings.json  Shell Hook     Hookify         Grade
──────────────────────────────────────────────────────────────────────────
recursive force delete     —             bash-guardian   fs-safety(warn)  A
git push force             —             bash-guardian   fs-safety(warn)  A
git reset hard             —             bash-guardian   fs-safety(warn)  A
git clean force            —             bash-guardian   fs-safety(warn)  A
DELETE FROM (no WHERE)     —             sql-guardian    sb-destr(warn)   A
TRUNCATE                   —             sql-guardian    sb-destr(warn)   A
DROP TABLE                 —             sql-guardian    —                B
DROP FUNCTION              —             sql-guardian    —                B
DROP VIEW                  —             sql-guardian    —                B
deploy_edge_function      DENY           —              —                B
create/merge/delete_branch DENY          —              —                B
send_whatsapp_message     DENY           —              —                B
WhatsApp campaigns        DENY           —              —                B
n8n delete_workflow        —             —              n8n-delete(blk)  B
kill -9                    —             bash-guardian   fs-safety(warn)  A
.env modification          —             bash-guardian   fs-safety(warn)  A
docker rm force            —             bash-guardian   fs-safety(warn)  A
chmod 777                  —             bash-guardian   —                B
```

**Grades**: A+ = 3 hard layers | A = 2 layers (1+ hard) | B = 1 hard layer | F = guidance only or none

Flag anything below B.

---

## Phase 7: Token Efficiency Analysis

### 7a. Estimate per-session overhead

| Layer | Tokens Each | Frequency |
|-------|-------------|-----------|
| settings.local.json | 0 | Passive |
| Shell hooks (pass) | 0 | Every matching call |
| Hookify block | ~50 | On match |
| Hookify warn | ~200-400 | On match |
| Hookify addContext | ~200-400 | On match |
| SessionStart rules | ~200-400 | Once |

### 7b. Optimization opportunities

- Warn rules with shell hook backup → redundant guidance, ~300 tokens wasted per trigger. Consider disabling if shell hook covers same patterns.
- addContext on frequent tool calls → evaluate if guidance changes behavior enough to justify cost.
- SessionStart addContext → fires once, acceptable.

### 7c. Score

```
A = < 2,000 tok/session | B = 2-4K | C = 4-6K | D = 6-10K | F = > 10K
```

---

## Phase 8: Auto-Fix & Report Card

### Auto-Fix

| Issue | Fix | Auto? |
|-------|-----|-------|
| Escape hatch in allow | Remove pattern | YES |
| Missing deny entry | Add to deny[] | YES |
| Hook not executable | `chmod +x` | YES |
| Hook not registered | Add to settings hooks | YES |
| Missing hookify rule | Copy from template | YES |
| Disabled rule | Set `enabled: true` | YES |
| Allow/deny contradiction | Remove from allow | YES |
| Plugin import bug | Copy fixed code from plugins/hookify/ to cache | YES |
| Warn without hard backup | Create shell hook or convert to block | ASK |

Ask: "Found {N} issues ({C} critical, {M} medium, {L} low). Apply all? (y/n/review)"

After fixes: re-run Phases 2-7 to verify.

### Hookify Plugin Prerequisite

```bash
ls ~/.claude/plugins/cache/claude-code-plugins/hookify/ 2>/dev/null
```

If not installed: Layer 3 is INACTIVE — all `.local.md` rules are inert. Flag in report.

### Report Card

```
╔══════════════════════════════════════════════════════╗
║  HOOKS & RULES VERIFICATION — {project name}        ║
╠══════════════════════════════════════════════════════╣
║                                                      ║
║  Layer 1 (settings.json):                            ║
║    Escape hatches:     {0} ............. {PASS/FAIL} ║
║    Deny coverage:      {N/M} .......... {PASS/FAIL}  ║
║    Allow quality:      {N patterns} ... {PASS/INFO}  ║
║                                                      ║
║  Layer 2 (Shell Hooks):                              ║
║    Registered:         {N/M} .......... {PASS/FAIL}  ║
║    Executable:         {N/M} .......... {PASS/FAIL}  ║
║    Pattern coverage:   {N/M} .......... {PASS/FAIL}  ║
║                                                      ║
║  Layer 3 (Hookify Rules):                            ║
║    Present:            {N/M} .......... {PASS/FAIL}  ║
║    Runtime tests:      {N/M} .......... {PASS/FAIL}  ║
║    Safety enforcement: {desc} ......... {PASS/WARN}  ║
║                                                      ║
║  Cross-Layer:                                        ║
║    HARD STOP coverage: {N/M} ops ...... {PASS/FAIL}  ║
║    Min grade per op:   {grade} ........ {PASS/WARN}  ║
║                                                      ║
║  Token Efficiency:     ~{N} tok/session  {GRADE}     ║
║                                                      ║
║  Overall Grade: {A+/A/B/C/D/F}                       ║
║                                                      ║
║  Issues:  {C} critical | {M} medium | {L} low        ║
║  Fixed:   {N}  |  Remaining: {N}                     ║
╚══════════════════════════════════════════════════════╝
```

**A+** = 0 critical, 0 medium, token A | **A** = 0 critical, <=2 medium | **B** = 0 critical, >2 medium | **C** = 1+ critical unfixed | **F** = escape hatch or HARD STOP with zero enforcement

---

## Template Portability

- MCP servers from `.mcp.json` (not hardcoded)
- Hookify expectations scale with detected servers
- Shell hook patterns are universal
- Deny list derives from server flags
- No project-specific names/IDs

---

## Related

- `/setup` — full project setup
- `/update-latest` — pull template updates
- `.claude/hooks/` — shell hook scripts
- `.claude/settings.local.json` — permission enforcement backbone
