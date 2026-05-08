# Changelog

## 1.2.0 — 2026-05-09

### Added — Autonomous CTO loop

**Skills**
- `auto-issue-triage` — cron-triggered hourly triage: scores issues by impact, picks top priority, routes to implementation
- `review-github-pr` — self-reviews PR diff, runs build + health check on preview URL, writes plain-English founder summary
- `await-merge-approval` — sends PR summary to founder via chat platform, blocks until YES/NO, merges or feeds back into the loop

**Workflows**
- `cto-loop` — full autonomous CTO workflow: cron → triage → implement → PR → review → approval → ship

**README**
- Added "Autonomous CTO loop" section with real example of the founder Telegram experience

---

## 1.1.0 — 2026-05-09

### Added

**Skills**
- `manage-github-issues` — triage, create, label, assign, and close GitHub issues via `gh` CLI
- `create-github-pr` — creates PR from feature branch with description drawn from Hermes memory

**Workflows**
- `github-ops` — full GitHub ops loop: triage issues → implement → PR → preview deploy → merge

### Changed

- All 13 existing skills rewritten with CSO-optimized descriptions (all start "Use when...")
- Descriptions now describe triggering conditions only — no workflow summaries
- All skills under 350 words for Hermes memory efficiency

---

## 1.0.0 — 2026-05-09

### Added

**Skills**
- `create-skill` — create new skills in the correct format (meta-skill)
- `clarify-requirements` — structured requirement clarification, stores answers to Hermes memory
- `product-brief` — generates product brief from clarified requirements, writes PRODUCT_BRIEF.md
- `design-handoff` — converts Claude Design output to an implementation spec
- `choose-engine` — routes a task to Claude Code, Codex, or Hermes based on task type
- `implement-with-claude-code` — scaffolds Claude Code session with full project context
- `implement-with-codex` — scaffolds Codex invocation with full context in command string
- `deploy-to-vercel` — deploys to Vercel with pre-deploy checks and post-deploy URL capture
- `connect-supabase` — wires Supabase project, runs migrations, sets Vercel env vars
- `setup-monitoring` — configures Sentry SDK and documents Uptime Kuma setup
- `health-check` — calls /health endpoint, validates response, reports status
- `send-notification` — sends Slack webhook notification with deployment or status info
- `post-deploy-followup` — runs health-check, logs deployment to memory, sends notification

**Workflows**
- `idea-to-deploy` — full lifecycle from idea to deployed app
- `design-to-code` — design output to implemented code
- `deploy-and-monitor` — deploy existing codebase with monitoring setup

**Templates**
- `templates/AGENTS.md.template` — AGENTS.md template for new projects
- `templates/.env.example` — environment variables template for new projects
- `templates/healthcheck/nextjs-health-route.ts` — /health endpoint for Next.js App Router
- `templates/healthcheck/express-health.js` — /health endpoint for Express

**Scripts**
- `install.sh` — installs skills and workflows to ~/.hermes/
- `scripts/bootstrap.sh` — bootstraps new projects with AGENTS.md, .env.example, health endpoint
- `scripts/verify.sh` — validates install completeness

**Documentation**
- `README.md`, `docs/architecture.md`, `docs/installation.md`, `docs/engines.md`
- `docs/workflows.md`, `docs/design-handoff.md`, `docs/improvements-to-hermes.md`

**Examples**
- `examples/starter-app/` — minimal Next.js + Supabase + Vercel starter
