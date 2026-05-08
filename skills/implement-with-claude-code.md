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

## Pitfalls

- Always include "Read AGENTS.md before starting" — Claude Code follows this.
- Include full memory context in the prompt. Claude Code cannot access Hermes memory.
- Be specific: "Add Stripe billing — monthly/annual plans, store subscription status in Supabase users table, add /api/billing/subscribe and /api/billing/cancel endpoints" not "add billing."

## Verification

- User confirms expected output exists
- Outcome saved to Hermes memory
