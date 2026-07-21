#!/usr/bin/env bash
# check_site.sh - Check a single website's HTTP status and response time via curl.
#
# Usage: ./check_site.sh <url> [max_response_seconds]
#
# Exit codes:
#   0 - UP   (2xx status, within the response time threshold)
#   1 - DOWN (connection failed or non-2xx status)
#   2 - SLOW (2xx status, but response time exceeded the threshold)

set -uo pipefail

url="${1:?Usage: $0 <url> [max_response_seconds]}"
threshold="${2:-2}"

read -r status_code response_time <<< "$(
    curl -s -o /dev/null -w "%{http_code} %{time_total}" --max-time 10 "$url" 2>/dev/null
)"
status_code="${status_code:-000}"
response_time="${response_time:-0}"

if [[ "$status_code" == "000" ]]; then
    echo "DOWN  $url -> connection failed"
    exit 1
elif [[ ! "$status_code" =~ ^2 ]]; then
    echo "DOWN  $url -> $status_code (${response_time}s)"
    exit 1
elif awk -v t="$response_time" -v max="$threshold" 'BEGIN { exit !(t > max) }'; then
    echo "SLOW  $url -> $status_code (${response_time}s, over ${threshold}s threshold)"
    exit 2
else
    echo "UP    $url -> $status_code (${response_time}s)"
    exit 0
fi
