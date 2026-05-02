#!/usr/bin/env bash
# Common utility functions for cloud-init scripts

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log levels
LOG_DEBUG=0
LOG_INFO=1
LOG_WARN=2
LOG_ERROR=3

LOG_LEVEL=${LOG_LEVEL:-$LOG_INFO}
LOG_FILE="${LOG_FILE:-/var/log/cloud-init-setup.log}"

# Initialize logging
init_logging() {
  mkdir -p "$(dirname "$LOG_FILE")"
  touch "$LOG_FILE"
}

# Log function with timestamp and level
log() {
  local level="$1"
  shift
  local message="$@"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  local log_line="[$timestamp] [$level] $message"

  echo "$log_line" >> "$LOG_FILE"

  case "$level" in
    DEBUG) [[ $LOG_LEVEL -le $LOG_DEBUG ]] && echo -e "${BLUE}${log_line}${NC}" ;;
    INFO)  [[ $LOG_LEVEL -le $LOG_INFO ]]  && echo -e "${GREEN}${log_line}${NC}" ;;
    WARN)  [[ $LOG_LEVEL -le $LOG_WARN ]]  && echo -e "${YELLOW}${log_line}${NC}" >&2 ;;
    ERROR) [[ $LOG_LEVEL -le $LOG_ERROR ]] && echo -e "${RED}${log_line}${NC}" >&2 ;;
  esac
}

log_debug() { log DEBUG "$@"; }
log_info() { log INFO "$@"; }
log_warn() { log WARN "$@"; }
log_error() { log ERROR "$@"; }

# Error handler
handle_error() {
  local line_number=$1
  local exit_code=$2
  log_error "Error on line $line_number with exit code $exit_code"
  return $exit_code
}

# Retry function with exponential backoff
retry_with_backoff() {
  local max_attempts=5
  local timeout=1
  local attempt=1

  while [[ $attempt -le $max_attempts ]]; do
    if "$@"; then
      return 0
    fi

    log_warn "Command failed (attempt $attempt/$max_attempts). Retrying in ${timeout}s..."
    sleep "$timeout"
    timeout=$((timeout * 2))
    attempt=$((attempt + 1))
  done

  log_error "Command failed after $max_attempts attempts"
  return 1
}

# Check if command exists
require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log_error "Required command not found: $cmd"
    return 1
  fi
}

# Wait for system to be ready (networking, package manager)
wait_for_system_ready() {
  local max_wait=300  # 5 minutes
  local elapsed=0

  log_info "Waiting for system to be ready..."

  # Wait for package manager lock
  while [[ $elapsed -lt $max_wait ]]; do
    if ! lsof /var/lib/apt/lists/lock >/dev/null 2>&1 && \
       ! lsof /var/cache/apt/archives/lock >/dev/null 2>&1; then
      log_info "System is ready"
      return 0
    fi
    sleep 5
    elapsed=$((elapsed + 5))
  done

  log_warn "System readiness check timed out after ${max_wait}s"
  return 1
}

# Verify a directory or file exists and is readable
verify_path() {
  local path="$1"
  if [[ ! -r "$path" ]]; then
    log_error "Path not found or not readable: $path"
    return 1
  fi
}

# Get disk space in MB
get_disk_space() {
  local path="${1:-.}"
  df -BM "$path" | tail -1 | awk '{print $4}' | sed 's/M//'
}

# Get free memory in MB
get_free_memory() {
  free -m | awk 'NR==2 {print $7}'
}

# Check if sufficient disk space available (in MB)
check_disk_space() {
  local required_mb=$1
  local path="${2:-.}"
  local available=$(get_disk_space "$path")

  if [[ $available -lt $required_mb ]]; then
    log_error "Insufficient disk space. Required: ${required_mb}MB, Available: ${available}MB"
    return 1
  fi
  log_debug "Disk space check passed: ${available}MB available"
  return 0
}

# Load configuration from file
load_config() {
  local config_file="$1"
  if [[ ! -f "$config_file" ]]; then
    log_warn "Configuration file not found: $config_file"
    return 1
  fi

  log_info "Loading configuration from $config_file"
  # shellcheck disable=SC1090
  source "$config_file"
}

# Validate required environment variables
validate_env_vars() {
  local missing_vars=()

  for var in "$@"; do
    if [[ -z "${!var:-}" ]]; then
      missing_vars+=("$var")
    fi
  done

  if [[ ${#missing_vars[@]} -gt 0 ]]; then
    log_error "Missing required environment variables: ${missing_vars[*]}"
    return 1
  fi

  return 0
}

# Create temporary directory with cleanup on exit
create_temp_dir() {
  local temp_dir=$(mktemp -d /tmp/cloud-init-setup.XXXXXX)
  echo "$temp_dir"
  trap "rm -rf '$temp_dir'" EXIT
}

# Wait for network connectivity
wait_for_network() {
  local max_wait=60
  local elapsed=0

  log_info "Waiting for network connectivity..."

  while [[ $elapsed -lt $max_wait ]]; do
    if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
      log_info "Network is available"
      return 0
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done

  log_warn "Network connectivity check timed out after ${max_wait}s"
  return 1
}

# Export all functions for use in subshells
export -f log log_debug log_info log_warn log_error
export -f retry_with_backoff require_command wait_for_system_ready
export -f verify_path get_disk_space get_free_memory check_disk_space
export -f load_config validate_env_vars wait_for_network
export LOG_FILE LOG_LEVEL RED GREEN YELLOW BLUE NC
