---
name: choose-engine
description: Use when starting a coding task and unsure whether Hermes, Claude Code, or Codex should execute it
version: 1.0.0
tags: [routing, orchestration, engine]
---

## Overview

5-branch decision tree that routes tasks to the right execution engine. Fast — a decision should take seconds.

## When to Use

- Starting any coding or ops task
- After `design-handoff` or `product-brief` completes
- User asks "who should do this?"

## Prerequisites

- Task description available (from user, memory, or implementation spec)

## Procedure

Apply in order — stop at the first match:

1. **UI/UX exploration, no code yet?**
   → Claude Design (human step at claude.ai/design). Tell user, then offer to run `design-handoff` with the output.

2. **Operational task?** (deploy, monitor, notify, health check, schedule, run migration)
   → Hermes handles directly. Load the matching skill.

3. **Complex multi-file change?** (new feature across files, architectural refactor, new subsystem, test suite from scratch)
   → Claude Code. Load `implement-with-claude-code`.

4. **Targeted single-file change?** (known bug in specific file, adding one field, quick prototype)
   → Codex. Load `implement-with-codex`.

5. **Still unsure?** Ask once: "How many files will this change?" 1-2 → Codex. 3+ → Claude Code.

State the recommendation and rationale in one sentence. Offer to immediately load the implement skill.

## Pitfalls

- The choice between Claude Code and Codex is recoverable. Do not overthink — speed matters more than perfection.
- Do not route operational tasks to coding engines. Deploy, monitor, notify → Hermes only.
- If a Codex task expands to 3+ files during execution, stop and switch to Claude Code.

## Verification

Recommendation stated with rationale. Next skill loaded and running.
