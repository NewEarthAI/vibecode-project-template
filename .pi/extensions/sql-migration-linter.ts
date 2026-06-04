/**
 * sql-migration-linter.ts — tool_result hook (Edit/Write)
 * Warns about common SQL migration footguns before write (non-blocking).
 * Scope: only files under supabase/migrations/*.sql
 *
 * Addresses insights suggestion S5 (2026-04-10) — SQL migrations had failed from
 * quote escaping and check constraint violations. This catches common patterns.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  pi.on("tool_result", async (event, ctx) => {
    try {
      // Only inspect Edit and Write tools
      const toolName = event.toolName;
      if (toolName !== "Edit" && toolName !== "Write") {
        return;
      }

      const input = event.toolCall.input as any;
      const filePath = input?.file_path || "";

      // Scope: only SQL migrations
      if (
        !filePath.includes("/supabase/migrations/") ||
        !filePath.endsWith(".sql")
      ) {
        return;
      }

      // Extract content
      const content = input?.content || input?.new_string || "";
      if (!content) {
        return;
      }

      const warnings: string[] = [];

      // Check 1: CREATE TABLE without IF NOT EXISTS
      if (
        /CREATE TABLE [^I]/i.test(content) &&
        !/CREATE TABLE IF NOT EXISTS/i.test(content)
      ) {
        warnings.push(
          "CREATE TABLE without IF NOT EXISTS — breaks migration re-runs"
        );
      }

      // Check 2: DROP without IF EXISTS
      if (
        /DROP (TABLE|VIEW|FUNCTION|INDEX|SCHEMA)\s+[^I]/i.test(content) &&
        !/IF EXISTS/i.test(content)
      ) {
        warnings.push("DROP without IF EXISTS — breaks migration re-runs");
      }

      // Check 3: CREATE INDEX without IF NOT EXISTS
      if (
        /CREATE INDEX [^I]/i.test(content) &&
        !/CREATE INDEX IF NOT EXISTS/i.test(content)
      ) {
        warnings.push(
          "CREATE INDEX without IF NOT EXISTS — breaks re-runs"
        );
      }

      // Check 4: ALTER TABLE ADD COLUMN without IF NOT EXISTS
      if (
        /ALTER TABLE .* ADD COLUMN [^I]/i.test(content) &&
        !/ADD COLUMN IF NOT EXISTS/i.test(content)
      ) {
        warnings.push(
          "ALTER TABLE ADD COLUMN without IF NOT EXISTS — breaks re-runs"
        );
      }

      // Check 5: DELETE without WHERE
      if (
        /DELETE FROM [^;]*;/i.test(content) &&
        !/DELETE FROM [^;]*WHERE/i.test(content)
      ) {
        warnings.push("DELETE without WHERE clause — will delete all rows");
      }

      // Check 6: pg_cron with nested $$ quoting collision
      if (
        /cron\.schedule/i.test(content) &&
        /\$\$.*DO \$\$.*\$\$.*\$\$/i.test(content)
      ) {
        warnings.push(
          "pg_cron schedule with nested $$ — use $cron$ ... $cron$ delimiter"
        );
      }

      // Report warnings (non-blocking)
      if (warnings.length > 0) {
        const fileName = require("node:path").basename(filePath);
        const msg = `⚠ SQL migration lint warnings for ${fileName}:\n${warnings.map((w) => `  - ${w}`).join("\n")}\n(warnings only — edit will proceed. Fix before applying migration.)`;
        ctx.ui.notify(msg, "warning");
      }
    } catch (err) {
      // Silently catch all errors — never block
    }
  });
}
