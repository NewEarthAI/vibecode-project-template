/**
 * newvibe-autofire-stop.ts — agent_end hook
 * NewVibe autofire — fires after every assistant turn.
 *
 * Dispatches ONLY when nv_detect_ship_completion confirms a genuinely clean
 * ship completed, a fresh master continuation exists, and that continuation
 * has not already been autofired.
 *
 * Default path is a fast, silent no-op.
 * Non-blocking — always exits successfully.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { execSync } from "node:child_process";
import { existsSync } from "node:fs";
import { join } from "node:path";

export default function (pi: ExtensionAPI) {
  pi.on("agent_end", async (_event, ctx) => {
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
      const libPath = join(
        autovibeSkillDir,
        "scripts",
        "newvibe-dispatch-lib.sh"
      );

      if (!existsSync(libPath)) return; // autovibe not available

      // Check if ship completed this turn
      let shipDetected: string;
      try {
        const detectCmd = `source "${libPath}" || exit 0; NEWVIBE_ROOT_OVERRIDE="${projectRoot}"; nv_detect_ship_completion 2>/dev/null`;
        shipDetected = execSync(`bash -c '${detectCmd.replace(/'/g, "'\\''")}'`, {
          cwd: projectRoot,
          encoding: "utf-8",
          stdio: "pipe",
          timeout: 3000,
        }).trim();
      } catch {
        return; // no ship detected
      }

      if (!shipDetected) return;

      // Find latest master continuation
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
        return; // no continuation found
      }

      if (!canonical) return;

      // Dispatch continuation
      try {
        const dispatchCmd = `source "${libPath}" || exit 0; NEWVIBE_ROOT_OVERRIDE="${projectRoot}"; nv_autofire "${canonical}" "stop" || true`;
        execSync(`bash -c '${dispatchCmd.replace(/'/g, "'\\''")}'`, {
          cwd: projectRoot,
          stdio: "pipe",
          timeout: 5000,
        });
      } catch {
        // Ignore dispatch errors — non-blocking
      }
    } catch (err) {
      // Silently catch — never block session end
    }
  });
}
