---
name: await-merge-approval
description: Use when a PR is ready and the founder needs to approve or reject before Hermes merges to production
version: 1.0.0
tags: [github, pr, approval, autonomous, human-in-loop]
---

## Overview

Sends the PR summary to the founder via their configured messaging platform, then blocks until they reply. On YES: merges and deploys. On NO: notes feedback and closes the loop. The founder never needs to open GitHub.

## When to Use

- After `review-github-pr` completes with a passing health check
- Always — never merge without human approval

## Prerequisites

- PR number and founder summary from `review-github-pr`
- Hermes messaging platform configured (Telegram, Slack, Discord, WhatsApp, etc.)
- `SLACK_WEBHOOK_URL` or equivalent set in environment

## Procedure

1. **Send approval request** via the founder's primary messaging platform:

   Message format:
   ```
   New update ready for your approval

   PR #[n]: [title]
   [plain-English summary from review-github-pr]

   Preview: [url]

   Reply:
   YES — merge to production
   NO  — skip this one (tell me why and I'll fix it)
   LATER — remind me in 2 hours
   ```

2. **Save pending state to Hermes memory:**
   - key: `pending-approval`, value: `{ prNumber, sentAt: now, status: "waiting" }`

3. **Wait for response.** Hermes listens on the messaging platform.

4. **On YES:**
   ```bash
   gh pr merge [number] --squash --delete-branch
   ```
   Then load `post-deploy-followup` (Vercel auto-deploys on merge to main).
   Update memory: `pending-approval.status = "approved"`, clear `current-task`.

5. **On NO:**
   - Ask: "What should be changed?" — wait for one more message
   - Save feedback to Hermes memory: key `pr-feedback-[number]`
   - Close the PR: `gh pr close [number] --comment "[feedback]"`
   - Reopen the issue: `gh issue reopen [issue-number]`
   - Add feedback as issue comment
   - Clear `current-task` from memory — issue goes back to the triage queue

6. **On LATER:**
   - Set a 2-hour Hermes reminder: `hermes remind 2h "Pending PR #[n] approval"`
   - Reply: "Reminded. I'll check back in 2 hours."

7. **On no response after 24 hours:**
   - Send one follow-up: "Still waiting on your approval for PR #[n]. Reply YES / NO / LATER."
   - If no response after another 24h: mark as `stalled`, notify founder, pause the loop.

## Pitfalls

- Never merge without explicit YES. LATER is not YES.
- If the founder says NO without explaining why, always ask for the reason before closing. The reason becomes feedback for the next implementation attempt.
- Squash merge keeps the main branch history clean — one commit per feature/fix.
- After merge, do not try to health-check immediately — wait for Vercel deployment to complete (typically 30-90 seconds). `post-deploy-followup` handles the timing.

## Verification

- Founder received the message on their platform
- Memory updated with approval state
- On YES: `gh pr view [number]` shows merged
- On NO: issue back to open state with feedback comment
