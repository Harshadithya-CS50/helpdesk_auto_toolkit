#!/usr/bin/env bash
# Shared helpers. Source this file; do not run it directly.
LOG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/logs"
LOG_FILE="$LOG_DIR/toolkit.log"
mkdir -p "$LOG_DIR"

log() {                      # usage: log LEVEL message
  local level="$1"; shift
  echo "$(date '+%F %T') [$level] $*" | tee -a "$LOG_FILE"
}

require_root() {
  [[ $EUID -eq 0 ]] || { log ERROR "Run with sudo"; exit 1; }
}
