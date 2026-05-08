---
name: github-ops
description: Manage GitHub issues and pull requests from idea to merge
version: 1.0.0
tags: [github, workflow, issues, pr]
---

## Overview

Full GitHub ops workflow: triage issues → route to implementation → create PR → verify → merge.

## Steps

```
ISSUE / BUG REPORT
  ↓  manage-github-issues   ← triage, label, assign
  ↓  choose-engine          ← route to Hermes / Claude Code / Codex
  ↓  implement              ← build the fix or feature
  ↓  create-github-pr       ← PR from feature branch with memory context
  ↓  deploy-to-vercel       ← preview deployment auto-created by Vercel
  ↓  health-check           ← verify preview URL
  ↓  [human] review + merge
  ↓  post-deploy-followup   ← production health check + notification
```

## Usage

Tell Hermes:
```
triage our GitHub issues
```
```
I fixed the auth bug in src/middleware.ts — create a PR
```
```
run the github-ops workflow for issue #42
```

## Notes

- Preview deployments are created automatically when a PR is opened (requires Vercel GitHub integration, set up via `deploy-to-vercel`)
- Merging to main triggers production deployment automatically
- `post-deploy-followup` runs after every production deploy
