---
name: connect-supabase
description: Use when a Supabase project needs to be linked to the app for the first time, or when new migrations need to be pushed
version: 1.0.0
tags: [supabase, database, setup, migrations]
---

## Overview

Links Supabase to the project, sets environment variables locally and in Vercel, pushes migrations.

## When to Use

- First-time Supabase connection for this project
- New migrations to push to the live database
- Supabase env vars missing from Vercel

## Prerequisites

- Supabase account and project created at supabase.com
- Supabase CLI: `npm install -g supabase`
- Logged in: `supabase login`
- Project ref from Supabase dashboard → Project Settings → General

## Procedure

**Initial setup:**
```bash
supabase init                               # if not already initialized
supabase link --project-ref [project-ref]
```

Add to `.env.local` (values from Supabase dashboard → Settings → API):
```
SUPABASE_URL=https://[ref].supabase.co
SUPABASE_ANON_KEY=[anon-key]
SUPABASE_SERVICE_KEY=[service-role-key]
DATABASE_URL=postgresql://postgres:[password]@db.[ref].supabase.co:5432/postgres
```

Add vars to Vercel:
```bash
vercel env add SUPABASE_URL production
vercel env add SUPABASE_ANON_KEY production
vercel env add SUPABASE_SERVICE_KEY production
vercel env add DATABASE_URL production
```

Push migrations:
```bash
supabase db push
```

Save to Hermes memory: key `supabase-config`, value `{ projectRef, url }`.

**Adding new migrations:**
```bash
supabase migration new [migration-name]
# edit the generated file
supabase db push
```

## Pitfalls

- `SUPABASE_SERVICE_KEY` has full DB access — never prefix with `NEXT_PUBLIC_` or expose to the client.
- `supabase db push` is irreversible for destructive changes. Review migration files before running.
- Always commit migration files to git — they are the schema source of truth.

## Verification

- `supabase status` shows linked and correct project
- All 4 env vars in `.env.local` and Vercel dashboard
- `supabase db diff` shows no pending changes
