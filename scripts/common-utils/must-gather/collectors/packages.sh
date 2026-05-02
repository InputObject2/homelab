#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: must-gather-packages.sh [--output-dir DIR]

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

WORKDIR="$(mktemp -d /tmp/must-gather-packages.XXXXXX)"
trap 'rm -rf "$WORKDIR"' EXIT

mkdir -p "$WORKDIR/commands"

run_cmd() {
  local out="$1"
  shift
  ("$@" >"$WORKDIR/commands/$out" 2>&1) || true
}

# Debian/Ubuntu packages
if command -v dpkg >/dev/null 2>&1; then
  run_cmd "dpkg_list.txt"        dpkg -l
  run_cmd "apt_list_upgradable.txt" apt list --upgradable
  run_cmd "apt_autoremove_-s.txt" apt autoremove -s
fi

# RHEL/CentOS/Fedora packages
if command -v rpm >/dev/null 2>&1; then
  run_cmd "rpm_-qa.txt"          rpm -qa
  run_cmd "rpm_-qa_updates.txt"  rpm -qa --last
fi

# Snap packages
if command -v snap >/dev/null 2>&1; then
  run_cmd "snap_list.txt" snap list
fi

# Flatpak packages
if command -v flatpak >/dev/null 2>&1; then
  run_cmd "flatpak_list.txt" flatpak list --app
fi

# pip packages (if Python is installed)
if command -v pip3 >/dev/null 2>&1; then
  run_cmd "pip3_list.txt" pip3 list
elif command -v pip >/dev/null 2>&1; then
  run_cmd "pip_list.txt" pip list
fi

# Node.js packages (if npm is installed)
if command -v npm >/dev/null 2>&1; then
  run_cmd "npm_list.txt" npm list -g
fi

# Container runtime info
if command -v docker >/dev/null 2>&1; then
  run_cmd "docker_version.txt" docker version
  run_cmd "docker_images.txt" docker images || true
  run_cmd "docker_ps_all.txt" docker ps -a || true
fi

if command -v podman >/dev/null 2>&1; then
  run_cmd "podman_version.txt" podman version
  run_cmd "podman_images.txt" podman images
  run_cmd "podman_ps_all.txt" podman ps -a
fi

TS="$(date +%Y%m%d%H%M%S)"
OUTFILE="${OUTPUT_DIR}/${TS}-must-gather-packages.tar.gz"

(
  cd "$WORKDIR"
  tar -czf "$OUTFILE" .
)

echo "$OUTFILE"
