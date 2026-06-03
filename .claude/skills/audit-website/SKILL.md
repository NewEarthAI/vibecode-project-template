---
name: audit-website
description: |
  Holistic website health audit — 230+ rules across SEO, performance, security, accessibility,
  legal, E-E-A-T, and more using squirrelscan CLI. Health score 0-100.
  For UI/UX design review only, use design-review instead.
  For security-specific code review, use master-security-review instead.
version: 1.22
source: squirrelscan/skills
triggers:
  - "audit website"
  - "SEO check"
  - "website health"
  - "squirrelscan"
do-not-trigger:
  - "review this UI" (design only) → use design-review
  - "security review" (code) → use master-security-review
paths:
  - "clients/**"
---

# Website Audit (SquirrelScan)

Comprehensive website auditing via squirrelscan CLI. Emulates browser + search crawler.

## 230+ Rules in 21 Categories
SEO, Technical, Performance, Content, Security, Accessibility, Usability, Links, E-E-A-T, UX, Mobile, Crawlability, Schema, Legal, Social, URL Structure, Keywords, Content, Images, Local SEO, Video

## Reports Include
- Health score (0-100)
- Category breakdowns
- Specific issues with URLs
- Broken link detection
- Actionable recommendations

## Prerequisites
squirrel CLI installed and accessible in PATH

## Rule Documentation
https://docs.squirrelscan.com/rules/{rule_category}/{rule_id}
