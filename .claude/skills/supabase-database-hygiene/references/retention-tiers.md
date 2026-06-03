---
title: Retention Tier Design
description: Enterprise-grade data retention windows by data type with regulatory context
tags: retention, tiers, compliance, FMCSA, POPIA, logistics
---

# Retention Tier Design

## Industry Benchmarks (Fleet/Logistics)

| Platform | GPS/Trip History | ELD/HOS Records | Video |
|----------|-----------------|-----------------|-------|
| Geotab | 2 years (standard) | Same umbrella | — |
| Samsara | Indefinite (configurable) | Indefinite | 28d–4yr |
| Verizon Connect | 2 years; 13mo GDPR default | Compliance-driven | — |

## Regulatory Context

| Regulation | Requirement |
|-----------|-------------|
| FMCSA ELD (USA) | 6-month minimum for Records of Duty Status |
| POPIA (South Africa) | Purpose-limitation; no fixed window; delete when no longer needed |
| GDPR (EU) | Purpose-limitation; 13-month industry default for location data |

## Recommended Tier Architecture

| Tier | Data Type | Retention | Storage | Justification |
|------|-----------|-----------|---------|---------------|
| **Hot** | Raw GPS positions (sub-minute pings) | 30–90 days | Primary DB (indexed) | Operational queries, incident investigation |
| **Hot** | Telematics events (speed, harsh braking, idle) | 30–90 days raw, strip payload at 14d | Primary DB | Payload JSON is 60%+ of row size; metadata sufficient after 14d |
| **Hot** | System/pipeline logs | 14 days | Primary DB | Debugging value decays rapidly |
| **Hot** | Cooldown/dedup tables | 7 days | Primary DB | No compliance value; exists only for deduplication |
| **Warm** | Aggregated GPS (hourly/daily rollups) | 1–3 years | Archive table or export | Trend analysis, compliance audits |
| **Warm** | Alert/notification history | 90 days–1 year | Primary DB | Operational accountability |
| **Cold** | Audit trail events | **Never delete** | Primary DB | Legal, compliance, reconstruction |
| **Cold** | Incident records, accidents | **Indefinite** | Separate compliance store | Legal hold; may surface years later |

## Choosing Retention Windows

Ask these questions for each table:

1. **Does anything query historical rows?** Check RPCs, views, dashboard queries
2. **Is aggregated data available elsewhere?** If trips table has rollups, raw GPS positions are redundant after 30d
3. **Could someone investigate a past event?** Keep enough for the investigation window (typically 90d)
4. **Any regulatory requirement?** FMCSA = 6mo, POPIA = "purpose-limited"
5. **Is the table dedup/cooldown only?** 7 days is sufficient; no one investigates cooldown history

## NOT NULL Column Gotcha

When stripping payload columns (e.g., setting `raw_event` to empty):
- Check `attnotnull` in `pg_attribute` BEFORE writing the function
- If NOT NULL: use `'{}'::jsonb` instead of `NULL`
- If nullable: `NULL` is preferred (smaller storage than `'{}'`)
