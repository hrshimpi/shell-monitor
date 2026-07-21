#!/usr/bin/env bash
# test_scenarios.sh - Run check_site.sh against known good/bad URLs and
# print the results side by side, so all failure modes can be eyeballed
# in one shot instead of testing them one at a time.
#
# Usage: ./test_scenarios.sh

set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
check_script="$script_dir/check_site.sh"

# name|url|threshold_seconds|expected
scenarios=(
    "2xx OK|https://example.com|2|UP"
    "404 Not Found|https://example.com/does-not-exist|2|DOWN"
    "500 Server Error|https://httpstat.us/500|2|DOWN"
    "503 Unavailable|https://httpstat.us/503|2|DOWN"
    "Connection refused|http://localhost:1|2|DOWN"
    "Unresolvable host|http://this-host-does-not-exist.invalid|2|DOWN"
    "Slow response (forced)|https://example.com|0.001|SLOW"
)

printf "%-24s %-9s %-9s %s\n" "SCENARIO" "EXPECTED" "RESULT" "DETAIL"
printf "%s\n" "--------------------------------------------------------------------------"

for entry in "${scenarios[@]}"; do
    IFS='|' read -r name url threshold expected <<< "$entry"

    detail=$("$check_script" "$url" "$threshold" 2>&1)
    case $? in
        0) result="UP" ;;
        2) result="SLOW" ;;
        *) result="DOWN" ;;
    esac

    if [[ "$result" == "$expected" ]]; then
        mark="OK"
    else
        mark="MISMATCH"
    fi

    printf "%-24s %-9s %-9s %s [%s]\n" "$name" "$expected" "$result" "$detail" "$mark"
done
