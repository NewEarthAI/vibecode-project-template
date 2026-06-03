#!/usr/bin/env python3
"""Rule evaluation engine for hookify plugin.

v0.1.2 (2026-03-03): fnmatch wildcards, OR combinator, not_exists/not_equals/
contains_any/regex operators, context_rules separation, proper no-matcher guard.
"""

import fnmatch
import re
import sys
from functools import lru_cache
from typing import List, Dict, Any, Optional

# Import from local module
from core.config_loader import Rule, Condition


# Cache compiled regexes (max 128 patterns)
@lru_cache(maxsize=128)
def compile_regex(pattern: str) -> re.Pattern:
    """Compile regex pattern with caching."""
    return re.compile(pattern, re.IGNORECASE)


class RuleEngine:
    """Evaluates rules against hook input data."""

    def __init__(self):
        pass

    def evaluate_rules(self, rules: List[Rule], input_data: Dict[str, Any]) -> Dict[str, Any]:
        """Evaluate all rules and return combined results.

        Priority: block > context > warn. All matching messages combined.
        Context rules get clean messages (no [name] prefix).
        """
        hook_event = input_data.get('hook_event_name', '')
        blocking_rules = []
        warning_rules = []
        context_rules = []

        for rule in rules:
            if self._rule_matches(rule, input_data):
                if rule.action == 'block':
                    blocking_rules.append(rule)
                elif rule.action == 'addContext':
                    context_rules.append(rule)
                else:
                    warning_rules.append(rule)

        # If any blocking rules matched, block the operation
        if blocking_rules:
            messages = [f"**[{r.name}]**\n{r.message}" for r in blocking_rules]
            combined_message = "\n\n".join(messages)

            if hook_event == 'Stop':
                return {
                    "decision": "block",
                    "reason": combined_message,
                    "systemMessage": combined_message
                }
            elif hook_event in ['PreToolUse', 'PostToolUse']:
                return {
                    "hookSpecificOutput": {
                        "hookEventName": hook_event,
                        "permissionDecision": "deny"
                    },
                    "systemMessage": combined_message
                }
            else:
                return {
                    "systemMessage": combined_message
                }

        # Combine warnings (with name prefix) and context (clean)
        all_messages = []
        if warning_rules:
            all_messages.extend([f"**[{r.name}]**\n{r.message}" for r in warning_rules])
        if context_rules:
            all_messages.extend([r.message for r in context_rules])

        if all_messages:
            return {
                "systemMessage": "\n\n".join(all_messages)
            }

        # No matches - allow operation
        return {}

    def _rule_matches(self, rule: Rule, input_data: Dict[str, Any]) -> bool:
        """Check if rule matches input data.

        A rule matches when:
        1. tool_matcher matches the tool_name (if specified), AND
        2. All conditions match (if specified), using combinator logic.

        If only tool_matcher is specified (no conditions), the match is based
        on tool_matcher alone. If neither is specified, the rule does not match.
        """
        tool_name = input_data.get('tool_name', '')
        tool_input = input_data.get('tool_input', {})

        # Check tool matcher if specified
        if rule.tool_matcher:
            if not self._matches_tool(rule.tool_matcher, tool_name):
                return False
        else:
            # For non-tool events (Stop, SessionStart, UserPromptSubmit),
            # rules with no tool_matcher and no conditions match unconditionally
            # — they're already filtered by event type in load_rules().
            # Only reject empty rules for tool-scoped events.
            if not rule.conditions:
                hook_event = input_data.get('hook_event_name', '')
                if hook_event in ('PreToolUse', 'PostToolUse'):
                    return False
                # Stop/SessionStart/UserPromptSubmit: match unconditionally
                return True

        # If no conditions, match on tool_matcher alone
        if not rule.conditions:
            return True

        # Evaluate conditions with combinator (default: AND)
        combinator = getattr(rule, 'combinator', 'and')

        if combinator == 'or':
            return any(
                self._check_condition(c, tool_name, tool_input, input_data)
                for c in rule.conditions
            )
        else:
            return all(
                self._check_condition(c, tool_name, tool_input, input_data)
                for c in rule.conditions
            )

    def _matches_tool(self, matcher: str, tool_name: str) -> bool:
        """Check if tool_name matches the matcher pattern.

        Supports:
        - Exact match: "Bash", "mcp__github__get_file_contents"
        - OR matching: "Edit|Write|NotebookEdit"
        - Glob wildcards: "mcp__supabase-*__execute_sql"
        - Regex-style .*: "mcp__n8n-mcp-.*__n8n_delete_workflow"
          (normalized to glob * before matching)
        - Universal: "*"
        """
        if matcher == '*':
            return True

        # Split on | for OR matching
        for pattern in matcher.split('|'):
            # Normalize regex-style .* to glob-style *
            glob_pattern = pattern.replace('.*', '*')

            if '*' in glob_pattern or '?' in glob_pattern:
                if fnmatch.fnmatch(tool_name, glob_pattern):
                    return True
            elif pattern == tool_name:
                return True

        return False

    def _check_condition(self, condition: Condition, tool_name: str,
                        tool_input: Dict[str, Any], input_data: Dict[str, Any] = None) -> bool:
        """Check if a single condition matches."""
        field_value = self._extract_field(condition.field, tool_name, tool_input, input_data)

        operator = condition.operator
        pattern = condition.pattern

        # Handle existence operators BEFORE null check
        if operator == 'not_exists':
            return field_value is None or field_value == ''
        if operator == 'exists':
            return field_value is not None and field_value != ''

        # For all other operators, None means field not found = no match
        if field_value is None:
            return False

        if operator in ('regex_match', 'regex'):
            return self._regex_match(pattern, field_value)
        elif operator == 'contains':
            return pattern in field_value
        elif operator == 'equals':
            return str(pattern) == str(field_value)
        elif operator == 'not_contains':
            return pattern not in field_value
        elif operator == 'not_equals':
            return str(pattern) != str(field_value)
        elif operator == 'starts_with':
            return field_value.startswith(pattern)
        elif operator == 'ends_with':
            return field_value.endswith(pattern)
        elif operator == 'contains_any':
            # Comma-separated list of patterns - match if any is found
            patterns = [p.strip() for p in pattern.split(',')]
            return any(p in field_value for p in patterns)
        else:
            print(f"Warning: Unknown operator '{operator}' in condition", file=sys.stderr)
            return False

    def _extract_field(self, field: str, tool_name: str,
                      tool_input: Dict[str, Any], input_data: Dict[str, Any] = None) -> Optional[str]:
        """Extract field value from tool input or hook input data."""
        # Direct tool_input fields
        if field in tool_input:
            value = tool_input[field]
            if isinstance(value, str):
                return value
            return str(value)

        # For Stop events and other non-tool events, check input_data
        if input_data:
            if field == 'reason':
                return input_data.get('reason', '')
            elif field == 'transcript':
                transcript_path = input_data.get('transcript_path')
                if transcript_path:
                    try:
                        with open(transcript_path, 'r') as f:
                            return f.read()
                    except (FileNotFoundError, PermissionError, IOError, OSError, UnicodeDecodeError) as e:
                        print(f"Warning: Error reading transcript {transcript_path}: {e}", file=sys.stderr)
                        return ''
            elif field == 'user_prompt':
                return input_data.get('user_prompt', '')

        # Handle special cases by tool type
        if tool_name == 'Bash':
            if field == 'command':
                return tool_input.get('command', '')

        elif tool_name in ['Write', 'Edit']:
            if field == 'content':
                return tool_input.get('content') or tool_input.get('new_string', '')
            elif field in ('new_text', 'new_string'):
                return tool_input.get('new_string', '')
            elif field in ('old_text', 'old_string'):
                return tool_input.get('old_string', '')
            elif field == 'file_path':
                return tool_input.get('file_path', '')

        elif tool_name == 'MultiEdit':
            if field == 'file_path':
                return tool_input.get('file_path', '')
            elif field in ('new_text', 'content'):
                edits = tool_input.get('edits', [])
                return ' '.join(e.get('new_string', '') for e in edits)

        return None

    def _regex_match(self, pattern: str, text: str) -> bool:
        """Check if pattern matches text using regex."""
        try:
            regex = compile_regex(pattern)
            return bool(regex.search(text))
        except re.error as e:
            print(f"Invalid regex pattern '{pattern}': {e}", file=sys.stderr)
            return False
