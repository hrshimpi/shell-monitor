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
# Consecutive-failure tracking: a single failed check is a blip, not an
# outage. Each URL's consecutive DOWN count is persisted between runs in
# logs/state/, so cron invocations (separate processes) accumulate it over
# time. A site is only flagged ALERT once it has failed
# MONITOR_FAILURE_THRESHOLD times in a row (default 3), and flagged
# RECOVERED the first time it succeeds again after being down.
#
# alert.sh is invoked exactly once per transition (the tick that crosses
# the threshold, and the tick that recovers) so a prolonged outage doesn't
# spam every configured alert channel on every single tick.
#
# Exit codes:
#   0 - all sites UP
#   1 - at least one site DOWN
#   2 - no site DOWN, but at least one SLOW

set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
check_script="$script_dir/check_site.sh"
alert_script="$script_dir/alert.sh"
config_file="${1:-$script_dir/../config/urls.conf}"
state_dir="${MONITOR_STATE_DIR:-$script_dir/../logs/state}"
failure_threshold="${MONITOR_FAILURE_THRESHOLD:-3}"

if [[ ! -f "$config_file" ]]; then
    echo "Config file not found: $config_file" >&2
    exit 1
fi

mkdir -p "$state_dir"

state_file_for() {
    local sanitized
    sanitized="$(echo "$1" | tr -c '[:alnum:]' '_')"
    echo "$state_dir/$sanitized.count"
}

printf "%-40s %-9s %-8s %s\n" "URL" "RESULT" "STREAK" "DETAIL"
printf "%s\n" "--------------------------------------------------------------------------------"

exit_code=0

while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue

    read -r url threshold <<< "$line"
    threshold="${threshold:-2}"

    detail=$("$check_script" "$url" "$threshold" 2>&1)
    check_exit=$?

    state_file="$(state_file_for "$url")"
    prev_count=0
    [[ -f "$state_file" ]] && prev_count="$(cat "$state_file")"
    prev_count="${prev_count:-0}"

    if [[ $check_exit -eq 1 ]]; then
        result="DOWN"
        new_count=$((prev_count + 1))
        echo "$new_count" > "$state_file"
        if [[ $new_count -ge $failure_threshold ]]; then
            streak="ALERT"
            if [[ $new_count -eq $failure_threshold ]]; then
                "$alert_script" ALERT "$url" "$detail" >/dev/null
            fi
        else
            streak="$new_count/$failure_threshold"
        fi
        exit_code=1
    else
        result=$([[ $check_exit -eq 2 ]] && echo "SLOW" || echo "UP")
        if [[ $prev_count -ge $failure_threshold ]]; then
            streak="RECOVERED"
            "$alert_script" RECOVERED "$url" "$detail" >/dev/null
        else
            streak="-"
        fi
        echo "0" > "$state_file"
        if [[ $check_exit -eq 2 && $exit_code -eq 0 ]]; then
            exit_code=2
        fi
    fi

    printf "%-40s %-9s %-8s %s\n" "$url" "$result" "$streak" "$detail"
done < "$config_file"

exit "$exit_code"
