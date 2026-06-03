/**
 * ts-typecheck.ts
 * Runs tsc --noEmit after TypeScript/TSX edits to catch type errors immediately.
 * Ported from: .claude/hooks/ts-typecheck.sh
 *
 * Scope: only fires after Edit/Write tool calls on .ts/.tsx files.
 * Non-blocking — warnings surface but don't block the edit.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { execSync } from "node:child_process";
import { existsSync } from "node:fs";
import { join, dirname } from "node:path";

export default function (pi: ExtensionAPI) {
  pi.on("tool_result", async (event, ctx) => {
    // Only fire after Edit or Write
    if (event.toolName !== "edit" && event.toolName !== "write") return;

    const input = (event.input ?? {}) as Record<string, unknown>;
    const filePath = String(input.path ?? input.file_path ?? "");

    // Only TypeScript files
    if (!/\.(ts|tsx)$/.test(filePath)) return;

    const cwd = ctx.cwd || process.cwd();

    // Find project root with tsconfig.json
    let projectRoot = dirname(filePath);
    for (let i = 0; i < 10; i++) {
      if (existsSync(join(projectRoot, "tsconfig.json"))) break;
      const parent = dirname(projectRoot);
      if (parent === projectRoot) return; // no tsconfig found
      projectRoot = parent;
    }

    if (!existsSync(join(projectRoot, "tsconfig.json"))) return;

    // Check if tsc is available
    try {
      const tscPath = join(projectRoot, "node_modules", ".bin", "tsc");
      const tscCmd = existsSync(tscPath) ? tscPath : "npx tsc";

      const result = execSync(`${tscCmd} --noEmit --pretty false 2>&1`, {
        cwd: projectRoot,
        encoding: "utf-8",
        stdio: "pipe",
        timeout: 30000, // 30s max
      });

      // If no errors, result is empty
      if (!result.trim()) return;

      // Filter errors to only show ones related to our file
      const errors = result
        .split("\n")
        .filter((line) => line.includes(filePath))
        .slice(0, 5); // max 5 errors

      if (errors.length > 0) {
        ctx.ui.notify(
          `⚠️ TypeScript errors in ${filePath}:\n${errors.join("\n")}`,
          "warning"
        );
      }
    } catch {
      // tsc not available or timed out — don't block
    }
  });
}
