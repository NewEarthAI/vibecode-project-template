# Research Before Locking Numerical Thresholds or Industry Rules

**Scoped to**: any session that will codify numerical thresholds in doctrine files (`.claude/rules/*.md`), constants in algorithms (outlier detection, confidence gates, scoring weights), or citations to industry rules as precedent.

**Purpose**: Prevent two recurring failure modes where "obvious" defaults ship with latent bugs or stale industry citations.

---

## The Two Failure Modes

### Failure 1 — Asymptotic statistical constants used at small N

Canonical statistical constants are almost always derived for N→∞. At small sample sizes, the true bias-corrected value differs materially. Shipping the asymptotic value at small N produces silent 15-35% error in the direction that matters (usually over-flagging / under-estimating spread).

**Illustrative example — MAD constants at small N**:

The MAD (Median Absolute Deviation) canonical multiplier `1.4826` is the asymptotic correction under normality. At small N, the correct finite-sample bias-correction (Park-Kim-Wang 2020, arXiv 2207.12005) is:

| N | Correct Cₙ | Bias if using 1.4826 |
|---|---|---|
| 3 | 2.2049 | −33% (over-flags clean samples) |
| 4 | 2.0167 | −26% |
| 5 | 1.8039 | −18% |
| 6 | 1.7638 | −16% |
| 7 | 1.6868 | −12% |
| 8 | 1.6718 | −11% |

Using the asymptotic value `3 × 1.4826 × MAD` at N=3-5 would over-flag ~33% of clean samples. This is one of many statistical constants with the same small-N-vs-asymptotic divergence — z-scores, F-statistics, chi-square critical values all have finite-sample corrections.

### Failure 2 — Zombie industry rules cited as current precedent

"Widely cited" industry rules may have been retired at the primary source but linger in informal guidance, blog posts, CE materials, and secondary sources. Citing them as "current industry standard" in doctrine produces amateur documentation and legally suspect rules.

**Illustrative example — real estate appraisal**:

The "10% net / 15% gross / 25% per-line" appraisal adjustment cap is cited everywhere as industry standard. It was **retired by Fannie Mae in December 2014 via Lender Letter LL-2015-02** — over a decade ago. The current Selling Guide (B4-1.3-09) explicitly states: "Fannie Mae does not have specific limitations or guidelines associated with net or gross adjustments."

Secondary sources still describe it as active. Only primary-source verification catches the retirement.

This pattern recurs in every regulated industry: USPAP appraisal standards, Basel capital requirements, HIPAA covered-entity definitions, SOX control frameworks — all have clauses that were amended or struck and still propagate in informal guidance.

---

## The Rule

Before committing any of the following to code or doctrine, run at least ONE targeted research pass:

- **Numerical constants in statistical code** (outlier multipliers, confidence thresholds, z-scores, percentile breakpoints)
- **Industry-rule citations in doctrine files** (regulatory thresholds, appraisal standards, underwriting norms, compliance framework clauses)
- **"Industry-standard" thresholds** in algorithms where the default would materially change behavior (auto-flag rates, refuse-to-opine gates, grade boundaries)

Pair every numeric threshold with:
1. The specific primary source (paper, regulator publication, standards body)
2. The sample-size domain or scope where the constant is valid
3. A citation with URL or section number

---

## How to research — /agent-research worker templates

When invoking `/agent-research` for numerical thresholds, include at least ONE worker dedicated to each applicable concern:

### Worker — small-N correctness (for statistical constants)

> Compare the robustness of method X at sample sizes N=3, 4, 5, 6, 7, 8. Cite finite-sample correction tables if they exist (Park-Kim-Wang 2020 for MAD; Grubbs' finite-N constraints; etc.). Flag if the asymptotic constant is biased at small N and report the correct bias-corrected values.

### Worker — primary-source current status (for industry rule citations)

> Verify the current status of [rule name] in [specific primary source: USPAP / Fannie Mae Selling Guide / Basel III / HIPAA / etc.]. Search for retirement announcements, amendment bulletins, or framework updates from [year] onwards. Cite the specific section/paragraph where the rule currently lives, OR the bulletin that retired it.

### Worker — regulated-industry cross-check

> For regulated industries (real estate, financial services, medical, legal, security compliance), cross-check whether the threshold is codified in primary regulation vs. convention/informal guidance. "Industry standard" in secondary sources without primary citation = zombie rule risk.

---

## When this rule does NOT apply

- Thresholds explicitly chosen as project-specific values with honest attribution — frame as invention, not industry-codified
- Thresholds inherited from a prior council session that has cited primary sources (re-use, don't re-research)
- Config values with no numerical semantics (feature flags, enum values, URL slugs)

---

## Enforcement

- Before a PR lands that codifies numerical thresholds in `.claude/rules/*.md` or statistical algorithms, the PR description must cite the research source (research audit file, council session, or linked primary source)
- Code-council reviewers: flag un-sourced thresholds as an IMPORTANT finding. Require citation OR explicit "project-invented, no industry precedent claimed" framing.
