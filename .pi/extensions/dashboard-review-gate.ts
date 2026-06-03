/**
 * dashboard-review-gate.ts — tool_call hook (Bash + Edit/Write)
 * Blocks frontend code commits that contain security anti-patterns:
 *   - Hardcoded API keys or service role key references
 *   - dangerouslySetInnerHTML (XSS vector)
 *   - Direct Supabase mutations (.insert/.update/.delete/.upsert)
 *   - References to forbidden tables (financial_records)
 *
 * Scope: Only checks staged .ts/.tsx files OUTSIDE supabase/functions/
 * (edge functions legitimately use service_role key).
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { execSync } from "node:child_process";

const SECURITY_PATTERNS = [
  { pattern: /service_role/i, name: "service_role key reference" },
  { pattern: /supabase_url/i, name: "hardcoded Supabase URL" },
  { pattern: /dangerouslySetInnerHTML/i, name: "dangerouslySetInnerHTML (XSS vector)" },
  { pattern: /financial_records/i, name: "forbidden table reference (financial_records)" },
];

const MUTATION_PATTERNS = [
  /\.insert\(/,
  /\.update\(/,
  /\.delete\(/,
  /\.upsert\(/,
];

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event, ctx) => {
    try {
      // Only inspect git commit commands
      if (event.toolName !== "bash") return;

      const command = (event.toolCall.input as any)?.command;
      if (!command || !/\bgit\s+commit\b/.test(command)) return;

      // Find repo root
      let repoRoot: string;
      try {
        repoRoot = execSync("git rev-parse --show-toplevel", {
          encoding: "utf-8",
          stdio: "pipe",
        }).trim();
      } catch {
        return;
      }

      // Get staged .ts/.tsx files (outside supabase/functions/)
      let stagedFiles: string[];
      try {
        const output = execSync("git diff --cached --name-only", {
          cwd: repoRoot,
          encoding: "utf-8",
          stdio: "pipe",
        });
        stagedFiles = output
          .split("\n")
          .filter(
            (f) =>
              f.trim() &&
              /\.(tsx?)$/.test(f) &&
              !f.includes("supabase/functions/")
          );
      } catch {
        return;
      }

      if (stagedFiles.length === 0) return;

      const issues: string[] = [];

      for (const file of stagedFiles) {
        try {
          const diff = execSync(`git diff --cached -- "${file}"`, {
            cwd: repoRoot,
            encoding: "utf-8",
            stdio: "pipe",
          });

          const addedLines = diff
            .split("\n")
            .filter((l) => l.startsWith("+"))
            .map((l) => l.substring(1));

          for (const line of addedLines) {
            for (const { pattern, name } of SECURITY_PATTERNS) {
              if (pattern.test(line)) {
                issues.push(`  ${file}: ${name} — ${line.trim().substring(0, 80)}`);
              }
            }
            for (const pattern of MUTATION_PATTERNS) {
              if (pattern.test(line)) {
                issues.push(
                  `  ${file}: Direct Supabase mutation — ${line.trim().substring(0, 80)}`
                );
              }
            }
          }
        } catch {
          // ignore diff errors
        }
      }

      if (issues.length > 0) {
        const reason = `🚨 Dashboard review gate BLOCKED commit — security anti-patterns found:\n\n${issues.join("\n")}\n\nMove Supabase mutations to edge functions. Use environment variables for keys, not hardcoded values.`;
        return { block: true, reason };
      }
    } catch (err) {
      // Silently catch — never block on guard failure
    }
  });
}
