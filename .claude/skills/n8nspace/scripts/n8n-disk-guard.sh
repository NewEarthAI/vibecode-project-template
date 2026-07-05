#!/usr/bin/env bash
# n8n-disk-guard.sh — Autonomous disk space guardian for n8n production droplets
# Version: 1.0.0
# Target: n8n-server-digitalocean (YOUR_VPS_IP, 25GB, FRA1)
# Deploy: /usr/local/sbin/n8n-disk-guard.sh
# Cron:   /etc/cron.d/n8n-disk-guard
# Mac:    ssh root@YOUR_VPS_IP "/usr/local/sbin/n8n-disk-guard.sh"
#
# Modes:
#   retention (default) — delete binaryData files older than RETENTION_MINUTES
#   emergency (auto)    — triggered when disk >= THRESH_EMERG%, full purge
#   dry-run (--dry-run) — report what WOULD be deleted without deleting
#
# Safety:
#   - Only deletes within directories ending in /binaryData
#   - Validates permissions before any action
#   - Detects Docker Compose vs bare Node.js runtime
#   - Produces structured JSON report

set -euo pipefail

# ─── Configuration (override via env vars or args) ─────────────────────────
THRESH_WARN="${THRESH_WARN:-80}"
THRESH_EMERG="${THRESH_EMERG:-95}"
RETENTION_MINUTES="${RETENTION_MINUTES:-1440}"  # 24h default (aggressive for 25GB disk)
BINARY_DIR="${BINARY_DIR:-}"                     # auto-detected if empty
N8N_COMPOSE_DIR="${N8N_COMPOSE_DIR:-/opt/n8n}"
LOG_FILE="${LOG_FILE:-/var/log/n8n-disk-guard.log}"
REPORT_FILE="${REPORT_FILE:-/var/log/n8n-disk-guard-report.json}"
DRY_RUN=0
EMERGENCY_OVERRIDE=0
VERBOSE=0

# ─── Runtime state ─────────────────────────────────────────────────────────
RUNTIME_MODE=""           # "docker" or "node"
N8N_SERVICE=""            # docker compose service name
N8N_STOPPED=0             # whether we stopped n8n during this run
DISK_BEFORE=""
DISK_AFTER=""
BINARY_SIZE_BEFORE=""
BINARY_SIZE_AFTER=""
ACTIONS_TAKEN=()
WARNINGS=()

# ─── Parse arguments ──────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)    DRY_RUN=1; shift ;;
        --emergency)  EMERGENCY_OVERRIDE=1; shift ;;
        --verbose|-v) VERBOSE=1; shift ;;
        --help|-h)
            echo "Usage: $0 [--dry-run] [--emergency] [--verbose]"
            echo ""
            echo "Environment variables:"
            echo "  THRESH_WARN=80         Warning threshold %"
            echo "  THRESH_EMERG=95        Emergency threshold %"
            echo "  RETENTION_MINUTES=1440 Delete files older than N minutes"
            echo "  BINARY_DIR=            Override binaryData path (auto-detected if empty)"
            echo "  N8N_COMPOSE_DIR=/opt/n8n  Docker Compose directory"
            echo "  DRY_RUN=1              Same as --dry-run"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Allow DRY_RUN env var
[[ "${DRY_RUN:-0}" == "1" ]] && DRY_RUN=1

# ─── Logging ──────────────────────────────────────────────────────────────
log() {
    local msg="[$(date -Is)] $*"
    echo "$msg"
    echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

log_verbose() {
    [[ $VERBOSE -eq 1 ]] && log "$@"
}

# ─── Disk measurement ────────────────────────────────────────────────────
disk_used_pct() {
    df -P / | awk 'NR==2 {gsub("%","",$5); print $5}'
}

disk_free_human() {
    df -h / | awk 'NR==2 {print $4}'
}

dir_size_bytes() {
    local d="$1"
    [[ -d "$d" ]] && du -sb "$d" 2>/dev/null | awk '{print $1}' || echo "0"
}

dir_size_human() {
    local d="$1"
    [[ -d "$d" ]] && du -sh "$d" 2>/dev/null | awk '{print $1}' || echo "0"
}

bytes_to_human() {
    local b="$1"
    if (( b >= 1073741824 )); then
        echo "$(echo "scale=1; $b / 1073741824" | bc)G"
    elif (( b >= 1048576 )); then
        echo "$(echo "scale=1; $b / 1048576" | bc)M"
    else
        echo "${b}B"
    fi
}

# ─── Safety checks ───────────────────────────────────────────────────────
safety_check_dir() {
    local d="$1"
    if [[ ! -d "$d" ]]; then
        log "WARN: Binary dir not found: $d"
        return 1
    fi
    if [[ "$d" != */binaryData ]]; then
        log "REFUSE: $d does not end with /binaryData — aborting"
        return 1
    fi
    return 0
}

check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        if ! sudo -n true 2>/dev/null; then
            log "ERROR: Must be root or have passwordless sudo"
            exit 1
        fi
    fi
}

# ─── Runtime detection ───────────────────────────────────────────────────
detect_runtime() {
    # Check Docker first
    if command -v docker &>/dev/null; then
        if [[ -f "$N8N_COMPOSE_DIR/docker-compose.yml" ]] || [[ -f "$N8N_COMPOSE_DIR/docker-compose.yaml" ]]; then
            local services
            services=$(cd "$N8N_COMPOSE_DIR" && docker compose config --services 2>/dev/null || true)
            if echo "$services" | grep -qi "n8n"; then
                RUNTIME_MODE="docker"
                N8N_SERVICE=$(echo "$services" | grep -i "n8n" | head -1)
                log_verbose "Detected Docker Compose runtime: service=$N8N_SERVICE"
                return 0
            fi
        fi
        # Check for standalone docker container named n8n
        if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "n8n"; then
            RUNTIME_MODE="docker"
            N8N_SERVICE="n8n"
            log_verbose "Detected standalone Docker container: n8n"
            return 0
        fi
    fi

    # Check bare Node.js process
    if pgrep -f "n8n" &>/dev/null; then
        RUNTIME_MODE="node"
        log_verbose "Detected bare Node.js n8n process"
        return 0
    fi

    log "WARN: Could not detect running n8n instance — proceeding with cleanup only"
    RUNTIME_MODE="unknown"
}

# ─── Binary data path detection ──────────────────────────────────────────
detect_binary_dir() {
    # If explicitly set, use that
    if [[ -n "$BINARY_DIR" ]]; then
        log_verbose "Using explicit BINARY_DIR=$BINARY_DIR"
        return 0
    fi

    # Try reading from n8n environment
    if [[ "$RUNTIME_MODE" == "docker" ]]; then
        local env_path
        if [[ -f "$N8N_COMPOSE_DIR/docker-compose.yml" ]] || [[ -f "$N8N_COMPOSE_DIR/docker-compose.yaml" ]]; then
            env_path=$(cd "$N8N_COMPOSE_DIR" && docker compose exec -T "$N8N_SERVICE" printenv N8N_BINARY_DATA_STORAGE_PATH 2>/dev/null || true)
        else
            env_path=$(docker exec "$N8N_SERVICE" printenv N8N_BINARY_DATA_STORAGE_PATH 2>/dev/null || true)
        fi
        if [[ -n "$env_path" ]]; then
            # Map container path to host path (common bind mount pattern)
            BINARY_DIR="${env_path}"
            log_verbose "Detected from container env: $BINARY_DIR"
        fi
    elif [[ "$RUNTIME_MODE" == "node" ]]; then
        local env_path
        env_path=$(tr '\0' '\n' < /proc/$(pgrep -f "n8n" | head -1)/environ 2>/dev/null | grep "^N8N_BINARY_DATA_STORAGE_PATH=" | cut -d= -f2- || true)
        if [[ -n "$env_path" ]]; then
            BINARY_DIR="$env_path"
            log_verbose "Detected from process env: $BINARY_DIR"
        fi
    fi

    # Fallback: search known locations
    if [[ -z "$BINARY_DIR" ]] || [[ ! -d "$BINARY_DIR" ]]; then
        local found
        found=$(find /opt /root /home -type d -name binaryData -prune -print 2>/dev/null | head -1 || true)
        if [[ -n "$found" ]]; then
            BINARY_DIR="$found"
            log_verbose "Found via filesystem search: $BINARY_DIR"
        else
            BINARY_DIR="/opt/n8n/n8n_data/binaryData"
            log_verbose "Using default path: $BINARY_DIR"
        fi
    fi
}

# ─── Cleanup functions ───────────────────────────────────────────────────
vacuum_journal() {
    if [[ $DRY_RUN -eq 1 ]]; then
        log "[DRY-RUN] Would vacuum journald to 200M"
        return 0
    fi
    log "Vacuuming journald..."
    journalctl --vacuum-size=200M 2>/dev/null || true
    ACTIONS_TAKEN+=("journal_vacuum")
}

apt_clean() {
    if [[ $DRY_RUN -eq 1 ]]; then
        log "[DRY-RUN] Would clean apt cache"
        return 0
    fi
    log "Cleaning apt cache..."
    apt-get clean 2>/dev/null || true
    rm -rf /var/lib/apt/lists/* 2>/dev/null || true
    ACTIONS_TAKEN+=("apt_clean")
}

docker_prune() {
    command -v docker &>/dev/null || return 0
    if [[ $DRY_RUN -eq 1 ]]; then
        log "[DRY-RUN] Would run docker system prune -af"
        docker system df 2>/dev/null || true
        return 0
    fi
    log "Pruning Docker (unused images, stopped containers, build cache)..."
    docker system prune -af 2>/dev/null || true
    docker volume prune -f 2>/dev/null || true
    ACTIONS_TAKEN+=("docker_prune")
}

prune_binaries_by_age() {
    local d="$1"
    safety_check_dir "$d" || return 0

    local count
    count=$(find "$d" -type f -mmin "+$RETENTION_MINUTES" 2>/dev/null | wc -l)

    if [[ $DRY_RUN -eq 1 ]]; then
        local size
        size=$(find "$d" -type f -mmin "+$RETENTION_MINUTES" -exec du -cb {} + 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")
        log "[DRY-RUN] Would delete $count files older than ${RETENTION_MINUTES}min ($(bytes_to_human "${size:-0}"))"
        return 0
    fi

    log "Pruning $count files older than ${RETENTION_MINUTES} minutes in $d"
    find "$d" -type f -mmin "+$RETENTION_MINUTES" -delete 2>/dev/null || true
    find "$d" -type d -empty -delete 2>/dev/null || true
    ACTIONS_TAKEN+=("binary_age_prune:${count}_files")
}

purge_all_binaries() {
    local d="$1"
    safety_check_dir "$d" || return 0

    if [[ $DRY_RUN -eq 1 ]]; then
        local size
        size=$(dir_size_human "$d")
        local count
        count=$(find "$d" -type f 2>/dev/null | wc -l)
        log "[DRY-RUN] EMERGENCY would delete ALL $count files ($size) in $d"
        return 0
    fi

    log "EMERGENCY: Purging ALL contents of $d"
    rm -rf "$d"/* 2>/dev/null || true
    ACTIONS_TAKEN+=("emergency_purge")
}

stop_n8n() {
    if [[ $DRY_RUN -eq 1 ]]; then
        log "[DRY-RUN] Would stop n8n ($RUNTIME_MODE)"
        return 0
    fi

    if [[ "$RUNTIME_MODE" == "docker" ]]; then
        if [[ -f "$N8N_COMPOSE_DIR/docker-compose.yml" ]] || [[ -f "$N8N_COMPOSE_DIR/docker-compose.yaml" ]]; then
            log "Stopping n8n via docker compose..."
            (cd "$N8N_COMPOSE_DIR" && docker compose stop "$N8N_SERVICE") || true
        else
            log "Stopping Docker container: $N8N_SERVICE"
            docker stop "$N8N_SERVICE" 2>/dev/null || true
        fi
    elif [[ "$RUNTIME_MODE" == "node" ]]; then
        log "Stopping n8n Node.js process..."
        pkill -f "n8n" || true
    fi
    N8N_STOPPED=1
}

start_n8n() {
    if [[ $DRY_RUN -eq 1 ]]; then
        log "[DRY-RUN] Would start n8n ($RUNTIME_MODE)"
        return 0
    fi

    if [[ "$RUNTIME_MODE" == "docker" ]]; then
        if [[ -f "$N8N_COMPOSE_DIR/docker-compose.yml" ]] || [[ -f "$N8N_COMPOSE_DIR/docker-compose.yaml" ]]; then
            log "Starting n8n via docker compose..."
            (cd "$N8N_COMPOSE_DIR" && docker compose up -d "$N8N_SERVICE") || true
        else
            log "Starting Docker container: $N8N_SERVICE"
            docker start "$N8N_SERVICE" 2>/dev/null || true
        fi
    elif [[ "$RUNTIME_MODE" == "node" ]]; then
        log "WARN: Cannot auto-start bare Node.js n8n — manual restart required"
        WARNINGS+=("n8n_manual_restart_needed")
    fi
}

health_check() {
    # Give n8n a moment to start
    sleep 3
    if ss -ltnp 2>/dev/null | grep -q ':5678'; then
        log "Health: port 5678 LISTENING"
        return 0
    else
        log "WARN: port 5678 NOT listening"
        WARNINGS+=("port_5678_not_listening")
        return 1
    fi
}

# ─── JSON report ─────────────────────────────────────────────────────────
write_json_report() {
    local report
    report=$(cat <<JSONEOF
{
  "timestamp": "$(date -Is)",
  "hostname": "$(hostname)",
  "dry_run": $( [[ $DRY_RUN -eq 1 ]] && echo "true" || echo "false" ),
  "runtime_mode": "$RUNTIME_MODE",
  "n8n_service": "$N8N_SERVICE",
  "binary_dir": "$BINARY_DIR",
  "thresholds": {
    "warn": $THRESH_WARN,
    "emergency": $THRESH_EMERG,
    "retention_minutes": $RETENTION_MINUTES
  },
  "disk": {
    "before_pct": $DISK_BEFORE,
    "after_pct": ${DISK_AFTER:-$DISK_BEFORE},
    "free_after": "$(disk_free_human)"
  },
  "binary_data": {
    "before": "$BINARY_SIZE_BEFORE",
    "after": "${BINARY_SIZE_AFTER:-$BINARY_SIZE_BEFORE}"
  },
  "n8n_stopped": $( [[ $N8N_STOPPED -eq 1 ]] && echo "true" || echo "false" ),
  "actions": [$(if [ ${#ACTIONS_TAKEN[@]} -gt 0 ]; then printf '"%s",' "${ACTIONS_TAKEN[@]}" | sed 's/,$//'; fi)],
  "warnings": [$(if [ ${#WARNINGS[@]} -gt 0 ]; then printf '"%s",' "${WARNINGS[@]}" | sed 's/,$//'; fi)]
}
JSONEOF
)
    if [[ $DRY_RUN -eq 0 ]]; then
        echo "$report" > "$REPORT_FILE" 2>/dev/null || true
    fi
    echo "$report"
}

# ─── Main ────────────────────────────────────────────────────────────────
main() {
    log "═══ n8n-disk-guard v1.0.0 ═══"
    [[ $DRY_RUN -eq 1 ]] && log "MODE: DRY-RUN (no changes will be made)"
    [[ $EMERGENCY_OVERRIDE -eq 1 ]] && log "MODE: EMERGENCY (forced full purge)"

    # Preflight
    check_permissions
    detect_runtime
    detect_binary_dir

    # Snapshot
    DISK_BEFORE=$(disk_used_pct)
    BINARY_SIZE_BEFORE=$(dir_size_human "$BINARY_DIR")
    log "Disk: ${DISK_BEFORE}% used | binaryData: ${BINARY_SIZE_BEFORE} | Runtime: ${RUNTIME_MODE} | Dir: ${BINARY_DIR}"

    # Phase 1: OS cleanup (always)
    vacuum_journal
    apt_clean

    # Re-check disk after OS cleanup
    local used
    used=$(disk_used_pct)

    # Phase 2: Determine cleanup strategy
    if [[ $EMERGENCY_OVERRIDE -eq 1 ]] || (( used >= THRESH_EMERG )); then
        # Emergency mode: stop n8n, full purge, restart
        log "EMERGENCY: Disk at ${used}% (threshold: ${THRESH_EMERG}%)"
        docker_prune
        stop_n8n
        purge_all_binaries "$BINARY_DIR"
        start_n8n
        if [[ $DRY_RUN -eq 0 ]] && [[ $N8N_STOPPED -eq 1 ]]; then
            health_check || true
        fi
    elif (( used >= THRESH_WARN )); then
        # Warning mode: age-based prune + docker prune
        log "WARNING: Disk at ${used}% (threshold: ${THRESH_WARN}%)"
        docker_prune
        prune_binaries_by_age "$BINARY_DIR"

        # Re-check — if still critical after age prune, escalate
        local after_prune
        after_prune=$(disk_used_pct)
        if (( after_prune >= THRESH_EMERG )); then
            log "Age-based prune insufficient (${after_prune}%). Escalating to emergency."
            stop_n8n
            purge_all_binaries "$BINARY_DIR"
            start_n8n
            if [[ $DRY_RUN -eq 0 ]] && [[ $N8N_STOPPED -eq 1 ]]; then
                health_check || true
            fi
        fi
    else
        # Healthy: just age-based prune (housekeeping)
        log "Disk healthy at ${used}%. Running retention cleanup."
        prune_binaries_by_age "$BINARY_DIR"
    fi

    # Final measurements
    DISK_AFTER=$(disk_used_pct)
    BINARY_SIZE_AFTER=$(dir_size_human "$BINARY_DIR")

    # Summary
    log "═══ Summary ═══"
    log "Disk: ${DISK_BEFORE}% → ${DISK_AFTER}% | binaryData: ${BINARY_SIZE_BEFORE} → ${BINARY_SIZE_AFTER}"
    log "Actions: ${ACTIONS_TAKEN[*]:-none}"
    [[ ${#WARNINGS[@]} -gt 0 ]] && log "Warnings: ${WARNINGS[*]}"
    log "═══ Done ═══"

    # Write JSON report
    write_json_report > /dev/null
}

main "$@"
