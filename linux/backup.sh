#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

SRC="${1:?Usage: $0 <source_dir> <dest_dir>}"
DEST="${2:?Usage: $0 <source_dir> <dest_dir>}"
[[ -d "$SRC" ]] || { log ERROR "Source not found: $SRC"; exit 1; }
mkdir -p "$DEST"
DEST="$(realpath "$DEST")"

TARGET="$DEST/backup_$(date +%F_%H%M%S)"
log INFO "Backing up $SRC -> $TARGET"
rsync -a --link-dest="$DEST/latest" "$SRC"/ "$TARGET.partial"/
mv "$TARGET.partial" "$TARGET"             # only a finished backup gets the real name
ln -sfn "$TARGET" "$DEST/latest"
log INFO "Backup complete"

# keep the 7 newest, delete the rest
ls -1dt "$DEST"/backup_* | tail -n +8 | xargs -r rm -rf
log INFO "Retention applied (kept newest 7)"
