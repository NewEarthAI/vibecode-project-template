/**
 * framing-audit-activation.ts — session_start + before_agent_start hook
 * Layer 2 of the Mandatory Framing-Audit Programme.
 *
 * session_start: injects framing-audit mandate banner into EVERY session.
 * before_agent_start: pattern-matches prompt for decision/comparison signals;
 *   injects one-line nudge toward matching framing-audit primitive.
 *
 * Never runs audit on trivia. Warn-only.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const MANDATE_BANNER = `## Framing Audit Mandate (active)
Before load-bearing, multi-phase work, a framing audit — confirming the work is the RIGHT question — is mandatory.
Primitives: /reduce-to-first-principles, /check-commensurability, /map-feedback-loops DECISION mode.
Not required for trivia, routine fixes, or simple reads.`;

const NUDGE_PATTERNS: Array<{ pattern: RegExp; primitive: string }> = [
  { pattern: /\b(decide|decision|choose|pick|select)\b/i, primitive: "/reduce-to-first-principles" },
  { pattern: /\b(compare|versus|vs\.?|alternative|trade-?off)\b/i, primitive: "/check-commensurability" },
  { pattern: /\b(feedback|loop|cycle|cause.*effect|unintended)\b/i, primitive: "/map-feedback-loops" },
  { pattern: /\b(should we|is it worth|do we need|pros and cons)\b/i, primitive: "/check-commensurability" },
];

export default function (pi: ExtensionAPI) {
  // Inject mandate banner on every session start
  pi.on("session_start", async (_event, ctx) => {
    // The banner is informational — loaded via before_agent_start
  });

  // Inject mandate + nudge on relevant prompts
  pi.on("before_agent_start", async (event, ctx) => {
    const prompt = event.prompt || "";

    // Skip trivial prompts (slash commands, very short)
    if (prompt.startsWith("/") || prompt.length < 20) {
      return;
    }

    let extraContext = MANDATE_BANNER;

    // Check for nudge patterns
    for (const { pattern, primitive } of NUDGE_PATTERNS) {
      if (pattern.test(prompt)) {
        extraContext += `\n\n**Framing nudge**: this prompt may benefit from ${primitive} before proceeding.`;
        break; // Only one nudge per prompt
      }
    }

    return {
      systemPrompt: event.systemPrompt + "\n\n" + extraContext,
    };
  });
}
