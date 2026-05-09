---
name: post-deploy-followup
description: Use when a deployment has just completed and health verification, logging, and notification need to run
version: 1.0.0
tags: [deployment, ops, health, notification]
---

## Overview

Orchestrates the three post-deploy actions: health-check → log to memory → send-notification. The only skill that writes deployment history.

## When to Use

- Immediately after every deployment (called automatically by `deploy-to-vercel`)
- Manually after any deployment not handled by that skill

## Prerequisites

- Deployment URL in Hermes memory (key: `last-deployment`) or provided directly
- `health-check` skill available
- `send-notification` skill available

## Procedure

1. **Get URL** from Hermes memory key `last-deployment` or from user

2. **Run `health-check`**
   - PASS → continue
   - FAIL → run `send-notification` with failure message, log failure, stop. Do not report success.

3. **Log deployment to Hermes memory:**
   - key: `deployment-log`
   - Append: `{ url, timestamp, healthStatus: "healthy" | "unhealthy", engine: "claude-code" | "codex" | "hermes" | "manual" }`

4. **Run `send-notification`:**
   - Event: "Deploy"
   - Status: healthy
   - Include URL

5. **Check monitoring:**
   - Retrieve `monitoring-config` from Hermes memory
   - Not configured → print: "Monitoring not configured. Run `setup-monitoring` to set up Sentry and Uptime Kuma."

6. **Print summary:**
   ```
   Deployment summary
   ──────────────────
   URL:          [url]
   Health:       PASS / FAIL
   Notification: sent / not sent
   Monitoring:   configured / not configured
   Logged:       yes
   ```

## Pitfalls

- Health check PASS means the endpoint responded — not that the app has no bugs. Note this when reporting.
- Do not skip this skill. It is the only thing that writes deployment history to memory.

## Verification

- Deployment in Hermes memory under `deployment-log`
- Slack notification delivered (or failure explained)
- Health status confirmed
- Monitoring status noted
