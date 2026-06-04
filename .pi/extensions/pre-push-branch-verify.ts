/**
 * pre-push-branch-verify.ts — tool_call hook (Bash)
 * Warns when `git push origin <branch>` targets a different branch than HEAD.
 * Catches silent branch-switch failure mode where a parallel session swaps
 * the worktree branch out from under you.
 *
 * EFFICIENCY: Fast-path substring check for "git push" in command (~2ms bail).
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { execSync } from "node:child_process";

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event, ctx) => {
    try {
      if (event.toolName !== "bash") return;

      const command = (event.toolCall.input as any)?.command;
      if (!command) return;

      // FAST PATH: bail if not a git push
      if (!command.includes("git push")) return;

      // Extract target branch from push command
      const pushMatch = command.match(
        /git\s+push\s+(?:origin\s+)?(\S+)(?:\s+(\S+))?/
      );
      if (!pushMatch) return;

      // No-arg push (no branch specified) — safe
      const targetBranch = pushMatch[2] || pushMatch[1];
      if (
        !targetBranch ||
        targetBranch === "origin" ||
        targetBranch.startsWith("-")
      ) {
        return;
      }

      // Get current HEAD branch
      let currentBranch: string;
      try {
        currentBranch = execSync("git rev-parse --abbrev-ref HEAD", {
          encoding: "utf-8",
          stdio: "pipe",
        }).trim();
      } catch {
        return; // no git
      }

      // Check for mismatch
      if (
        targetBranch !== currentBranch &&
        targetBranch !== "HEAD"
      ) {
        ctx.ui.notify(
          `⚠ Branch mismatch: you're on '${currentBranch}' but pushing to '${targetBranch}'. ` +
          `If a parallel session switched branches, this could push to the wrong branch. ` +
          `Verify: git branch --show-current`,
          "warning"
        );
      }
    } catch (err) {
      // Silently catch — never block
    }
  });
}
