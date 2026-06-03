#!/usr/bin/env python3
"""SessionStart hook executor for hookify plugin.

New in v0.1.1: Loads SessionStart rules and outputs their messages as additionalContext.
"""

import os
import sys
import json

PLUGIN_ROOT = os.environ.get('CLAUDE_PLUGIN_ROOT')
if PLUGIN_ROOT:
    parent_dir = os.path.dirname(PLUGIN_ROOT)
    if parent_dir not in sys.path:
        sys.path.insert(0, parent_dir)
    if PLUGIN_ROOT not in sys.path:
        sys.path.insert(0, PLUGIN_ROOT)

try:
    from core.config_loader import load_rules
except ImportError as e:
    # If imports fail, output empty result and exit cleanly
    print(json.dumps({}), file=sys.stdout)
    sys.exit(0)


def main():
    try:
        # SessionStart has no stdin input — just load rules
        rules = load_rules(events=['SessionStart'])

        if not rules:
            print(json.dumps({}), file=sys.stdout)
            sys.exit(0)

        # Combine all SessionStart rule messages into additionalContext
        messages = []
        for rule in rules:
            if rule.enabled and rule.message:
                messages.append(rule.message)

        if messages:
            combined = "\n\n".join(messages)
            result = {
                "hookSpecificOutput": {
                    "hookEventName": "SessionStart",
                    "additionalContext": combined
                }
            }
            print(json.dumps(result), file=sys.stdout)
        else:
            print(json.dumps({}), file=sys.stdout)

    except Exception as e:
        # On error, output empty result — never block session start
        print(json.dumps({}), file=sys.stdout)

    finally:
        sys.exit(0)


if __name__ == '__main__':
    main()
