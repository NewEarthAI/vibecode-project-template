# the agency — System Architecture

## Overview

the agency operates as an AI-augmented data pipeline platform. The architecture follows a **hub-and-spoke model** with n8n as the central automation hub, Supabase as the data layer, and AI (OpenAI/LangChain) at strategic decision points.

## System Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│                        TRIGGER LAYER                              │
│  Webhooks │ Email │ WhatsApp │ Cron │ Manual │ Supabase Triggers │
└─────────────────────────────┬────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│                    AUTOMATION LAYER (n8n)                          │
│                                                                    │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐         │
│  │ Code Nodes   │──▶│ AI Nodes     │──▶│ Action Nodes │         │
│  │ (JS/JSON)    │   │ (OpenAI/     │   │ (HTTP, DB,   │         │
│  │ Normalize    │   │  LangChain)  │   │  Email, API) │         │
│  │ Transform    │   │ Classify     │   │              │         │
│  │ Validate     │   │ Analyze      │   │              │         │
│  └──────────────┘   │ Decide       │   └──────────────┘         │
│                     └──────────────┘                              │
│                                                                    │
│  n8n-your-org (agency)  │  n8n-your-instance (a SaaS app)           │
└─────────────────────────────┬────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│                      DATA LAYER (Supabase)                        │
│                                                                    │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────────┐ │
│  │ supabase-yourproject│  │supabase-dispo-  │  │supabase-mid-     │ │
│  │ (cross-project) │  │daddy (a SaaS app)   │  │atlantic (Prop)   │ │
│  └─────────────────┘  └─────────────────┘  └──────────────────┘ │
│                                                                    │
│  Tables │ RPCs │ Edge Functions │ Realtime                        │
└─────────────────────────────┬────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                              │
│                                                                    │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐         │
│  │ Lovable.dev  │   │ Gmail Reports│   │ WhatsApp     │         │
│  │ Dashboards   │   │ PDF exports  │   │ (Wassenger)  │         │
│  │ (Next.js)    │   │              │   │              │         │
│  └──────────────┘   └──────────────┘   └──────────────┘         │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                    DEVELOPMENT LAYER                               │
│                                                                    │
│  Claude Code ──▶ MCP Servers ──▶ Direct platform changes          │
│  GitHub ──▶ Lovable auto-deploy                                   │
│  Redis (caching/state) │ Make.com (supplementary automations)     │
└──────────────────────────────────────────────────────────────────┘
```

## Communication Patterns

| From | To | Method |
|------|----|--------|
| External → n8n | Webhooks, email triggers, WhatsApp (Wassenger API) |
| n8n → Supabase | Direct DB operations, RPC calls, edge function invocations |
| n8n → External | HTTP requests, Gmail SMTP, Wassenger API |
| Supabase → n8n | Database triggers, webhook notifications |
| Lovable → Supabase | Direct client (Supabase JS), RPC calls |
| Claude Code → All | MCP server connections |
| GitHub → Lovable | Push triggers auto-deploy |

## Design Principles

1. **Deterministic first, AI second** — Use AI only where intelligent decision-making adds value. Keep pipelines predictable.
2. **Data must be queryable** — Everything stored in structured, queryable format in Supabase.
3. **Minimal mode first** — Always start with the least data needed, escalate only when required.
4. **Platform-native** — Use each tool's strengths (n8n for orchestration, Supabase for data, Lovable for UI).
5. **Claude Code as deployer** — All changes flow through Claude Code via MCP for auditability.

## Component Responsibilities

| Component | Responsibility |
|-----------|---------------|
| **n8n** | Orchestration, data pipeline processing, AI integration, scheduling |
| **Supabase** | Persistent storage, RPCs, edge functions, realtime subscriptions |
| **Redis** | Caching, session state, temporary data, rate limiting |
| **Lovable.dev** | Frontend dashboards, client-facing UIs, data visualization |
| **OpenAI/LangChain** | Classification, analysis, natural language processing, decision support |
| **Wassenger** | WhatsApp automation, client communication |
| **Gmail** | Report delivery, notifications, client communication |
| **GitHub** | Version control, CI/CD (via Lovable), code management |
| **Claude Code** | Development, deployment, cross-platform orchestration |
| **Make.com** | Supplementary automations where n8n isn't optimal |
