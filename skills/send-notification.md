---
name: send-notification
description: Use when a deployment completes, a health check fails, or an important status event needs to be reported to the founder
version: 1.1.0
tags: [notification, slack, telegram, ops, webhook]
---

## Overview

Sends a structured notification to the founder. Supports Slack webhook and Telegram bot. Uses whichever backend is configured — both can be active simultaneously. Logs delivery to Hermes memory. Degrades gracefully if no backend is configured.

## When to Use

- After deployment (called by `post-deploy-followup`)
- After health check failure or recovery
- Approval requests (called by `await-merge-approval`)
- Any ops event that needs human awareness

## Prerequisites

At least one of:
- `SLACK_WEBHOOK_URL` in environment
- `TELEGRAM_BOT_TOKEN` + `TELEGRAM_CHAT_ID` in environment

## Procedure

**1. Compose message** — include:
- Event type: Deploy / Health Fail / Health Pass / Approval Request / Update
- Project name
- Environment: production or preview
- URL (if deployment)
- Timestamp
- Brief status note (plain English, no raw logs)

**2. Send to Slack** (if `SLACK_WEBHOOK_URL` is set):
```bash
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$SLACK_WEBHOOK_URL" \
  -H 'Content-Type: application/json' \
  -d "{\"text\": \"[event] [project] → [environment]\n[url]\n[status]\n[timestamp]\"}")
```
HTTP 200 = delivered. Anything else = log failure, continue to next backend.

**3. Send to Telegram** (if `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` are set):
```bash
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  -d chat_id="$TELEGRAM_CHAT_ID" \
  -d text="[event] [project] → [environment]%0A[url]%0A[status]%0A[timestamp]" \
  -d parse_mode="HTML")
```
HTTP 200 = delivered.

**4. If no backend configured:**
- Print notification content to console (do not fail silently)
- Print: "No notification backend configured. Set SLACK_WEBHOOK_URL or TELEGRAM_BOT_TOKEN + TELEGRAM_CHAT_ID."

**5. Save to Hermes memory:** key `notification-log`, append `{ event, timestamp, backend, delivered: true/false }`.

## Pitfalls

- Slack webhook URLs expire or get revoked. Non-200 → verify URL in Slack app settings.
- Keep messages under 4000 characters — Slack truncates, Telegram rejects above 4096.
- Never include env var values or credentials in notification content.
- Telegram `TELEGRAM_CHAT_ID` for a personal chat is your numeric user ID — get it by messaging `@userinfobot`.
- If both backends are configured, a failure on one does not block the other.

## Verification

- HTTP 200 from at least one backend
- Message appears in Slack channel or Telegram chat
- Entry appended to `notification-log` in Hermes memory
