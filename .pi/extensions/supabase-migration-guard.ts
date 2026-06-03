/**
 * supabase-migration-guard.ts — tool_call hook (Supabase execute_sql/apply_migration)
 * Gates for Supabase MCP mutations:
 *   1. SQL pattern rules R1/R2/R3 — known incident classes
 *   2. Branch guard — only from main or hotfix/*
 *   3. Up-to-date check — must be current with origin/main
 *   4. Migration lock — atomic mkdir (session-scoped)
 *
 * EFFICIENCY: Fast-path bail for read-only SQL (<2ms). Slow-path only on mutations.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { execSync } from "node:child_process";
import {
  mkdirSync,
  writeFileSync,
  readFileSync,
  rmSync,
  existsSync,
} from "node:fs";
import { join } from "node:path";

const MUTATION_KEYWORDS =
  /\b(CREATE|ALTER|DROP|UPDATE|DELETE|INSERT|GRANT|REVOKE|TRUNCATE)\b/i;

function isMutation(toolName: string, query: string): boolean {
  if (toolName.includes("apply_migration")) return true;
  if (toolName.includes("execute_sql")) {
    return MUTATION_KEYWORDS.test(query);
  }
  return false;
}

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event, ctx) => {
    try {
      const toolName = event.toolName;

      // Only inspect Supabase tools
      if (
        !toolName.includes("supabase") ||
        (!toolName.includes("execute_sql") &&
          !toolName.includes("apply_migration"))
      ) {
        return;
      }

      const input = event.toolCall.input as any;
      const query = input?.query || input?.name || "";

      // FAST PATH: bail if not a mutation
      if (!isMutation(toolName, query)) {
        return;
      }

      const reasons: string[] = [];
      const sqlLower = query.toLowerCase();
      const sqlOneline = sqlLower.replace(/\n/g, " ");

      // Tier classification
      let tier = "STANDARD";
      if (sqlLower.includes("security_invoker")) tier = "HIGH_VIEW";
      else if (
        /\b(create|alter|drop)\s+policy\b/i.test(sqlLower)
      )
        tier = "HIGH_POLICY";
      else if (sqlLower.includes("security definer")) tier = "HIGH_SECDEF";
      else if (/\bcreate\s+table\b/i.test(sqlLower)) tier = "MEDIUM_TABLE";

      // R1: security_invoker requires -- policies-checked: comment
      if (tier === "HIGH_VIEW") {
        if (
          !/^\s*--\s*policies-checked\s*:\s*\S+/.test(query)
        ) {
          reasons.push(
            "R1 (security_invoker): migration sets security_invoker=true but lacks required '-- policies-checked: <comma-separated-tables>' comment. Query pg_policies for each joined base table first."
          );
        }
      }

      // R2: CREATE TABLE must enable RLS in same migration
      if (tier === "MEDIUM_TABLE") {
        const isTemp = /\b(create|temporary|temp)\s+table\b/i.test(sqlLower);
        if (!isTemp) {
          const hasRls =
            /enable\s+row\s+level\s+security/i.test(sqlOneline);
          const hasExempt = /^\s*--\s*rls-exempt\s*:\s*\S+/m.test(query);
          if (!hasRls && !hasExempt) {
            reasons.push(
              "R2 (RLS): CREATE TABLE detected but no 'ALTER TABLE ... ENABLE ROW LEVEL SECURITY' found, and no '-- rls-exempt: <reason>' escape comment."
            );
          }
        }
      }

      // R3: UPDATE ... WHERE ... IS NULL needs trigger
      if (
        /update\s+[a-z_0-9.]+\s+set\s+.*\s+where\s+.*\s+is\s+null/i.test(
          sqlOneline
        )
      ) {
        const hasTrigger = /create\s+(or\s+replace\s+)?trigger/i.test(
          sqlOneline
        );
        const hasBackfillComment =
          /^\s*--\s*backfill-only-see\s*:\s*\S+/m.test(query);
        if (!hasTrigger && !hasBackfillComment) {
          reasons.push(
            "R3 (backfill + forward trigger): 'UPDATE ... SET ... WHERE ... IS NULL' detected but no CREATE TRIGGER in same migration, and no '-- backfill-only-see: <trigger-name>' escape comment."
          );
        }
      }

      // B1: Branch must be main or hotfix/*
      let branch = "unknown";
      try {
        branch = execSync("git branch --show-current", {
          encoding: "utf-8",
          stdio: "pipe",
        }).trim();
      } catch {
        // no git
      }
      if (branch !== "unknown" && branch !== "main" && !branch.startsWith("hotfix/")) {
        reasons.push(
          `B1 (branch): current branch is '${branch}' — production DB mutations only from 'main' or 'hotfix/*'.`
        );
      }

      // B2: Must be up-to-date with origin/main
      if (branch === "main") {
        try {
          execSync("git fetch origin main", {
            encoding: "utf-8",
            stdio: "pipe",
            timeout: 3000,
          });
          const behind = parseInt(
            execSync("git rev-list --count HEAD..origin/main", {
              encoding: "utf-8",
              stdio: "pipe",
            }).trim(),
            10
          );
          if (behind > 0) {
            const recent = execSync(
              "git log --oneline HEAD..origin/main | head -5",
              { encoding: "utf-8", stdio: "pipe" }
            );
            reasons.push(
              `B2 (up-to-date): local main is ${behind} commits behind origin/main. Pull first: git pull origin main.\nRecent commits:\n${recent}`
            );
          }
        } catch {
          // fetch failed — skip check
        }
      }

      // Block if any reason failed
      if (reasons.length > 0) {
        const msg = `🚨 Supabase migration guard BLOCKED (tier: ${tier}):\n\n${reasons.map((r) => `  • ${r}`).join("\n\n")}`;
        return { block: true, reason: msg };
      }

      // B3: Migration lock (atomic mkdir)
      const projectRoot = ctx.cwd || process.cwd();
      const lockDir = join(projectRoot, ".claude", ".supabase-migration-lock");
      const metadataFile = join(lockDir, "metadata.json");
      const sessionId =
        process.env.CLAUDE_SESSION_ID || `pi-pid-${process.pid}`;
      const nowEpoch = Math.floor(Date.now() / 1000);
      const ttlSeconds = 600;

      try {
        mkdirSync(lockDir, { exclusive: true });
        writeFileSync(
          metadataFile,
          JSON.stringify(
            {
              session_id: sessionId,
              tool_name: toolName,
              acquired_at: nowEpoch,
              acquired_iso: new Date().toISOString(),
              intent_preview: query.substring(0, 200),
              tier,
            },
            null,
            2
          )
        );
      } catch {
        // Lock exists — check if stale
        if (existsSync(metadataFile)) {
          try {
            const metadata = JSON.parse(
              readFileSync(metadataFile, "utf-8")
            );
            const age = nowEpoch - (metadata.acquired_at || 0);

            if (metadata.session_id === sessionId) {
              // Same session re-entering — OK
            } else if (age > ttlSeconds) {
              // Stale — force-release + re-acquire
              rmSync(metadataFile, { force: true });
              try {
                rmSync(lockDir, { recursive: true, force: true });
              } catch {
                // ignore
              }
              mkdirSync(lockDir, { exclusive: true });
              writeFileSync(
                metadataFile,
                JSON.stringify(
                  {
                    session_id: sessionId,
                    tool_name: toolName,
                    acquired_at: nowEpoch,
                    acquired_iso: new Date().toISOString(),
                    intent_preview: query.substring(0, 200),
                    tier,
                    note: `force-released stale lock held for ${age}s by ${metadata.session_id}`,
                  },
                  null,
                  2
                )
              );
            } else {
              return {
                block: true,
                reason: `🚨 Supabase migration-lock held by session '${metadata.session_id}' (age ${age}s, TTL ${ttlSeconds}s). Their intent: ${metadata.intent_preview}. Wait for them to finish.`,
              };
            }
          } catch {
            // metadata unreadable — treat as stale
          }
        }
      }

      // All green — proceed
    } catch (err) {
      // Silently catch errors — never block on guard failure
    }
  });
}
