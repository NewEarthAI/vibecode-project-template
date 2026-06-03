/**
 * pocock-implicit-activation.ts
 * Detects work-class signals in user prompts and suggests relevant skills.
 * Ported from: .claude/hooks/pocock-implicit-activation.sh
 *
 * NOT auto-fire — discoverability boost so the agent considers the right skill
 * without requiring exact trigger phrases.
 *
 * Performance: <1ms per invocation. Pattern matching only.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

interface SignalPattern {
  patterns: RegExp[];
  skills: string[];
  hint: string;
}

const SIGNALS: SignalPattern[] = [
  {
    patterns: [/why.*broken/i, /what.*wrong/i, /debug.*this/i, /fix.*bug/i, /not.*working/i],
    skills: ["/reduce-to-first-principles", "/diagnose-bottleneck"],
    hint: "Consider /reduce-to-first-principles (strip framing) or /diagnose-bottleneck (find constraint)",
  },
  {
    patterns: [/stress.*test/i, /challenge.*this/i, /pressure.*test/i, /poke.*holes/i, /what.*missing/i],
    skills: ["/council", "/challenge", "/reduce-to-first-principles"],
    hint: "Consider /council (multi-perspective) or /challenge (contradiction detection)",
  },
  {
    patterns: [/refactor/i, /clean.*up/i, /restructure/i, /reorganize/i],
    skills: ["/code-council", "/refactor-claude-md"],
    hint: "Consider /code-council (multi-lens review) before and after refactor",
  },
  {
    patterns: [/should.*we/i, /decide/i, /which.*option/i, /trade.*off/i, /pros.*cons/i],
    skills: ["/decide-under-uncertainty", "/council", "/check-commensurability"],
    hint: "Consider /decide-under-uncertainty (diagnostic) or /council (deliberation)",
  },
  {
    patterns: [/ship.*this/i, /commit.*push/i, /deploy/i, /merge.*pr/i, /open.*pr/i],
    skills: ["/ship", "/code-council"],
    hint: "Consider /ship (autonomous code-ship) with pre-flight gates",
  },
  {
    patterns: [/research.*this/i, /deep.*dive/i, /investigate/i, /look.*into/i],
    skills: ["/agentresearch", "/competitive-intelligence"],
    hint: "Consider /agentresearch (coordinated research teams)",
  },
  {
    patterns: [/plan.*this/i, /how.*build/i, /architecture/i, /design.*this/i],
    skills: ["/plan", "/council --extended"],
    hint: "Consider /plan (implementation spec) then /council --extended (review)",
  },
  {
    patterns: [/where.*everything/i, /what.*running/i, /any.*collisions/i, /status/i],
    skills: ["/where", "/verify-shipped"],
    hint: "Consider /where (live git state) or /verify-shipped (fleet check)",
  },
  {
    patterns: [/daily.*plan/i, /what.*work.*on/i, /today/i, /priorities/i],
    skills: ["/daily-plan", "/daily-business-plan"],
    hint: "Consider /daily-plan (technical) or /daily-business-plan (BF)",
  },
  {
    patterns: [/map.*system/i, /feedback.*loop/i, /second.*order/i, /unintended/i, /dynamic/i],
    skills: ["/map-feedback-loops", "/diagnose-bottleneck"],
    hint: "Consider /map-feedback-loops (systems thinking) or /diagnose-bottleneck (ToC)",
  },
];

export default function (pi: ExtensionAPI) {
  pi.on("input", async (event, ctx) => {
    const input = event.text || "";
    if (input.length < 5 || input.length > 500) return; // skip very short or very long

    const matches: string[] = [];

    for (const signal of SIGNALS) {
      if (signal.patterns.some((p) => p.test(input))) {
        matches.push(signal.hint);
      }
    }

    if (matches.length > 0) {
      // Only inject if we found signals — advisory only
      ctx.ui.notify(
        `💡 Skill candidates: ${matches.join(" | ")}`,
        "info"
      );
    }
  });
}
