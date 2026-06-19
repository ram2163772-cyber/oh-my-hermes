---
name: health-check
description: Use when a deployed app needs to be verified as running, after every deployment, or on-demand to confirm availability
version: 1.1.0
tags: [health, monitoring, ops, supabase, vercel]
metadata:
  hermes:
    tags: [health, monitoring, supabase, vercel-logs]
    requires_toolsets: [terminal, web]
---

## Overview

Three-layer check: app endpoint → Supabase connection → Vercel recent logs. Reports a full picture, not just "is it up."

## When to Use

- After every deployment (called by `post-deploy-followup`)
- Scheduled every 15 minutes by Ops Agent cron
- On-demand after an incident to verify recovery

## Prerequisites

- Deployed app URL (from Hermes memory key `last-deployment-url`, or provided directly)
- `SUPABASE_URL` in environment (for Supabase check)
- Vercel CLI logged in (for log pull)

## Procedure

### 1. App health endpoint

```bash
curl -s -o /tmp/health_body.json -w "%{http_code} %{time_total}" \
  [url]/api/health
```

Validate:
- HTTP 200
- Body parses as JSON with `"status": "ok"`
- Response time < 3000ms (warn if > 1000ms)

On 404 → health endpoint missing, run `bootstrap.sh`.
On timeout → retry once (Vercel cold start), then fail.

### 2. Supabase connection check

```bash
curl -s -o /dev/null -w "%{http_code}" \
  "$SUPABASE_URL/rest/v1/" \
  -H "apikey: $SUPABASE_ANON_KEY"
```

- HTTP 200 → Supabase reachable
- HTTP 401/403 → reachable but key issue
- Timeout / 5xx → Supabase incident — check status.supabase.com

Also check DB query latency if `DATABASE_URL` is set:
```bash
psql "$DATABASE_URL" -c "SELECT 1" -t -A 2>&1
```

### 3. Vercel logs (last 50 lines)

```bash
vercel logs [deployment-url] --limit 50
```

Scan for:
- `Error:` or `Unhandled` — application errors
- `FATAL` — process crashes
- Response times > 5000ms — performance issues
- Status 500 or 502 — server errors

Flag any of these in the report. Do not flood the founder — summarize ("3 errors in the last 50 requests, all related to auth").

### 4. Report

```
Health check — [timestamp]
────────────────────────────────────
App endpoint:   PASS / FAIL  ([ms]ms)
Supabase:       PASS / FAIL
Vercel logs:    CLEAN / [n] errors detected

[If anything failed or logged errors:]
  Details: [plain-English summary]
  Action:  [what Hermes will do next]
```

### 5. On any FAIL

- Save to Hermes memory: key `health-failure-log`, append `{ timestamp, layer, detail }`
- Load `send-notification` with failure summary
- If Vercel logs show 500s: pull more logs and identify the failing route
- If Supabase down: check status.supabase.com, notify founder, do not attempt DB operations

## Pitfalls

- Vercel cold starts cause slow first requests — always retry once before failing.
- Supabase has its own status page (status.supabase.com) — check it before alerting, the issue may be on their end.
- `vercel logs` requires the deployment URL, not the alias. Get it from memory key `last-deployment-url`.
- Do not report Vercel log noise (routine 200s, OPTIONS requests) as errors.

## Verification

Full report printed with all three layers checked. Any failures logged to memory.
