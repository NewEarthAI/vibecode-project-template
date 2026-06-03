#!/usr/bin/env bash
# ============================================================================
# bootstrap.sh — Zero-friction MCP setup for any Mac
#
# Usage: ./bootstrap.sh              (prompts for each credential)
#        ./bootstrap.sh --refresh    (re-resolve paths only, keep credentials)
#        ./bootstrap.sh --verify     (check all MCP servers are configured)
#
# Creates ~/.mcp.json from .mcp.template.json with:
#   - Dynamic binary paths (npx, node, uvx) resolved at runtime
#   - Credentials stored in ~/.env.nirvana (never committed to git)
#
# Layer 2 upgrade (future): add 1Password CLI support behind `op` check
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="${SCRIPT_DIR}/.mcp.template.json"
ENV_FILE="${HOME}/.env.nirvana"
OUTPUT="${HOME}/.mcp.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail()  { echo -e "${RED}[FAIL]${NC} $1"; exit 1; }

# ── Resolve binary paths ──────────────────────────────────────────────────
resolve_paths() {
  info "Resolving binary paths..."

  NPX_PATH=$(which npx 2>/dev/null || true)
  NODE_PATH=$(which node 2>/dev/null || true)
  UVX_PATH=$(which uvx 2>/dev/null || true)
  NPM_GLOBAL_ROOT=$(npm root -g 2>/dev/null || true)

  [[ -z "$NPX_PATH" ]]  && fail "npx not found. Install Node.js via nvm first."
  [[ -z "$NODE_PATH" ]]  && fail "node not found. Install Node.js via nvm first."
  [[ -z "$UVX_PATH" ]]   && warn "uvx not found. Redis MCP server won't work. Install: pip install uvx"

  ok "npx:  $NPX_PATH"
  ok "node: $NODE_PATH"
  [[ -n "$UVX_PATH" ]] && ok "uvx:  $UVX_PATH" || true
  ok "npm global: $NPM_GLOBAL_ROOT"
  echo ""
}

# ── Check prerequisite binaries ───────────────────────────────────────────
check_prerequisites() {
  info "Checking global npm packages..."

  local chrome_mcp="${NPM_GLOBAL_ROOT}/chrome-devtools-mcp/build/src/bin/chrome-devtools-mcp.js"
  local playwright_mcp="${NPM_GLOBAL_ROOT}/@playwright/mcp/cli.js"

  if [[ ! -f "$chrome_mcp" ]]; then
    warn "chrome-devtools-mcp not installed globally."
    echo "  Fix: npm install -g chrome-devtools-mcp"
  else
    ok "chrome-devtools-mcp found"
  fi

  if [[ ! -f "$playwright_mcp" ]]; then
    warn "@playwright/mcp not installed globally."
    echo "  Fix: npm install -g @playwright/mcp"
  else
    ok "@playwright/mcp found"
  fi

  if [[ ! -f "${HOME}/bin/github-mcp-server" ]]; then
    warn "github-mcp-server not found at ~/bin/github-mcp-server"
    echo "  Fix: Download from https://github.com/github/github-mcp-server/releases"
    echo "       Place binary at ~/bin/github-mcp-server && chmod +x ~/bin/github-mcp-server"
  else
    ok "github-mcp-server found"
  fi
  echo ""
}

# ── Prompt for a credential ───────────────────────────────────────────────
prompt_credential() {
  local var_name="$1"
  local description="$2"
  local current_value="${3:-}"

  if [[ -n "$current_value" ]]; then
    echo -e "  ${GREEN}${var_name}${NC}: [already set — press Enter to keep, or paste new value]"
    read -r -s new_value
    if [[ -n "$new_value" ]]; then
      eval "export ${var_name}='${new_value}'"
    else
      eval "export ${var_name}='${current_value}'"
    fi
  else
    echo -e "  ${YELLOW}${var_name}${NC}: ${description}"
    read -r -s value
    echo ""
    if [[ -z "$value" ]]; then
      fail "${var_name} cannot be empty. Aborting."
    fi
    eval "export ${var_name}='${value}'"
  fi
}

# ── Load existing credentials if available ────────────────────────────────
load_existing_credentials() {
  if [[ -f "$ENV_FILE" ]]; then
    info "Loading existing credentials from ${ENV_FILE}..."
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    ok "Loaded $(grep -c '=' "$ENV_FILE" 2>/dev/null || echo 0) credentials"
    echo ""
    return 0
  fi
  return 1
}

# ── Collect credentials ───────────────────────────────────────────────────
collect_credentials() {
  info "Enter credentials (paste each value, then press Enter):"
  info "Tip: Copy from your password manager — values are hidden as you type."
  echo ""

  prompt_credential "REDIS_PASSWORD" \
    "Redis Cloud password (for redis-nirvana)" \
    "${REDIS_PASSWORD:-}"

  prompt_credential "N8N_API_KEY_HONEYBIRD" \
    "n8n API key for Honeybird instance" \
    "${N8N_API_KEY_HONEYBIRD:-}"

  prompt_credential "N8N_API_KEY_NEWEARTHAI" \
    "n8n API key for NewEarth AI instance (n8n.newearthai.agency)" \
    "${N8N_API_KEY_NEWEARTHAI:-}"

  prompt_credential "AIRTABLE_API_KEY" \
    "Airtable personal access token" \
    "${AIRTABLE_API_KEY:-}"

  prompt_credential "SUPABASE_ACCESS_TOKEN_NIRVANA" \
    "Supabase PAT for Nirvana (rikkwehjqcgtraxtkcpo)" \
    "${SUPABASE_ACCESS_TOKEN_NIRVANA:-}"

  prompt_credential "SUPABASE_ACCESS_TOKEN_BUYBOXAI" \
    "Supabase PAT for BuyBox AI (rkjbdjxihppklvlbfywp)" \
    "${SUPABASE_ACCESS_TOKEN_BUYBOXAI:-}"

  prompt_credential "SUPABASE_ACCESS_TOKEN_NEWEARTHAI" \
    "Supabase PAT for NewEarth AI (ridqdojzjotlvexfuwvx)" \
    "${SUPABASE_ACCESS_TOKEN_NEWEARTHAI:-}"

  prompt_credential "GITHUB_PAT" \
    "GitHub personal access token" \
    "${GITHUB_PAT:-}"

  echo ""
}

# ── Save credentials to ~/.env.nirvana ────────────────────────────────────
save_credentials() {
  info "Saving credentials to ${ENV_FILE}..."
  cat > "$ENV_FILE" << ENVEOF
# MCP Credentials — generated by bootstrap.sh on $(date +%Y-%m-%d)
# NEVER commit this file. It is gitignored.
REDIS_PASSWORD='${REDIS_PASSWORD}'
N8N_API_KEY_HONEYBIRD='${N8N_API_KEY_HONEYBIRD}'
N8N_API_KEY_NEWEARTHAI='${N8N_API_KEY_NEWEARTHAI}'
AIRTABLE_API_KEY='${AIRTABLE_API_KEY}'
SUPABASE_ACCESS_TOKEN_NIRVANA='${SUPABASE_ACCESS_TOKEN_NIRVANA}'
SUPABASE_ACCESS_TOKEN_BUYBOXAI='${SUPABASE_ACCESS_TOKEN_BUYBOXAI}'
SUPABASE_ACCESS_TOKEN_NEWEARTHAI='${SUPABASE_ACCESS_TOKEN_NEWEARTHAI}'
GITHUB_PAT='${GITHUB_PAT}'
ENVEOF
  chmod 600 "$ENV_FILE"
  ok "Credentials saved (chmod 600)"
}

# ── Generate ~/.mcp.json from template ────────────────────────────────────
generate_mcp_json() {
  info "Generating ${OUTPUT} from template..."

  if [[ ! -f "$TEMPLATE" ]]; then
    fail "Template not found: ${TEMPLATE}"
  fi

  # Export ALL variables needed by envsubst (paths + credentials)
  export NPX_PATH NODE_PATH UVX_PATH NPM_GLOBAL_ROOT HOME
  export REDIS_PASSWORD N8N_API_KEY_HONEYBIRD N8N_API_KEY_NEWEARTHAI
  export AIRTABLE_API_KEY SUPABASE_ACCESS_TOKEN_NIRVANA
  export SUPABASE_ACCESS_TOKEN_BUYBOXAI SUPABASE_ACCESS_TOKEN_NEWEARTHAI
  export GITHUB_PAT

  # envsubst replaces ${VAR} patterns in the template
  # Only substitute our known variables (prevents replacing unrelated ${} patterns)
  local VARS='${NPX_PATH} ${NODE_PATH} ${UVX_PATH} ${NPM_GLOBAL_ROOT} ${HOME}'
  VARS+=' ${REDIS_PASSWORD} ${N8N_API_KEY_HONEYBIRD} ${N8N_API_KEY_NEWEARTHAI}'
  VARS+=' ${AIRTABLE_API_KEY} ${SUPABASE_ACCESS_TOKEN_NIRVANA}'
  VARS+=' ${SUPABASE_ACCESS_TOKEN_BUYBOXAI} ${SUPABASE_ACCESS_TOKEN_NEWEARTHAI}'
  VARS+=' ${GITHUB_PAT}'
  envsubst "$VARS" < "$TEMPLATE" > "$OUTPUT"
  chmod 600 "$OUTPUT"
  ok "Generated ${OUTPUT} (chmod 600)"
}

# ── Verify output ─────────────────────────────────────────────────────────
verify_output() {
  info "Verifying generated config..."

  # Check JSON is valid
  if ! python3 -c "import json; json.load(open('${OUTPUT}'))" 2>/dev/null; then
    fail "Generated ${OUTPUT} is not valid JSON!"
  fi
  ok "Valid JSON"

  # Check no unsubstituted placeholders remain
  if grep -q '${' "$OUTPUT"; then
    warn "Unsubstituted placeholders found:"
    grep -o '\${[^}]*}' "$OUTPUT" | sort -u | while read -r p; do
      echo "  - $p"
    done
    fail "Some placeholders were not replaced. Check your credentials."
  fi
  ok "All placeholders resolved"

  # Check no empty credential values
  local empty_count
  empty_count=$(python3 -c "
import json
c = json.load(open('${OUTPUT}'))
empty = 0
for name, srv in c.get('mcpServers', {}).items():
    for k, v in srv.get('env', {}).items():
        if not v or v.strip() == '':
            print(f'  Empty: {name}.env.{k}')
            empty += 1
    for a in srv.get('args', []):
        if a == '':
            print(f'  Empty arg in: {name}')
            empty += 1
print(empty)
" 2>/dev/null | tail -1)

  if [[ "$empty_count" != "0" ]]; then
    fail "Empty credential values detected. Re-run bootstrap.sh."
  fi
  ok "No empty values"

  # Count servers
  local server_count
  server_count=$(python3 -c "import json; print(len(json.load(open('${OUTPUT}')).get('mcpServers', {})))")
  ok "${server_count} MCP servers configured"
  echo ""
}

# ── Main ──────────────────────────────────────────────────────────────────
main() {
  echo ""
  echo "========================================"
  echo "  MCP Bootstrap — NewEarth AI"
  echo "========================================"
  echo ""

  # Check template exists
  [[ -f "$TEMPLATE" ]] || fail "Template not found: ${TEMPLATE}. Run this from the repo root."

  # Resolve paths (always, even on --refresh)
  resolve_paths
  check_prerequisites

  if [[ "${1:-}" == "--verify" ]]; then
    if [[ -f "$OUTPUT" ]]; then
      verify_output
      ok "Verification complete!"
    else
      fail "No ${OUTPUT} found. Run bootstrap.sh first."
    fi
    exit 0
  fi

  # Load or collect credentials
  if [[ "${1:-}" == "--refresh" ]]; then
    if load_existing_credentials; then
      info "Refreshing paths only (keeping existing credentials)..."
    else
      fail "No existing credentials found at ${ENV_FILE}. Run bootstrap.sh without --refresh first."
    fi
  else
    load_existing_credentials || true
    collect_credentials
    save_credentials
  fi

  # Generate and verify
  generate_mcp_json
  verify_output

  echo -e "${GREEN}========================================"
  echo "  Setup complete!"
  echo "========================================"
  echo ""
  echo "  Config:      ${OUTPUT}"
  echo "  Credentials: ${ENV_FILE}"
  echo ""
  echo "  Next: Restart Cursor / Claude Code"
  echo "  Verify: ./bootstrap.sh --verify"
  echo "========================================${NC}"
  echo ""
}

main "$@"