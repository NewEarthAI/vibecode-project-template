# OWASP Standards — LLM Top 10 (2025) + Agentic Deltas

> Reference for `newearth-security`. Maps the review categories (`security-categories.md`) onto the
> OWASP standard most relevant to NewEarth's LLM + agentic stack, and records the 2025 deltas.
> **Source pattern**: `agamm/claude-code-owasp` (ABSORB-PATTERN, 2026-05-22 council).

## Next Review

**2026-08-22** (90-day cadence per Amendment 16).

> **Primary-source caveat** (`.claude/rules/research-before-threshold-lock.md`): OWASP lists are revised
> on their own cadence and "widely-cited" numbering goes stale. At every review, re-verify this file's
> numbering and the "2025 delta" claims against the **primary OWASP publication** (owasp.org), not against
> blog summaries. The numbering below reflects the OWASP Top 10 for LLM Applications **2025** edition as
> understood at authoring (2026-05-22); treat any item as advisory until reconfirmed at the primary source.

---

## OWASP Top 10 for LLM Applications — 2025

The agentic-stack analogue of the classic web Top 10. This is the right lens for NewEarth because the
threat surface is the LLM pipeline, not a traditional web app.

| ID | Name | NewEarth relevance | Maps to category (`security-categories.md`) |
|----|------|--------------------|---------------------------------------------|
| **LLM01** | Prompt Injection | KI ingestion of external content; inbound comms | 10 — see `prompt-injection-defence.md` |
| **LLM02** | Sensitive Information Disclosure | secrets in prompt context, PII in model logs | 3 |
| **LLM03** | **Supply Chain** | model providers, npm deps in n8n/edge fns, third-party MCP servers | 9 — see `dependency-health.md` |
| **LLM04** | Data and Model Poisoning | poisoned training/RAG corpus (KI knowledge_items) | 7 |
| **LLM05** | Improper Output Handling | LLM output interpolated into SQL/HTTP/DOM without validation | 1 / 5 / 10 |
| **LLM06** | Excessive Agency | edge function / model given more authority than the task needs | 10 — see `prompt-injection-defence.md` |
| **LLM07** | System Prompt Leakage | system prompt reveals secrets or exploitable structure | 3 |
| **LLM08** | Vector and Embedding Weaknesses | RAG retrieval poisoning, embedding inversion (Neo4j/Graphiti, KI) | 7 |
| **LLM09** | Misinformation | model fabricates a confident wrong answer downstream consumers trust | (process control, not a code finding) |
| **LLM10** | Unbounded Consumption | runaway token/compute/cost (cost-tracking pillar) | 8 |

---

## 2025 deltas (vs the prior LLM Top 10 edition)

These are the changes a reviewer should be aware of so the taxonomy stays current:

- **Supply Chain (LLM03) elevated.** Third-party model providers, package dependencies, and MCP servers
  are now first-class supply-chain risk — not a footnote. NewEarth's growing MCP fleet + npm-in-n8n make
  this material. Cross-reference `dependency-health.md`.
- **Improper Output Handling (LLM05) sharpened ("mishandling").** Explicitly: treating model output as
  trusted when it feeds a sink. This is the same foundation as `prompt-injection-defence.md` — the model
  is a conduit; the downstream sink is where the damage happens.
- **System Prompt Leakage (LLM07) added** as its own item — previously folded under information disclosure.
- **Vector and Embedding Weaknesses (LLM08) added** — directly relevant as NewEarth invests in RAG +
  temporal knowledge graphs (Neo4j/Graphiti for KI).
- **Unbounded Consumption (LLM10)** broadened from "model denial of service" to include cost/quota
  exhaustion — relevant to the LLM cost-tracking work.

> The continuation that scoped this file abbreviated these as "A03 supply chain new" and
> "A10 mishandling new". Those map to **LLM03 Supply Chain** and **LLM05 Improper Output Handling**
> respectively in the 2025 LLM list. The conductor's Tier 2 table rows are labelled with the LLM IDs to
> avoid collision with the *web* OWASP Top 10 (whose A03/A10 are Injection/SSRF).

---

## OWASP Agentic Security Initiative (ASI) — watch, not yet adopted

OWASP's Agentic Security Initiative publishes an agentic-AI threats-and-mitigations catalogue (memory
poisoning, tool misuse, privilege compromise, cascading multi-agent failures). It is **not yet folded
into this skill's operational checklist** — it is on the ROADMAP NEXT watch list (council Amendment 12,
post-V1.2). When adopted, it gets its own reference file rather than being crammed here.

At next review, decide: has ASI stabilised enough to operationalise? If yes, author `agentic-threats.md`.

---

## How this composes

- This file is the standards-mapping layer over `security-categories.md`.
- LLM01/LLM05/LLM06 route to `prompt-injection-defence.md`.
- LLM03 routes to `dependency-health.md`.
- The conductor `SKILL.md` Tier 2 table carries the LLM03 + LLM05 rows added in V1.1.
- `stride-dread.md` is the complementary *method* (how to threat-model); this file is the *taxonomy*
  (what categories exist).
