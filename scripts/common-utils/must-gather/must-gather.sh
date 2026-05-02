#!/usr/bin/env bash
set -euo pipefail

# Base directory for staging and output; default to /root (expected on target VMs)
OUTPUT_BASE="/root"

PATHS=()
INCLUDE_JOURNAL=0
INCLUDE_CLOUD_INIT=0
INCLUDE_DMESG=0
INCLUDE_LOGFILES=0
INCLUDE_NETWORKING=0

EXTRA_PING_HOSTS=""
EXTRA_DNS_HOSTS=""

# Directory that holds this script and the must-gather-* helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-dir)
      OUTPUT_BASE="$2"
      shift 2
      ;;
    --paths)
      IFS=',' read -r -a PATHS <<< "$2"
      shift 2
      ;;
    --include-journal)
      INCLUDE_JOURNAL=1
      shift
      ;;
    --include-cloud-init)
      INCLUDE_CLOUD_INIT=1
      shift
      ;;
    --include-dmesg)
      INCLUDE_DMESG=1
      shift
      ;;
    --include-logfiles)
      INCLUDE_LOGFILES=1
      shift
      ;;
    --include-networking)
      INCLUDE_NETWORKING=1
      shift
      ;;
    --extra-ping-hosts)
      EXTRA_PING_HOSTS="$2"
      shift 2
      ;;
    --extra-dns-resolvable-hosts)
      EXTRA_DNS_HOSTS="$2"
      shift 2
      ;;
    *)
      # Unknown arg, just skip for now (or you can echo a warning)
      shift
      ;;
  esac
done

# Final output tarball and staging directory (resolved after arg parsing)
OUTPUT="${OUTPUT_BASE}/must-gather-$(hostname)-$(date +%Y%m%d-%H%M%S).tar.gz"
STAGING_DIR="${OUTPUT_BASE}/must-gather"

# Start from a clean staging directory
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
mkdir -p "$STAGING_DIR/paths"

# 1) Raw copies of requested paths (backward compatible behavior)
for p in "${PATHS[@]}"; do
  cp -r "$p" "$STAGING_DIR/paths/" 2>/dev/null || true
done

# 2) Run modular must-gather scripts, dropping their bundles into STAGING_DIR

# Collectors echo their own output path to stdout as a status message — redirect
# to stderr so it doesn't pollute the single final path we print at the end.

# Cloud-init
if [[ "$INCLUDE_CLOUD_INIT" -eq 1 ]]; then
  "$SCRIPT_DIR/collectors/cloud-init.sh" \
    --output-dir "$STAGING_DIR" >&2
fi

# Journald
if [[ "$INCLUDE_JOURNAL" -eq 1 ]]; then
  "$SCRIPT_DIR/collectors/journald.sh" \
    --output-dir "$STAGING_DIR" >&2
fi

# dmesg / kernel logs
if [[ "$INCLUDE_DMESG" -eq 1 ]]; then
  "$SCRIPT_DIR/collectors/dmesg.sh" \
    --output-dir "$STAGING_DIR" >&2
fi

# Log files (e.g. /var/log + optional paths)
if [[ "$INCLUDE_LOGFILES" -eq 1 ]]; then
  if [[ "${#PATHS[@]}" -gt 0 ]]; then
    PATHS_JOINED="$(IFS=','; echo "${PATHS[*]}")"
    "$SCRIPT_DIR/collectors/log-files.sh" \
      --output-dir "$STAGING_DIR" \
      --paths "$PATHS_JOINED" >&2
  else
    "$SCRIPT_DIR/collectors/log-files.sh" \
      --output-dir "$STAGING_DIR" >&2
  fi
fi

# Networking bundle
if [[ "$INCLUDE_NETWORKING" -eq 1 ]]; then
  NET_ARGS=(--output-dir "$STAGING_DIR")

  if [[ -n "$EXTRA_PING_HOSTS" ]]; then
    NET_ARGS+=(--extra-ping-hosts "$EXTRA_PING_HOSTS")
  fi
  if [[ -n "$EXTRA_DNS_HOSTS" ]]; then
    NET_ARGS+=(--extra-dns-resolvable-hosts "$EXTRA_DNS_HOSTS")
  fi

  "$SCRIPT_DIR/collectors/network.sh" "${NET_ARGS[@]}" >&2
fi

# 3) Final archive with everything staged
tar -czf "$OUTPUT" -C "$OUTPUT_BASE" "$(basename "$STAGING_DIR")"

echo "$OUTPUT"
