/**
 * parallel-chat-conflict-canary.ts — session_start hook
 * Warns if the SAME file is being changed in two git worktrees at once.
 * Warn-only. Never blocks, never mutates, always exits clean.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { execSync } from "node:child_process";
import { existsSync } from "node:fs";
import { join } from "node:path";

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
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

      // Get all worktrees
      let worktrees: string[];
      try {
        const wtOutput = execSync("git worktree list --porcelain", {
          cwd: projectRoot,
          encoding: "utf-8",
          stdio: "pipe",
        });
        worktrees = wtOutput
          .split("\n")
          .filter((l) => l.startsWith("worktree "))
          .map((l) => l.replace("worktree ", "").trim());
      } catch {
        return; // no git or no worktrees
      }

      if (worktrees.length <= 1) return; // only one worktree — no conflict possible

      // Collect changed files per worktree
      const worktreeFiles: Map<string, Set<string>> = new Map();

      for (const wt of worktrees) {
        try {
          const status = execSync(
            "git -c core.quotePath=false status --porcelain",
            {
              cwd: wt,
              encoding: "utf-8",
              stdio: "pipe",
            }
          );
          const files = status
            .split("\n")
            .map((l) => l.replace(/^.../, "").trim())
            .filter((l) => l);
          if (files.length > 0) {
            worktreeFiles.set(wt, new Set(files));
          }
        } catch {
          // skip worktree
        }
      }

      // Find overlapping files
      const overlaps: string[] = [];
      const wtEntries = Array.from(worktreeFiles.entries());

      for (let i = 0; i < wtEntries.length; i++) {
        for (let j = i + 1; j < wtEntries.length; j++) {
          const [wt1, files1] = wtEntries[i];
          const [wt2, files2] = wtEntries[j];

          for (const file of files1) {
            if (files2.has(file)) {
              const wt1Name = wt1.split("/").pop() || wt1;
              const wt2Name = wt2.split("/").pop() || wt2;
              overlaps.push(
                `  ${file} — changed in both ${wt1Name} and ${wt2Name}`
              );
            }
          }
        }
      }

      if (overlaps.length > 0) {
        ctx.ui.notify(
          `⚠ Parallel session conflict detected — same file(s) changed in multiple worktrees:\n${overlaps.join("\n")}\n\n` +
          `Whichever session commits second will shadow the other. Consider coordinating or using single-folder feature-branch flow.`,
          "warning"
        );
      }
    } catch (err) {
      // Silently catch — never block session start
    }
  });
}
