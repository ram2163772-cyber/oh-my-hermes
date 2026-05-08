---
name: cto-loop
description: Fully autonomous development loop — Hermes monitors issues, implements, reviews, and ships with founder approval
version: 1.0.0
tags: [autonomous, cto, workflow, github, cron]
---

## Overview

The core loop that makes Hermes a real CTO for non-technical founders. Runs continuously via cron. The founder only needs to reply YES or NO on their phone.

## The Loop

```
CRON — every hour
  ↓
auto-issue-triage
  ├─ No actionable issues → "All caught up" → sleep
  ├─ Issue too vague → ask founder for clarification → sleep
  └─ Issue picked → assign + label "in-progress"
        ↓
     choose-engine
        ├─ Hermes handles directly (ops tasks)
        ├─ → implement-with-claude-code (complex)
        └─ → implement-with-codex (quick fix)
              ↓
           create-github-pr (draft)
              ↓
           review-github-pr
              ├─ Health check FAIL → fix or flag → notify founder
              ├─ Secrets detected → STOP → alert founder
              └─ All clear → compose plain-English summary
                    ↓
                 await-merge-approval
                    ├─ YES → merge → post-deploy-followup → loop
                    ├─ NO  → feedback → reopen issue → loop
                    └─ LATER → remind in 2h → loop
```

## Setup

Tell Hermes once:

```
Set up the CTO loop. Monitor our GitHub repo [owner/repo], 
triage issues every hour, and send approvals to me on [Telegram/Slack/Discord].
```

Hermes will:
1. Ask for your GitHub repo name
2. Ask which messaging platform to use for approvals
3. Set up the hourly cron job
4. Send you a confirmation

## What the founder experiences

- Receives a message when something is ready: plain English, preview link, YES/NO prompt
- Replies YES → it ships. Replies NO → tells Hermes what to change
- Nothing else required. No GitHub logins. No terminal.

## What Hermes handles autonomously

- Monitoring open issues around the clock
- Prioritizing by impact and urgency
- Routing to the right implementation engine
- Running builds and health checks
- Writing the PR and reviewing it
- Deploying to preview, then production after approval
- Sending Slack/Telegram notifications after every deploy
- Logging everything to memory for future context

## Escalation rules

Hermes messages the founder immediately (does not wait for cron) when:
- Health check fails on production
- A secret or credential is detected in a diff
- An issue has been stalled for more than 24 hours
- A task has been attempted twice and still fails

## Customization

Tell Hermes at any time:
```
pause the CTO loop until Monday
```
```
only work on bugs, ignore feature requests for now
```
```
skip issue #42, it's blocked on design
```
```
make the triage run every 30 minutes instead of hourly
```
