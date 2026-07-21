#!/usr/bin/env bash
# monitor.sh - Check every URL listed in a config file using check_site.sh
# and print a summary table. This is the main entry point for periodic
# (e.g. cron-driven) monitoring runs.
#
# Usage: ./monitor.sh [config_file]
#
# Config format (see config/urls.conf):
#   <url> [max_response_seconds]
# Blank lines and lines starting with # are ignored.
#
# Exit codes:
#   0 - all sites UP
#   1 - at least one site DOWN
#   2 - no site DOWN, but at least one SLOW

set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
check_script="$script_dir/check_site.sh"
config_file="${1:-$script_dir/../config/urls.conf}"

if [[ ! -f "$config_file" ]]; then
    echo "Config file not found: $config_file" >&2
    exit 1
fi

printf "%-40s %-9s %s\n" "URL" "RESULT" "DETAIL"
printf "%s\n" "--------------------------------------------------------------------------"

exit_code=0

while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue

    read -r url threshold <<< "$line"
    threshold="${threshold:-2}"

    detail=$("$check_script" "$url" "$threshold" 2>&1)
    check_exit=$?

    case $check_exit in
        0) result="UP" ;;
        2) result="SLOW" ;;
        *) result="DOWN" ;;
    esac

    if [[ $check_exit -eq 1 ]]; then
        exit_code=1
    elif [[ $check_exit -eq 2 && $exit_code -eq 0 ]]; then
        exit_code=2
    fi

    printf "%-40s %-9s %s\n" "$url" "$result" "$detail"
done < "$config_file"

exit "$exit_code"
