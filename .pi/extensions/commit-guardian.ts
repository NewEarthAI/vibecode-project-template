/**
 * commit-guardian.ts
 * Pre-commit quality gate. Blocks commits with debug artifacts, .env files, large files.
 * Ported from: .claude/hooks/commit-guardian.sh
 *
 * Checks staged files for:
 *   - Debug artifacts (console.log, debugger, TODO-REMOVE)
 *   - Staged .env files (credential leak risk)
 *   - Staged large files (>1MB, likely accidental)
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { execSync } from "node:child_process";

const DEBUG_PATTERNS = [
  /console\.log\(/,
  /debugger;?/,
  /TODO-REMOVE/,
  /FIXME-REMOVE/,
  /HACK-REMOVE/,
];

const BLOCKED_FILES = [
  /^\.env$/,
  /^\.env\.local$/,
  /^\.env\.production$/,
  /\.pem$/,
  /\.key$/,
];

const MAX_FILE_SIZE = 1024 * 1024; // 1MB

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event, ctx) => {
    if (event.toolName !== "bash") return;

    const cmd = String((event.input as Record<string, unknown>).command ?? "");

    // Only inspect git commit commands
    if (!/git\s+commit/.test(cmd)) return;

    try {
      const cwd = ctx.cwd || process.cwd();

      // Get staged files
      const staged = execSync("git diff --cached --name-only --diff-filter=ACMR", {
        cwd,
        encoding: "utf-8",
        stdio: "pipe",
      }).trim();

      if (!staged) return; // nothing staged

      const files = staged.split("\n");
      const issues: string[] = [];

      for (const file of files) {
        // Check blocked file patterns
        if (BLOCKED_FILES.some((p) => p.test(file))) {
          issues.push(`🚫 ${file} — credential/key file staged`);
          continue;
        }

        // Check file size
        try {
          const sizeStr = execSync(
            `git diff --cached --numstat -- "${file}" | awk '{print $1}'`,
            { cwd, encoding: "utf-8", stdio: "pipe" }
          ).trim();
          const size = parseInt(sizeStr, 10);
          if (size > MAX_FILE_SIZE) {
            issues.push(`📦 ${file} — ${(size / 1024 / 1024).toFixed(1)}MB (>${MAX_FILE_SIZE / 1024 / 1024}MB)`);
          }
        } catch {
          // size check failed, skip
        }

        // Check debug patterns in staged content (only for code files)
        if (/\.(ts|tsx|js|jsx|py)$/.test(file)) {
          try {
            const diff = execSync(
              `git diff --cached --unified=0 -- "${file}"`,
              { cwd, encoding: "utf-8", stdio: "pipe" }
            );
            const addedLines = diff
              .split("\n")
              .filter((l) => l.startsWith("+") && !l.startsWith("+++"));

            for (const line of addedLines) {
              for (const pattern of DEBUG_PATTERNS) {
                if (pattern.test(line)) {
                  issues.push(`🐛 ${file} — debug artifact: ${pattern.source}`);
                  break;
                }
              }
            }
          } catch {
            // diff check failed, skip
          }
        }
      }

      if (issues.length > 0) {
        return {
          block: true,
          reason: `Commit blocked — ${issues.length} issue(s):\n${issues.join("\n")}\n\nFix or use --no-verify to override.`,
        };
      }
    } catch {
      // git failed — don't block
    }
  });
}
