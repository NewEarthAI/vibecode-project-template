# Data Ingestion — Multi-Source Data Protocols

> How to pull live data from any source into presentations.
> Every data point must be sourced, verified, and attributed.

---

## Source Priority

When multiple sources could provide the same data, prefer in this order:

1. **Live database query** — Most accurate, real-time
2. **Project files** — ROADMAP.md, CONTEXT.md, specs/
3. **Conversation context** — User-provided information
4. **Web research** — External data, market research
5. **Inference** — Only when explicitly labeled as estimated

---

## Supabase (3 Instances)

### Pattern: Execute SQL Query

```sql
-- Always specify columns (never SELECT *)
-- Always include LIMIT
-- Use the correct project context

SELECT column_1, column_2, column_3
FROM public.table_name
WHERE condition = 'value'
ORDER BY created_at DESC
LIMIT 100;
```

### Instance Mapping

| Data Need | Supabase Instance | MCP Server |
|-----------|------------------|------------|
| Primary project KPIs, financials | {{Agency Name}} | `supabase-.*` |
| {{Venture/Client Name}} metrics, deals | {{Venture/Client Name}} | `supabase-.*` |
| {{Client Name}} ops data | {{Client Name}} | `supabase-.*` |

### Common Queries for Presentations

```sql
-- Client KPIs (feedback reports)
SELECT metric_name, metric_value, period, trend
FROM client_metrics
WHERE client_id = '{{client_id}}'
AND period = '{{period}}'
ORDER BY metric_name;

-- Automation performance (case studies)
SELECT workflow_name, execution_count, success_rate, avg_duration_ms
FROM automation_metrics
WHERE date >= '{{start_date}}'
GROUP BY workflow_name;

-- Maturity scores (audit reports)
SELECT domain_name, score, level, weight
FROM audit_scores
WHERE engagement_id = '{{engagement_id}}';
```

### Column Verification (MANDATORY)

Before writing ANY SQL, verify columns exist:
```sql
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = '{{table_name}}'
ORDER BY ordinal_position;
```

---

## n8n (2 Instances)

### Instance Mapping

| Data Need | n8n Instance | MCP Server |
|-----------|-------------|------------|
| Agency + client automations | {{Agency Name}} | `n8n-mcp-.*` |
| {{Venture/Client Name}} automations | {{Venture/Client Name}} | `n8n-mcp-.*` |

### Useful Data Points

| Metric | How to Get |
|--------|-----------|
| Active workflow count | MCP: `n8n_list_workflows` (count active) |
| Execution success rate | MCP: `n8n_executions` (filter by status) |
| Automation uptime | Calculate from execution history |
| Error frequency | Count failed executions in period |

### Usage Rules

- Use `mode: 'minimal'` for execution queries (never 'full')
- Never use `n8n_list_workflows` for IDs — use project workflow skill
- Calculate derived metrics (success rate, uptime) from raw execution data

---

## Project Files

### Common Sources for Presentations

| Data Need | File Path | What to Extract |
|-----------|-----------|----------------|
| Project status | `clients/{slug}/ROADMAP.md` | Current milestones, completed items |
| Client profile | `clients/{slug}/PROFILE.yaml` | Contact info, industry, engagement type |
| Client context | `clients/{slug}/CLAUDE.md` | Architecture, integrations, key systems |
| Audit methodology | `agency/AI_MATURITY_AUDIT_TEMPLATE.md` | Domain definitions, scoring |
| Service menu | `departments/marketing/CONTEXT.md` | Service offerings, ICP |
| Department context | `departments/{dept}/CONTEXT.md` | Department-specific KPIs |

### Extraction Pattern

1. Read the file with the Read tool
2. Extract relevant sections
3. Map extracted data to slide content
4. Attribute the source in speaker notes

---

## Airtable

### Usage

Query Airtable via MCP tools when data lives there (legacy, migrating to ClickUp):

```
mcp__airtable-mcp-.*__list_records
mcp__airtable-mcp-.*__search_records
```

### Common Data

| Data | Base/Table | When |
|------|-----------|------|
| Client CRM records | Agency Base | Proposal context |
| Project tracking | Projects Table | Status reports |

---

## Web Sources

### WebFetch for Specific URLs

```
Use WebFetch to pull specific pages:
- Client websites (for context/branding)
- Industry reports (for market data)
- Competitor analysis (for positioning)
```

### WebSearch for Market Data

```
Use WebSearch for:
- Industry statistics ("logistics automation market size 2026")
- Competitor information
- Technology benchmarks
- Regulatory updates (POPIA, data protection)
```

### Attribution Rule

ALL web-sourced data MUST include:
- Source name
- URL
- Date accessed
- Confidence level (verified/estimated/projected)

---

## Chrome DevTools / Playwright

### Dashboard Screenshots

For visual evidence in feedback reports:

```
Use Chrome DevTools or Playwright to:
1. Navigate to the client's dashboard
2. Take viewport screenshots (NOT full-page)
3. Embed as base64 in HTML presentations
4. Add as image in PPTX presentations
```

### Rules

- Use `fullPage: false` (viewport screenshot)
- Element screenshots preferred over full page
- Add annotations/callouts to highlight key metrics
- Always use `browser_snapshot` for interaction, screenshots for capture

---

## Conversation Context

### Extracting from Discussion

When the user has been discussing a topic, extract:

1. **Key points** mentioned in the conversation
2. **Numbers/metrics** the user has referenced
3. **Decisions made** during the session
4. **Pain points** the user has described
5. **Goals** the user has expressed

### Pattern

```
Source: Conversation context
Confidence: User-provided (verify if quantitative)
Attribution: "Based on our discussion on {{date}}"
```

---

## Data Integrity Rules

### MANDATORY for All Data

1. **Never fabricate numbers** — If you don't have data, say "Data not available" or ask
2. **Always attribute** — Every data point has a source
3. **Verify against source** — Re-query or re-read to confirm before including
4. **Date-stamp** — Include the date data was pulled
5. **Confidence labels** — Mark as Actual / Estimated / Projected / Target
6. **Consistent units** — ZAR vs USD, hours vs days, % vs absolute
7. **Context** — "40% improvement" always includes "from X to Y"

### Data Freshness

| Source Type | Freshness |
|-------------|-----------|
| Live SQL query | Real-time (state at query time) |
| Project files | Last commit date |
| Cached data | Must be < 24 hours old |
| Web research | Date of publication noted |
| Conversation | Current session only |

---

## Data-to-Slide Mapping

| Data Type | Best Slide Type | Chart Type |
|-----------|----------------|------------|
| Single KPI | Bold Claim | Gauge / big number |
| Trend over time | Data | Line chart |
| Category comparison | Data | Horizontal bar |
| Before vs After | Split | Grouped bar or side-by-side |
| Composition | Data | Donut chart |
| Multi-axis assessment | Data | Radar chart |
| Status list | Content | Table with color coding |
| Process steps | Diagram | Assembly Line diagram |
| Timeline | Timeline | Milestone markers |

---

*Reference Version: 1.0 — Multi-Source Data Ingestion*
