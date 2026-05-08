---
name: product-brief
description: Use when requirements are saved to Hermes memory and a written artifact is needed before implementation or design begins
version: 1.0.0
tags: [planning, brief, memory]
---

## Overview

Transforms raw requirements from Hermes memory into a structured product brief. Writes PRODUCT_BRIEF.md as a shareable artifact.

## When to Use

- After `clarify-requirements` has completed
- Memory contains `requirements-[project-name]`
- Need a document to share with collaborators or hand off to a coding engine

## Prerequisites

- Hermes memory contains `requirements-[project-name]`

## Procedure

1. Retrieve `requirements-[project-name]` from Hermes memory
2. Generate a product brief with these sections:
   - **Problem Statement** — one paragraph: problem, who, how often
   - **Target Users** — specific description
   - **Core Features (V1)** — max 5, numbered, priority order, one-sentence each
   - **Out of Scope (V1)** — explicit exclusions
   - **Tech Stack** — each layer with chosen tool and one-sentence rationale
   - **Success Criteria** — measurable outcomes at 30 days
   - **Open Questions** — anything marked [OPEN QUESTION] in requirements
3. Save to Hermes memory: key `product-brief-[project-name]`
4. Write to `PRODUCT_BRIEF.md` in current directory
5. Offer to continue to `design-handoff` or `choose-engine`

## Pitfalls

- Do not invent requirements not in memory. Mark anything unclear as open question.
- Do not list more than 5 core features. Prioritize ruthlessly.
- Tech stack entries must be specific: "Supabase PostgreSQL — built-in RLS and auth" not "a database."

## Verification

- `PRODUCT_BRIEF.md` exists in current directory
- Brief retrievable from Hermes memory as `product-brief-[project-name]`
- All [OPEN QUESTION] items from requirements appear in Open Questions section
