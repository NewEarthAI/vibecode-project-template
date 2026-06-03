---
name: playwright-full-page
enabled: true
event: PreToolUse
tool_matcher: mcp__plugin_playwright_playwright__browser_take_screenshot|mcp__playwright__browser_take_screenshot|mcp__chrome-devtools__take_screenshot
action: block
conditions:
  - field: fullPage
    operator: equals
    pattern: true
---

**[BLOCKED] fullPage=true captures the entire document — often 50-200KB**

Full-page screenshots are rarely necessary for debugging or development tasks. Use a targeted approach instead:

**Better alternatives:**
- `browser_take_screenshot()` — viewport only (~10-50KB)
- `browser_take_screenshot({ ref: "element-id" })` — specific element (smallest)
- `browser_snapshot()` — accessibility tree (~5KB, best for interaction planning)
- `chrome-devtools take_snapshot` — DOM snapshot (structured, token-efficient)

**When fullPage IS appropriate (CONTEXT_APPROVAL required):**
- Visual regression testing that requires the full rendered page
- Archival/documentation of full page layout
- Debugging layout issues that appear below the fold

**Fix your call:**
```
browser_take_screenshot()  // viewport only, no fullPage param
```

**Token savings: 50-80% with viewport or element screenshots**
