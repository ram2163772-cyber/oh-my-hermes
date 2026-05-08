---
name: design-handoff
description: Use when design-output.md exists in the current directory after a Claude Design session and implementation has not yet started
version: 1.0.0
tags: [design, handoff, implementation, spec]
---

## Overview

Converts raw Claude Design session notes into a structured implementation spec. Removes ambiguity before code is written.

## When to Use

- `design-output.md` exists in the current directory
- About to route to Claude Code or Codex for implementation
- Design notes are in prose and need to become concrete engineering tasks

## Prerequisites

- `design-output.md` in current directory with exported design notes
- `product-brief-[project-name]` in Hermes memory (recommended, not required)

## Procedure

1. Read `design-output.md` from current directory
2. Generate implementation spec with these sections:
   - **Components to build** — name, description, props/data needed
   - **Data requirements** — what each component needs and where it comes from
   - **Routes / Pages** — each route and what renders there
   - **API endpoints** — method, path, request shape, response shape
   - **Database changes** — new tables, columns, indexes, RLS policies
   - **Interactions** — click handlers, form submissions, real-time updates
   - **Edge cases** — from the design output
   - **Implementation order** — data layer → API → components → integration
3. Mark ambiguous items `[NEEDS CLARIFICATION]` — do not guess
4. Save to Hermes memory: key `implementation-spec-[feature-name]`
5. Write to `IMPLEMENTATION_SPEC.md` in current directory
6. Run `choose-engine` to route to the appropriate coding engine

## Pitfalls

- Do not guess at data shapes not in the design output. Mark `[NEEDS CLARIFICATION]`.
- Do not assume database schema unless stated in design or product brief.
- Always start implementation order with the data layer — not UI components.

## Verification

- `IMPLEMENTATION_SPEC.md` exists in current directory
- All ambiguities marked `[NEEDS CLARIFICATION]`
- Spec retrievable from Hermes memory as `implementation-spec-[feature-name]`
