#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

WARN="${1:-80}"
[[ "$WARN" =~ ^[0-9]+$ ]] || { log ERROR "Threshold must be a number, got '$WARN'"; exit 1; }

cpu_usage() {                # % CPU busy, measured over 1 second
  local u n s i io irq sirq st idle1 total1 idle2 total2
  read -r _ u n s i io irq sirq st _ < /proc/stat
  idle1=$((i+io)); total1=$((u+n+s+i+io+irq+sirq+st))
  sleep 1
  read -r _ u n s i io irq sirq st _ < /proc/stat
  idle2=$((i+io)); total2=$((u+n+s+i+io+irq+sirq+st))
  echo $(( 100 * ((total2-total1) - (idle2-idle1)) / (total2-total1) ))
}

log INFO "=== Health report: $(hostname) ==="
echo "Uptime:  $(uptime -p)"
read -r l1 l5 l15 _ < /proc/loadavg
echo "Load:    $l1 $l5 $l15 (1/5/15 min) on $(nproc) cores"
echo "CPU:     $(cpu_usage)% busy"
free -m | awk '/Mem:/ {printf "Memory:  %d / %d MB used\n", $3, $2}'

echo "Disks at or above ${WARN}%:"
full=$(df -h --output=target,pcent -x tmpfs -x devtmpfs \
  | awk -v t="$WARN" 'NR>1 && $2+0 >= t {print "  WARNING " $1 " " $2}' || true)
if [[ -n "$full" ]]; then echo "$full"; log WARN "Disk usage above ${WARN}%"; else echo "  none"; fi

echo "Failed services:"
if [[ -d /run/systemd/system ]]; then
  failed=$(systemctl --failed --no-legend --plain | awk '{print "  " $1}' || true)
  if [[ -n "$failed" ]]; then echo "$failed"; else echo "  none"; fi
else
  echo "  systemd not running here - check skipped"
fi
