---
name: auto-issue-triage
description: Use when running on a cron schedule to automatically find, score, and pick the highest-priority GitHub issue to work on next
version: 1.0.0
tags: [github, issues, triage, cron, autonomous]
---

## Overview

Automated triage pass. Scores every open issue, picks the top priority, assigns it to Hermes, and routes it to the dev loop. Designed to run unattended on a cron schedule.

## When to Use

- Triggered by Hermes cron (hourly or daily schedule)
- No human present — fully autonomous
- Part of the `cto-loop` workflow

## Prerequisites

- GitHub CLI authenticated: `gh auth login`
- Hermes memory has `github-repo` key set (owner/repo)
- Hermes cron configured (see Setup below)

## Setup (one-time)

Tell Hermes:
```
schedule auto-issue-triage to run every hour
```

Hermes creates a cron job that fires this skill hourly. To check:
```
hermes cron list
```

## Procedure

1. **Fetch open issues:**
   ```bash
   gh issue list --repo [owner/repo] --state open --json number,title,labels,createdAt,comments --limit 50
   ```

2. **Score each issue** (0-10 scale, higher = do first):
   - `bug` label: +4
   - `priority:high` label: +3
   - `priority:low` label: -2
   - Has no label: +1 (needs triage, flag it)
   - Older than 7 days: +1
   - Has user comments (signal of impact): +1 per comment, max +2
   - Already assigned: skip

3. **Pick top-scoring issue.** If tie, pick older one.

4. **Check if already in progress:**
   - Retrieve `current-task` from Hermes memory
   - If a task is already in progress and not blocked: skip this cycle, send status update instead
   - If blocked or stalled > 4 hours: escalate to user via `send-notification`

5. **Assign and label:**
   ```bash
   gh issue edit [number] --add-assignee [hermes-github-username] --add-label "in-progress"
   ```

6. **Save to Hermes memory:**
   - key: `current-task`, value: `{ issueNumber, title, assignedAt: now }`

7. **Route to implementation:**
   - Load `choose-engine` with the issue title and body as the task description
   - After implementation: load `create-github-pr`
   - After PR: load `review-github-pr`

8. **If no actionable issues found:**
   - Send summary via `send-notification`: "No open issues. All caught up."
   - Log to memory: `{ checkedAt: now, status: "idle" }`

## Pitfalls

- Never start two tasks in parallel. Check `current-task` memory first.
- Issues labeled `wontfix`, `blocked`, or `needs-design` are not actionable — skip them.
- If the issue body is too vague to implement, do not guess. Load `send-notification` to ask the founder for clarification before starting work.

## Verification

- `current-task` updated in Hermes memory
- Issue assigned and labeled `in-progress` on GitHub
- `choose-engine` has been loaded to start implementation
