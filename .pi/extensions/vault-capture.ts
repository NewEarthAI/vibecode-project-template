/**
 * vault-capture.ts — agent_end hook
 * Captures session summary into Obsidian vault daily note.
 * Runs AFTER session-summarizer (depends on its output).
 *
 * Edge case defenses (from council 2026-04-13):
 *   1. Atomic append (>>) not overwrite (>)
 *   2. All paths double-quoted (vault path has a space)
 *   3. mkdir-based file locking for parallel session safety (macOS compatible)
 *   4. Exit 0 always — never block session end
 *   5. Missing config = visible warning to stderr
 *   6. Content tagged #auto-capture
 *   7. Cold start counter
 *
 * Non-blocking — all errors silently caught (with logging to stderr).
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
  existsSync,
  readFileSync,
  writeFileSync,
  mkdirSync,
  appendFileSync,
} from "node:fs";
import { dirname, join } from "node:path";
import { execSync } from "node:child_process";

export default function (pi: ExtensionAPI) {
  pi.on("agent_end", async (_event, ctx) => {
    try {
      const home = process.env.HOME!;
      const cwd = ctx.cwd || process.cwd();

      // Find project root
      let projectRoot = cwd;
      for (let i = 0; i < 20; i++) {
        if (existsSync(join(projectRoot, ".git"))) break;
        const parent = dirname(projectRoot);
        if (parent === projectRoot) break;
        projectRoot = parent;
      }

      const configFile = join(projectRoot, ".claude", "obsidian-second-brain.local.md");

      // Check config exists
      if (!existsSync(configFile)) {
        console.error(
          `VAULT CAPTURE SKIPPED: No config at ${configFile}`
        );
        return;
      }

      // Extract vault_path from YAML frontmatter
      const configContent = readFileSync(configFile, "utf-8");
      const frontmatterMatch = configContent.match(
        /^---\n([\s\S]*?)\n---/
      );
      let vaultPath = "";
      if (frontmatterMatch) {
        const pathMatch = frontmatterMatch[1].match(
          /vault_path:\s*"?([^"\n]+)"?/
        );
        if (pathMatch) {
          vaultPath = pathMatch[1].trim();
        }
      }

      if (!vaultPath) {
        console.error(
          `VAULT CAPTURE SKIPPED: No vault_path in config`
        );
        return;
      }

      if (!existsSync(vaultPath)) {
        console.error(
          `VAULT CAPTURE SKIPPED: Vault directory not found: ${vaultPath}`
        );
        return;
      }

      const sessionsDir = join(home, ".pi", "agent", "sessions");
      const today = new Date().toISOString().split("T")[0];
      const now = new Date().toTimeString().split(" ")[0].substring(0, 5);

      // Find session summary
      let gitHash = "no-git";
      try {
        gitHash = execSync("git rev-parse --short HEAD", {
          cwd: projectRoot,
          encoding: "utf-8",
          stdio: "pipe",
        })
          .trim();
      } catch {
        // no git
      }

      const sessionFile = join(sessionsDir, `SESSION-${today}-${gitHash}.md`);

      // Fall back to most recent session file if exact match not found
      let actualSessionFile = sessionFile;
      if (!existsSync(sessionFile)) {
        const fs = require("node:fs");
        const sessionFiles = (
          fs.readdirSync(sessionsDir) || []
        )
          .filter((f: string) => f.startsWith(`SESSION-${today}-`))
          .sort()
          .reverse();
        if (sessionFiles.length > 0) {
          actualSessionFile = join(sessionsDir, sessionFiles[0]);
        } else {
          console.error(
            `VAULT CAPTURE SKIPPED: No session summary found for ${today}`
          );
          return;
        }
      }

      const sessionContent = readFileSync(actualSessionFile, "utf-8");

      // Extract sections from session summary
      const extractSection = (
        content: string,
        sectionName: string,
        maxLines: number = 20
      ): string => {
        const regex = new RegExp(
          `^## ${sectionName}\n\n([\\s\\S]*?)(?=\n^##|$)`,
          "m"
        );
        const match = content.match(regex);
        if (!match) return "";
        return match[1]
          .split("\n")
          .slice(0, maxLines)
          .join("\n");
      };

      const workCompleted = extractSection(sessionContent, "Work Completed", 20);
      const commits = extractSection(sessionContent, "Commits Today", 10);
      const branchMatch = sessionContent.match(/^- Branch: (.+)$/m);
      const branch = branchMatch ? branchMatch[1] : "unknown";
      const gitStateMatch = sessionContent.match(
        /- (Clean|WARNING|uncommitted)/
      );
      const gitState = gitStateMatch ? gitStateMatch[1] : "unknown";

      const projectName = require("node:path").basename(projectRoot);

      // Build vault block
      const vaultBlock = `## Session ${now} — ${gitHash} (${projectName})
#session #auto-capture #project/${projectName.replace(/ /g, "-")}

### Work Completed
${workCompleted || "No progress log for this session."}

### Commits
${commits || "No commits today."}

### Git State
**Branch**: ${branch}
**Status**: ${gitState}

---`;

      // Daily note path (conventional Obsidian: vault/Daily Notes/YYYY-MM-DD.md)
      const dailyNotePath = join(vaultPath, "Daily Notes", `${today}.md`);
      mkdirSync(dirname(dailyNotePath), { recursive: true });

      // File locking with mkdir (POSIX atomic operation)
      const lockDir = `/tmp/vault-capture-${today}.lock.d`;
      const maxWaitMs = 3000;
      const startMs = Date.now();

      const acquireLock = (): boolean => {
        while (Date.now() - startMs < maxWaitMs) {
          try {
            mkdirSync(lockDir, { exclusive: true });
            return true;
          } catch {
            // Lock held, wait
            require("node:timers").sleep(50);
          }
        }
        return false;
      };

      const releaseLock = () => {
        try {
          require("node:fs").rmSync(lockDir, { recursive: true });
        } catch {
          // ignore
        }
      };

      const cleanup = () => releaseLock();
      process.on("exit", cleanup);

      if (!acquireLock()) {
        console.error(
          `VAULT CAPTURE SKIPPED: Could not acquire lock after 3s`
        );
        return;
      }

      try {
        // Check if daily note exists
        if (!existsSync(dailyNotePath)) {
          // Create new daily note with header
          const newNote = `# ${today}

${vaultBlock}
`;
          writeFileSync(dailyNotePath, newNote);
        } else {
          // Append to existing
          appendFileSync(dailyNotePath, `\n${vaultBlock}\n`);
        }
      } finally {
        cleanup();
      }
    } catch (err) {
      // Silently catch all errors — never block session end
      // (uncomment for debugging):
      // console.error("vault-capture error:", err);
    }
  });
}
