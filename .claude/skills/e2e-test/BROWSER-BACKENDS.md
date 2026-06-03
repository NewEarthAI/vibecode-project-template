---
name: browser-backends
description: Browser backend operation mapping for e2e-test skill (loaded on demand)
parent_skill: e2e-test
---

# Browser Backend Operation Mapping

| Operation | Chrome DevTools MCP | Playwright MCP | agent-browser CLI |
|---|---|---|---|
| Navigate | `navigate_page(url)` | `browser_navigate(url)` | `agent-browser open <url>` |
| Snapshot | `take_snapshot()` | `browser_snapshot()` | `agent-browser snapshot -i` |
| Screenshot | `take_screenshot(filePath)` | `browser_take_screenshot(filename)` | `agent-browser screenshot <path>` |
| Click | `click(uid)` | `browser_click(ref)` | `agent-browser click @eN` |
| Fill field | `fill(uid, value)` | `browser_type(ref, text)` | `agent-browser fill @eN "text"` |
| Fill form | `fill_form(elements)` | `browser_fill_form(fields)` | (multiple fill) |
| Wait | `wait_for(text)` | `browser_wait_for(text)` | `agent-browser wait --text "..."` |
| Dialog | `handle_dialog(action)` | `browser_handle_dialog(accept)` | `agent-browser dialog accept` |
| JS eval | `evaluate_script(fn)` | `browser_evaluate(code)` | `agent-browser eval "..."` |
| Console | `list_console_messages()` | `browser_console_messages()` | `agent-browser console` |
| Network | `list_network_requests()` | `browser_network_requests()` | `agent-browser network` |
| Resize | `resize_page(w, h)` | -- | `agent-browser set viewport W H` |
| Emulate | `emulate(colorScheme, viewport)` | -- | `agent-browser set media dark` |
| Perf trace | `performance_start_trace/stop/analyze` | -- | -- |
| Memory | `take_memory_snapshot()` | -- | -- |

## Backend-Specific Advantages

- **Chrome DevTools**: Perf tracing, memory snapshots, emulation, native MCP structured responses
- **Playwright**: Lovable Cloud integration (built-in to IDE)
- **agent-browser**: Self-installing, semantic locators, video recording
