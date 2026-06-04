/**
 * newvibe-precompact.ts — session_before_compact hook
 * NewVibe context-budget handoff (Gate A fix, 2026-05-17).
 *
 * Fires when harness signals context is full. Runs post-handoff-writer.sh
 * to write DRAFT continuation floor, then dispatches rich MASTER continuation
 * via autovibe library (nv_autofire).
 *
 * Non-blocking — always exits successfully.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { execSync } from "node:child_process";
import { existsSync } from "node:fs";
import { join } from "node:path";

export default function (pi: ExtensionAPI) {
  pi.on("session_before_compact", async (_event, ctx) => {
    try {
      const cwd = ctx.cwd || process.cwd();

      // Find project root
      let projectRoot = cwd;
      for (let i = 0; i < 20; i++) {
        if (existsSync(join(projectRoot, ".git"))) break;
        const parent = require("node:path").dirname(projectRoot);
        if (parent === projectRoot) break;
        projectRoot = parent;
      }

      const autovibeSkillDir = join(projectRoot, ".pi", "skills", "autovibe");
      const libPath = join(autovibeSkillDir, "scripts", "newvibe-dispatch-lib.sh");
      const handoffWriterPath = join(autovibeSkillDir, "scripts", "post-handoff-writer.sh");

      if (!existsSync(autovibeSkillDir)) return;

      // Step 1: best-effort DRAFT continuation floor
      if (existsSync(handoffWriterPath)) {
        try {
          execSync(`bash "${handoffWriterPath}" 0 clean`, {
            cwd: projectRoot,
            stdio: "pipe",
            timeout: 5000,
          });
        } catch {
          // Ignore — non-blocking
        }
      }

      // Step 2: dispatch rich MASTER continuation if one exists
      if (!existsSync(libPath)) return;

      let canonical: string;
      try {
        const findCmd = `source "${libPath}" || exit 0; NEWVIBE_ROOT_OVERRIDE="${projectRoot}"; nv_find_latest_continuation 2>/dev/null`;
        canonical = execSync(`bash -c '${findCmd.replace(/'/g, "'\\''")}'`, {
          cwd: projectRoot,
          encoding: "utf-8",
          stdio: "pipe",
          timeout: 3000,
        }).trim();
      } catch {
        return;
      }

      if (!canonical) return;

      try {
        const dispatchCmd = `source "${libPath}" || exit 0; NEWVIBE_ROOT_OVERRIDE="${projectRoot}"; nv_autofire "${canonical}" "precompact" || true`;
        execSync(`bash -c '${dispatchCmd.replace(/'/g, "'\\''")}'`, {
          cwd: projectRoot,
          stdio: "pipe",
          timeout: 5000,
        });
      } catch {
        // Ignore — non-blocking
      }
    } catch (err) {
      // Silently catch all errors — never block compaction
    }
  });
}
