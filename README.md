# Shell Monitor

A lightweight, automated website monitoring system built with shell scripting.
It continuously checks website availability, validates HTTP status and
response time, logs uptime/downtime history, detects real outages (not
single blips), and triggers alerts on failure.

## Why this project

Most engineers reach for Prometheus/Grafana before they understand what
monitoring actually does. This project builds the core loop by hand first:

- Monitoring before failure becomes visible
- Automation over manual checks
- Observability starts small, not with tools

## Requirements

- `bash`, `curl`, `awk` (all standard on Linux/macOS; on Windows, use Git
  Bash or WSL)
- `crontab` if you want scheduled runs (Linux/macOS/WSL — not available on
  plain Windows)
- `mail` if you want email alerts (optional — webhook and log alerts work
  without it)

## Quick start

```bash
# Check one site by hand
./scripts/check_site.sh https://example.com

# Check every site in config/urls.conf
./scripts/monitor.sh

# Run all the scripts against known good/bad/slow URLs at once
./scripts/test_scenarios.sh

# Install a cron job to run monitor.sh every 5 minutes
./scripts/install_cron.sh
```

## Project layout

```
shell-monitor/
├── config/
│   └── urls.conf          # sites to monitor
├── scripts/
│   ├── check_site.sh      # check one URL: status + response time
│   ├── monitor.sh         # check every URL in the config, track failures, alert
│   ├── alert.sh           # dispatch an ALERT/RECOVERED event to log/webhook/email
│   ├── install_cron.sh    # install/update/remove the cron job
│   └── test_scenarios.sh  # side-by-side test harness for every outcome
└── logs/                  # uptime history, alerts, failure state (git-ignored)
```

## How it fits together

`monitor.sh` is the main entry point (what cron runs). For each URL in the
config it calls `check_site.sh`, which does one HTTP check and logs the
result. `monitor.sh` then tracks each site's consecutive failure count so a
single bad request doesn't look like an outage, and calls `alert.sh` exactly
once when a site crosses the failure threshold and once when it recovers.

```
install_cron.sh  -->  (every N minutes)  -->  monitor.sh
                                                  │
                                    for each URL in urls.conf
                                                  │
                                            check_site.sh  ──>  logs/monitor.log
                                                  │
                                   consecutive-failure tracking (logs/state/)
                                                  │
                                  on threshold-cross / recovery only
                                                  ▼
                                             alert.sh  ──>  logs/alerts.log
                                                        ──>  webhook (optional)
                                                        ──>  email (optional)
```

## Checking a single site

```bash
./scripts/check_site.sh <url> [max_response_seconds]
```

- Exit `0` — UP (2xx status, within the response time threshold)
- Exit `1` — DOWN (connection failed, or a non-2xx status)
- Exit `2` — SLOW (2xx status, but slower than `max_response_seconds`, default 2)

Every call appends a row to the log file (see [Logging](#logging)).

## Monitoring every configured site

```bash
./scripts/monitor.sh [config_file]   # defaults to config/urls.conf
```

`config/urls.conf` format — one site per line:

```
# comments and blank lines are ignored
<url> [max_response_seconds]
```

Example:

```
https://example.com
https://www.google.com 3
```

`monitor.sh` prints a table (URL, result, failure streak, detail) and exits
`0` if everything is UP, `2` if the worst case is SLOW, or `1` if anything is
DOWN.

## Failure detection (avoiding false alarms)

A single failed check is usually just a network blip, not an outage.
`monitor.sh` persists each URL's consecutive-failure count between runs (in
`logs/state/`, one file per URL) so cron ticks accumulate it over time:

- `1/3`, `2/3`, … — down, but not yet alert-worthy
- `ALERT` — down for `MONITOR_FAILURE_THRESHOLD` checks in a row (default 3)
- `RECOVERED` — the first successful check after being down

`alert.sh` fires exactly once per transition (entering `ALERT`, entering
`RECOVERED`) — not on every tick of an ongoing outage.

## Alerting

`alert.sh` is called by `monitor.sh` automatically, or can be run by hand:

```bash
./scripts/alert.sh <ALERT|RECOVERED> <url> <detail>
```

Channels, all optional:

| Channel | Enabled by | Behavior if unavailable/unset |
|---|---|---|
| Log | always on | — |
| Webhook | `ALERT_WEBHOOK_URL` env var | skipped |
| Email | `ALERT_EMAIL_TO` env var + `mail` installed | skipped with a note |

Example:

```bash
export ALERT_WEBHOOK_URL="https://your-webhook-endpoint"
export ALERT_EMAIL_TO="you@example.com"
./scripts/monitor.sh
```

## Logging

| File | Written by | Format |
|---|---|---|
| `logs/monitor.log` | `check_site.sh` | `timestamp  result  url  status_code  response_time` |
| `logs/alerts.log` | `alert.sh` | `timestamp  event  url  detail` |
| `logs/cron.log` | cron (via `install_cron.sh`) | raw stdout/stderr of each `monitor.sh` run |
| `logs/state/*.count` | `monitor.sh` | one file per URL, current consecutive-failure count |

All are plain tab-separated text, so `tail -f`, `grep`, or `awk` work
directly on them. All log paths are overridable via env vars
(`MONITOR_LOG_FILE`, `MONITOR_ALERT_LOG`, `MONITOR_STATE_DIR`) if you want
them somewhere other than `logs/`.

## Scheduling with cron

```bash
./scripts/install_cron.sh [interval_minutes]   # default 5
./scripts/install_cron.sh remove               # uninstall
```

Idempotent — re-running with a new interval replaces the existing entry
instead of adding a duplicate, and leaves any of your other cron jobs
untouched. Requires a real cron daemon (Linux/macOS/WSL); there's no
`crontab` on plain Windows.

## Testing all scenarios at once

```bash
./scripts/test_scenarios.sh
```

Runs `check_site.sh` against a fixed set of known-outcome URLs — 2xx, 404,
5xx, connection refused, unresolvable host, and a forced-SLOW case — and
prints expected vs. actual side by side, so every failure mode can be
sanity-checked in one shot instead of testing each one manually.
