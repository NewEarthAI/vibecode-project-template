// Integration test marker
/**
 * session-summarizer.ts — agent_end hook
 * Writes a session summary at end of every pi session.
 * Outputs:
 *   - ~/.pi/agent/sessions/SESSION-{date}-{hash}.md
 *   - ~/.pi/agent/sessions/session-state.env
 *
 * Non-blocking — all errors silently caught.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { execSync, spawnSync } from "node:child_process";
import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";

export default function (pi: ExtensionAPI) {
  pi.on("agent_end", async (_event, ctx) => {
    try {
      const cwd = ctx.cwd || process.cwd();
      
      // Find project root (walk up for .git)
      let projectRoot = cwd;
      for (let i = 0; i < 20; i++) {
        if (existsSync(join(projectRoot, ".git"))) break;
        const parent = dirname(projectRoot);
        if (parent === projectRoot) break;
        projectRoot = parent;
      }

      const sessionsDir = join(process.env.HOME!, ".pi", "agent", "sessions");
      mkdirSync(sessionsDir, { recursive: true });

      const today = new Date().toISOString().split("T")[0];
      const now = new Date().toTimeString().split(" ")[0].substring(0, 5);

      // Git hash
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
      const stateFile = join(sessionsDir, "session-state.env");

      // Initialize session-state.env if needed
      if (!existsSync(stateFile)) {
        writeFileSync(
          stateFile,
          `# Session state — cross-session flags
# Updated by session-summarizer, read by daily-plan-generator
CLIENTUPDATE_PENDING=false
`
        );
      }

      // Progress log (optional — may not exist in pi workflow)
      let progressSection = "No progress log found for this session.";
      let mutationCount = 0;
      const progressFile = join(
        sessionsDir,
        `claude-progress-${today}.md`
      );
      if (existsSync(progressFile)) {
        const content = readFileSync(progressFile, "utf-8");
        progressSection = content;
        mutationCount = (content.match(/^## /gm) || []).length;
      }

      // Git commits today
      let gitCommits = "No commits today.";
      try {
        const commits = execSync(
          `git log --oneline --since="${today} 00:00"`,
          {
            cwd: projectRoot,
            encoding: "utf-8",
            stdio: "pipe",
          }
        );
        if (commits.trim()) {
          gitCommits = commits
            .split("\n")
            .slice(0, 10)
            .join("\n");
        }
      } catch {
        // no commits or git error
      }

      // Git state
      let gitDirty = "";
      let gitUnpushed = "";
      let currentBranch = "unknown";
      try {
        gitDirty = execSync("git status --porcelain", {
          cwd: projectRoot,
          encoding: "utf-8",
          stdio: "pipe",
        });
        currentBranch = execSync("git rev-parse --abbrev-ref HEAD", {
          cwd: projectRoot,
          encoding: "utf-8",
          stdio: "pipe",
        })
          .trim();
        if (currentBranch !== "unknown") {
          try {
            gitUnpushed = execSync("git log --oneline @{upstream}..HEAD", {
              cwd: projectRoot,
              encoding: "utf-8",
              stdio: "pipe",
            });
          } catch {
            // no upstream
          }
        }
      } catch {
        // git error
      }

      const gitStateWarning = gitDirty
        ? `WARNING: ${gitDirty.split("\n").length - 1} uncommitted change(s) at session end.`
        : "";
      const unpushedWarning = gitUnpushed
        ? `NOTE: ${gitUnpushed.split("\n").length - 1} unpushed commit(s) on ${currentBranch}.`
        : "";

      // ROADMAP health
      let roadmapLines = 0;
      let roadmapWarning = "";
      let nextItems = "Check ROADMAP.md directly.";
      const roadmapFile = join(projectRoot, "ROADMAP.md");
      if (existsSync(roadmapFile)) {
        const roadmapContent = readFileSync(roadmapFile, "utf-8");
        roadmapLines = roadmapContent.split("\n").length;
        if (roadmapLines > 550) {
          roadmapWarning = `ROADMAP.md is ${roadmapLines} lines. Run /compress-roadmap.`;
        }

        // Extract top 3 NEXT lane items
        const nextMatch = roadmapContent.match(/^## NEXT\n([\s\S]*?)^## [^N]/m);
        if (nextMatch) {
          const nextSection = nextMatch[1];
          const items = nextSection
            .match(/^### (.+?)(?:\s*\[.+?\])?$/gm)
            ?.slice(0, 3)
            .map((line, idx) =>
              line.replace(/^### /, `${idx + 1}: `).replace(/\s*\[.+?\]/, "")
            )
            .join("\n");
          if (items) nextItems = items;
        }
      }

      // Session file count warning
      const sessionFiles = (
        require("node:fs").readdirSync(sessionsDir) || []
      ).filter((f: string) => f.startsWith("SESSION-"));
      const sessionWarning =
        sessionFiles.length > 14
          ? `${sessionFiles.length} session files. Consider archiving older ones.`
          : "";

      // Check for ROADMAP milestone changes
      let clientUpdateNote = "";
      let roadmapChanged = 0;
      try {
        const diff = execSync("git diff HEAD~1 HEAD -- ROADMAP.md", {
          cwd: projectRoot,
          encoding: "utf-8",
          stdio: "pipe",
        });
        roadmapChanged = (diff.match(/^\+.*(COMPLETE|DONE)/gm) || []).length;
      } catch {
        // no previous commit or git error
      }

      if (roadmapChanged > 0) {
        // Update session-state.env
        const stateContent = readFileSync(stateFile, "utf-8")
          .split("\n")
          .filter((line) => !line.startsWith("CLIENTUPDATE_PENDING"))
          .join("\n");
        writeFileSync(
          stateFile,
          stateContent + `\nCLIENTUPDATE_PENDING=true\n`
        );
        clientUpdateNote = `/clientprojectupdate auto-triggered (${roadmapChanged} milestone change(s) in ROADMAP)`;
      }

      // Write session summary
      const summary = `# Session — ${today} ${now}
**Git hash**: ${gitHash}
**Mutations logged**: ${mutationCount}

## Work Completed

${progressSection}

## Commits Today

${gitCommits}

## Next Session Priorities (from ROADMAP NEXT lane)

${nextItems}

## Git State at Session End
- Branch: ${currentBranch}
${gitDirty ? `- Uncommitted changes:
${gitDirty}` : ""}
${gitUnpushed ? `- Unpushed commits:
${gitUnpushed}` : ""}
${gitStateWarning ? `- ${gitStateWarning}` : ""}
${unpushedWarning ? `- ${unpushedWarning}` : ""}
${!gitDirty && !gitUnpushed ? "- Clean (all committed and pushed)" : ""}

## Context Health
- ROADMAP.md: ${roadmapLines} lines${roadmapWarning ? ` — ${roadmapWarning}` : ""}
${sessionWarning ? `- ${sessionWarning}` : ""}
${clientUpdateNote ? `- ${clientUpdateNote}` : ""}

---
*Generated by session-summarizer at ${now}*
`;

      writeFileSync(sessionFile, summary);
    } catch (err) {
      // Silently catch all errors — never block session end
    }
  });
}
// Hooks integration test — Tue 26 May 2026 15:54:28 SAST
