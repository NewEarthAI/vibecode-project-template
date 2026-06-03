---
name: plan-quality-gate
enabled: true
event: PreToolUse
tool_matcher: ExitPlanMode
action: addContext
---

# MANDATORY: Plan Quality Evaluation (Fires Before Compliance Gate)

**STOP. Before proceeding to the compliance checklist, perform this critical self-evaluation.**

This is NOT a checkbox exercise. This is a genuine re-examination of your plan's quality, elegance, and strategic value. Answer each question honestly — if any answer reveals a weakness, revise the plan BEFORE calling ExitPlanMode.

## 1. Outcome Excellence

- **Is this the SIMPLEST approach that achieves the goal?** Could you eliminate any files, steps, or abstractions without losing value?
- **Does every change earn its complexity?** Would a user seeing this diff think "elegant" or "over-engineered"?
- **Have you considered what NOT to build?** Sometimes the best plan removes scope rather than adds it.

## 2. User Experience & Flow

- **Walk through the user's actual journey** — from the moment they trigger this feature to the result. Is every step smooth, obvious, and delightful?
- **What happens when things go wrong?** Error states, edge cases, empty states — are they handled gracefully?
- **Does this feel like a connected system** or isolated patches? Features should cascade into each other.

## 3. Strategic Alignment

- **Does this move the product forward** or just fix a symptom? Are you solving the root cause?
- **What does this unlock next?** Good changes create leverage for future work.
- **Is this what the user ACTUALLY needs** or just what they literally asked for? Read between the lines.

## 4. Interoperability & Completeness

- **What breaks if this deploys halfway?** Identify the atomic unit of value — don't ship half-connected features.
- **Have you considered all consumers of the data/components you're changing?** Downstream effects?
- **Are existing patterns being reused** or are you creating new conventions unnecessarily?

## 5. The "Wow" Test

- **If someone reviewed this plan, would they think "that's clever" or "that's obvious"?** The best plans feel inevitable — so well-reasoned that no alternative seems better.
- **What's the ONE thing that would make this 10% better** with minimal extra effort? Do that thing.

## Decision

If ANY of the above reveals an improvement worth making:
1. Revise the plan file
2. Return to this gate

If the plan genuinely passes all five dimensions — proceed to the compliance gate (plan-mode-exit-gate).
