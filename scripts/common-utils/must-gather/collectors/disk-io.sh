#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: must-gather-disk-io.sh [--output-dir DIR]

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

WORKDIR="$(mktemp -d /tmp/must-gather-disk-io.XXXXXX)"
trap 'rm -rf "$WORKDIR"' EXIT

mkdir -p "$WORKDIR/commands" "$WORKDIR/files"

run_cmd() {
  local out="$1"
  shift
  ("$@" >"$WORKDIR/commands/$out" 2>&1) || true
}

# Disk usage
run_cmd "du_root_toplevel.txt"      du -sh /* 2>/dev/null
run_cmd "du_root_total.txt"         du -sh /
run_cmd "df_inodes.txt"             df -i

# Use ncdu if available for detailed analysis
if command -v ncdu >/dev/null 2>&1; then
  run_cmd "ncdu_root.txt" ncdu -o- / 2>/dev/null || true
fi

# Partition and disk info
run_cmd "lsblk_-a.txt"              lsblk -a
run_cmd "fdisk_-l.txt"              sudo fdisk -l 2>/dev/null || fdisk -l 2>/dev/null || true
run_cmd "partx_-l.txt"              sudo partx -l 2>/dev/null || partx -l 2>/dev/null || true
run_cmd "blkid.txt"                 sudo blkid 2>/dev/null || blkid 2>/dev/null || true

# I/O Statistics
if command -v iostat >/dev/null 2>&1; then
  run_cmd "iostat_-x.txt" iostat -x 1 2
fi

# Filesystem checks
run_cmd "mount.txt"                 mount

# Get root filesystem info - determine actual device first
ROOTDEV=$(findmnt -n -o SOURCE / 2>/dev/null || true)
if [[ -n "$ROOTDEV" ]]; then
  # Check if it's an ext filesystem and get tune2fs info
  if file "$ROOTDEV" 2>/dev/null | grep -q "ext[234]"; then
    run_cmd "tune2fs_-l_root.txt" sudo tune2fs -l "$ROOTDEV" 2>/dev/null || tune2fs -l "$ROOTDEV" 2>/dev/null || true
  fi
  # Get parted info for the root device
  if command -v parted >/dev/null 2>&1; then
    run_cmd "parted_-l_root.txt" sudo parted -l "$ROOTDEV" 2>/dev/null || parted -l "$ROOTDEV" 2>/dev/null || true
  fi
fi

# LVM info (if available)
if command -v lvs >/dev/null 2>&1; then
  run_cmd "lvs_-a.txt" lvs -a
  run_cmd "vgs.txt" vgs
  run_cmd "pvs.txt" pvs
fi

# RAID status (if available)
if command -v mdadm >/dev/null 2>&1; then
  run_cmd "mdadm_detail.txt" mdadm --detail --scan
fi

# Disk latency check
if command -v fio >/dev/null 2>&1; then
  run_cmd "fio_randread_latency.txt" fio --name=randread --ioengine=libaio --iodepth=16 --rw=randread --bs=4k --direct=1 --size=100M --numjobs=4 --runtime=10 --group_reporting || true
fi

# Copy important files
copy_path() {
  local src="$1"
  if [[ -r "$src" ]]; then
    local dest="$WORKDIR/files${src}"
    mkdir -p "$(dirname "$dest")"
    cp -a "$src" "$dest"
  fi
}

copy_path /etc/fstab

TS="$(date +%Y%m%d%H%M%S)"
OUTFILE="${OUTPUT_DIR}/${TS}-must-gather-disk-io.tar.gz"

(
  cd "$WORKDIR"
  tar -czf "$OUTFILE" .
)

echo "$OUTFILE"
