/**
 * worktree-guard.ts
 * Git worktree safety: dirty-tree protection, stale lock detection, branch reminders.
 * Ported from: .claude/hooks/worktree-guard.sh
 *
 * Three concerns:
 *   1. Branch-modifying git op while extra worktrees exist → reminder
 *   2. `git switch -c <new>` on dirty tree → warn about stash-first
 *   3. `git worktree add` → scan for stale .git/*.lock files
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { execSync } from "node:child_process";
import { existsSync, readdirSync } from "node:fs";
import { join } from "node:path";

function getWorktrees(cwd: string): string[] {
  try {
    const output = execSync("git worktree list --porcelain", {
      cwd,
      encoding: "utf-8",
      stdio: "pipe",
    });
    const worktrees: string[] = [];
    for (const line of output.split("\n")) {
      if (line.startsWith("worktree ")) {
        worktrees.push(line.substring(9).trim());
      }
    }
    return worktrees;
  } catch {
    return [];
  }
}

function isDirty(cwd: string): boolean {
  try {
    const status = execSync("git status --porcelain", {
      cwd,
      encoding: "utf-8",
      stdio: "pipe",
    });
    return status.trim().length > 0;
  } catch {
    return false;
  }
}

function findStaleLocks(gitDir: string): string[] {
  const locks: string[] = [];
  try {
    // Check .git for lock files
    const gitPath = gitDir;
    if (existsSync(gitPath)) {
      const files = readdirSync(gitPath);
      for (const f of files) {
        if (f.endsWith(".lock")) {
          locks.push(join(gitPath, f));
        }
      }
    }
    // Check worktree git dirs
    const worktreeDir = join(gitPath, "worktrees");
    if (existsSync(worktreeDir)) {
      for (const wt of readdirSync(worktreeDir)) {
        const wtGitDir = join(worktreeDir, wt);
        try {
          for (const f of readdirSync(wtGitDir)) {
            if (f.endsWith(".lock")) {
              locks.push(join(wtGitDir, f));
            }
          }
        } catch {
          // skip
        }
      }
    }
  } catch {
    // skip
  }
  return locks;
}

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event, ctx) => {
    if (event.toolName !== "bash") return;

    const cmd = String((event.input as Record<string, unknown>).command ?? "");
    const cwd = ctx.cwd || process.cwd();

    // Only inspect git commands
    if (!/git\s+/.test(cmd)) return;

    // 3. `git worktree add` → check for stale locks
    if (/git\s+worktree\s+add/.test(cmd)) {
      try {
        const gitDir = execSync("git rev-parse --git-dir", {
          cwd,
          encoding: "utf-8",
          stdio: "pipe",
        }).trim();
        const locks = findStaleLocks(gitDir);
        if (locks.length > 0) {
          return {
            block: true,
            reason: `Stale lock files detected:\n${locks.join("\n")}\n\nRemove before adding worktree: rm ${locks[0]}`,
          };
        }
      } catch {
        // git failed, skip
      }
      return;
    }

    // Branch-modifying operations
    const isBranchOp = /git\s+(checkout|switch|branch\s+-[dD]|merge|rebase|cherry-pick|reset)/.test(cmd);
    if (!isBranchOp) return;

    // 1. Extra worktrees exist → reminder
    const worktrees = getWorktrees(cwd);
    if (worktrees.length > 1) {
      ctx.ui.notify(
        `⚠️ ${worktrees.length} worktrees active. Branch ops in one don't affect others. Verify you're in the right tree.`,
        "warning"
      );
    }

    // 2. `git switch -c` or `git checkout -b` on dirty tree
    if (/git\s+(switch\s+-c|checkout\s+-b)/.test(cmd) && isDirty(cwd)) {
      ctx.ui.notify(
        "⚠️ Dirty tree + new branch. Consider `git stash` first, then switch. Stash pop after.",
        "warning"
      );
    }
  });
}
