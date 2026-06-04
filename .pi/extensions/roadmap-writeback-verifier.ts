/**
 * roadmap-writeback-verifier.ts — agent_end hook
 * WARN-ONLY backstop for the Roadmap Write-Back phase.
 *
 * Triggers when ALL hold:
 *   (1) A roadmap-relevant surface changed this session
 *   (2) A completion-class signal exists (commit landed)
 *   (3) NEITHER ROADMAP.md NOR any project-specific roadmap was modified
 *
 * GENERIC — reads ROADMAP_PATHS from environment or uses sensible defaults.
 * Fail-open: ANY error → silent. NEVER blocks.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { execSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { join, dirname } from "node:path";

/**
 * Roadmap paths to check. Override via PI_ROADMAP_PATHS env var (comma-separated).
 * Default: ROADMAP.md at project root.
 */
function getRoadmapPaths(projectRoot: string): string[] {
  const envPaths = process.env.PI_ROADMAP_PATHS;
  if (envPaths) return envPaths.split(",").map((p) => p.trim());

  const defaults = ["ROADMAP.md"];

  // Auto-discover: scan for ROADMAP.md in subdirectories (depth 2)
  try {
    const dirs = ["agency", "docs", "roadmaps"];
    for (const dir of dirs) {
      const candidate = join(projectRoot, dir, "ROADMAP.md");
      if (existsSync(candidate)) {
        defaults.push(`${dir}/ROADMAP.md`);
      }
    }
  } catch {
    // skip
  }

  return defaults;
}

/**
 * Relevance patterns. Override via PI_RELEVANT_PATTERNS env var (comma-separated regexes).
 * Default: any file outside of .git, node_modules, dist.
 */
function getRelevantPatterns(): RegExp[] {
  const envPatterns = process.env.PI_RELEVANT_PATTERNS;
  if (envPatterns) {
    return envPatterns.split(",").map((p) => new RegExp(p.trim()));
  }

  // Default: any source file change (not .git, node_modules, dist, build)
  return [
    /^(?!node_modules|\.git|dist|build|\.next|\.cache)/,
  ];
}

export default function (pi: ExtensionAPI) {
  pi.on("agent_end", async (_event, ctx) => {
    try {
      const cwd = ctx.cwd || process.cwd();
      let projectRoot = cwd;
      for (let i = 0; i < 20; i++) {
        if (existsSync(join(projectRoot, ".git"))) break;
        const parent = dirname(projectRoot);
        if (parent === projectRoot) break;
        projectRoot = parent;
      }

      // Check if git repo
      try {
        execSync("git rev-parse --git-dir", {
          cwd: projectRoot,
          stdio: "pipe",
        });
      } catch {
        return; // not a git repo
      }

      const roadmapPaths = getRoadmapPaths(projectRoot);

      // Get changed files (working tree + unpushed commits)
      let allChanges: string[] = [];

      // Working tree changes
      try {
        const status = execSync(
          "git -c core.quotePath=false status --porcelain",
          {
            cwd: projectRoot,
            encoding: "utf-8",
            stdio: "pipe",
          }
        );
        const workingChanges = status
          .split("\n")
          .map((l) => l.replace(/^.../, "").replace(/^.* -> /, ""))
          .filter((l) => l.trim());
        allChanges.push(...workingChanges);
      } catch {
        // no git
      }

      // Unpushed commits
      let branchHasCommits = false;
      try {
        const branchFiles = execSync(
          "git log '@{u}..HEAD' --name-only --pretty=format:",
          {
            cwd: projectRoot,
            encoding: "utf-8",
            stdio: "pipe",
          }
        );
        if (branchFiles.trim()) {
          branchHasCommits = true;
          allChanges.push(
            ...branchFiles.split("\n").filter((l) => l.trim())
          );
        }
      } catch {
        // no upstream — try HEAD's own changes
        try {
          const headFiles = execSync(
            "git show HEAD --name-only --pretty=format:",
            {
              cwd: projectRoot,
              encoding: "utf-8",
              stdio: "pipe",
            }
          );
          if (headFiles.trim()) {
            allChanges.push(
              ...headFiles.split("\n").filter((l) => l.trim())
            );
          }
        } catch {
          // no commits
        }
      }

      // Deduplicate
      allChanges = [...new Set(allChanges)];
      if (allChanges.length === 0) return; // nothing happened

      // (3) roadmap already touched? → write-back happened → silent
      const roadmapTouched = allChanges.some((f) =>
        roadmapPaths.some((rp) => f === rp || f.endsWith(`/${rp}`))
      );
      if (roadmapTouched) return;

      // (1) relevant surface changed?
      const patterns = getRelevantPatterns();
      const relevant = allChanges
        .filter((f) => patterns.some((p) => p.test(f)))
        .slice(0, 20);
      if (relevant.length === 0) return; // not our concern

      // (2) completion-class signal: branch has unpushed commits
      if (!branchHasCommits) return; // no completion signal → anti alarm-fatigue

      // All three hold → WARN
      const relevantList = relevant.map((r) => `      • ${r}`).join("\n");
      const roadmapList = roadmapPaths.map((rp) => `      • ${rp}`).join("\n");
      ctx.ui.notify(
        `⚠️  ROADMAP WRITE-BACK MAY BE MISSING (warn-only, does NOT block exit)\n` +
        `    A relevant surface changed this session and shows completion\n` +
        `    signal, but no roadmap was modified.\n` +
        `    Suspect surfaces:\n${relevantList}\n` +
        `    Roadmaps checked:\n${roadmapList}\n\n` +
        `    If work completed: run the Roadmap Write-Back phase — tick ONLY\n` +
        `    with a verified-verdict evidence pointer. No verdict → [~] (evidence-failed).`,
        "warning"
      );
    } catch (err) {
      // Fail-open: silently exit
    }
  });
}