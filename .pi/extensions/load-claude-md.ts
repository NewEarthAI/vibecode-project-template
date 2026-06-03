/**
 * load-claude-md.ts
 *
 * Loads CLAUDE.md from the project root into the system prompt on every session.
 *
 * Why: pi's context-file loader checks for AGENTS.md first, finds it (it just
 * says "READ CLAUDE.md"), and stops — so CLAUDE.md never auto-loads. This
 * extension bridges the gap without modifying AGENTS.md or CLAUDE.md.
 */

import * as fs from "node:fs";
import * as path from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
	pi.on("before_agent_start", async (event, ctx) => {
		const claudeMdPath = path.join(ctx.cwd, "CLAUDE.md");

		if (!fs.existsSync(claudeMdPath)) {
			return;
		}

		let content: string;
		try {
			content = fs.readFileSync(claudeMdPath, "utf-8");
		} catch {
			return;
		}

		return {
			systemPrompt:
				event.systemPrompt +
				`\n\n<project_instructions path="${claudeMdPath}">\n${content}\n</project_instructions>`,
		};
	});
}
