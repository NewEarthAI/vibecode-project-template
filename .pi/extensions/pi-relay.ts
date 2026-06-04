/**
 * pi-relay.ts — Inter-pi communication via shared message queue.
 *
 * Allows two independent pi instances to communicate by reading/writing
 * messages to a shared directory. Each pi has a channel name, writes to
 * the other's inbox, and polls its own inbox.
 *
 * Usage:
 *   pi --model ... -p "You are Agent A. Use pi-relay to coordinate with Agent B."
 *   pi --model ... -p "You are Agent B. Use pi-relay to coordinate with Agent A."
 *
 * Tools registered:
 *   pi-relay-send     — Send a message to another pi instance
 *   pi-relay-receive  — Check for messages from another pi instance
 *   pi-relay-status   — List all active channels and message counts
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
  writeFileSync,
  readFileSync,
  readdirSync,
  mkdirSync,
  existsSync,
  unlinkSync,
} from "node:fs";
import { join } from "node:path";
import { Type } from "typebox";

const RELAY_DIR = "/tmp/pi-relay";

export default function (pi: ExtensionAPI) {
  // Ensure relay directory exists
  mkdirSync(RELAY_DIR, { recursive: true });

  // Register send tool
  pi.registerTool({
    name: "pi-relay-send",
    label: "Pi Relay Send",
    description:
      "Send a message to another pi instance. Specify the target channel and your message.",
    parameters: Type.Object({
      to: Type.String({
        description: "Target channel name (e.g., 'agent-b', 'worker', 'reviewer')",
      }),
      message: Type.String({
        description: "Message content to send",
      }),
      from: Type.String({
        description: "Your channel name (sender identifier)",
      }),
    }),
    async execute(toolCallId, params, signal, onUpdate, ctx) {
      const { to, message, from } = params;
      const channelDir = join(RELAY_DIR, to);
      mkdirSync(channelDir, { recursive: true });

      const msgFile = join(
        channelDir,
        `${Date.now()}-${from}.json`
      );

      writeFileSync(
        msgFile,
        JSON.stringify(
          {
            from,
            to,
            message,
            timestamp: new Date().toISOString(),
          },
          null,
          2
        )
      );

      return {
        content: [
          {
            type: "text",
            text: `Message sent to '${to}' from '${to}': ${message.substring(0, 200)}...`,
          },
        ],
        details: { file: msgFile },
      };
    },
  });

  // Register receive tool
  pi.registerTool({
    name: "pi-relay-receive",
    label: "Pi Relay Receive",
    description:
      "Check for messages from another pi instance. Returns all unread messages for your channel.",
    parameters: Type.Object({
      channel: Type.String({
        description: "Your channel name (the inbox to check)",
      }),
      markRead: Type.Optional(
        Type.Boolean({
          description: "Delete messages after reading (default: true)",
          default: true,
        })
      ),
    }),
    async execute(toolCallId, params, signal, onUpdate, ctx) {
      const { channel, markRead = true } = params;
      const channelDir = join(RELAY_DIR, channel);

      if (!existsSync(channelDir)) {
        return {
          content: [{ type: "text", text: "No messages." }],
          details: { count: 0 },
        };
      }

      const files = readdirSync(channelDir)
        .filter((f) => f.endsWith(".json"))
        .sort();

      if (files.length === 0) {
        return {
          content: [{ type: "text", text: "No messages." }],
          details: { count: 0 },
        };
      }

      const messages = files.map((f) => {
        const content = readFileSync(join(channelDir, f), "utf-8");
        return JSON.parse(content);
      });

      // Mark as read (delete files)
      if (markRead) {
        for (const f of files) {
          try {
            unlinkSync(join(channelDir, f));
          } catch {
            // ignore
          }
        }
      }

      const summary = messages
        .map(
          (m: any) =>
            `[${m.timestamp}] From ${m.from}: ${m.message}`
        )
        .join("\n\n");

      return {
        content: [
          {
            type: "text",
            text: `${messages.length} message(s):\n\n${summary}`,
          },
        ],
        details: { count: messages.length },
      };
    },
  });

  // Register status tool
  pi.registerTool({
    name: "pi-relay-status",
    label: "Pi Relay Status",
    description: "List all active channels and message counts.",
    parameters: Type.Object({}),
    async execute(toolCallId, params, signal, onUpdate, ctx) {
      if (!existsSync(RELAY_DIR)) {
        return {
          content: [{ type: "text", text: "No active channels." }],
          details: {},
        };
      }

      const channels = readdirSync(RELAY_DIR).filter((f) =>
        require("node:fs")
          .statSync(join(RELAY_DIR, f))
          .isDirectory()
      );

      const status = channels.map((ch) => {
        const chDir = join(RELAY_DIR, ch);
        const count = readdirSync(chDir).filter((f) =>
          f.endsWith(".json")
        ).length;
        return `  ${ch}: ${count} unread`;
      });

      return {
        content: [
          {
            type: "text",
            text:
              channels.length === 0
                ? "No active channels."
                : `Active channels:\n${status.join("\n")}`,
          },
        ],
        details: { channels: channels.length },
      };
    },
  });
}
