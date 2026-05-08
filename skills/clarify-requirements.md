---
name: clarify-requirements
description: Use when a new project or significant feature starts and requirements are vague, unwritten, or only described in one sentence
version: 1.0.0
tags: [requirements, planning, memory]
---

## Overview

Structured 7-question intake. Saves answers to Hermes memory so every downstream skill has shared context.

## When to Use

- New project with no written requirements
- New major feature where scope is unclear
- User said "build me X" without specifying users, constraints, or success criteria

Do NOT use for bug fixes, small changes, or when requirements are already documented.

## Prerequisites

None. Run before anything else.

## Procedure

Ask these 7 questions. Wait for all answers before saving.

1. What problem does this solve? Who experiences it and how often?
2. Who are the primary users? Be specific ("solo founders building SaaS" not "developers").
3. What are the 3 most important features for V1? Priority order.
4. What is explicitly out of scope for this version?
5. What is the preferred tech stack, or are there constraints?
6. Hard constraints: deadline, budget, must-integrate-with systems, compliance?
7. What does success look like 30 days after launch?

After all 7 answers:
- Save to Hermes memory: key `requirements-[project-name]`
- Format as structured Q&A
- Confirm to user, offer to run `product-brief`

## Pitfalls

- Do not start implementing during clarification. Redirect: "Let's finish requirements first."
- Do not save partial answers. Wait for all 7.
- If user cannot answer a question, save as `[OPEN QUESTION: ...]` — do not skip.
- Do not ask more than 7 questions.

## Verification

Recall `requirements-[project-name]` from Hermes memory. All 7 answers present. Open questions marked.
