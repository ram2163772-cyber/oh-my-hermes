---
name: create-github-pr
description: Use when implementation is complete on a feature branch and a pull request needs to be created
version: 1.0.0
tags: [github, pr, ops, review]
---

## Overview

Creates a GitHub PR with a description drawn from Hermes memory — implementation spec, feature name, and linked issues. Uses `gh` CLI.

## When to Use

- Feature or fix complete on a non-main branch
- About to trigger preview deployment on Vercel
- Need to request review before merging to production

## Prerequisites

- GitHub CLI: `gh auth login`
- Changes committed and pushed to a feature branch
- At least one Hermes memory entry about the implementation (spec, brief, or summary)

## Procedure

1. Confirm current branch and remote:
   ```bash
   git branch --show-current
   git remote -v
   ```

2. Push branch if not yet pushed:
   ```bash
   git push -u origin [branch-name]
   ```

3. Retrieve from Hermes memory:
   - `implementation-spec-[feature-name]` or `implementation-[feature-name]`
   - Any linked issue numbers

4. Compose PR body:
   ```
   ## What
   [one-paragraph description of what changed]

   ## Why
   [problem being solved — from requirements or issue]

   ## Implementation notes
   [key decisions, trade-offs, anything a reviewer should know]

   ## Test plan
   - [ ] [specific thing to test]
   - [ ] Health check at preview URL

   Closes #[issue-number]
   ```

5. Create the PR:
   ```bash
   gh pr create \
     --title "[descriptive title]" \
     --body "[composed body]" \
     --base main \
     --draft
   ```
   Use `--draft` by default. Remove when ready for review.

6. Save PR URL to Hermes memory: key `pr-[feature-name]`, value `{ url, number, branch }`.

7. Offer to run `health-check` on the Vercel preview URL.

## Pitfalls

- PR title should describe the change, not the ticket: "Add Stripe billing" not "Fix issue #42."
- Always create as draft first — prevents accidental merge before testing.
- `Closes #[n]` in the body auto-closes the issue on merge. Use only when the issue is fully resolved by this PR.

## Verification

- `gh pr view` shows PR in correct state
- PR URL saved to Hermes memory
- Linked issue shows PR reference in GitHub UI
