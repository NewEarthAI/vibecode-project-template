/**
 * auto-sync-artifacts.ts — agent_end hook
 * Auto-commits and pushes metadata/artifact files to origin.
 * Runs AFTER session-summarizer so session logs are included.
 *
 * ONLY syncs non-code artifact paths. Source code changes remain explicit.
 * Safe to run on every session end — no-ops if nothing changed.
 * Non-blocking — push failures are logged, never block session end.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { execSync } from "node:child_process";
import { existsSync } from "node:fs";

const ARTIFACT_PATHS = [
  ".claude/memory/",
  ".claude/sessions/",
  ".claude/plans/",
  ".claude/rules/",
  ".claude/hookify.",
  "continuations/",
  "specs/",
  "council/",
  "research-outputs/",
  "e2e-screenshots/",
  "docs/",
  "roadmaps/",
  "agency/orchestration/",
];

export default function (pi: ExtensionAPI) {
  pi.on("agent_end", async (_event, ctx) => {
    try {
      const cwd = ctx.cwd || process.cwd();

      // Find project root
      let projectRoot = cwd;
      for (let i = 0; i < 20; i++) {
        if (existsSync(require("node:path").join(projectRoot, ".git"))) break;
        const parent = require("node:path").dirname(projectRoot);
        if (parent === projectRoot) break;
        projectRoot = parent;
      }

      // Stage only artifact paths that have changes
      for (const path of ARTIFACT_PATHS) {
        if (existsSync(require("node:path").join(projectRoot, path))) {
          try {
            execSync(`git add "${path}"`, {
              cwd: projectRoot,
              stdio: "pipe",
            });
          } catch {
            // ignore
          }
        }
      }

      // Check if anything was staged
      try {
        execSync("git diff --cached --quiet", {
          cwd: projectRoot,
          stdio: "pipe",
        });
        return; // Nothing to commit — clean exit
      } catch {
        // diff --cached --quiet exits 1 if there are changes — proceed
      }

      // Count what we're committing
      const fileCount = execSync("git diff --cached --name-only | wc -l", {
        cwd: projectRoot,
        encoding: "utf-8",
        stdio: "pipe",
      }).trim();

      const timestamp = new Date()
        .toISOString()
        .replace("T", " ")
        .substring(0, 16);

      const fileList = execSync(
        "git diff --cached --name-only | head -5 | tr '\\n' ','",
        {
          cwd: projectRoot,
          encoding: "utf-8",
          stdio: "pipe",
        }
      ).replace(/,$/, "");

      const moreFiles =
        parseInt(fileCount, 10) > 5
          ? ` (+${parseInt(fileCount, 10) - 5} more)`
          : "";

      // Commit with descriptive message
      try {
        execSync(
          `git commit -m "auto: sync ${fileCount} session artifact(s) [${timestamp}]\\n\\nPaths: ${fileList}${moreFiles}" --quiet`,
          {
            cwd: projectRoot,
            stdio: "pipe",
          }
        );
      } catch {
        // commit failed (pre-commit hook?) — skip push
        return;
      }

      // Push to origin (best-effort, don't block session exit)
      let branch = "main";
      try {
        branch = execSync("git rev-parse --abbrev-ref HEAD", {
          cwd: projectRoot,
          encoding: "utf-8",
          stdio: "pipe",
        }).trim();
      } catch {
        // default to main
      }

      try {
        execSync(`git push origin "${branch}" --quiet`, {
          cwd: projectRoot,
          stdio: "pipe",
          timeout: 10000,
        });
      } catch {
        // push failed — commit saved locally
      }
    } catch (err) {
      // Silently catch — never block session end
    }
  });
}
