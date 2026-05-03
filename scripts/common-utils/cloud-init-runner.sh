#!/usr/bin/env bash
set -euo pipefail

#
# Cloud-Init Setup Orchestrator
# Coordinates diagnostics collection, log upload to S3, and Discord notifications
#

# Script directory and configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$SCRIPT_DIR/..")"
CONFIG_FILE="${CONFIG_FILE:-/etc/cloud-init-setup.conf}"
LOG_DIR="/var/log/cloud-init-setup"
STAGING_DIR="/tmp/cloud-init-staging-$$"

# Source common utilities
source "$SCRIPT_DIR/../lib/common.sh"

# Initialize logging
init_logging

trap 'handle_error ${LINENO} $?' ERR

usage() {
  cat <<'EOF'
Usage: cloud-init-runner.sh [OPTIONS]

  --config CONFIG_FILE           Configuration file (default: /etc/cloud-init-setup.conf)
  --collect-only                 Only collect diagnostics, don't upload or notify
  --skip-collectors NAMES        Comma-separated list of collectors to skip
                                 (default: none)
                                 Available: cloud-init, journald, dmesg, logfiles, networking,
                                            system-info, packages, disk-io
  --include-collectors NAMES     Only run specified collectors (overrides --skip-collectors)
  --skip-upload                  Don't upload logs to S3
  --skip-notify                  Don't send Discord notification
  --help                         Show this help message

EOF
  exit 0
}

COLLECT_ONLY=0
SKIP_COLLECTORS=""
INCLUDE_COLLECTORS=""
SKIP_UPLOAD=0
SKIP_NOTIFY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config) CONFIG_FILE="$2"; shift 2 ;;
    --collect-only) COLLECT_ONLY=1; shift ;;
    --skip-collectors) SKIP_COLLECTORS="$2"; shift 2 ;;
    --include-collectors) INCLUDE_COLLECTORS="$2"; shift 2 ;;
    --skip-upload) SKIP_UPLOAD=1; shift ;;
    --skip-notify) SKIP_NOTIFY=1; shift ;;
    --help) usage ;;
    *) log_warn "Unknown argument: $1"; shift ;;
  esac
done

# Load configuration
if [[ -f "$CONFIG_FILE" ]]; then
  load_config "$CONFIG_FILE"
else
  log_warn "Configuration file not found: $CONFIG_FILE"
fi

# Validate required configuration variables (if not skipping upload/notify)
if [[ $SKIP_UPLOAD -eq 0 ]]; then
  validate_env_vars S3_ENDPOINT S3_BUCKET S3_ACCESS_KEY S3_SECRET_KEY || log_warn "S3 configuration incomplete"
fi

if [[ $SKIP_NOTIFY -eq 0 ]]; then
  validate_env_vars DISCORD_WEBHOOK || log_warn "Discord webhook not configured"
fi

# Create staging directory
mkdir -p "$STAGING_DIR" "$LOG_DIR"

log_info "=========================================="
log_info "Cloud-Init Setup Orchestrator"
log_info "=========================================="
log_info "Hostname: $(hostname)"
log_info "Timestamp: $(date)"
log_info "Log directory: $LOG_DIR"
log_info "Staging directory: $STAGING_DIR"

# Collector functions
run_collector() {
  local collector_name="$1"
  local collector_script="$SCRIPT_DIR/must-gather/collectors/${collector_name}.sh"

  # Check if should skip this collector
  if [[ -n "$INCLUDE_COLLECTORS" ]]; then
    if ! echo "$INCLUDE_COLLECTORS" | grep -q "$collector_name"; then
      log_debug "Skipping $collector_name (not in include list)"
      return 0
    fi
  elif [[ -n "$SKIP_COLLECTORS" ]]; then
    if echo "$SKIP_COLLECTORS" | grep -q "$collector_name"; then
      log_debug "Skipping $collector_name (in skip list)"
      return 0
    fi
  fi

  if [[ ! -f "$collector_script" ]]; then
    log_warn "Collector script not found: $collector_script"
    return 1
  fi

  log_info "Running collector: $collector_name"
  if "$collector_script" --output-dir "$STAGING_DIR" >>"$LOG_FILE" 2>&1; then
    log_debug "Collector $collector_name completed successfully"
    return 0
  else
    log_error "Collector $collector_name failed"
    return 1
  fi
}

# Main collection phase
log_info "Starting diagnostics collection..."

collect_all_diagnostics() {
  local collectors=(
    "cloud-init"
    "journald"
    "dmesg"
    "logfiles"
    "networking"
    "system-info"
    "packages"
    "disk-io"
  )

  local failed_collectors=()

  for collector in "${collectors[@]}"; do
    if ! run_collector "$collector"; then
      failed_collectors+=("$collector")
    fi
  done

  if [[ ${#failed_collectors[@]} -gt 0 ]]; then
    log_warn "Some collectors failed: ${failed_collectors[*]}"
  fi
}

wait_for_network
collect_all_diagnostics

# List collected files
log_info "Collected diagnostics:"
find "$STAGING_DIR" -type f -name "*.tar.gz" | while read -r bundle; do
  log_info "  - $(basename "$bundle")"
done

if [[ $COLLECT_ONLY -eq 1 ]]; then
  log_info "Collection-only mode enabled. Skipping upload and notification."
  exit 0
fi

# Upload phase
UPLOAD_STATUS="success"
PRESIGNED_URL=""

if [[ $SKIP_UPLOAD -eq 0 ]]; then
  log_info "Starting diagnostics upload..."

  # Create combined tarball
  COMBINED_TARBALL="$LOG_DIR/cloud-init-diagnostics-$(hostname)-$(date +%Y%m%d-%H%M%S).tar.gz"
  mkdir -p "$(dirname "$COMBINED_TARBALL")"

  if (cd "$STAGING_DIR" && tar -czf "$COMBINED_TARBALL" .); then
    log_info "Created combined tarball: $COMBINED_TARBALL"

    # Upload to S3
    log_info "Uploading to S3: $S3_BUCKET/$COMBINED_TARBALL"
    if retry_with_backoff "$SCRIPT_DIR/s3-uploader/upload.sh" \
        --file "$COMBINED_TARBALL" \
        --endpoint "$S3_ENDPOINT" \
        --bucket "$S3_BUCKET" \
        --access-key "$S3_ACCESS_KEY" \
        --secret-key "$S3_SECRET_KEY"; then

      log_info "Upload completed successfully"
      PRESIGNED_URL=$("$SCRIPT_DIR/s3-uploader/upload.sh" \
        --file "$COMBINED_TARBALL" \
        --endpoint "$S3_ENDPOINT" \
        --bucket "$S3_BUCKET" \
        --access-key "$S3_ACCESS_KEY" \
        --secret-key "$S3_SECRET_KEY" 2>/dev/null | tail -1)
      log_info "Pre-signed URL: $PRESIGNED_URL"
    else
      log_error "Upload to S3 failed"
      UPLOAD_STATUS="error"
    fi
  else
    log_error "Failed to create combined tarball"
    UPLOAD_STATUS="error"
  fi
else
  log_info "Upload skipped (--skip-upload)"
fi

# Notification phase
if [[ $SKIP_NOTIFY -eq 0 ]] && [[ -n "${DISCORD_WEBHOOK:-}" ]]; then
  log_info "Sending Discord notification..."

  # Prepare notification fields
  NOTIFICATION_FIELDS="Hostname:$(hostname),Status:$UPLOAD_STATUS,Timestamp:$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

  if [[ -n "$PRESIGNED_URL" ]]; then
    NOTIFICATION_FIELDS="$NOTIFICATION_FIELDS,Diagnostics URL:Available"
  fi

  "$SCRIPT_DIR/notifier/discord-notifier.sh" \
    --webhook "$DISCORD_WEBHOOK" \
    --title "Cloud-Init Setup $(hostname)" \
    --description "Diagnostics collection and upload completed" \
    --status "$UPLOAD_STATUS" \
    --hostname "$(hostname)" \
    --fields "$NOTIFICATION_FIELDS" \
    --log-url "${PRESIGNED_URL:-N/A}" \
    --footer-text "Cloud-Init Setup Orchestrator"

  log_info "Discord notification sent"
else
  if [[ $SKIP_NOTIFY -eq 1 ]]; then
    log_info "Notification skipped (--skip-notify)"
  else
    log_warn "Discord webhook not configured, skipping notification"
  fi
fi

# Final summary
log_info "=========================================="
log_info "Orchestrator completed with status: $UPLOAD_STATUS"
log_info "Full logs available at: $LOG_FILE"
log_info "=========================================="

# Cleanup
rm -rf "$STAGING_DIR"

[[ "$UPLOAD_STATUS" == "success" ]] && exit 0 || exit 1
