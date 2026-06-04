/**
 * skill-linker.ts
 * Discovers skills from .claude/skills/ and makes them available to pi.
 * pi reads skills from .pi/skills/ and .agents/skills/ per settings.json.
 * This extension adds .claude/skills/ to the skill search path at session start.
 *
 * Generic — works in any repo that has .claude/skills/ with SKILL.md files.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { existsSync } from "node:fs";
import { join } from "node:path";

export default function (pi: ExtensionAPI) {
  pi.on("resources_discover", async (event) => {
    const cwd = event.cwd || process.cwd();
    const claudeSkillsDir = join(cwd, ".claude", "skills");

    if (!existsSync(claudeSkillsDir)) return {};

    // Add .claude/skills/ to pi's skill search path
    // This makes all SKILL.md files in .claude/skills/*/ available to pi
    return {
      skillPaths: [claudeSkillsDir],
    };
  });
}