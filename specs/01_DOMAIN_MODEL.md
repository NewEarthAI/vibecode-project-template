# the agency — Domain Model

## Core Entities

### 1. Business (the agency)
The agency itself as a trackable entity.

| Property | Type | Description |
|----------|------|-------------|
| revenue_monthly | decimal | Monthly revenue across all sources |
| costs_monthly | decimal | Monthly costs (tools, subscriptions, contractors) |
| active_clients | integer | Count of active client engagements |
| active_projects | integer | Count of projects in progress |
| automations_live | integer | Count of live automations across all clients |

### 2. Client
Agency clients receiving AI automation services.

| Property | Type | Description |
|----------|------|-------------|
| name | string | Company/client name |
| contact_info | object | Primary contacts, email, phone |
| industry | string | Logistics, PropTech, etc. |
| contract_value | decimal | Total contract value |
| monthly_recurring | decimal | Monthly recurring revenue |
| payment_status | enum | current, overdue, pending |
| lifecycle_stage | enum | lead, discovery, scoping, active, monitoring, churned |
| ai_maturity_level | enum | none, basic, intermediate, advanced (future: audit-derived) |
| projects | relation[] | Associated projects |

**States**: `lead → discovery → scoping → active → monitoring → churned`

### 3. Project
Deliverables for a client — automations, dashboards, integrations.

| Property | Type | Description |
|----------|------|-------------|
| name | string | Project name |
| client_id | reference | Parent client |
| description | text | What the project delivers |
| status | enum | backlog, scoping, in_progress, testing, live, monitoring |
| repo_url | string | GitHub repo if applicable |
| n8n_folder | string | n8n folder name for this project's workflows |
| supabase_project | string | Which Supabase instance this uses |
| priority | enum | critical, high, medium, low |
| started_at | timestamp | When work began |
| delivered_at | timestamp | When delivered to client |

**States**: `backlog → scoping → in_progress → testing → live → monitoring`

### 4. Automation / Workflow
Individual n8n workflows, Make scenarios, or edge functions.

| Property | Type | Description |
|----------|------|-------------|
| name | string | Workflow name |
| project_id | reference | Parent project |
| platform | enum | n8n, make, supabase_edge, custom |
| n8n_workflow_id | integer | ID in n8n instance |
| n8n_instance | string | your-org or your-instance |
| trigger_type | enum | webhook, cron, manual, email, whatsapp, supabase_trigger |
| status | enum | draft, active, paused, error, deprecated |
| last_execution | timestamp | When it last ran |
| error_rate | decimal | Recent error percentage |

### 5. Financial Record
Revenue and cost tracking across ventures.

| Property | Type | Description |
|----------|------|-------------|
| type | enum | revenue, cost |
| category | string | client_payment, subscription, tool_cost, contractor |
| amount | decimal | Dollar amount |
| recurring | boolean | Is this recurring? |
| frequency | enum | one_time, monthly, annual |
| source | string | Which venture/client this relates to |
| date | date | Transaction date |

---

## Entity Relationships

```
the agency (Business)
├── Clients (1:many)
│   ├── Projects (1:many)
│   │   ├── Automations (1:many)
│   │   └── GitHub Repos (1:1 or 1:many)
│   └── Financial Records (1:many) — revenue per client
├── Internal Projects (1:many) — a SaaS app, Property Business
│   ├── Automations (1:many)
│   └── Financial Records (1:many)
└── Financial Records (1:many) — agency-level costs
```

---

## Key Workflows

### Client Delivery Flow
```
1. Lead received (word of mouth, referral)
2. Discovery call → understand business needs
3. Scoping / AI Audit → assess AI maturity, identify opportunities
4. Proposal → based on audit findings
5. Contract → agreement signed
6. Build/Automate → create workflows, dashboards, integrations
7. Deliver → handoff, training, go-live
8. Monitor → ongoing optimization, reporting, iteration
```

### Typical Automation Flow
```
Trigger (webhook/email/WhatsApp/cron)
  → n8n receives event
  → JavaScript code nodes normalize data
  → AI nodes (OpenAI/LangChain) classify/analyze
  → Supabase stores/retrieves data
  → Output (Gmail report / dashboard update / WhatsApp response / API call)
```

### Business Intelligence Flow
```
Raw data (n8n executions, Supabase tables, client activity)
  → Aggregate and correlate
  → Calculate KPIs (revenue, costs, automation success rates)
  → Present on dashboards (Lovable)
  → Generate reports (Gmail, PDF)
```
