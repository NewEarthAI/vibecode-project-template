/**
 * cmux-notify.ts
 * tmux notification bridge. Sends notifications on session end, agent stop, errors.
 * Ported from: .claude/hooks/cmux-notify.sh
 *
 * Non-blocking — notification failures never block the session.
 * Requires cmux running with Unix socket at CMUX_SOCK or /tmp/cmux.sock.
 *
 * GENERIC — workspace detection uses repo name from git remote, not hardcoded paths.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { execSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { join, basename } from "node:path";

const CMUX_SOCK = process.env.CMUX_SOCK || "/tmp/cmux.sock";

function sendNotification(title: string, body: string): boolean {
  try {
    if (!existsSync(CMUX_SOCK)) return false;
    const payload = JSON.stringify({ type: "notification", title, body });
    execSync(
      `echo '${payload.replace(/'/g, "'\\''")}' | socat - UNIX-CONNECT:${CMUX_SOCK}`,
      { stdio: "pipe", timeout: 2000 }
    );
    return true;
  } catch {
    return false;
  }
}

function detectWorkspace(cwd: string): string {
  // Try git remote first (generic)
  try {
    const remote = execSync("git remote get-url origin 2>/dev/null", {
      cwd,
      encoding: "utf-8",
      stdio: "pipe",
    }).trim();
    // Extract repo name from URL: git@github.com:Org/Repo.git → Repo
    const match = remote.match(/\/([^/]+?)(?:\.git)?$/);
    if (match) return match[1].toLowerCase();
  } catch {
    // no git
  }
  // Fallback: directory name
  return basename(cwd).toLowerCase();
}

export default function (pi: ExtensionAPI) {
  // Notify on agent end (session complete)
  pi.on("agent_end", async (_event, ctx) => {
    const cwd = ctx.cwd || process.cwd();
    const workspace = detectWorkspace(cwd);
    sendNotification(
      `${workspace} session complete`,
      `Agent finished in ${cwd}`
    );
  });

  // Notify on errors (tool failures)
  pi.on("tool_result", async (event, ctx) => {
    if (event.isError) {
      const cwd = ctx.cwd || process.cwd();
      const workspace = detectWorkspace(cwd);
      sendNotification(
        `${workspace} tool error`,
        `${event.toolName} failed`
      );
    }
  });
}