#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: must-gather-cloud-init.sh [--output-dir DIR]

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

WORKDIR="$(mktemp -d /tmp/must-gather-cloud-init.XXXXXX)"
trap 'rm -rf "$WORKDIR"' EXIT

mkdir -p "$WORKDIR/files" "$WORKDIR/commands"

copy_path() {
  local src="$1"
  if [[ -r "$src" ]]; then
    local dest="$WORKDIR/files${src}"
    mkdir -p "$(dirname "$dest")"
    cp -a "$src" "$dest"
  fi
}

# Cloud-init logs
copy_path /var/log/cloud-init.log
copy_path /var/log/cloud-init-output.log
copy_path /run/cloud-init

# Cloud-init config
if [[ -d /etc/cloud ]]; then
  copy_path /etc/cloud
fi

# cloud-init collect-logs (if available)
if command -v cloud-init >/dev/null 2>&1; then
  (
    cd "$WORKDIR"
    # This usually creates a tarball; we include it as-is
    cloud-init collect-logs -t "$WORKDIR/files/cloud-init-collect-logs.tar.gz" \
      >"$WORKDIR/commands/cloud-init-collect-logs.txt" 2>&1 || true
  )
fi

TS="$(date +%Y%m%d%H%M%S)"
OUTFILE="${OUTPUT_DIR}/${TS}-must-gather-cloud-init.tar.gz"

(
  cd "$WORKDIR"
  tar -czf "$OUTFILE" .
)

echo "$OUTFILE"
