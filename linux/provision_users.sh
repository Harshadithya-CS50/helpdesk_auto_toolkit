#!/usr/bin/env bash
set -euo pipefail
umask 077                                   # new files are owner-only
source "$(dirname "$0")/common.sh"

DRY_RUN=false
while getopts "n" opt; do
  case $opt in
    n) DRY_RUN=true ;;
    *) echo "Usage: sudo $0 [-n] users.csv"; exit 1 ;;
  esac
done
shift $((OPTIND-1))

CSV="${1:-}"
[[ -f "$CSV" ]] || { log ERROR "CSV not found: '$CSV'"; exit 1; }
$DRY_RUN || require_root

CRED_FILE="$LOG_DIR/credentials_$(date +%F_%H%M%S).txt"
run() { if $DRY_RUN; then log DRYRUN "$*"; else "$@"; fi; }

created=0; skipped=0
while IFS=, read -r username fullname group || [[ -n "$username" ]]; do
  [[ -z "$username" ]] && continue
  if [[ ! "$username" =~ ^[a-z][a-z0-9_-]{2,31}$ ]]; then
    log WARN "Invalid username '$username' - skipped"
    skipped=$((skipped+1)); continue
  fi
  if [[ ! "$group" =~ ^[a-z][a-z0-9_-]{1,31}$ ]]; then
    log WARN "Invalid group '$group' for '$username' - skipped"
    skipped=$((skipped+1)); continue
  fi
  if id "$username" &>/dev/null; then
    log INFO "'$username' already exists - skipped"
    skipped=$((skipped+1)); continue
  fi
  getent group "$group" &>/dev/null || run groupadd "$group"
  run useradd -m -c "$fullname" -G "$group" -s /bin/bash "$username"
  if $DRY_RUN; then
    log INFO "[dry-run] would create '$username' in group '$group'"
  else
    temp_pw=$(openssl rand -base64 9)
    echo "$username:$temp_pw" | chpasswd
    chage -d 0 "$username"                  # force change at first login
    echo "$username,$temp_pw" >> "$CRED_FILE"
    log INFO "Created '$username' in group '$group'"
  fi
  created=$((created+1))
done < <(tail -n +2 "$CSV" | tr -d '\r')

if $DRY_RUN; then
  log INFO "Done (dry run): $created would be created, $skipped skipped"
else
  log INFO "Done: $created created, $skipped skipped"
fi
