# The Topology / Intent-Gap System — Start-to-Finish Overview

> **Audience**: any project that has pulled this system from the template. This is the conceptual
> front-door — read it once and you understand what the whole thing is, why it exists, what each
> piece does, and how they fit. It points only to files that travel with the template (skills,
> doctrines, the `/topology` command) — never to the originating workshop's private history.

---

## 1. What this system is (in one paragraph)

It is a **machine-readable map of a software system's real structure** — every table, view, function,
workflow, code module, edge function, and config, plus the dependencies between them — built
*automatically from the source itself*, kept honest about its own coverage, and able to detect when the
live system has **drifted** from what was intended. It exists so that planning and building happen
against *what the system actually is*, not a stale mental model. The guiding principle throughout:
**never show a confident "all good" that isn't real** — partial or stale coverage is always reported as
partial or stale, never laundered into a green light.

## 2. The three parts of the mechanism (the "intent-actual-gap" idea)

A system's behaviour can be checked along three separable dimensions. The design keeps them **separate**
(proven, not assumed — each has its own data shape with low overlap):

| Part | Question it answers | Status |
|------|---------------------|--------|
| **Topology-from-source** | What does the system *actually* look like, read from the source? | BUILT |
| **Reconciliation** | Where has the live system *drifted* from its saved map? | BUILT |
| **Intent-capture** | What was the system *intended* to be? | DOCTRINE ONLY — not yet built (named future work) |

The "why" behind each is written up as a doctrine: `docs/operational-doctrine/04_intent-capture.md`,
`05_topology-from-source.md`, `06_conservation-law-verification.md`. Two of three parts ship today; the
intent-capture *mechanism* is honestly deferred — **the system never fabricates an intent record to fill
the gap.**

## 3. How the map is built — the substrate + the emitters

- **The substrate** (`topology-substrate` skill) is the storage: one **platform-neutral shape** — a set
  of `nodes` and `edges` (plus parent/child maps). Everything becomes the same kind of "box + line",
  regardless of which platform it came from. This is the contract that makes the system extensible.
- **The emitters** are the scanners that *fill* the substrate, each reading one source and writing the
  shared shape:
  - `code-emitter` — TypeScript/frontend modules + their cross-system calls (Supabase, fetch, etc.)
  - `supabase-live-emitter` — a live Supabase project (tables/views/functions/RLS)
  - `n8n-cloud-emitter` — live n8n cloud workflows
  - `repo-config-emitter` — in-repo n8n JSON / Vercel / package config
  - `external-api-graph-emitter` — external HTTP/`fetch` calls → resolved or blind-spot edges
- **Adding a new platform = writing a new emitter against the same contract.** The substrate does not
  change; the system is *system-agnostic by construction*.

## 4. Keeping the map honest — the health check

`topology-health-check` (run via `/topology health`) produces a coverage + freshness report. Crucially it
distinguishes four states per source — **covered**, **absent**, **degenerate**, **declared-missing** — and
flags anomalies (an emitter that owns nodes but shows no coverage, future-dated timestamps, etc.). It never
reports "all clear" over a source that simply hasn't run. A staleness gate guards against an aged map being
trusted.

## 5. Detecting drift — reconciliation

`topology-reconcile` (run via `/topology reconcile`) compares the saved map against the live system and
surfaces where they have drifted apart — **ranked by impact, each with a named next step** (revert /
reconcile / approve-as-intentional / escalate). Every verdict is **re-derived from the map** (a guard
against faked results), and the read is strictly **read-only** — it never mutates the system it inspects.
It ships the drift classes that need no intent record; the class that needs intent-capture is deferred.

## 6. Seeing the map — the visual layer

The map is a graph by construction, so it renders directly. `topology-visual-emitter` turns the substrate
+ the drift verdicts into two render-ready files (a structure graph + a drift overlay); the included viewer
app (`topology-viewer/`) draws them — cross-system links coloured by type, **blind spots in amber** (an
unknown/unresolved connection is *never* shown green), and drift lit up *on the map* rather than read from
a text report. The two render files are the value; any surface can render them.

## 7. Planning against the map — the System-Awareness Alignment Gate

`system-awareness-gate` (run via `/topology align`, auto-triggered by its hook on plan-class work) makes a
planning session **consult the map before a plan locks**. It asks "does this plan fit the *real* system?"
and reports honestly: **only a fresh map + an in-sync reconcile licenses the word "aligned"** — every other
state (no map / stale / partial / corrupt / drift) surfaces its specific coverage gap. Advisory, never
blocks. It is the symmetric twin of the framing-audit gate (which asks "is this the *right question*?").

## 8. The one rule that governs everything

**Honest degradation.** Across every piece — health, reconcile, visual, the alignment gate — a partial,
stale, absent, or uncertain result is reported *as such*, never upgraded to a false green. A blind spot is
amber; an unrun source is "not yet run", not "all clear"; an aged map cannot license "aligned". This is the
system's whole reason to be trusted.

## 9. How to drive it

One command, `/topology`, with sub-commands: `status` (default overview), `health`, `reconcile`, `visual`,
`align`, `validate`, `read`, and `init <entity>` (the one mutating sub-command that builds a map from
scratch). The alignment gate's `/topology align` is auto-run by its hook — you never type it.

## 10. Extending it to a new platform (the system-agnostic path)

To map a platform the emitters don't cover yet (Slack, Salesforce, Stripe, Telegram, …): write one new
emitter that reads that platform and writes the existing node/edge shape — or compose an existing connector
as its back-end. If the platform's structure fits the existing node *kinds* and edge *types*, it is a small
add; if it genuinely needs a new kind, that is the signal a deeper extension is warranted. Either way the
honest-degradation rule holds: a platform you haven't mapped is shown as uncovered, never as a green map.

---

*This overview is intentionally conceptual and self-contained. For the exact contract of the shared shape,
see `topology-substrate/references/canonical-shape.md`; for the "why" of each part, the three doctrines in
`docs/operational-doctrine/`; for each component's specifics, its own `SKILL.md`.*
