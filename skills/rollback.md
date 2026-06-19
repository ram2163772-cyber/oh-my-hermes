---
name: rollback
description: Use when a health check fails after a deploy and the last deploy was under 2 hours ago, to roll back production to the previous working deployment
version: 1.0.0
tags: [ops, vercel, rollback, incident]
metadata:
  hermes:
    tags: [ops, deployment, incident, recovery]
    requires_toolsets: [terminal]
---

## Overview

Rolls back the Vercel production deployment to the previous version. Always requires explicit founder confirmation before executing. Logs the rollback to memory and notifies via `send-notification`.

## When to Use

- Health check fails after a deploy AND last deploy was under 2 hours ago
- Founder explicitly requests a rollback
- Ops Agent identifies a production incident tied to a recent change

Do NOT use for incidents unrelated to a recent deploy (e.g., Supabase outage, external API failure).

## Prerequisites

- `VERCEL_TOKEN` in environment
- `vercel` CLI installed and authenticated: `vercel whoami`
- Hermes memory has `last-deployment-url` (set by `deploy-to-vercel`)
- Founder has been notified of the incident before this skill runs

## Procedure

1. **Retrieve last deployment URL from memory:**
   ```bash
   LAST_DEPLOY_URL=$(hermes memory get last-deployment-url 2>/dev/null)
   ```
   If empty, ask founder for the deployment URL before proceeding.

2. **Show founder what will happen** — send this message via `send-notification` before acting:
   ```
   Rolling back production.

   Current (broken): [current-url]
   Rolling back to: previous deployment

   This will make the previous deployment live immediately.

   Reply YES to confirm.
   ```

3. **Wait for explicit YES.** If no response in 10 minutes, do not roll back. Alert founder again.

4. **Execute rollback:**
   ```bash
   vercel rollback "$LAST_DEPLOY_URL" --token "$VERCEL_TOKEN" --yes
   ```

5. **Verify recovery** via `health-check` — wait 30 seconds for propagation, then run:
   ```bash
   curl -s -w "\n%{http_code}" "[production-url]/api/health"
   ```
   Expected: HTTP 200 + `"status":"ok"`.

6. **Save to memory:** key `rollback-log`, append `{ rolledBackAt, fromUrl, reason, healthStatus }`.

7. **Notify founder** of outcome via `send-notification`:
   - Success: "Rolled back. Production is healthy. Health: [response-time]ms."
   - Failure: "Rollback completed but health check still failing. Manual investigation needed."

8. **Update kanban card** for the deploy that caused the incident to `blocked` with a note.

## Pitfalls

- Never roll back without founder confirmation — always send the confirmation message first.
- Vercel rollback targets a specific deployment URL, not "previous". Use `last-deployment-url` from memory or ask for the exact URL.
- If health check still fails after rollback, the issue is not deployment-related — escalate to founder with logs summary.
- Do not chain multiple rollbacks. One rollback, verify, then stop. If still broken, alert founder.

## Verification

- `vercel ls --token "$VERCEL_TOKEN"` shows previous deployment now marked as current
- `curl [production-url]/api/health` returns HTTP 200 + `status: ok`
- Rollback entry saved to `rollback-log` in Hermes memory
- Founder notified of outcome
