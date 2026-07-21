#!/usr/bin/env bash
# check_site.sh - Check a single website's HTTP status via curl.
#
# Usage: ./check_site.sh <url>

set -euo pipefail

url="${1:?Usage: $0 <url>}"

status_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$url" || echo "000")

if [[ "$status_code" == "000" ]]; then
    echo "DOWN  $url -> connection failed"
    exit 1
elif [[ "$status_code" =~ ^2 ]]; then
    echo "UP    $url -> $status_code"
    exit 0
else
    echo "DOWN  $url -> $status_code"
    exit 1
fi
