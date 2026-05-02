#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: must-gather-logfiles.sh [--paths path1,path2,...] [--output-dir DIR]

  --paths       Comma-separated list of files/directories to include.
                If omitted, defaults to /var/log
  --output-dir  Directory where the resulting tar.gz will be written (default: current dir)
EOF
}

PATHS_ARG=""
OUTPUT_DIR="$(pwd)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --paths)
      [[ $# -ge 2 ]] || { echo "Missing value for --paths" >&2; usage; exit 1; }
      PATHS_ARG="$2"
      shift 2
      ;;
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

WORKDIR="$(mktemp -d /tmp/must-gather-logfiles.XXXXXX)"
trap 'rm -rf "$WORKDIR"' EXIT

mkdir -p "$WORKDIR/files"

# Build list of paths
declare -a PATHS
if [[ -n "$PATHS_ARG" ]]; then
  IFS=',' read -r -a PATHS <<< "$PATHS_ARG"
else
  PATHS=("/var/log")
fi

copy_path() {
  local src="$1"
  [[ -e "$src" ]] || return 0  # silently skip missing

  # Preserve the original absolute path under files/
  local dest="$WORKDIR/files${src}"
  mkdir -p "$(dirname "$dest")"

  if [[ -d "$src" ]]; then
    cp -a "$src"/. "$dest"
  elif [[ -f "$src" ]]; then
    cp -a "$src" "$dest"
  fi
}

for p in "${PATHS[@]}"; do
  [[ -n "$p" ]] && copy_path "$p"
done

TS="$(date +%Y%m%d%H%M%S)"
OUTFILE="${OUTPUT_DIR}/${TS}-must-gather-logfiles.tar.gz"

(
  cd "$WORKDIR"
  tar -czf "$OUTFILE" .
)

echo "$OUTFILE"
