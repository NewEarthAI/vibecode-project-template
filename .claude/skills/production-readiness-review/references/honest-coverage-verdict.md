# Honest-Coverage Verdict — the anti-theatre core

This is the rule that makes the prod-readiness gate worth trusting instead of decorative. It **cites,
does not duplicate**, the honest-degradation doctrine in `.claude/rules/system-awareness-mandate.md`
(the topology-align R0–R7 matrix) and `.claude/skills/system-awareness-gate/`. The principle there:
*honest-partial-coverage-correctly-reported IS the complete behaviour, not a degraded one.* A check
that reports "ready" over coverage it never actually had has failed in the exact `522`-class way this
skill exists to catch — a green light over a dead site.

## The three states

The verdict folds **three independent dimensions** — mapping completeness (from
`map-diff-to-surfaces.sh`), the browser-drive result, and the DB-storm check:

| State | Licensed ONLY when | Meaning |
|---|---|---|
| **GREEN / READY** | every changed file is MAPPED or EXEMPT (zero UNMAPPED) **AND** every mapped journey driven clean (all four universal smoke assertions held) **AND** DB-storm signature clear | The deployed change rendered + behaved for a real logged-in user across every surface it touched. Safe. |
| **AMBER / PARTIAL** | driven journeys were clean **BUT** coverage is incomplete: ≥1 UNMAPPED file, OR topology unavailable→registry fallback used, OR a journey was UNREACHABLE (auth/route/no-data) | What was checked is clean; what could NOT be checked is named explicitly. NOT a pass — a stated gap the operator decides on. |
| **RED / REGRESSION** | ANY driven journey failed a universal smoke assertion (console error / non-2xx incl `522` / blank / ErrorBoundary) **OR** the DB-storm signature is present | A real user would hit a broken surface. Blocks confidence; names the exact surface + signal. |

## The one hard rule

**GREEN is licensed by exactly one combination.** Every other combination is AMBER or RED. Specifically:

- **Never GREEN with any UNMAPPED file.** A changed file with no mapped surface means the browser
  smoke could not have covered it — reporting GREEN would launder absence into a pass. → AMBER, naming
  the file(s).
- **Never GREEN on a registry-only mapping while claiming topology grounding.** Today topology is
  absent, so every run is registry-mapped. The verdict states `mapping_source=registry` plainly; it
  does NOT claim topology-grade confidence it doesn't have. (Registry-complete coverage can still be
  GREEN — the honesty is in *labelling the source*, not in withholding the pass.)
- **Never GREEN on an UNREACHABLE journey.** A surface that couldn't be driven (login failed, no
  public id) is a coverage hole → AMBER, not an assumed pass.
- **RED dominates.** Any single regression signal makes the whole verdict RED regardless of coverage.

## Output shape (what the skill prints)

```
PROD-READINESS VERDICT: <GREEN | AMBER | RED>   (target: <url>, diff: <range>)

Coverage:   mapped=<n> exempt=<n> unmapped=<n>  mapping_source=registry
Journeys driven: <slug> ✓ | <slug> ✗ (<signal>) | <slug> ⊘ UNREACHABLE
DB-storm:   <clear | DETECTED: 53300/too-many-clients/statement-timeout flood in last <window>>

WHY <state>:
  - <the specific reason(s): which file is unmapped, which surface 522'd, which journey unreachable>

PUNCH-LIST (surface only — never auto-acted):
  - <concrete next action per gap/regression>
```

## What the skill must NOT do

- Must NOT mutate production, auto-fix, redeploy, or admin-merge (Confident Mode HARD STOP). It
  **surfaces** the verdict; the operator acts.
- Must NOT round AMBER up to GREEN to "look done". An honest AMBER that names the gap is a successful
  run; a GREEN over a gap is a failed one.
- Must NOT fabricate test data in production to make a journey reachable (no forced public report, no
  forced deal).

## Composition note

This verdict is the post-deploy sibling of the plan-time `/topology align` verdict. Same honest-
degradation spine, different moment: `/topology align` asks "does the PLAN fit the system?" before a
build; this asks "did the DEPLOY actually work for a user?" after it. Neither launders a gap into a
green light.
