#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: must-gather-system-info.sh [--output-dir DIR]

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

WORKDIR="$(mktemp -d /tmp/must-gather-system-info.XXXXXX)"
trap 'rm -rf "$WORKDIR"' EXIT

mkdir -p "$WORKDIR/commands" "$WORKDIR/files"

run_cmd() {
  local out="$1"
  shift
  ("$@" >"$WORKDIR/commands/$out" 2>&1) || true
}

# System information
run_cmd "uname_-a.txt"             uname -a
run_cmd "lsb_release_-a.txt"       lsb_release -a
run_cmd "cat_etc_os_release.txt"   cat /etc/os-release
run_cmd "timedatectl.txt"          timedatectl
run_cmd "uptime.txt"               uptime
run_cmd "date.txt"                 date

# Hardware information
run_cmd "lscpu.txt"                lscpu
run_cmd "lsmem.txt"                lsmem
run_cmd "free_-h.txt"              free -h
run_cmd "df_-h.txt"                df -h
run_cmd "lsblk.txt"                lsblk
run_cmd "lspci.txt"                lspci
run_cmd "dmidecode.txt"            dmidecode

# Process information
run_cmd "ps_auxf.txt"              ps auxf
run_cmd "top_-bn1.txt"             top -bn1

# Package managers
if command -v dpkg >/dev/null 2>&1; then
  run_cmd "dpkg_-l.txt" dpkg -l
fi
if command -v rpm >/dev/null 2>&1; then
  run_cmd "rpm_-qa.txt" rpm -qa
fi

# Systemd
run_cmd "systemctl_--all.txt"      systemctl --all
run_cmd "systemctl_status.txt"     systemctl status --all

# SELinux/AppArmor status (if available)
if command -v getenforce >/dev/null 2>&1; then
  run_cmd "getenforce.txt" getenforce
fi
if command -v aa_status >/dev/null 2>&1; then
  run_cmd "apparmor_status.txt" aa_status --json
fi

# Copy important system files
copy_path() {
  local src="$1"
  if [[ -r "$src" ]]; then
    local dest="$WORKDIR/files${src}"
    mkdir -p "$(dirname "$dest")"
    cp -a "$src" "$dest"
  fi
}

copy_path /etc/hostname
copy_path /etc/fstab
copy_path /etc/crypttab
copy_path /proc/cmdline

TS="$(date +%Y%m%d%H%M%S)"
OUTFILE="${OUTPUT_DIR}/${TS}-must-gather-system-info.tar.gz"

(
  cd "$WORKDIR"
  tar -czf "$OUTFILE" .
)

echo "$OUTFILE"
