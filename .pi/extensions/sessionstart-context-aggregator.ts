/**
 * sessionstart-context-aggregator.ts
 * Loads repo state briefing at session start: branch, recent commits,
 * MEMORY.md index, open PRs, ROADMAP head.
 * Ported from: .claude/hooks/sessionstart-context-aggregator.sh
 *
 * Injects context into system prompt so the agent picks up live state
 * without manual /prime invocation.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { execSync } from "node:child_process";
import { readFileSync, existsSync } from "node:fs";
import { join } from "node:path";

function safeExec(cmd: string, cwd: string): string {
  try {
    return execSync(cmd, { cwd, encoding: "utf-8", stdio: "pipe" }).trim();
  } catch {
    return "";
  }
}

export default function (pi: ExtensionAPI) {
  pi.on("before_agent_start", async (event, ctx) => {
    const cwd = ctx.cwd || process.cwd();
    const sections: string[] = [];

    // 1. Git state
    const branch = safeExec("git rev-parse --abbrev-ref HEAD", cwd);
    const dirty = safeExec("git status --porcelain", cwd);
    const unpushed = safeExec("git log --oneline @{upstream}..HEAD 2>/dev/null", cwd);
    const recentCommits = safeExec("git log --oneline -5", cwd);

    let gitSection = `**Branch**: ${branch || "unknown"}`;
    if (dirty) {
      const dirtyCount = dirty.split("\n").length;
      gitSection += ` | ${dirtyCount} uncommitted change(s)`;
    }
    if (unpushed) {
      const unpushedCount = unpushed.split("\n").length;
      gitSection += ` | ${unpushedCount} unpushed commit(s)`;
    }
    if (recentCommits) {
      gitSection += `\n**Recent commits**:\n${recentCommits.split("\n").slice(0, 5).join("\n")}`;
    }
    sections.push(`## Git State\n${gitSection}`);

    // 2. MEMORY.md index (first 80 lines)
    const memoryPaths = [
      join(cwd, "agency", "memory", "MEMORY.md"),
      join(cwd, ".claude", "memory", "MEMORY.md"),
    ];
    for (const memPath of memoryPaths) {
      if (existsSync(memPath)) {
        try {
          const content = readFileSync(memPath, "utf-8");
          const lines = content.split("\n").slice(0, 80).join("\n");
          sections.push(`## Memory Index (top 80 lines)\n${lines}`);
        } catch {
          // skip
        }
        break;
      }
    }

    // 3. Open PRs (via gh CLI)
    const openPRs = safeExec("gh pr list --limit 5 --state open --json number,title,headRefName --jq '.[] | \"#\(.number) \(.title) [\(.headRefName)]\"' 2>/dev/null", cwd);
    if (openPRs) {
      sections.push(`## Open PRs\n${openPRs}`);
    }

    // 4. ROADMAP head (first 30 lines)
    const roadmapPath = join(cwd, "ROADMAP.md");
    if (existsSync(roadmapPath)) {
      try {
        const content = readFileSync(roadmapPath, "utf-8");
        const lines = content.split("\n").slice(0, 30).join("\n");
        const totalLines = content.split("\n").length;
        let roadmapSection = `## ROADMAP (${totalLines} lines)\n${lines}`;
        if (totalLines > 500) {
          roadmapSection += `\n\n⚠️ ROADMAP is ${totalLines} lines — consider /compress-roadmap`;
        }
        sections.push(roadmapSection);
      } catch {
        // skip
      }
    }

    // 5. BF ROADMAP head (if exists)
    const bfRoadmapPath = join(cwd, "agency", "business-foundations", "ROADMAP.md");
    if (existsSync(bfRoadmapPath)) {
      try {
        const content = readFileSync(bfRoadmapPath, "utf-8");
        const totalLines = content.split("\n").length;
        sections.push(`## BF ROADMAP: ${totalLines} lines (read with /daily-business-plan)`);
      } catch {
        // skip
      }
    }

    // Heartbeat
    const totalBytes = sections.reduce((acc, s) => acc + s.length, 0);
    const heartbeat = `Session context loaded: ${sections.length} sections, ${totalBytes} bytes`;

    return {
      systemPrompt:
        event.systemPrompt +
        `\n\n## Session Context (auto-loaded)\n\n${heartbeat}\n\n${sections.join("\n\n")}`,
    };
  });
}
