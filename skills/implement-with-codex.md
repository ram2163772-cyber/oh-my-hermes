---
name: implement-with-codex
description: Use when choose-engine has routed to Codex for a targeted single-file or quick-fix task
version: 1.0.0
tags: [implementation, codex, coding]
---

## Overview

Composes a self-contained Codex CLI command. Codex context is per-invocation — every relevant detail must be in the command string.

## When to Use

- `choose-engine` routed the task here
- Task is 1-2 files, well-scoped, location known
- Quick bug fix in a specific function

## Prerequisites

- Codex CLI installed (`npm install -g @openai/codex`)
- `OPENAI_API_KEY` set in environment
- Task description is specific and scoped

## Procedure

1. Retrieve relevant context from Hermes memory (architecture decisions, specific file and function)

2. Compose the Codex command — ALL context in the string:
   ```bash
   codex "[file path], [what is wrong], [how to fix it], [do not change other files]"
   ```

   Example:
   ```bash
   codex "In src/middleware.ts, auth redirect sends users to /login even when authenticated. The check uses supabase.auth.getSession(). Fix the condition so authenticated users go to /dashboard instead. Do not change other files."
   ```

3. Provide the exact command to the user (or execute directly in automated context)

4. After completion: save outcome to Hermes memory

## Scope constraint

Add to every Codex prompt:

```
Change only the file and function named above.
Do not touch other files. Do not refactor adjacent code.
After changes: commit with a clear message.
Do NOT commit .env files, API keys, tokens, or any credentials.
```

## Pitfalls

- Every invocation starts fresh. Put ALL relevant context in the prompt string — no persistent state.
- Scope tightly. If the task expands to 3+ files, stop and load `implement-with-claude-code` instead.
- Name the file and function explicitly in the prompt.

## Verification

- Only the named file changed
- Build/typecheck passes: `npm run typecheck`
- Changes committed with a clear message
- No secrets in committed files
- Outcome saved to Hermes memory
