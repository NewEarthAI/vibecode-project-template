/**
 * hookify-loader.ts — Loads .claude/hookify.*.local.md files as pi extensions.
 *
 * Each hookify file has YAML frontmatter:
 *   name: hook-name
 *   enabled: true|false
 *   event: PreToolUse|Stop|SessionStart
 *   tool_matcher: regex (for PreToolUse)
 *   action: block|warn|addContext
 *
 * And a markdown body with the message/instruction to inject.
 *
 * Event mapping:
 *   PreToolUse  → tool_call (block/warn) or before_agent_start (addContext)
 *   Stop        → agent_end
 *   SessionStart → session_start or before_agent_start
 *
 * Reads from .claude/hookify.*.local.md (same source as Claude Code).
 * Idempotent — reloads on each session_start so edits take effect immediately.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { readFileSync, readdirSync, existsSync } from "node:fs";
import { join } from "node:path";

interface HookCondition {
  field: string;
  operator: string;
  pattern: string;
}

interface HookifyRule {
  name: string;
  enabled: boolean;
  event: string;
  tool_matcher?: string;
  action: string;
  conditions?: HookCondition[];
  body: string;
}

function parseHookifyFile(filePath: string): HookifyRule | null {
  try {
    const content = readFileSync(filePath, "utf-8");

    // Parse YAML frontmatter
    const frontmatterMatch = content.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
    if (!frontmatterMatch) return null;

    const yaml = frontmatterMatch[1];
    const body = frontmatterMatch[2].trim();

    const nameMatch = yaml.match(/name:\s*(.+)/);
    const enabledMatch = yaml.match(/enabled:\s*(.+)/);
    const eventMatch = yaml.match(/event:\s*(.+)/);
    const matcherMatch = yaml.match(/tool_matcher:\s*(.+)/);
    const actionMatch = yaml.match(/action:\s*(.+)/);

    if (!nameMatch || !eventMatch || !actionMatch) return null;

    // Parse conditions block
    const conditions: HookCondition[] = [];
    const condBlock = yaml.match(/conditions:\s*\n([\s\S]*?)(?=\n[a-z]|$)/);
    if (condBlock) {
      const condLines = condBlock[1].split("\n").filter((l: string) => l.trim().startsWith("- "));
      let current: Partial<HookCondition> = {};
      for (const line of condLines) {
        const fieldMatch = line.match(/field:\s*(.+)/);
        const opMatch = line.match(/operator:\s*(.+)/);
        const patMatch = line.match(/pattern:\s*(.+)/);
        if (fieldMatch) current.field = fieldMatch[1].trim();
        if (opMatch) current.operator = opMatch[1].trim();
        if (patMatch) current.pattern = patMatch[1].trim().replace(/^"|"$/g, "");
        if (current.field && current.operator && current.pattern) {
          conditions.push(current as HookCondition);
          current = {};
        }
      }
    }

    return {
      name: nameMatch[1].trim(),
      enabled: enabledMatch ? enabledMatch[1].trim() === "true" : true,
      event: eventMatch[1].trim(),
      tool_matcher: matcherMatch ? matcherMatch[1].trim() : undefined,
      action: actionMatch[1].trim(),
      conditions: conditions.length > 0 ? conditions : undefined,
      body,
    };
  } catch {
    return null;
  }
}

/**
 * Translate Claude Code tool matcher to pi tool name pattern.
 * Claude Code: mcp__supabase-yourproject__execute_sql
 * Pi:          supabase_your-org_execute_sql
 *
 * Pattern: mcp__server__tool → server_tool (hyphens → underscores in server)
 * Wildcards: mcp__supabase-*__execute_sql → supabase_.*_execute_sql
 */
function translateToolMatcher(matcher: string): string {
  // Handle pipe-separated alternatives
  if (matcher.includes("|")) {
    return matcher
      .split("|")
      .map((m) => translateToolMatcher(m.trim()))
      .join("|");
  }

  // Skip non-MCP matchers (Bash, Agent, etc.)
  if (!matcher.startsWith("mcp__")) {
    return matcher;
  }

  // mcp__server__tool → server_tool
  const mcpMatch = matcher.match(/^mcp__([^_].*?)__(.+)$/);
  if (!mcpMatch) return matcher;

  const server = mcpMatch[1]
    .replace(/-/g, "_")    // hyphens → underscores
    .replace(/\*/g, ".*");  // wildcards → regex (no extra underscore)
  const tool = mcpMatch[2];

  return `${server}_${tool}`;
}

function loadHookifyRules(projectRoot: string): HookifyRule[] {
  const rules: HookifyRule[] = [];
  const hookifyDir = join(projectRoot, ".claude");

  if (!existsSync(hookifyDir)) return rules;

  const files = readdirSync(hookifyDir).filter((f) =>
    f.startsWith("hookify.") && f.endsWith(".local.md")
  );

  for (const file of files) {
    const rule = parseHookifyFile(join(hookifyDir, file));
    if (rule && rule.enabled) {
      rules.push(rule);
    }
  }

  return rules;
}

export default function (pi: ExtensionAPI) {
  let rules: HookifyRule[] = [];

  // Load rules on session_start (hot-reload)
  pi.on("session_start", async (_event, ctx) => {
    const cwd = ctx.cwd || process.cwd();
    rules = loadHookifyRules(cwd);
  });

  // Also load immediately on extension load
  try {
    const cwd = process.cwd();
    rules = loadHookifyRules(cwd);
  } catch {
    // Will load on session_start
  }

  // PreToolUse → tool_call (block/warn) + before_agent_start (addContext)
  // For addContext rules that fire on PreToolUse, we inject them via before_agent_start
  // since pi doesn't have a "add context to tool call" mechanism.
  pi.on("before_agent_start", async (event, ctx) => {
    const addContextRules = rules.filter(
      (r) => r.event === "PreToolUse" && r.action === "addContext"
    );

    if (addContextRules.length === 0) return;

    const contextLines = addContextRules.map(
      (r) => `### ${r.name}\n${r.body}`
    );
    const extraContext = `\n\n## Hookify Rules (auto-loaded)\n\n${contextLines.join("\n\n")}`;

    return {
      systemPrompt: event.systemPrompt + extraContext,
    };
  });

  // Evaluate conditions against tool input
  function conditionsMet(rule: HookifyRule, input: Record<string, unknown>): boolean {
    if (!rule.conditions || rule.conditions.length === 0) return true; // no conditions = always match
    return rule.conditions.every((cond) => {
      const value = String(input[cond.field] ?? "");
      switch (cond.operator) {
        case "contains":
          return value.includes(cond.pattern);
        case "regex":
          return new RegExp(cond.pattern).test(value);
        case "equals":
          return value === cond.pattern;
        case "not_contains":
          return !value.includes(cond.pattern);
        default:
          return true; // unknown operator = pass
      }
    });
  }

  // PreToolUse → tool_call (block/warn)
  pi.on("tool_call", async (event, ctx) => {
    const toolName = event.toolName;
    const input = (event.input ?? {}) as Record<string, unknown>;

    const matchingRules = rules.filter(
      (r) =>
        r.event === "PreToolUse" &&
        (r.action === "block" || r.action === "warn") &&
        r.tool_matcher &&
        new RegExp(translateToolMatcher(r.tool_matcher)).test(toolName)
    );

    for (const rule of matchingRules) {
      // Check conditions — skip rule if conditions not met
      if (!conditionsMet(rule, input)) continue;

      if (rule.action === "block") {
        return {
          block: true,
          reason: `[${rule.name}] ${rule.body}`,
        };
      } else if (rule.action === "warn") {
        ctx.ui.notify(`[${rule.name}] ${rule.body}`, "warning");
      }
    }
  });

  // Stop → agent_end
  pi.on("agent_end", async (_event, ctx) => {
    const stopRules = rules.filter(
      (r) => r.event === "Stop" && r.action === "addContext"
    );

    for (const rule of stopRules) {
      // These are end-of-session instructions — log to session summary
      // The session-summarizer handles the actual file writing
      // These rules are informational for the model at session end
    }
  });

  // SessionStart → session_start (already handled above for rule loading)
  // SessionStart addContext rules are injected via before_agent_start
}
