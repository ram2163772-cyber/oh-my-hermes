---
name: health-check
description: Use when a deployed app needs to be verified as running, after every deployment, or on-demand to confirm availability
version: 1.0.0
tags: [health, monitoring, ops]
---

## Overview

GETs `/api/health`, validates HTTP 200 + JSON body with `status: "ok"`, measures response time, reports PASS or FAIL.

## When to Use

- After every deployment (called by `post-deploy-followup`)
- On-demand to confirm an app is running
- After an incident to verify recovery

## Prerequisites

- Deployed app URL (from Hermes memory key `last-deployment`, or provided directly)

## Procedure

1. Get app URL from Hermes memory key `last-deployment` or from user
2. `GET [url]/api/health`
3. Measure response time
4. Validate:
   - HTTP status = 200
   - Body parses as JSON
   - `status` field = `"ok"`
   - Response time < 3000ms

5. Report:
   ```
   Health check: [url]/api/health
   Status:        PASS / FAIL
   HTTP:          200 / [other]
   Response time: [ms]ms
   Body:          { "status": "ok", "version": "...", "timestamp": "..." }
   ```

6. On FAIL:
   - HTTP 404 → health endpoint missing, run `bootstrap.sh` to add it
   - Timeout → check Vercel function logs in dashboard
   - Wrong body → app running but health route has a bug
   - Run `send-notification` with failure alert
   - Save to Hermes memory: key `health-failure-log`

## Pitfalls

- HTTP 404 on `/api/health` means the endpoint is missing, not that the app is down.
- Response time > 3000ms is a warning, not automatic failure — log it but note cold start possibility.
- Vercel cold starts can cause the first request to be slow. If timeout on first check, retry once before reporting failure.

## Verification

Clear PASS or FAIL with HTTP status, response time, and body content printed.
