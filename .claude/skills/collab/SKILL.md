---
name: collab
description: |
  Bidirectional founder collaboration. Run /collab and speak naturally. Claude
  auto-classifies the input (question / issue / OVS / rock / report / idea /
  feedback / news), resolves which founder is at the keyboard via `gh api user`
  + `.claude/team.json`, files via the right channel (GitHub Issue, strategy
  decisions log, roadmap activity log), and dispatches a Telegram notification
  to the other founder. Pull-in mode (`/collab pull <id>` or `/collab inbox`)
  lets a founder integrate an incoming collab against THEIR own local
  context — different CLAUDE.md, ROADMAP, memory, profile.yaml on each side.
  Use when: user says "I had an idea", "Met with X", "Riley signed",
  "what do you think about", "Sam should look at", "review this when you
  can", "/collab", "submit this for consideration", "log this proposal",
  "send this to Alex", "send this to Sam", or invokes /collab directly.
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, Agent
user-invocable: true
version: 1.0
classification: encoded-preference
created: 2026-04-27
updated: 2026-04-27
template_managed: true
template_section: collaboration
parameters:
  - name: team_file
    type: path
    default: ".claude/team.json"
  - name: confidence_threshold
    type: number
    default: 0.80
    description: "Below this confidence, Claude asks for classification override"
  - name: telegram_bot_token_env
    type: string
    default: "TELEGRAM_BOT_TOKEN"
  - name: telegram_collab_group_env
    type: string
    default: "TELEGRAM_COLLAB_GROUP_ID"
  - name: collab_log_table
    type: string
    default: "collab_log"
  - name: partners_table
    type: string
    default: "partners"
  - name: partner_match_threshold
    type: number
    default: 0.95
    description: "Levenshtein similarity required for auto-tag (avoids Riley vs Riley)"
validated_on:
  - "a 2-person repo with team.json"
  - "Bidirectional outbound + handoff flows"
  - "Multi-machine identity resolution via gh api user"
  - "Per-recipient context-aware pull-in (different CLAUDE.md, ROADMAP, memory)"
related_artifacts:
  - specs/collab-skill-design.md  # full design spec, v2
  - .claude/team.json              # founder identity registry
  - supabase/migrations/20260427140616_collab_tables.sql  # data model
  - .claude/skills/daily-plan-generator/SKILL.md  # Phase 0.6 inbox surface
---

# /collab — Bidirectional Founder Collaboration

> Speak naturally. Claude routes intelligently. Other founder sees it on Telegram + in their next /daily-plan. Pull-in mode bridges different local contexts cleanly.

---

## Two modes

The skill has TWO modes, auto-detected from input:

| Mode | Triggered by | What it does |
|---|---|---|
| **SUBMIT** | Default — any natural-language collab input | Classify → route → file → notify other founder |
| **PULL-IN** | `/collab pull <id>` or `/collab inbox` | Load incoming collab → read RECIPIENT's local context → propose integration options → execute |

---

## SUBMIT mode — full workflow

### Phase 1 — Identity Resolution (ALWAYS FIRST)

```bash
ME=$(gh api user --jq .login 2>/dev/null)
TEAM_FILE=".claude/team.json"

if [ -z "$ME" ]; then
  echo "❌ Cannot resolve current user via gh api. Authenticate gh first."
  exit 1
fi

if [ ! -f "$TEAM_FILE" ]; then
  echo "❌ team.json not found. /collab requires founder identity registry."
  exit 1
fi

FOUNDER_NAME=$(jq -r ".founders[\"$ME\"].name // empty" "$TEAM_FILE")
FOUNDER_LANE=$(jq -r ".founders[\"$ME\"].eos_lane // empty" "$TEAM_FILE")
TG_HANDLE=$(jq -r ".founders[\"$ME\"].telegram_handle // empty" "$TEAM_FILE")

# Resolve OTHER founder (recipient of the dispatch)
OTHER_GH=$(jq -r ".founders | to_entries | map(select(.key != \"$ME\")) | .[0].key // empty" "$TEAM_FILE")
OTHER_NAME=$(jq -r ".founders[\"$OTHER_GH\"].name // empty" "$TEAM_FILE")
```

**Halt** with clear error if either fails. /collab is meaningless without founder identity.

### Phase 2 — Mode Detection (outbound vs handoff)

Infer from input phrasing:

| Phrasing | Mode |
|---|---|
| "Can you…" / "Please…" / "You should…" / "Do this when you can" / "<other founder> should…" | **handoff** |
| Default (declarative thoughts, observations, news, ideas) | **outbound** |
| Mixed/ambiguous | Confidence gate (Phase 3) — Claude asks |

### Phase 3 — Classification (with confidence gate)

Claude infers one of 8 types from the input. **NOT regex** — Claude reasoning.

```
question  → "Should we...", "What do you think about...", "How would I..."
issue     → "X is broken", "Y stopped working", "Z bug"
OVS       → "We should NOT be doing X", "This drifts from Y", "Strategy gap"
rock      → "Q3 rock:", "Goal for next quarter:", "We need to commit to..."
report    → "Met with X today", "Call summary", "Status update on Y"
idea      → "Crazy thought", "What if we", "Had an idea about"
feedback  → "I noticed X looks wrong", "UX nit on Y", "Z page feels off"
news      → "<partner> signed", "<partner> committed to", "<partner> launched"
```

**Confidence gate** (parameter `confidence_threshold`, default 0.80):

- **≥0.80** → file silently with inferred type
- **<0.80** → Claude says:
  ```
  Not sure yet. Top guesses:
    1) {top_guess} ({score}% confidence)
    2) {second_guess} ({score}% confidence)
  Or pick one: question | issue | OVS | rock | report | idea | feedback | news
  Or override syntax: `/collab as <type> "<text>"`
  ```

**Explicit override** always works: `/collab as idea "..."` skips classification.

### Phase 4 — Theme Detection

Auto-derive a theme code (≤8 chars uppercase) for the collab ID prefix:

```
1. Match input against known ROADMAP item codes (CM38, DR12, SI4, T3) — grep ROADMAP.md
2. If partner name matched (Phase 6) → THEME = "PARTNER"
3. If keyword matches: "rock"|"goal"|"quarterly" → THEME = "ROCK"
4. If keyword matches: "ux"|"design"|"brand"|"copy" → THEME = "BRAND"
5. If keyword matches: "broken"|"slow"|"bug"|"failing" → THEME = "OPS"
6. If keyword matches: "deal"|"property"|"buyer"|"seller" → THEME = "DEALS"
7. Fallback → "MISC"
```

Override syntax: `/collab theme=PARTNER "..."` forces theme.

### Phase 5 — ID Generation

```sql
-- Get next sequence for this theme
SELECT COALESCE(MAX(seq), 0) + 1 AS next_seq
FROM collab_log
WHERE theme = $1;
```

Format: `CL-{THEME}-{NNNN}` zero-padded — e.g., `CL-PARTNER-0023`, `CL-CM38-0007`, `CL-MISC-0142`.

### Phase 6 — Partner Auto-Tagging (optional)

```sql
-- Match input text against partners.name with similarity threshold
SELECT id, name, context FROM partners
WHERE similarity(name, '{input_excerpt}') >= 0.95;
```

Match → record relationship in `collab_relationships(collab_id, relation_kind='partner', relation_target=<partner_id>)`.

**Skip** if `partners` table missing or empty (graceful degrade).

### Phase 7 — Routing per Type

| Type | Primary destination | Secondary |
|---|---|---|
| question, issue, feedback, idea | `gh issue create` with label matching type | collab_log |
| OVS, news | append to `strategy/decisions-log.md` | collab_log |
| report, rock | INSERT into `bb_roadmap_activity` | collab_log |
| handoff (any type) | + adds row to recipient's task surface | collab_log mode='handoff' |

### Phase 8 — DB Write (MANDATORY when Supabase tool is available)

**This phase is NOT optional.** If `mcp__supabase-{{project}}__execute_sql` is in the assistant's available tool list, the assistant MUST invoke it for both INSERTs below. Skipping the call when the tool is available — for any reason ("seems redundant", "GitHub issue is enough", "I'll add a TODO note", etc.) — is a doctrine violation that breaks the `/collab inbox` and daily-plan-generator surfaces downstream.

The footer of the user-facing confirmation MUST distinguish three states:
- ✅ **Filed to DB** — INSERT returned a row (verify with the post-mutation `SELECT` below)
- ⏸️ **DB-pending** — Supabase tool genuinely unavailable (not in tool list); user told to retry from a chat that has it
- ❌ **DB-write attempted but failed** — show the SQL error verbatim; never mask as "skipped"

The wording "DB write skipped because TODO in practice" is BANNED. There is no TODO. The instruction is: invoke the tool now.

```sql
INSERT INTO collab_log (
  collab_id, founder_github, founder_name, recipient_github,
  classified_type, theme, seq, mode, raw_input, confidence,
  routed_to, status, created_at
) VALUES (
  'CL-PARTNER-0023', 'teammate-handle', 'Sam', 'your-org',
  'idea', 'PARTNER', 23, 'outbound', '{raw input}', 0.92,
  '{"github_issue": 340, "github_repo": "your-org/your-project", "telegram_dispatched": true}'::jsonb,
  'open', now()
)
RETURNING collab_id, theme, seq, status, created_at;
-- VERIFY: SELECT collab_id, status, routed_to->>'github_issue' AS gh_issue FROM collab_log WHERE collab_id = 'CL-PARTNER-0023' LIMIT 1

INSERT INTO collab_relationships (collab_id, relation_kind, relation_target)
VALUES
  ('CL-PARTNER-0023', 'partner', '<partner_uuid>'),
  ('CL-PARTNER-0023', 'github_issue', '340'),
  ('CL-PARTNER-0023', 'roadmap_item', 'a ROADMAP item');
-- VERIFY: SELECT count(*) FROM collab_relationships WHERE collab_id = 'CL-PARTNER-0023'
```

Both INSERTs MUST carry a trailing `-- VERIFY:` comment per the project's mutation-safety hook (otherwise the mutation guard rejects the call).

Rollback on any failure → user sees "Failed to file. {error}. Retry?"

### Phase 8 self-audit (run BEFORE writing the user-facing confirmation)

1. Did I actually call `mcp__supabase-{{project}}__execute_sql` with the INSERT? (Not just write SQL into the chat — actually invoke the tool.)
2. Did the tool return a row in `RETURNING`? (Empty result = INSERT silently rejected.)
3. Does the post-mutation `SELECT` find the row I just wrote?

If any answer is "no", the confirmation must say ❌ or ⏸️, not ✅.

### Phase 9 — Telegram Dispatch

```bash
if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_COLLAB_GROUP_ID" ]; then
  # Use existing CM.4 dispatch infrastructure via process-notification-queue
  # OR direct call to Telegram Bot API
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d chat_id="${TELEGRAM_COLLAB_GROUP_ID}" \
    -d parse_mode="MarkdownV2" \
    -d text="${MESSAGE}"
else
  echo "ℹ️ Telegram dispatch skipped (env vars unset). Filed to collab_log only."
fi
```

**Message format** (clean, concise, action-oriented per spec §9.2):

```
🟢 idea (CL-PARTNER-0023) from Sam
Riley's fund wants 0% down, 50yr seller carry
→ Alex: read + integrate via /collab pull CL-PARTNER-0023
```

Three lines: type+ID+author / content (≤140 chars truncated) / action verb. No raw URLs in body — link via tap.

Type icons: 🟢 idea | 🔴 issue | 🔵 question | 🟣 OVS | 🟡 rock | 🟠 report | 🟤 feedback | 📰 news | ⚡ handoff

### Phase 10 — Confirm + Display to Founder

```
✓ Filed CL-PARTNER-0023 (idea, theme: PARTNER)
  Routed to: GitHub Issue #340
  Notified: Sam on Telegram
  Status: open

  Track at: gh issue view 340
```

---

## PULL-IN mode — recipient-context integration

Triggered by `/collab pull CL-X-NNNN` or `/collab inbox`.

### Step 1 — Load the collab

```sql
SELECT cl.*, array_agg(cr.relation_kind || ':' || cr.relation_target) AS relations
FROM collab_log cl
LEFT JOIN collab_relationships cr ON cr.collab_id = cl.collab_id
WHERE cl.collab_id = $1
GROUP BY cl.collab_id;
```

### Step 2 — Read RECIPIENT's local context

The recipient's machine has DIFFERENT local context from the sender's. Read what THIS founder has on disk RIGHT NOW:

| Source | Use |
|---|---|
| `ROADMAP.md` (NOW + NEXT items) | Match keywords / item codes |
| `CLAUDE.md` | Project conventions |
| `MEMORY.md` + relevant project memory files | Recent priorities, in-flight work |
| `git log --since="7 days ago"` | What I've been working on |
| `gh pr list --author=@me --state=open` | What I have in flight |
| `continuations/*.md` (recent) | Active multi-session work |
| `strategy/decisions-log.md` (last 10) | Recent strategic decisions |
| Sam's machine: also Obsidian `relationships.md` (if MCP available) | Partner context |
| Alex's machine: also your CRM recent activity (if MCP available) | Partner CRM context |

### Step 3 — Cross-reference

Score each potential integration by fit:
- ROADMAP item match — exact code in input → +50
- ROADMAP item match — keyword similarity → +20-40
- Open PR touches related repo paths → +30
- Recent memory entry references same topic → +25
- Active continuation references same topic → +25
- Partner already in dd_partners or partners → +30

### Step 4 — Propose 4-6 ranked integration options

```
📥 Pulling CL-PARTNER-0023 — "Riley's fund wants 0% down, 50yr seller carry"
   Type: idea | Theme: PARTNER | From: Sam | Filed: 2h ago

Your local context says this connects to:
• a ROADMAP item (Contract Builder — creative finance) — IN PROGRESS
• Memory: project_creative_finance_the app_intake (queued)
• Open PR #339 — touches subject-to formulas
• strategy/decisions-log.md last entry: 2026-04-23 (Riley JV layer)

Integration options (ranked by fit):
(a) Add to ROADMAP under a ROADMAP item as a sub-item        ← recommended
(b) Open extended council — strategic implications for feature intake
(c) Queue as research brief for next /agentresearch
(d) Park in "considered, deferred" — note rationale
(e) Forward to your CRM Riley record + log strategy decision (no roadmap change)
(f) Custom — describe what you want

Pick a-f, or describe what you want differently:
```

### Step 5 — Execute the chosen integration

| Option | Action |
|---|---|
| (a) Roadmap sub-item | INSERT dd_roadmap_items row + collab_relationships link |
| (b) Council | invoke `/council --extended` with collab as proposal input |
| (c) Research brief | append to `continuations/AGENT-RESEARCH-QUEUE.md`, schedule for next session |
| (d) Park / deferred | UPDATE collab_log SET status='deferred', prompt for rationale → store in notes |
| (e) Forward / log | POST to your CRM Notes API + append `strategy/decisions-log.md` |
| (f) Custom | Claude offers to draft a custom action plan |

### Step 6 — Update collab + notify sender

```sql
UPDATE collab_log SET
  status = 'integrated',
  resolved_at = now(),
  resolved_by_collab_id = $1,
  integration_choice = $2,
  integration_notes = $3
WHERE collab_id = $4;
```

Telegram → sender:
```
✅ Alex integrated your CL-PARTNER-0023 → a ROADMAP item sub-item
```

---

## INBOX mode

`/collab inbox` lists all open collabs where the running founder is recipient:

```
📥 Collab Inbox for Alex (3 open)

🚨 Older than 72h:
  CL-OPS-0099 — Dashboard slow on Sam's Mac (issue, 4d ago)

⚠️ Older than 24h:
  CL-CM38-0007 — Reverse dispo angle (feedback, 1d ago)

🆕 Last 24h:
  CL-PARTNER-0023 — Riley 0% down 50yr terms (idea, 2h ago)

Pull one: /collab pull <id>
```

---

## Anti-patterns

| Wrong | Why | Right |
|---|---|---|
| Auto-classify and silent-route on low confidence | Misclassification cascades through routing — wrong destination = lost collab | Confidence gate at 0.80; ask if below |
| Map sender's ROADMAP/memory directly to recipient | Sender's a ROADMAP item may not exist on recipient's side, or have different status | Pull-in step ALWAYS reads recipient's local state — never assumes sender state |
| Auto-tag partners on weak match | `Riley` mistagged as different `Riley` person → wrong CRM note → trust collapse | 95%+ Levenshtein similarity required |
| Dispatch to Telegram if env unset | Hard error blocks the whole flow — collab is lost | Skip Telegram silently, write to collab_log, surface in next /daily-plan |
| Write to collab_log without idempotency check | Duplicate filings on retry | Check (founder_github, raw_input, created_at >NOW()-30s) before INSERT |
| Pull-in without recipient confirmation | Modifies recipient's roadmap/strategy/CRM without consent | ALWAYS confirm-before-execute, even at high confidence |
| Forget to update sender on integration | Sender doesn't know if their collab landed | Telegram dispatch on status change |
| Park/defer without rationale | Future "why didn't this happen?" can't be answered | Require 1-line rationale on park/defer |
| Hardcode partner names in skill | New partners need code changes | Read from partners table; both founders can add |
| Use `gh pr list` instead of `gh search prs` for inbox | Misses cross-repo collabs | Use `gh search prs` (account-wide) |

---

## Migration

Tables (new) authored in `supabase/migrations/20260427140616_collab_tables.sql`:
- `collab_log` — append-only (sort of) main log
- `collab_relationships` — many-to-many to ROADMAP / partners / repo paths / GitHub issues
- `partners` — shared partner registry (mutual founders contribute)

**MIGRATION NOT AUTO-APPLIED.** Alex reviews + applies via `apply_migration` MCP tool when ready.

---

## Held-out validation

This skill works for any 2-founder team that has:
- A `.claude/team.json` with `founders` map keyed by GitHub handle
- A Supabase project with the migration applied
- A `gh` CLI authenticated as the founder using the skill

The pattern (identity resolution → classification → routing → dispatch → context-aware pull-in) generalizes to any cross-team async collaboration where each side has its own working context. Replace `collab_log` table prefix and `team.json` path via parameters; everything else holds.

---

## Error handling

| Condition | Behavior |
|---|---|
| `gh` not authenticated | Halt with clear error — skill cannot resolve identity |
| `team.json` missing | Halt — skill is multi-founder by design |
| Founder not in `team.json` | Halt — explain how to add entry |
| Supabase MCP unavailable | SUBMIT mode: still file via GitHub Issue / decisions-log fallback; mark collab_log as `pending_db`. PULL-IN mode: cannot proceed (state lives in DB) |
| Telegram env unset | Skip dispatch silently, log "Filed to collab_log only" |
| Partner registry empty | Skip auto-tag silently |
| Confidence <0.80 with no fallback hints | Show all 8 types, let founder pick |
| Override `/collab as <invalid>` | Show valid types, ask again |
| Collab ID conflict (race condition) | Retry sequence query, increment, re-INSERT |
| Pull-in target not found | "No collab with that ID — run /collab inbox to see open" |

---

## Hooks (v1.1+ — out of scope for v1)

Documented in spec §6. v1 ships skill + DB only. Hooks come in v1.1:
- PR merged that closes a collab_log GitHub Issue → mark resolved + notify
- ROADMAP item moves to DONE for a related collab → mark resolved + notify
- Marketing-piece-complete → notify originating collab founder
- Partner record (your CRM) updated → append to related collabs

---

## Daily-plan integration

`/daily-plan` Phase 0.6 (NEW in v5.4 — extension of `daily-plan-generator/SKILL.md`):

Surfaces incoming collabs where the running founder is recipient. Handoffs (mode='handoff') get score=88 in the scored plan steps. Outbound collabs (idea/feedback/etc) appear in inbox section but NOT auto-added to scored work — recipient picks via `/collab pull`.

See `.claude/skills/daily-plan-generator/SKILL.md` Phase 0.6 for full output format.

---

*Skill version: 1.0 | Created 2026-04-27 — initial v1 build per specs/collab-skill-design.md (v2-locked). 8 classification types, identity resolution via team.json, themed Linear-style IDs, confidence-gated classification, bidirectional outbound+handoff modes, Telegram dispatch via CM.4 reuse, pull-in workflow with recipient-local-context awareness, INBOX mode for surfacing open collabs. v1 scope: skill + migration + daily-plan Phase 0.6 extension. Out of scope: hooks (v1.1), your CRM partner auto-tagging, marketing-piece-complete hook, EOS portal Rocks UI (Layer 2 council-required), voice input, Telegram bulk import.*
