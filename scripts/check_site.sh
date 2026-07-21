#!/usr/bin/env bash
# check_site.sh - Check a single website's HTTP status and response time via
# curl, and append the result to a log file for uptime/downtime history.
#
# Usage: ./check_site.sh <url> [max_response_seconds]
#
# Env:
#   MONITOR_LOG_FILE - path to the log file (default: logs/monitor.log next
#                       to this script's parent directory)
#
# Exit codes:
#   0 - UP   (2xx status, within the response time threshold)
#   1 - DOWN (connection failed or non-2xx status)
#   2 - SLOW (2xx status, but response time exceeded the threshold)

set -uo pipefail

url="${1:?Usage: $0 <url> [max_response_seconds]}"
threshold="${2:-2}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
log_file="${MONITOR_LOG_FILE:-$script_dir/../logs/monitor.log}"

read -r status_code response_time <<< "$(
    curl -s -o /dev/null -w "%{http_code} %{time_total}" --max-time 10 "$url" 2>/dev/null
)"
status_code="${status_code:-000}"
response_time="${response_time:-0}"

if [[ "$status_code" == "000" ]]; then
    result="DOWN"
    message="$url -> connection failed"
elif [[ ! "$status_code" =~ ^2 ]]; then
    result="DOWN"
    message="$url -> $status_code (${response_time}s)"
elif awk -v t="$response_time" -v max="$threshold" 'BEGIN { exit !(t > max) }'; then
    result="SLOW"
    message="$url -> $status_code (${response_time}s, over ${threshold}s threshold)"
else
    result="UP"
    message="$url -> $status_code (${response_time}s)"
fi

mkdir -p "$(dirname "$log_file")"
timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
printf "%s\t%s\t%s\t%s\t%s\n" "$timestamp" "$result" "$url" "$status_code" "$response_time" >> "$log_file"

printf "%-5s %s\n" "$result" "$message"

case "$result" in
    UP)   exit 0 ;;
    SLOW) exit 2 ;;
    *)    exit 1 ;;
esac
