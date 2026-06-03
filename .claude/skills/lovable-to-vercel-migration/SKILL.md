---
name: lovable-to-vercel-migration
description: |
  Complete Lovable to Vercel production migration with zero-downtime DNS cutover.
  Use when migrating a Lovable-hosted SPA (React/Vite/Supabase) to Vercel. Covers
  pre-flight audit (env vars, CORS, Lovable-specific code, CI/CD gaps), production
  deploy workflow creation, Vercel env var setup, Supabase auth redirect updates,
  DNS cutover sequence with MX record protection, and post-cutover cleanup.
  DNS-provider-agnostic (GoDaddy, Namecheap, Cloudflare, etc.) with handoff
  protocol for domains managed by third parties. Preserves the newearth-ui-design
  system during migration (design tokens, component recipes, audit scripts) and
  provides post-migration design audit verification.
  Battle-tested on BuyBox-AI (April 2026). Handles dual-deploy race conditions,
  Vercel token scoping gotchas, and encrypted env var corruption.
version: 2.1
classification: encoded-preference
created: 2026-04-06
updated: 2026-04-10
validated_on:
  - BuyBox-AI (React 18 + Vite + Supabase, 45 edge functions, GoDaddy DNS, April 2026)
  - Nirvana Freight (planned — third-party DNS provider)
parameters:
  - name: project_name
    type: string
  - name: supabase_project_ref
    type: string
  - name: production_domain
    type: string
  - name: vercel_team_id
    type: string
  - name: vercel_project_id
    type: string
  - name: github_org
    type: string
  - name: github_repo
    type: string
  - name: dns_provider
    type: string
    description: "DNS registrar (GoDaddy, Namecheap, Cloudflare, etc.)"
  - name: dns_managed_by
    type: string
    description: "Who controls DNS? 'self' or contact name/email of external person"
  - name: email_service
    type: string
    description: "Email service using MX records (Resend, Google Workspace, none)"
  - name: lovable_ip
    type: string
    default: "185.158.133.1"
    description: "Lovable's A record IP (for rollback reference)"
---

# Lovable to Vercel Production Migration

> Battle-tested protocol from BuyBox-AI migration (April 2026). Every gotcha listed here caused a real failure.

---

## Architecture Context

Lovable SPAs are pure static file deployments. Supabase handles ALL backend. The migration is a CDN swap, not an app migration.

```
Browser -> CDN (Lovable or Vercel) -> Static JS/CSS/HTML
                                          |
                                    Supabase (auth, DB, edge functions, realtime)
```

---

## Phase 1: Pre-Flight Audit (1-2 hours)

### 1.1 Env Var Inventory

Spawn research agent to find every env var reference:

| Category | Pattern | Where to set | Affected? |
|----------|---------|-------------|-----------|
| Build-time frontend | `import.meta.env.VITE_*` | Vercel + GitHub Secrets | YES |
| Build-time CI | `process.env.*` | GitHub Secrets | YES |
| Edge function secrets | `Deno.env.get()` | Supabase secret store | NO |

### 1.2 CORS Audit

For each `supabase/functions/*/index.ts`:
- Uses shared CORS utility? -> GOOD
- Hardcodes `Access-Control-Allow-Origin` to apex domain? -> SAFE if production = apex
- Hardcodes to subdomain? -> MUST UPDATE
- Wildcard `*`? -> Security risk but won't break

**CRITICAL DECISION:** Use apex `{{production_domain}}` (not `www.`) to avoid redeploying edge functions.

### 1.3 Lovable-Specific Code

| Search for | Assessment |
|-----------|------------|
| `lovable-tagger` in `vite.config.ts` | SAFE (dev-only guard) |
| `lovable-tagger` in `package.json` | CLEANUP post-migration |
| `lovable.dev` URLs in `index.html` | CLEANUP (OG images) |
| Lovable URLs in docs | CLEANUP |

### 1.3a Design System Preservation Check (newearth-ui-design)

Before starting migration, verify the design system files are present and DO NOT TOUCH them during any migration phase. These files are pure source code and have zero deployment coupling — they belong to the source-code layer, not the hosting layer.

| File / Path | Action |
|-------------|--------|
| `src/index.css` (or wherever tokens.css is imported) | PRESERVE — contains NewEarth CSS variables |
| `src/styles/tokens.css` (if present) | PRESERVE — design tokens source of truth |
| `tailwind.config.ts` `darkMode: 'class'` setting | PRESERVE — dark mode toggle depends on this |
| `src/components/ui/*.tsx` | PRESERVE — shadcn-ui primitives with NewEarth theming |
| `.claude/skills/newearth-ui-design/` | PRESERVE — the design system skill itself |

**Rule**: this migration is a CDN swap, not a redesign. No visual changes during migration. If you find yourself editing a component's className during Phase 1-3, stop — that's scope creep.

---

### 1.4 CI/CD Gap Analysis

- Does `deploy-production.yml` exist with `--prod` flag?
- Does the `staging` branch actually exist?
- Are all env vars passed to the build step?

### 1.5 Vercel Token Verification

```bash
# Verify token sees the correct team
curl -s -H "Authorization: Bearer $TOKEN" "https://api.vercel.com/v2/teams"

# Verify token can access the project
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://api.vercel.com/v9/projects/$PROJECT_ID?teamId=$TEAM_ID"
```

| Prefix | Type | Use for CI/CD? |
|--------|------|----------------|
| `vcp_` | Deploy Token | YES |
| `vck_` | Client Key | NO (read-only) |

---

## Phase 2: Infrastructure Setup (30-60 min)

### 2.1 Production Deploy Workflow

Create `.github/workflows/deploy-production.yml`:
- Trigger on `push` to `main` + `workflow_dispatch`
- `npm ci` -> `npm run build` with all `VITE_*` env vars from secrets
- `amondnet/vercel-action@v25` with `vercel-args: '--prod'`
- **`working-directory: ./`** (NOT `./dist` -- causes project link failure)

### 2.2 Set GitHub Secrets

```bash
gh secret set VERCEL_TOKEN --body "$TOKEN"
gh secret set VERCEL_ORG_ID --body "$TEAM_ID"
gh secret set VERCEL_PROJECT_ID --body "$PROJECT_ID"
gh secret set VITE_SUPABASE_URL --body "$URL"
gh secret set VITE_SUPABASE_PUBLISHABLE_KEY --body "$KEY"
# ... all remaining VITE_* vars
```

### 2.3 Set Vercel Project Env Vars

```bash
curl -X POST "https://api.vercel.com/v10/projects/$PROJECT/env?teamId=$TEAM" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"key":"VAR_NAME","value":"VAR_VALUE","target":["production","preview","development"],"type":"plain"}'
```

Note: `"type":"sensitive"` vars cannot target `development` -- use `["production","preview"]`.

### 2.4 Supabase Auth Redirect URLs

Add to Supabase Dashboard -> Authentication -> URL Configuration:
- `https://{{production_domain}}/**`
- `https://{{project_name}}.vercel.app/**`
- Keep existing Lovable URL for 48h overlap

### 2.5 Test Deploy

```bash
gh workflow run deploy-production.yml --ref main
# Wait ~3 min
gh run list --workflow=deploy-production.yml --limit 1
```

Verify auth works on Vercel preview URL before DNS cutover.

---

## Phase 2.5: Add Custom Domain to Vercel (BEFORE DNS cutover)

Register the domain with Vercel so it's ready to serve when DNS resolves:

```bash
# Add apex domain
curl -X POST "https://api.vercel.com/v10/projects/$PROJECT_ID/domains?teamId=$TEAM_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "{{production_domain}}"}'

# Add www redirect to apex (308 permanent)
curl -X POST "https://api.vercel.com/v10/projects/$PROJECT_ID/domains?teamId=$TEAM_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "www.{{production_domain}}", "redirect": "{{production_domain}}", "redirectStatusCode": 308}'
```

Verify both return `"verified": true`. If not, Vercel needs the DNS records updated first (chicken-and-egg — proceed to Phase 3).

```bash
# Check domain config
curl -s "https://api.vercel.com/v6/domains/{{production_domain}}/config?teamId=$TEAM_ID" \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
# Look for: "misconfigured": false
```

---

## Phase 3: DNS Cutover (15 min active + 30 min propagation)

### 3.0 DNS Provider Abstraction

This skill works with ANY DNS provider. The only operations needed:
1. Lower TTL on A/CNAME records
2. Change A record value (or CNAME if provider supports apex CNAME/ALIAS)
3. Verify MX records are untouched

| Provider | TTL Minimum | A Record Edit | Notes |
|----------|-------------|---------------|-------|
| GoDaddy | 1/2 Hour (1800s) | Web UI or API | No apex CNAME |
| Namecheap | 1 min (60s) | Web UI | No apex CNAME |
| Cloudflare | 1 min (60s) or Auto | Web UI or API | Supports CNAME flattening (preferred) |
| Route53 | 60s | AWS Console or API | Supports ALIAS records |
| Google Domains | 1 hour | Web UI | No apex CNAME |

### 3.0.1 Third-Party DNS Handoff Protocol

**If `dns_managed_by` is NOT 'self'**, you cannot edit DNS directly. Generate a handoff document:

```markdown
## DNS Change Request for {{production_domain}}

Hi {{dns_managed_by}},

We're migrating {{production_domain}} hosting to Vercel. Please make these DNS changes:

### Step 1: Lower TTL (do this 24h before Step 2)
- Change TTL on A record for `@` (root) to the lowest available (ideally 60s or 5 min)
- Change TTL on A record for `www` to the lowest available

### Step 2: Swap A Records (the actual cutover)
| Record | Name | OLD Value | NEW Value |
|--------|------|-----------|-----------|
| A | @ | {{lovable_ip}} | 76.76.21.21 |
| A | www | {{lovable_ip}} | 76.76.21.21 |

### DO NOT TOUCH these records:
| Record | Name | Value | Why |
|--------|------|-------|-----|
| MX | @ | (whatever exists) | Email delivery — changing breaks inbound email |
| TXT | @ | (whatever exists) | Domain verification — changing breaks email auth |
| NS | @ | (whatever exists) | Nameservers — changing breaks everything |

### After change
Let me know once done. I'll verify SSL and functionality within 30 minutes.

### If anything breaks
Revert both A records back to {{lovable_ip}}. The old hosting is still running.
```

Save this as `specs/dns-change-request-{{production_domain}}.md` and share with the DNS contact.

### Pre-Cutover (24h before)
- [ ] Lower DNS TTL to lowest available (60s ideal, 1/2 hour acceptable)
- [ ] Verify Vercel staging works (auth, data, edge functions)
- [ ] All env vars verified on Vercel
- [ ] Custom domain added to Vercel (Phase 2.5)

### Cutover Sequence (EXACT ORDER — battle-tested)

```
1. Add custom domain to Vercel (Phase 2.5 — if not already done)
   -> Must be registered BEFORE DNS points to Vercel

2. DNS: Change A records -> Vercel
   -> A record @ : 76.76.21.21
   -> A record www: 76.76.21.21
   -> DO NOT TOUCH MX, TXT, NS RECORDS
   -> DO NOT disconnect Lovable yet (safety net)

3. Verify DNS propagation
   -> dig {{production_domain}} A +short
   -> Should return 76.76.21.21

4. Verify HTTPS + SSL
   -> curl -sI https://{{production_domain}} | grep "server: Vercel"
   -> SSL auto-provisions via Let's Encrypt (1-5 min after DNS resolves)

5. Smoke test all critical paths (see Verification Checklist)

6. Monitor 24-48h with Lovable still connected as safety net

7. ONLY AFTER 48h stable: Disconnect Lovable GitHub webhook
```

**KEY DIFFERENCE from v1.0:** Do NOT disconnect Lovable before DNS cutover. Both hosts serve identical code. Lovable stays as a rollback target. Disconnect only after 48h of stable Vercel serving.

### Verified Timing (from BuyBox-AI cutover 2026-04-07)

| Step | Expected | Actual (BuyBox) |
|------|----------|-----------------|
| Add domain to Vercel | 30s | 30s (API call) |
| DNS propagation | Up to TTL | **Instant** (local), ~30 min (global) |
| SSL provisioning | 5-15 min | **< 1 min** (Vercel pre-provisions on domain add) |
| Smoke test | 5 min | 3 min (7 routes + Supabase + MX) |
| Total active work | 15 min | **~10 min** |
| Total wall clock | 45 min | **~15 min** (DNS propagated instantly) |

### MX Record Protection

MX and A/CNAME are independent DNS record types. Changing A/CNAME does NOT affect email. Rules:
- NEVER "clean up" DNS records during migration
- NEVER delete records you don't understand
- Verify after cutover: `dig MX {{production_domain}}`
- If email service exists (Resend, Google Workspace), verify: `dig TXT {{production_domain}}` (SPF/DKIM records intact)

### Rollback (instant, no code changes)

```bash
# 1. Revert DNS A records to Lovable
#    @ -> {{lovable_ip}}
#    www -> {{lovable_ip}}
# 2. Lovable is still connected and deploying — no action needed
# 3. Propagation: up to TTL (30 min if lowered)
# 4. Supabase auth URLs still include Lovable — no action needed
```

**Rollback is a single DNS edit.** No code, no config, no redeployment. This is why we don't disconnect Lovable until 48h stable.

---

## Phase 4: Post-Cutover Cleanup (48h after stable)

- [ ] Replace OG/Twitter image URLs in `index.html`
- [ ] Remove `lovable-tagger` from `package.json` + `vite.config.ts`
- [ ] Update docs (CLAUDE.md, README.md)
- [ ] Remove hardcoded Supabase fallback in `client.ts` (if exists)
- [ ] Remove Lovable URL from Supabase auth
- [ ] Cancel Lovable subscription

---

## Phase 5: Post-Migration Design Audit (newearth-ui-design)

Once Vercel has been serving stably for 48h and the migration is closed out, run the NewEarth UI design audit scripts to get a baseline of design debt in the migrated codebase. This is a READ-ONLY audit — it does not change any code. The output becomes a backlog for a future focused cleanup session, never an "urgent fix" list.

### Rationale

The migration phase intentionally does not touch component code. But the migration is the *cleanest possible moment* to take a fresh design-debt snapshot because:
1. The codebase is stable (no in-flight refactors muddying the signal)
2. You just proved you can deploy reliably (safe to follow up with visual changes later)
3. The Vercel environment may have different behavior for certain patterns (e.g., image optimization, edge function CORS) that the audit can surface

### Run The Three Audits

```bash
# From the project root, after migration is verified stable:
bash .claude/skills/newearth-ui-design/scripts/audit-forbidden-patterns.sh . 2>&1 | tee audit-forbidden-post-migration.txt
bash .claude/skills/newearth-ui-design/scripts/audit-colors.sh . 2>&1 | tee audit-colors-post-migration.txt
bash .claude/skills/newearth-ui-design/scripts/audit-hover-consistency.sh . 2>&1 | tee audit-hover-post-migration.txt
```

### Compare Against Pre-Migration Baseline

If a pre-migration baseline exists (e.g., `continuations/NEWEARTH-DESIGN-DEBT-BACKLOG-*.md`), diff the results:

- **Same count**: migration was clean, no new debt introduced ✓
- **Fewer violations**: migration fixed something incidentally (celebrate, update backlog)
- **More violations**: migration introduced regressions — investigate immediately before closing out

### Handoff To Cleanup Session

Do NOT attempt to fix audit findings as part of the migration. Save the output as:

```
continuations/DESIGN-DEBT-POST-VERCEL-MIGRATION-{{date}}.md
```

and hand off to a dedicated cleanup session that can work through items in small PRs. The migration session's job is done.

### Reference

See [.claude/skills/newearth-ui-design/SKILL.md](../newearth-ui-design/SKILL.md) for the design system itself. Key documents:
- `references/anti-vibe-coded.md` — what the audits are checking and why
- `references/color-discipline.md` — rationale for pastel / unsemantic color rejections
- `references/silver-signature.md` — the NewEarth hover curve and metallic accent system

---

## Known Gotchas

### 1. Wrong-Team Vercel Token
**Symptom:** "Project not found" or GitHub Action hangs at "Retrieving project..."
**Fix:** Create token scoped to correct team at vercel.com/account/tokens

### 2. Encrypted Env Var Corruption
**Symptom:** App loads, auth fails "Invalid API key" despite vars existing
**Cause:** Vars set with wrong-team token encrypt to garbage
**Fix:** Delete ALL vars via API, re-create with correct token

### 3. working-directory: ./dist
**Symptom:** "Could not retrieve Project Settings"
**Fix:** Use `working-directory: ./` (root)

### 4. Dual-Deploy Race Condition
**Symptom:** Brief broken site after git push (both hosts building simultaneously)
**Fix:** Leave both connected during cutover (no user impact — DNS determines which serves). Disconnect Lovable only after 48h stable on Vercel.

### 5. In-Flight Magic Links
**Symptom:** Users land on dead Lovable page after DNS cutover
**Fix:** Keep Lovable URL in Supabase auth for 48h

### 6. Realtime Origin Validation
**Symptom:** Data loads on refresh but no live updates
**Fix:** Add Vercel domain to Supabase auth URL config before cutover

### 7. Google Maps API Referrer Restrictions
**Symptom:** Maps/Street View 403 after migration
**Fix:** Update Google Cloud Console referrer whitelist (only if domain changes)

---

## Anti-Patterns

| Wrong | Right |
|-------|-------|
| Change DNS before testing on preview URL | Test on preview first |
| Modify MX records during cutover | Only touch A/CNAME |
| Use `vck_*` client key as deploy token | Use `vcp_*` deploy token |
| Set `working-directory: ./dist` | Use `working-directory: ./` |
| Couple refactors with migration | Migration = CDN swap only |
| Remove Lovable auth URLs before 48h | Keep for overlap |
| Set env vars with wrong-team token | Verify team access first |
| Use `www.` without updating CORS | Use apex or update all edge functions |
| Rotate secrets during migration | Change only hosting |
| Disconnect Lovable before DNS is verified | Keep Lovable as rollback for 48h |
| Skip adding domain to Vercel before DNS swap | Domain must be registered in Vercel first |
| Assume DNS propagation takes 24h | With low TTL, often instant locally, ~30 min globally |
| Edit tokens.css / component className during migration | Preserve design system — run audit in Phase 5 instead |
| Fix audit findings during migration | Save to backlog file; cleanup is a separate session |
| Delete `.claude/skills/newearth-ui-design/` thinking it's Lovable-specific | It's framework-agnostic — preserve across all hosts |

---

## Verification Checklist

### Automated Smoke Test (run immediately after DNS resolves)

```bash
# 1. Server identity
curl -sI https://{{production_domain}} | grep "server: Vercel"

# 2. All routes return 200
for route in / /auth /pricing; do
  echo "$route -> $(curl -sI "https://{{production_domain}}$route" -o /dev/null -w "%{http_code}")"
done

# 3. www redirect (expect 308)
curl -sI "https://www.{{production_domain}}" | grep -E "HTTP|location"

# 4. MX records untouched
dig {{production_domain}} MX +short

# 5. Supabase reachable (expect 401 = auth working)
curl -sI "https://{{supabase_project_ref}}.supabase.co/rest/v1/" \
  -H "apikey: $ANON_KEY" | grep "access-control-allow-origin"

# 6. SSL + HSTS
curl -sI "https://{{production_domain}}" | grep "strict-transport-security"
```

### Manual Verification

| Test | Expected |
|------|----------|
| Landing page loads | No console errors, React renders |
| Auth: protected route redirect | `/pipeline` -> `/auth` when logged out |
| Auth: sign in | Login succeeds, redirects correctly |
| App pages load with data | Supabase queries succeed |
| Edge function calls | No CORS errors in Network tab |
| Realtime subscriptions | Live updates without refresh |
| Mobile layout | Same as before (375px) |
| Error tracking | Events appear in Sentry/PostHog |
| Email intake (if applicable) | `dig MX` matches pre-migration + test email works |
