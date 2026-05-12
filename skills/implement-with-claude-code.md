---
name: implement-with-claude-code
description: Use when choose-engine has routed to Claude Code for complex multi-file implementation
version: 1.0.0
tags: [implementation, claude-code, coding]
---

## Overview

Composes a handoff prompt from Hermes memory and project context. Claude Code has no access to Hermes memory — context must be explicitly passed.

## When to Use

- `choose-engine` routed the task here
- Task spans 3+ files or involves unknown architectural decisions
- Building from scratch, major refactor, or writing a test suite

## Prerequisites

- Claude Code installed (`npm install -g @anthropic-ai/claude-code`)
- Project has `AGENTS.md` (run `bootstrap.sh` if missing)
- Task description available

## Procedure

1. Retrieve from Hermes memory:
   - `product-brief-[project-name]` (if exists)
   - `implementation-spec-[feature-name]` (if design handoff done)
   - `requirements-[project-name]` (if exists)
   - Any architecture decisions or "avoid" notes

2. Compose handoff prompt:
   ```
   Context from project memory:
   [paste relevant memory entries]

   Task:
   [specific description of what to implement]

   Constraints:
   - Read AGENTS.md before starting
   - [stack requirements]
   - [specific constraints from brief or requirements]

   Expected output:
   [what should exist when done]
   ```

3. Tell user: "Open Claude Code in the project directory: `claude`"
4. Provide the exact prompt to paste (from step 2)
5. After session: ask user to confirm expected output exists. Save to Hermes memory: `implementation-[feature-name]` → `completed by Claude Code on [date]`

## Scope constraint

Every changed file must trace directly to the task. Include in the handoff prompt:

```
Surgical scope:
- Change only what the task requires. Do not refactor adjacent code.
- Do not add features beyond what is specified.
- Match existing code style — do not reformat.
- Commit after every logical unit of work with a clear message.

Never commit:
- API keys, tokens, passwords, or credentials of any kind
- .env files or any file matching *.env*
- Connection strings with passwords embedded
- Private keys or certificates
Run `git diff --staged` and scan for secrets before every commit.
If you see a key or credential, stop and tell the user immediately.
```

## Pitfalls

- Always include "Read AGENTS.md before starting" — Claude Code follows this.
- Include full memory context in the prompt. Claude Code cannot access Hermes memory.
- Be specific: "Add Stripe billing — monthly/annual plans, store subscription status in Supabase users table" not "add billing."

## Verification

- User confirms expected output exists
- All changed files trace directly to the task — no unrelated edits
- No secrets in committed files
- Outcome saved to Hermes memory
