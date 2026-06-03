# n8n Security Module

> Deep n8n workflow security checks. Referenced by newearthai-security-review Tier 4.

## Webhook Authentication

All webhook nodes accepting external input MUST have authentication:

| Method | How | When |
|--------|-----|------|
| Shared secret | Header check in first Code node | Simple integrations |
| HMAC signature | Compute HMAC, compare to header | Payment webhooks (Stripe) |
| IP allowlist | Check `$input.item.json.headers['x-forwarded-for']` | Known partners |

**CRITICAL**: Unauthenticated webhooks accepting untrusted data that writes to DB = injection vector.

## Code Node Security

| Check | Severity | Pattern |
|-------|----------|---------|
| `eval()` or `new Function()` | CRITICAL | Dynamic code execution from input |
| Credentials in code | CRITICAL | API keys, tokens hardcoded in Code node |
| Unsanitized input in SQL | CRITICAL | `$json.field` directly in query string |
| `console.log` with secrets | HIGH | Credential values in execution logs |

### Sandbox Limitations
- `fetch()` is NOT available in n8n Cloud
- Use HTTP Request node for external calls
- `require('crypto')`, `Buffer`, `URL` ARE available

## HTTP Request Node

- Never put secrets in URL parameters (use headers)
- Be aware: HTTP Request node REPLACES `$json` with response
- Downstream nodes needing upstream data must use `$('UpstreamCodeNode').first().json`

## Credential Handling

- Never log credential values
- Never expose credentials in webhook responses
- Use n8n credential store, not Code node variables
- Rotate credentials on suspected exposure

## Workflow-Level Checks

- Error workflows should NOT expose internal data
- Production workflows should have error handling branches
- Sensitive data should not persist in execution logs longer than necessary
