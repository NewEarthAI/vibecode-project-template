#!/usr/bin/env bash
# =============================================================================
# safe-bash task: n8n_export_workflow
# Export n8n workflow JSON, canonically normalize, compute sha256
# Usage: ./n8n_export_workflow.sh <workflow_id> [output_dir]
# Requires: N8N_BASE_URL, N8N_API_KEY env vars
# =============================================================================
set -euo pipefail

WORKFLOW_ID="${1:?Usage: $0 <workflow_id> [output_dir]}"
OUTPUT_DIR="${2:-n8n-workflows}"
AUDIT_LOG="${SAFE_BASH_AUDIT_LOG:-.claude/safe-bash-audit.jsonl}"

# --- Env validation ---
if [ -z "${N8N_BASE_URL:-}" ]; then
  echo "ERROR: N8N_BASE_URL not set" >&2
  echo "Set: export N8N_BASE_URL=https://your-instance.app.n8n.cloud/api/v1" >&2
  exit 1
fi
if [ -z "${N8N_API_KEY:-}" ]; then
  echo "ERROR: N8N_API_KEY not set" >&2
  echo "Set: export N8N_API_KEY=your-api-key" >&2
  exit 1
fi

# --- Arg validation (reject metacharacters in workflow_id) ---
if [[ "$WORKFLOW_ID" =~ [\`\$\|\;\>\<\&\(\)\{\}] ]]; then
  echo "ERROR: Invalid characters in workflow_id" >&2
  exit 2
fi

# --- Fetch workflow ---
START_MS=$(($(date +%s) * 1000))
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

HTTP_CODE=$(curl -s -o "$TMPFILE" -w "%{http_code}" \
  "${N8N_BASE_URL}/workflows/${WORKFLOW_ID}" \
  -H "X-N8N-API-KEY: ${N8N_API_KEY}")

if [ "$HTTP_CODE" != "200" ]; then
  echo "ERROR: n8n API returned HTTP $HTTP_CODE" >&2
  cat "$TMPFILE" >&2
  exit 3
fi

# --- Canonical normalization: sorted keys, 2-space indent ---
mkdir -p "$OUTPUT_DIR"
OUTPUT_FILE="${OUTPUT_DIR}/${WORKFLOW_ID}.json"
jq -S '.' "$TMPFILE" > "$OUTPUT_FILE"

# --- Compute sha256 ---
HASH=$(sha256sum "$OUTPUT_FILE" | cut -d' ' -f1)
END_MS=$(($(date +%s) * 1000))
DURATION=$((END_MS - START_MS))

# --- Audit log ---
WORKFLOW_NAME=$(jq -r '.name // "unknown"' "$OUTPUT_FILE")
mkdir -p "$(dirname "$AUDIT_LOG")"
cat >> "$AUDIT_LOG" <<AUDIT_EOF
{"timestamp":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","task":"n8n_export_workflow","args":["${WORKFLOW_ID}","${OUTPUT_DIR}"],"cwd":"$(pwd)","env_keys":["N8N_BASE_URL","N8N_API_KEY"],"exit_code":0,"modified_files":[{"path":"${OUTPUT_FILE}","sha256":"${HASH}"}],"duration_ms":${DURATION}}
AUDIT_EOF

# --- Output ---
echo "Exported: ${OUTPUT_FILE}"
echo "Name: ${WORKFLOW_NAME}"
echo "SHA256: ${HASH}"
echo "Lines: $(wc -l < "$OUTPUT_FILE")"
