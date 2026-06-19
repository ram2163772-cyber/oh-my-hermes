---
name: onboarding
description: Use when a user says "set up the CTO loop", "get started", or messages for the first time and github-repo is not saved in memory
version: 1.0.0
tags: [setup, onboarding, cto, guided]
---

## Overview

Guided conversational setup over chat. Asks one question at a time, explains every step in plain language, and configures everything internally. The user never opens a terminal.

## When to Use

- User says "set up the CTO loop", "get started", or "set up"
- `github-repo` key is not in Hermes memory
- First meaningful interaction after install

## Prerequisites

- Hermes Agent v0.9+ is installed and reachable.
- `gh` is installed on the host where setup runs.
- User can provide a GitHub repo, fine-grained token, production URL or `skip`, and daily report time.

## Procedure

Follow the steps below in order. Ask one question, wait for the answer, save the value to memory, then continue.

## Rules

- One question per message. Wait for the answer before continuing.
- Explain why you need each thing before asking for it.
- Never show a raw token back to the user. Acknowledge receipt with "✓ Connected" only.
- Keep messages short. No walls of text.

---

## Step 1 — Welcome

```
Hey! I'm your autonomous CTO. I'll watch your GitHub, implement fixes, review code, and ask for your approval before anything ships.

Let's get set up — it takes about 5 minutes and I'll guide you through each step.

What's your GitHub repository? (format: owner/repo — for example: acme/my-app)
```

Save answer → memory key `github-repo`.

---

## Step 2 — GitHub token

```
I need a token to read your issues and create pull requests. Here's exactly how to get one:

1. Go to github.com → click your profile photo (top right) → Settings
2. Scroll all the way down → click "Developer settings"
3. Click "Personal access tokens" → "Fine-grained tokens"
4. Click "Generate new token"
5. Give it any name, set expiry to 1 year
6. Under "Repository access" → "Only select repositories" → pick [their repo]
7. Under "Permissions" turn on:
   · Contents — Read and Write
   · Issues — Read and Write
   · Pull requests — Read and Write
   · Metadata — Read (turns on automatically)
8. Click "Generate token" at the bottom and copy it

Paste it here when ready. It starts with github_pat_
```

On receipt:
1. Run: `echo "[token]" | gh auth login --with-token && gh auth status`
2. Success → reply `✓ Connected to GitHub as [username]`, save `github-username` to memory
3. Failure → explain what went wrong (wrong permissions, expired), ask to try again
4. Never echo the token back

---

## Step 3 — Production URL

```
What's the URL of your live app? (for example: https://myapp.vercel.app)

I'll check it every 15 minutes to make sure it's running. If you haven't deployed yet, just say "skip" — I'll ask again after your first deploy.
```

Save answer → memory key `production-url` (or `not set` if skipped).

---

## Step 4 — Report time

```
Every morning I'll send you a summary — what's in progress, what shipped, anything that needs your attention.

What time works for you? (for example: "9am" or "8:30am")
```

Save answer → memory key `report-time`. Convert to cron: "9am" → `0 9`, "8:30am" → `30 8`.

---

## Step 5 — Run setup (silently)

Do not show these commands to the user. Run them in the background.

```bash
for profile in cto pm dev qa ops security; do
  hermes profile create "$profile" 2>/dev/null || true
done

hermes kanban init 2>/dev/null || true

hermes cron add "0 * * * *"    "Run auto-issue-triage for [github-repo]" 2>/dev/null
hermes cron add "*/15 * * * *" "Run health-check on [production-url]" 2>/dev/null
hermes cron add "[cron for report-time] * * *" "Send cto-status-report to founder" 2>/dev/null
hermes cron add "0 9 * * 1"    "Run security-review supply chain assessment for [github-repo]" 2>/dev/null
```

---

## Step 6 — Confirm

```
You're all set. Here's what I'll do from now on:

Every hour — I check your GitHub issues, pick the most important one, and start working on it.

When a fix is ready — I send you a message with what changed, whether tests pass, and a preview link. You reply YES or NO.

Every morning at [report-time] — a short summary of everything in progress, done, and blocked.

Every Monday — a security check on your packages.

Checking your open issues now...
```

Then load and run `auto-issue-triage` for the configured repo.

---

## Error handling

| Problem | Response |
|---|---|
| Token rejected | Re-explain the permissions, provide the link, ask to try again |
| No open issues | "Nothing open right now. Create an issue on GitHub and I'll pick it up within the hour." |
| Profile creation fails | "Run `hermes update` and message me again — your version may need an update." |
| gh CLI not found | "Type `! brew install gh` in your terminal, then message me again." |

## Pitfalls

- Do not continue after a failed GitHub token check.
- Do not reveal or repeat the token in chat, logs, or summaries.
- Do not create duplicate gateway sessions for the same bot token.

## Verification

- `github-repo`, `github-username`, `production-url`, and `report-time` are saved in memory.
- Profiles exist for `cto`, `pm`, `dev`, `qa`, `ops`, and `security`.
- Cron entries exist for issue triage, health check, daily report, and weekly security assessment.
- `hermes kanban list` succeeds after setup.
