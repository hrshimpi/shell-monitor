#!/usr/bin/env bash
# alert.sh - Dispatch an alert for a monitoring event (ALERT or RECOVERED).
#
# Usage: ./alert.sh <event> <url> <detail>
#
# Channels (all optional, enabled by setting the corresponding env var):
#   Always     - appended to logs/alerts.log
#   ALERT_WEBHOOK_URL - POST a JSON payload to this URL via curl
#   ALERT_EMAIL_TO    - send via the `mail` command, if available
#
# Missing tools/config for a channel are skipped with a note rather than
# failing the whole script, so one broken channel doesn't block the others.

set -uo pipefail

event="${1:?Usage: $0 <event> <url> <detail>}"
url="${2:?Usage: $0 <event> <url> <detail>}"
detail="${3:-}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
alert_log="${MONITOR_ALERT_LOG:-$script_dir/../logs/alerts.log}"
timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

mkdir -p "$(dirname "$alert_log")"
message="[$event] $url - $detail"

printf "%s\t%s\t%s\t%s\n" "$timestamp" "$event" "$url" "$detail" >> "$alert_log"
echo "$message"

if [[ -n "${ALERT_WEBHOOK_URL:-}" ]]; then
    escaped_detail="${detail//\\/\\\\}"
    escaped_detail="${escaped_detail//\"/\\\"}"
    payload=$(printf '{"event":"%s","url":"%s","detail":"%s","timestamp":"%s"}' \
        "$event" "$url" "$escaped_detail" "$timestamp")
    if curl -s -o /dev/null --max-time 5 -X POST -H "Content-Type: application/json" \
        -d "$payload" "$ALERT_WEBHOOK_URL"; then
        echo "  webhook: sent to $ALERT_WEBHOOK_URL"
    else
        echo "  webhook: failed to reach $ALERT_WEBHOOK_URL"
    fi
fi

if [[ -n "${ALERT_EMAIL_TO:-}" ]]; then
    if command -v mail >/dev/null 2>&1; then
        if echo "$message" | mail -s "Shell Monitor: $event $url" "$ALERT_EMAIL_TO"; then
            echo "  email: sent to $ALERT_EMAIL_TO"
        else
            echo "  email: failed to send to $ALERT_EMAIL_TO"
        fi
    else
        echo "  email: skipped ('mail' command not available)"
    fi
fi
