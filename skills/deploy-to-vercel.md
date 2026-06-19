---
name: deploy-to-vercel
description: Use when implementation is complete and the project needs to be deployed or redeployed to Vercel
version: 1.0.0
tags: [deployment, vercel, ops]
---

## Overview

Pre-deploy checks → deploy → capture URL → trigger post-deploy-followup. Includes one-time GitHub auto-deploy setup.

## When to Use

- First deployment to Vercel
- Redeployment after changes
- Implementation is complete and build passes locally

## Prerequisites

- Vercel CLI: `npm install -g vercel`
- Logged in: `vercel login`
- Git repo initialized with at least one commit
- Project has `/api/health` endpoint

## Procedure

**Pre-deploy checklist — fix all failures before continuing:**
1. `git status` → clean working tree, no uncommitted changes
2. `.env.local` is in `.gitignore`
3. `AGENTS.md` is committed
4. `/api/health` endpoint exists
5. `npm run build` passes locally

**First-time deploy:**
```bash
vercel        # interactive — links to Vercel project
vercel --prod
```

**Redeployment:**
```bash
vercel --prod
```

Capture deployment URL from output.

**GitHub auto-deploy (one-time, first deploy only):**
```bash
vercel link
```
Then: Vercel dashboard → Settings → Git → Connect Repository.
After connecting: main branch pushes → production. Other branches → preview URLs.

**Post-deploy:**
1. Save URL to Hermes memory: key `last-deployment-url`, value URL string
2. Run `post-deploy-followup`

## Pitfalls

- `vercel --prod` exit code 0 does NOT mean the app is healthy. Always run `post-deploy-followup`.
- Build fails on Vercel but passes locally: check Vercel env vars, Node.js version, missing build deps.
- Force fresh build if cached: `vercel --force --prod`

## Verification

- `vercel --prod` exits 0
- Deployment URL captured and in Hermes memory
- `post-deploy-followup` started
