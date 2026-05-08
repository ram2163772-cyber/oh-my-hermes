---
name: send-notification
description: Use when a deployment completes, a health check fails, or an important status event needs to be reported to Slack
version: 1.0.0
tags: [notification, slack, ops, webhook]
---

## Overview

Sends a structured Slack webhook message. Logs delivery to Hermes memory. Degrades gracefully if webhook not configured.

## When to Use

- After deployment (called by `post-deploy-followup`)
- After health check failure
- Any ops event that needs human awareness

## Prerequisites

- `SLACK_WEBHOOK_URL` in environment (`echo $SLACK_WEBHOOK_URL` to verify)

## Procedure

**Compose message** — include:
- Event type: Deploy / Health Fail / Health Pass / Update
- Project name
- Environment: production or preview
- URL (if deployment)
- Timestamp
- Brief status note

**Send:**
```bash
curl -s -o /dev/null -w "%{http_code}" -X POST "$SLACK_WEBHOOK_URL" \
  -H 'Content-Type: application/json' \
  -d "{\"text\": \"[event] [project] → [environment]\n[url]\n[status]\n[timestamp]\"}"
```

Check response: HTTP 200 = delivered. Anything else = failed.

**If `SLACK_WEBHOOK_URL` not set:**
- Print notification content to console (do not fail silently)
- Print: "Set SLACK_WEBHOOK_URL to enable Slack notifications. Get webhook URL at api.slack.com/apps → Incoming Webhooks."

**Save to Hermes memory:** key `notification-log`, append `{ event, timestamp, delivered: true/false }`.

## Pitfalls

- Slack webhook URLs expire or get revoked. Non-200 response → verify URL in Slack app settings.
- Keep messages under 4000 characters — Slack truncates longer messages.
- Never include env var values or credentials in notification content.

## Verification

- HTTP 200 from Slack
- Message appears in target Slack channel
- Entry appended to `notification-log` in Hermes memory
