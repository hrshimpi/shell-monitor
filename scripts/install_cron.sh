#!/usr/bin/env bash
# install_cron.sh - Install (or remove) a cron job that runs monitor.sh
# on a schedule, so checks happen automatically instead of by hand.
#
# Usage:
#   ./install_cron.sh [interval_minutes]   # install/update, default 5
#   ./install_cron.sh remove               # uninstall
#
# Idempotent: re-running with a new interval replaces the existing entry
# instead of adding a duplicate. Requires a cron daemon (Linux/macOS/WSL) -
# there is no crontab on plain Windows.

set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
monitor_script="$script_dir/monitor.sh"
log_file="$script_dir/../logs/cron.log"
marker="# shell-monitor (managed by install_cron.sh)"

if ! command -v crontab >/dev/null 2>&1; then
    echo "crontab not found - this script requires a cron daemon (Linux/macOS/WSL)." >&2
    exit 1
fi

existing="$(crontab -l 2>/dev/null || true)"
filtered="$(printf '%s\n' "$existing" | grep -v "$marker" || true)"
filtered="$(printf '%s\n' "$filtered" | sed '/^$/d')"

if [[ "${1:-}" == "remove" ]]; then
    printf '%s\n' "$filtered" | crontab -
    echo "Removed shell-monitor cron job."
    exit 0
fi

interval="${1:-5}"
if ! [[ "$interval" =~ ^[0-9]+$ ]] || [[ "$interval" -lt 1 ]]; then
    echo "interval_minutes must be a positive integer, got: $interval" >&2
    exit 1
fi

cron_line="*/$interval * * * * $monitor_script >> $log_file 2>&1 $marker"

{
    [[ -n "$filtered" ]] && printf '%s\n' "$filtered"
    echo "$cron_line"
} | crontab -

echo "Installed cron job: runs monitor.sh every $interval minute(s)."
echo "$cron_line"
