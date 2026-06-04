/**
 * tool-guards.ts
 * Token-efficiency + safety guards for Supabase, n8n, bash, and subagents.
 * Ported from: supabase-select-star, supabase-list-tables-block,
 *   n8n-use-essentials, n8n-workflow-delete-block, safe-bash-enforcer,
 *   subagent-cost-guard, rebase-ours-theirs-guard hookify files.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// Context injected before any Supabase call
const SUPABASE_CHECKLIST = `
**Supabase — before every query**: Specific columns (no SELECT *) · LIMIT present · WHERE filters · JSONB: use ->>'key' not full fetch · Could an RPC do this?
Progressive disclosure: COUNT first (~50 tok) → targeted SELECT+LIMIT (~500 tok) → full row only when editing.
Anti-patterns: SELECT * on JSONB tables (5K+/row) · missing LIMIT (50K+) · N+1 loops (use array_agg/JOIN).
`.trim();

// Context injected before any n8n call
const N8N_CHECKLIST = `
**n8n modes (mandatory)**: n8n_get_workflow → use mode:'structure' (not 'full'=50K+) · n8n_executions → use mode:'summary' · get_node_info → use get_node_essentials instead (95% token savings).
Prefer partial_workflow over full_workflow for updates.
STOP for user approval: node rename · sub-workflow contract change · branch logic near Merge node.
`.trim();

export default function (pi: ExtensionAPI) {

	pi.on("tool_call", async (event, ctx) => {
		const tool = event.toolName;
		const input = event.input as Record<string, unknown>;

		// ── Supabase: SELECT * block ──────────────────────────────────────────
		if (tool.includes("execute_sql")) {
			const query = String(input.query ?? "").toUpperCase();
			if (/SELECT\s+\*/.test(query)) {
				return {
					block: true,
					reason: "SELECT * wastes 60–80% tokens on JSONB/media columns. Specify columns. For schema: SELECT column_name, data_type FROM information_schema.columns WHERE table_name='X'",
				};
			}
		}

		// ── Supabase: list_tables block ───────────────────────────────────────
		if (tool.includes("list_tables")) {
			return {
				block: true,
				reason: "list_tables returns ~480KB. Use instead: SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_name ILIKE '%pattern%'",
			};
		}

		// ── Supabase: context inject ──────────────────────────────────────────
		if (tool.startsWith("supabase-")) {
			ctx.ui.notify(SUPABASE_CHECKLIST, "info");
		}

		// ── n8n: get_node_info block ──────────────────────────────────────────
		if (tool.includes("get_node_info")) {
			return {
				block: true,
				reason: "get_node_info dumps 100KB+. Use get_node_essentials instead — returns only required params + gotchas, ~2–5KB.",
			};
		}

		// ── n8n: delete workflow block ────────────────────────────────────────
		if (tool.includes("n8n_delete_workflow") || tool.includes("n8n_delete_multiple")) {
			const ok = await ctx.ui.confirm(
				"n8n workflow delete",
				`This permanently deletes a workflow.\n\nTool: ${tool}\nProceed?`
			);
			if (!ok) return { block: true, reason: "User declined workflow delete" };
		}

		// ── n8n: context inject ───────────────────────────────────────────────
		if (tool.startsWith("n8n-")) {
			ctx.ui.notify(N8N_CHECKLIST, "info");
		}

		// ── Bash: safety gates ────────────────────────────────────────────────
		if (tool === "bash") {
			const cmd = String(input.command ?? "");

			// Hard block: rebase --ours/--theirs (silent code discard)
			if (/git\s+.*--(ours|theirs)/.test(cmd)) {
				return {
					block: true,
					reason: "--ours/--theirs silently discards code during rebase. Resolve conflicts manually.",
				};
			}

			// Confirm: destructive git ops
			if (/git\s+(reset\s+--hard|push\s+.*--force|clean\s+-fd?)/.test(cmd)) {
				const ok = await ctx.ui.confirm(
					"Destructive git operation",
					`Command: ${cmd}\n\nThis is irreversible. Proceed?`
				);
				if (!ok) return { block: true, reason: "User declined destructive git op" };
			}

			// Confirm: rm -rf
			if (/rm\s+-[rf]{1,2}\s+[^/\s]/.test(cmd)) {
				const ok = await ctx.ui.confirm("rm -rf", `Command: ${cmd}\n\nProceed?`);
				if (!ok) return { block: true, reason: "User declined rm -rf" };
			}

			// Hard block: sudo
			if (/\bsudo\b/.test(cmd)) {
				return { block: true, reason: "sudo not allowed in automated flows" };
			}
		}

		// ── Subagent cost gate ────────────────────────────────────────────────
		// pi's subagent extension registers a tool named "subagent"
		if (tool === "subagent") {
			ctx.ui.notify(
				"Subagent spawning — verify: (1) Could Glob/Grep/Read achieve this? (2) Complex enough to justify token cost? (3) If parallel, truly independent?",
				"warning"
			);
		}
	});
}
