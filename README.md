# Shell Monitor

A lightweight, automated website monitoring system built with shell scripting.
It continuously checks website availability, validates HTTP responses, logs
uptime/downtime history, and triggers alerts on failure.

## Why this project

Most engineers reach for Prometheus/Grafana before they understand what
monitoring actually does. This project builds the core loop by hand first:

- Monitoring before failure becomes visible
- Automation over manual checks
- Observability starts small, not with tools

## Core concepts

- HTTP request lifecycle
- HTTP status codes (2xx, 4xx, 5xx)
- Shell scripting for automation
- Cron-based scheduling
- Failure detection & alert logic

## Project layout

```
shell-monitor/
├── config/          # list of URLs to monitor
├── scripts/         # the monitor, alerting, and cron setup scripts
└── logs/            # uptime/downtime history (git-ignored)
```

## Status

Work in progress — being built incrementally. See commit history for the
build order.
