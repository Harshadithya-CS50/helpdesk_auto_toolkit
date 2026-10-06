# Helpdesk Automation Toolkit

Bash scripts that automate repetitive IT helpdesk work on Linux: bulk account creation from a CSV, system health reports, and incremental scheduled backups. Every script validates input, logs its actions, and is safe to re-run.

## Problem
Manual helpdesk work is slow and error-prone: typos in usernames, forgotten backups, and disks found full only after users complain. This toolkit automates those tasks safely.

## Features
- **Bulk user provisioning**: creates accounts from a CSV with validation, a dry-run mode, random temporary passwords, and forced password change at first login
- **Health report**: uptime, load, CPU, memory, disks over a threshold, failed services
- **Incremental backups**: dated snapshots using rsync hard links, keeping the newest 7
- **Logging**: every action is written to `logs/toolkit.log` with a timestamp and level

## Project structure

    helpdesk-toolkit/
    ├── README.md
    ├── linux/
    │   ├── common.sh            shared logging and root check
    │   ├── health_report.sh
    │   ├── provision_users.sh
    │   └── backup.sh
    ├── data/
    │   └── users.csv.example
    └── logs/                    created at runtime, git-ignored

## Requirements
- Ubuntu 22.04 (also works in WSL)
- bash, rsync, openssl (`sudo apt install rsync openssl shellcheck`)

## Setup

    git clone git@github.com:Harshadithya-CS50/helpdesk_auto_toolkit.git
    cd helpdesk_auto_toolkit
    chmod +x linux/*.sh

## Usage

Health report (optional disk warning threshold, default 80):

    ./linux/health_report.sh
    ./linux/health_report.sh 70

Bulk user creation. Preview first, then run for real:

    ./linux/provision_users.sh -n data/users.csv.example
    sudo ./linux/provision_users.sh data/users.csv.example

CSV format (header row required):

    username,fullname,group
    asmith,Alice Smith,helpdesk
    bkumar,Bala Kumar,developers

Backup:

    ./linux/backup.sh /path/to/source /path/to/backups

## How dry-run works
With `-n`, every state-changing command goes through a `run` function that logs the command instead of executing it. No users, groups or passwords are created, and root is not required.

## Scheduling (cron)
Weekday backup at 02:30. Use absolute paths because cron has a minimal environment. Edit with `crontab -e`:

    30 2 * * 1-5 /abs/path/linux/backup.sh /abs/src /abs/dest >> /abs/path/logs/cron.log 2>&1

## Log cleanup
Preview, then delete compressed logs older than 30 days:

    find /var/log -type f -name "*.gz" -mtime +30 -print
    sudo find /var/log -type f -name "*.gz" -mtime +30 -delete

## Design decisions
- `set -euo pipefail` so errors stop a script instead of passing silently
- Shared `common.sh` so logging is consistent across scripts
- Usernames and groups are validated with a regex before reaching `useradd`
- Existing users are skipped, so re-running never duplicates or breaks anything (idempotent)
- The CSV loop reads from process substitution, not a pipe, so the created/skipped counters survive
- Windows line endings (`\r`) are stripped from the CSV, and a final row with no trailing newline is still processed
- Temporary passwords are random, stored in an owner-only file, and git-ignored
- Backups use rsync `--link-dest`: unchanged files are hard links, so each snapshot looks complete but costs little space. They are written to a `.partial` folder and renamed on success

## Testing performed
- Missing CSV, no arguments, bad flag
- Invalid username, blank row, duplicate row, last row without trailing newline
- Dry run versus real run, and running the same CSV twice (no duplicates)
- Running without sudo (clear error)
- Backup hard links verified by matching inode numbers; cron verified by temporarily running every minute
- `shellcheck` run on all scripts

## Troubleshooting
- **`bad interpreter` or `\r` errors**: the file has Windows line endings. Run `sed -i 's/\r$//' linux/*.sh`
- **`Permission denied` running a script**: `chmod +x linux/*.sh`
- **`Permission denied` on `logs/toolkit.log`**: logs were created by sudo. Run `sudo chown -R $USER logs`
- **`Run with sudo`**: user creation needs root. Use `-n` to preview without it
- **`systemd not running`**: the failed-services check is skipped on systems without systemd (common in WSL)
- **Cron job not running**: use absolute paths, check `logs/cron.log`, and make sure the cron service is running (`sudo service cron start` in WSL)
- **Disk full**: `df -h`, then `sudo du -sh /* 2>/dev/null | sort -h` to find the culprit, then clean logs or caches

## Limitations
- Local accounts only (no Active Directory or LDAP)
- Credentials are stored in a local file; a real deployment would use a password vault
- CSV fields cannot contain commas
- A Windows PowerShell version is planned but not included yet

## Possible improvements
Configuration management (Ansible), a password vault, email alerts when disk thresholds are crossed.
