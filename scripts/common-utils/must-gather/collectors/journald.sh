#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: must-gather-journald.sh [--output-dir DIR]

  --output-dir   Directory where the resulting tar.gz will be written (default: current dir)
EOF
}

OUTPUT_DIR="$(pwd)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-dir)
      [[ $# -ge 2 ]] || { echo "Missing value for --output-dir" >&2; usage; exit 1; }
      OUTPUT_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

mkdir -p "$OUTPUT_DIR"

WORKDIR="$(mktemp -d /tmp/must-gather-journald.XXXXXX)"
trap 'rm -rf "$WORKDIR"' EXIT

mkdir -p "$WORKDIR/commands"

run_journal() {
  local out="$1"
  shift
  (journalctl "$@" --no-pager >"$WORKDIR/commands/$out" 2>&1) || true
}

# Current boot, everything
run_journal "journalctl_boot.txt" -b

# Current boot, warning and above
run_journal "journalctl_boot_warn+.txt" -b -p warning

# Last 1000 lines of everything (all boots)
run_journal "journalctl_last_1000.txt" -n 1000

# Systemd unit failures summary
(systemctl --failed >"$WORKDIR/commands/systemctl_failed.txt" 2>&1) || true

TS="$(date +%Y%m%d%H%M%S)"
OUTFILE="${OUTPUT_DIR}/${TS}-must-gather-journald.tar.gz"

(
  cd "$WORKDIR"
  tar -czf "$OUTFILE" .
)

echo "$OUTFILE"
