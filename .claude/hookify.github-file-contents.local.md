---
name: github-file-contents
enabled: true
event: PreToolUse
tool_matcher: mcp__github__get_file_contents
action: warn
---

**[github-file-contents] Consider File Size First!**

Before fetching file contents, consider:

1. **Do you know the file size?** Large files waste tokens.
2. **Could the Tree API work instead?** For discovery, use:
   ```javascript
   github_get_tree({ owner, repo, tree_sha: "HEAD" })  // ~90% smaller
   ```

**Efficient GitHub workflow:**
```javascript
// Step 1: Get file tree first (small response)
const tree = await github_get_tree({ owner, repo, tree_sha: "HEAD" });

// Step 2: Identify specific files needed
const targetFiles = tree.filter(f => f.path.endsWith('.config.js'));

// Step 3: Fetch only what you need
const content = await github_get_file_contents({ path: targetFiles[0].path });
```

**For comparing changes:**
```javascript
// Use Compare API instead of fetching full files
github_compare({ owner, repo, base: "main", head: "feature" })  // 70-90% savings
```

**Token savings: 70-90% when using tree API for discovery!**