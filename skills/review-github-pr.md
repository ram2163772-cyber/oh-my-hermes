---
name: review-github-pr
description: Use when a PR has been created and needs to be self-reviewed before presenting to the user for merge approval
version: 1.0.0
tags: [github, pr, review, autonomous, quality]
---

## Overview

Hermes reviews its own PR: checks the diff for quality, runs build and typecheck, runs health check on the preview URL, writes a plain-English summary for the founder. No jargon — written for a non-technical reader.

## When to Use

- Immediately after `create-github-pr` completes
- Part of the `cto-loop` workflow
- Before loading `await-merge-approval`

## Prerequisites

- PR created and push to branch complete
- Vercel preview URL available (auto-generated when PR is opened with GitHub integration)
- `gh` CLI authenticated

## Procedure

1. **Get PR details:**
   ```bash
   gh pr view [number] --json number,title,body,url,headRefName,files
   gh pr diff [number]
   ```

2. **Check automated status:**
   ```bash
   gh pr checks [number]
   ```
   Wait up to 3 minutes for CI checks to complete. If still running, note "CI in progress."

3. **Review the diff.** Flag any of:
   - New env vars added but not in `.env.example`
   - Secrets or API keys hardcoded
   - TODO or FIXME comments left in production code
   - Files changed outside the expected scope (scope creep)
   - Missing error handling at API boundaries

4. **Health check preview URL:**
   - Vercel preview URL format: `https://[repo]-[branch]-[org].vercel.app`
   - Load `health-check` with the preview URL
   - Record: PASS / FAIL + response time

5. **Compose founder summary** (plain English, no jargon):
   ```
   PR #[n]: [title]
   ───────────────────────────────
   What changed:
   [2-3 sentences: what the feature or fix does, in plain language]

   Files touched: [n] files
   [list the most important ones with one-line plain-English description]

   Quality checks:
   ✓ Build: passing
   ✓ Preview health: OK (200ms)
   ✓ No secrets detected
   [any flags or warnings]

   Preview link: [url]
   Full diff:    [gh pr url]

   Ready to merge to production? Reply YES to merge, NO to skip.
   ```

6. **Load `await-merge-approval`** with the PR number and summary.

## Pitfalls

- If health check FAILS on preview: do NOT load `await-merge-approval`. Fix the issue first or label the PR `blocked` and notify the founder.
- If secrets are detected in the diff: stop immediately, alert founder, do not proceed to approval.
- Write the summary for someone who does not read code. "Updated the login button" not "Refactored auth middleware token validation."

## Verification

- PR checks status retrieved
- Health check run on preview URL
- Founder summary written in plain English
- `await-merge-approval` loaded with summary
