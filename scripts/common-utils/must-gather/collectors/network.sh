#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: must-gather-networking.sh
         [--extra-ping-hosts host1,host2,...]
         [--extra-dns-resolvable-hosts host1,host2,...]
         [--output-dir DIR]

  --extra-ping-hosts             Comma-separated list of extra hosts/IPs to ping
  --extra-dns-resolvable-hosts   Comma-separated list of hostnames to resolve via DNS
  --output-dir                   Directory where the resulting tar.gz will be written (default: current dir)
EOF
}

EXTRA_PING_HOSTS=""
EXTRA_DNS_HOSTS=""
OUTPUT_DIR="$(pwd)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --extra-ping-hosts)
      [[ $# -ge 2 ]] || { echo "Missing value for --extra-ping-hosts" >&2; usage; exit 1; }
      EXTRA_PING_HOSTS="$2"
      shift 2
      ;;
    --extra-dns-resolvable-hosts)
      [[ $# -ge 2 ]] || { echo "Missing value for --extra-dns-resolvable-hosts" >&2; usage; exit 1; }
      EXTRA_DNS_HOSTS="$2"
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

WORKDIR="$(mktemp -d /tmp/must-gather-networking.XXXXXX)"
trap 'rm -rf "$WORKDIR"' EXIT

mkdir -p "$WORKDIR/commands" "$WORKDIR/tests"

run_cmd() {
  local out="$1"
  shift
  ("$@" >"$WORKDIR/commands/$out" 2>&1) || true
}

# 1) Static network info
run_cmd "ip_addr.txt"          ip address
run_cmd "ip_link.txt"          ip -s link
run_cmd "ip_route.txt"         ip route
run_cmd "ip_neigh.txt"         ip neigh
run_cmd "ss_-tulpn.txt"        ss -tulpn
run_cmd "resolv.conf.txt"      cat /etc/resolv.conf
run_cmd "hosts.txt"            cat /etc/hosts
run_cmd "hostnamectl.txt"      hostnamectl
run_cmd "nmcli_general.txt"    nmcli general status
run_cmd "nmcli_dev_show.txt"   nmcli device show
run_cmd "iptables-save.txt"    iptables-save
run_cmd "nft_list_ruleset.txt" nft list ruleset

# 2) Connectivity tests (gateway + internet + extra ping hosts)
PING_CMD=(ping -c 4 -w 5)

ping_to() {
  local target="$1"
  local outfile="$WORKDIR/tests/ping-${target}.txt"
  ("${PING_CMD[@]}" "$target" >"$outfile" 2>&1) || true
}

# 2a) Default gateway
DEFAULT_GW="$(ip route show default 0.0.0.0/0 2>/dev/null | awk '/default/ {print $3; exit}')"
if [[ -n "${DEFAULT_GW}" ]]; then
  ping_to "$DEFAULT_GW"
fi

# 2b) Internet reachability (customizable list)
DEFAULT_PING_TARGETS=(1.1.1.1 8.8.8.8)
IFS=',' read -r -a EXTRA_PING_ARRAY <<< "${EXTRA_PING_HOSTS:-}"

for t in "${DEFAULT_PING_TARGETS[@]}"; do
  ping_to "$t"
done

for t in "${EXTRA_PING_ARRAY[@]}"; do
  [[ -n "$t" ]] && ping_to "$t"
done

# 3) DNS resolution tests (internal + external)
# Prefer: dig -> host -> getent hosts
DIG_EXISTS=false
HOST_EXISTS=false

if command -v dig >/dev/null 2>&1; then
  DIG_EXISTS=true
elif command -v host >/dev/null 2>&1; then
  HOST_EXISTS=true
fi

dns_lookup() {
  local name="$1"
  local outfile="$WORKDIR/tests/dns-${name}.txt"
  if $DIG_EXISTS; then
    (dig "$name" +short >"$outfile" 2>&1) || true
  elif $HOST_EXISTS; then
    (host "$name" >"$outfile" 2>&1) || true
  else
    (getent hosts "$name" >"$outfile" 2>&1) || true
  fi
}

# Some default external DNS hosts
DEFAULT_DNS_HOSTS=(google.com cloudflare.com github.com)
IFS=',' read -r -a EXTRA_DNS_ARRAY <<< "${EXTRA_DNS_HOSTS:-}"

for h in "${DEFAULT_DNS_HOSTS[@]}"; do
  dns_lookup "$h"
done

for h in "${EXTRA_DNS_ARRAY[@]}"; do
  [[ -n "$h" ]] && dns_lookup "$h"
done

# 4) Build tarball
TS="$(date +%Y%m%d%H%M%S)"
OUTFILE="${OUTPUT_DIR}/${TS}-must-gather-networking.tar.gz"

(
  cd "$WORKDIR"
  tar -czf "$OUTFILE" .
)

# 5) Print final bundle name for the caller
echo "$OUTFILE"
