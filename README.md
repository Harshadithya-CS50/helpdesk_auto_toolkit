# Helpdesk Automation Toolkit

Command-line scripts (Bash and PowerShell) that automate repetitive IT helpdesk work: bulk account creation, health reports, incremental backups. Every script validates input, logs actions, and is safe to re-run.

## Requirements
- Linux: Ubuntu 22.04, bash, rsync, openssl (`sudo apt install rsync openssl shellcheck`)
- Windows: PowerShell 5.1 or later, run as Administrator for user creation

## Usage

Linux (from the repo root):

    ./linux/health_report.sh [disk_threshold_percent]
    sudo ./linux/provision_users.sh [-n] data/users.csv
    ./linux/backup.sh <source_dir> <dest_dir>

Windows (Administrator PowerShell, in the windows folder):

    .\Get-HealthReport.ps1 -DiskWarnPercent 80
    .\New-BulkUsers.ps1 -CsvPath ..\data\users.csv.example -WhatIf

CSV format: header `username,fullname,group`; see `data/users.csv.example`.

## How dry-run works
`-n` (Bash) wraps every state-changing command in a `run` function that logs the command instead of executing it. `-WhatIf` (PowerShell) uses `SupportsShouldProcess`. Nothing is created in either mode.

## Scheduling and cleanup
Weekday 02:30 backup, absolute paths required:

    30 2 * * 1-5 /abs/path/linux/backup.sh /abs/src /abs/dest >> /abs/path/logs/cron.log 2>&1

Old log cleanup (preview, then delete):

    find /var/log -type f -name "*.gz" -mtime +30 -print
    sudo find /var/log -type f -name "*.gz" -mtime +30 -delete

## Design decisions
- Shared `common.sh` / `Common.ps1` so logging is consistent
- `set -euo pipefail` so errors stop the script instead of being ignored
- Existing users are skipped (idempotent); invalid rows are logged and skipped
- Random temporary passwords with forced change at first login; credentials files are owner-only and git-ignored
- Backups use rsync `--link-dest` hard links, written to a `.partial` folder and renamed on success

## Testing performed
Missing CSV, no arguments, bad username, blank row, duplicate row, no trailing newline, run twice, run without sudo, `shellcheck` clean.

## Troubleshooting
- `bad interpreter` / `\r` errors: file has Windows line endings. Run `sed -i 's/\r$//' linux/*.sh`
- `Permission denied` on `logs/toolkit.log`: logs were created by sudo. Run `sudo chown -R $USER logs`
- `Run with sudo`: user creation needs root; use `-n` to preview without it
- `systemd not running`: failed-service check is skipped on systems without systemd
- Cron job not running: use absolute paths, check `logs/cron.log`, and make sure the cron service is running
- Disk full: `df -h`, then `sudo du -sh /* 2>/dev/null | sort -h` to find the culprit, then clean logs or caches
- PowerShell "running scripts is disabled": `Set-ExecutionPolicy -Scope Process RemoteSigned`

## Limitations
Local accounts only (not Active Directory); credentials stored in a local file (a real deployment would use a password vault); CSV fields cannot contain commas.
