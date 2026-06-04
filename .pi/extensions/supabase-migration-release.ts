/**
 * supabase-migration-release.ts — tool_result hook (Supabase)
 * Releases migration lock after apply_migration/execute_sql completes.
 * Always exits clean — never blocks.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { rmSync, readFileSync, existsSync } from "node:fs";
import { join } from "node:path";

export default function (pi: ExtensionAPI) {
  pi.on("tool_result", async (event, ctx) => {
    try {
      const toolName = event.toolName;

      // Only fire on Supabase mutation tools
      if (
        !toolName.includes("supabase") ||
        (!toolName.includes("execute_sql") &&
          !toolName.includes("apply_migration"))
      ) {
        return;
      }

      const projectRoot = ctx.cwd || process.cwd();
      const lockDir = join(projectRoot, ".claude", ".supabase-migration-lock");
      const metadataFile = join(lockDir, "metadata.json");

      if (!existsSync(lockDir)) return;

      // Check if this session owns the lock
      const sessionId = process.env.CLAUDE_SESSION_ID || `pi-pid-${process.pid}`;
      if (existsSync(metadataFile)) {
        try {
          const metadata = JSON.parse(readFileSync(metadataFile, "utf-8"));
          if (metadata.session_id !== sessionId) {
            return; // Not our lock — don't release
          }
        } catch {
          // Can't read metadata — skip
          return;
        }
      }

      // Release lock
      rmSync(metadataFile, { force: true });
      try {
        rmSync(lockDir, { recursive: true, force: true });
      } catch {
        // ignore
      }
    } catch (err) {
      // Silently catch — never block
    }
  });
}
