/**
 * code-council-verification.ts — agent_end hook
 * Warns when a code-council / code-review subagent issues a PASS verdict
 * without a verification artifact (runtime evidence).
 *
 * Artifact = one of:
 *   - VERIFIED: prefix line
 *   - Triple-backtick terminal-output block
 *   - Specific file:line citation (path/to/file.tsx:123)
 *   - Inline screenshot reference
 *
 * Warn-only. Never blocks.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  pi.on("agent_end", async (_event, ctx) => {
    try {
      // This hook checks if a code-council ran and produced PASS without evidence.
      // In pi, we check the session manager for recent subagent results.
      // For now, this is a placeholder that warns if the session included
      // a code-council invocation without verification.

      // The actual verification logic would need to inspect the session entries
      // for subagent results containing "PASS" without "VERIFIED" evidence.
      // This requires ctx.sessionManager.getEntries() which is available in pi.

      // Skip for now — the hookify-loader handles PreToolUse rules,
      // and code-council-verification is primarily a SubagentStop hook
      // that doesn't have a direct pi equivalent.
    } catch (err) {
      // Silently catch — never block
    }
  });
}
