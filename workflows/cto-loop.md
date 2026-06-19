---
name: cto-loop
description: Fully autonomous multi-agent CTO system with kanban tracking and founder approval gate
version: 2.0.0
tags: [autonomous, cto, workflow, github, kanban, agents]
---

## Overview

Six specialized agents coordinate the CTO loop. The founder sees a kanban board and gets a plain-English message when something needs approval. Nothing ships without a human YES.

## Agents

| Agent | Role | Triggers |
|---|---|---|
| **CTO Agent** | Orchestrates, monitors, escalates | Always running |
| **PM Agent** | Triages GitHub issues → kanban tickets | Hourly cron |
| **Dev Agent** | Implements tickets → PRs | PM assigns |
| **Security Agent** | Checks PR security and weekly supply chain risk | PR ready + weekly cron |
| **QA Agent** | Reviews PRs → founder summary | Dev completes PR |
| **Ops Agent** | Deploys, monitors, notifies | Merge + scheduled |

## The loop

```
CRON — every hour
  │
  ▼
PM AGENT: auto-issue-triage
  ├─ No actionable issues → "All caught up" → sleep
  ├─ Issue too vague → ask founder for clarification → sleep
  └─ Issue scored + ticketed → kanban-task (ready, assignee=dev)
        │
        ▼
CTO AGENT: reviews ready work and keeps the loop moving

DEV AGENT: dispatcher claims top ready ticket
  ├─ kanban-task (running)
  ├─ choose-engine → implement
  └─ create-github-pr
        │ handoff summary + metadata
        ▼
SECURITY AGENT: security-review
  ├─ Critical/High → kanban-task (blocked) → alert founder → Dev fixes
  └─ Clean/Medium  → hand to QA Agent
        │
        ▼
QA AGENT: review-github-pr
  ├─ FAIL → kanban-task (blocked) → feedback to Dev → Dev fixes
  └─ PASS → founder summary
        │ kanban comment + approval request
        ▼
CTO AGENT: await-merge-approval
  ├─ YES → gh pr merge
  │     │
  │     ▼
  │  OPS AGENT: post-deploy-followup
  │     ├─ health check PASS → kanban-task (done) → notify founder
  │     └─ health check FAIL → incident → alert founder → kanban-task (blocked)
  │
  ├─ NO  → feedback saved → reopen issue → kanban-task (ready) → loop
  └─ LATER → remind in 2h → loop
```

## Kanban board (what the founder sees)

```
Triage        Todo           Ready          Running        Blocked       Done
────────      ──────         ─────          ───────        ───────       ────
Raw idea      Waiting dep    #42 Login      #38 Fix        #40 Needs     #39 Dark mode
#45 CSV       Payment spec   PR review      redirect       approval      #37 Bug fix
```

## Monitoring (Ops Agent, always on)

Cron jobs Hermes sets up automatically:

```bash
hermes cron add "*/15 * * * *" "Run health-check on [production-url]"
hermes cron add "0 * * * *"    "Run auto-issue-triage for [owner/repo]"
hermes cron add "0 9 * * *"    "Send cto-status-report to founder"
hermes cron add "0 9 * * 1"    "Run security-review supply chain assessment for [owner/repo]"
```

## Multi-agent execution

Hermes supports spawning up to 3 parallel sub-agents. In the CTO loop:
- The **CTO Agent** (main session) orchestrates and monitors
- It spawns **PM**, **Dev**, **Security**, **QA**, and **Ops** as sub-agents when assigning work
- Sub-agents share memory and kanban with the main session
- Max 3 parallel tasks at once (Hermes default)

## Setup

Run `scripts/setup-cto.sh` first (creates profiles, kanban, crons). Then tell Hermes:

```
Set up the CTO loop for [owner/repo]. 
Send approvals to me on [Telegram / Slack / Discord / WhatsApp].
```

Then lock persistent focus with `/goal` (Hermes v0.13+):

```
/goal Manage github.com/[owner/repo] as CTO. Triage issues hourly, implement top priority, send founder approval before merging. Never ship without YES.
```

`/goal` prevents context drift across long sessions — without it agents lose focus after many turns. Re-run `/goal` any time you restart the CTO session.

What Hermes does on setup:
1. Saves `github-repo` and `approval-platform` to memory
2. Creates profiles for CTO, PM, Dev, Security, QA, and Ops agents
3. Runs `hermes cron add` for triage, health check, morning report, and weekly security assessment
4. Confirms setup and shows the live kanban board

## Live board

```bash
hermes kanban watch    # live dashboard — see all tasks in real time
hermes kanban list     # snapshot of current tasks
```

## Customization (tell Hermes anytime)

```
pause the CTO loop until Monday
only work on bugs this week
skip issue #42, it's blocked on design
make triage run every 30 minutes
show me the kanban board
what is the Dev Agent working on right now?
```

Use `/steer` (v0.13+) to course-correct mid-run without interrupting the current task:
```
/steer prioritize the payment bug above everything else
/steer skip tests this sprint, we need to ship
```

## What the founder actually does

Receive a message. Read 10 lines. Reply YES or NO. That's it.
