# Architecture

## What Oh My Hermes is

Oh My Hermes is not a runtime. It is an opinionated extension layer — a curated set of skills, conventions, templates, and documentation that makes Hermes Agent useful for real app-building and app-ops workflows.

The repository ships files. Hermes runs them.

## Component roles

### Hermes Agent (operator layer)

Hermes is the long-lived operator. It:

- Remembers project context across sessions via its 4-layer memory system
- Orchestrates work by loading skills and routing to coding engines
- Runs deployment and health checks
- Sends notifications via its unified messaging gateway
- Schedules recurring tasks via its cron system

Oh My Hermes does not modify or wrap Hermes. It provides skills and AGENTS.md conventions that Hermes loads automatically.

### Claude Design (design surface)

Claude Design is a human-in-the-loop step. There is no public Claude Design API, so this cannot be automated. The workflow is:

1. You open Claude Design and do UI/UX work
2. You export the design decisions as text (component descriptions, layout notes, interaction patterns)
3. You run the `design-handoff` skill to convert that text into an implementation spec
4. Hermes saves the spec to memory and routes it to a coding engine

This is documented honestly. Oh My Hermes does not pretend to automate a step that requires human interaction.

### Claude Code (primary coding engine)

Claude Code is preferred for:

- New features involving multiple files
- Architectural changes
- Test suites
- Complex refactors
- Building from a product brief with many unknown decisions

Claude Code has full file system access, git integration, and can run commands. It is better for work that requires judgment across many files simultaneously.

### Codex (secondary coding engine)

Codex is preferred for:

- Quick targeted fixes (one or two files)
- Exploratory prototyping
- Simple, well-defined changes where the decision is already made
- Faster iteration on small tasks

See `docs/engines.md` for the full routing decision framework.

### Vercel (deployment)

Default deployment target. Connected via:

- `vercel` CLI for deployments from terminal
- Vercel GitHub integration for automatic deploy-on-push
- Vercel API for deployment status queries

The `deploy-to-vercel` skill handles deployment, pre-deploy checks, and post-deploy URL capture.

### Supabase (backend)

Default backend provider. Provides:

- PostgreSQL database
- Row Level Security (RLS) for data isolation
- Auth (email, OAuth, magic link)
- Storage (file uploads)
- Migrations via Supabase CLI

The `connect-supabase` skill handles project linking, migration setup, and environment variable wiring.

---

## Repository structure

```
oh-my-hermes/
├── README.md
├── AGENTS.md
├── CHANGELOG.md
├── .env.example
├── install.sh
│
├── docs/
│   ├── installation.md
│   ├── architecture.md             ← this file
│   ├── workflows.md
│   ├── engines.md
│   ├── design-handoff.md
│   └── improvements-to-hermes.md
│
├── skills/                         ← SKILL.md files (agentskills.io format)
│   ├── clarify-requirements.md
│   ├── product-brief.md
│   ├── design-handoff.md
│   ├── choose-engine.md
│   ├── implement-with-claude-code.md
│   ├── implement-with-codex.md
│   ├── deploy-to-vercel.md
│   ├── connect-supabase.md
│   ├── setup-monitoring.md
│   ├── health-check.md
│   ├── send-notification.md
│   └── post-deploy-followup.md
│
├── workflows/
│   ├── idea-to-deploy.md
│   ├── design-to-code.md
│   └── deploy-and-monitor.md
│
├── templates/
│   ├── AGENTS.md.template
│   ├── .env.example
│   └── healthcheck/
│       ├── nextjs-health-route.ts
│       └── express-health.js
│
├── examples/
│   └── starter-app/
│
└── scripts/
    ├── bootstrap.sh
    └── verify.sh
```

---

## How skills reach Hermes

Hermes discovers skills from `~/.hermes/skills/`. The `install.sh` script copies all files from `skills/` to that directory.

Skills are loaded by Hermes on demand — when the task description matches the skill's `description` field, or when explicitly requested by name.

---

## Deployment architecture defaults

```
Git repository (GitHub)
    │
    ├── Vercel integration
    │       ├── Push to any branch → Preview Deployment
    │       └── Merge to main → Production Deployment
    │
    ├── Supabase
    │       ├── Migration files at supabase/migrations/
    │       └── Migrations run during Vercel build
    │
    └── Monitoring
            ├── Sentry SDK in application (error tracking)
            ├── Uptime Kuma polling /health every 60s
            └── Slack webhook for notifications
```

---

## Health endpoint standard

Every project using Oh My Hermes must expose a `/health` endpoint:

```json
{
  "status": "ok",
  "version": "1.0.0",
  "timestamp": "2026-05-09T10:00:00.000Z"
}
```

HTTP 200 = healthy. HTTP 503 = unhealthy.

Templates in `templates/healthcheck/`. The `health-check` skill calls this endpoint. The `setup-monitoring` skill configures Uptime Kuma to poll it.

---

## Memory key registry

Hermes memory is a shared key-value store. All skills and agents read and write to the same namespace. This table is the authoritative list of keys — if a skill needs to add a key, document it here first.

| Key | Written by | Read by | Format | Description |
|---|---|---|---|---|
| `github-repo` | `setup-cto.sh`, `onboarding` | `auto-issue-triage`, `security-review`, `create-github-pr` | `owner/repo` string | GitHub repository under management |
| `github-username` | `setup-cto.sh`, `onboarding` | `auto-issue-triage` | string | GitHub username for issue self-assignment |
| `current-task` | `auto-issue-triage` | `auto-issue-triage`, CTO Agent | `{ issueNumber, taskId, title, assignedAt }` JSON | Currently in-progress issue; prevents parallel work |
| `task-id-issue-[n]` | `auto-issue-triage` | `kanban-task` | string (kanban card ID) | Maps GitHub issue number to kanban card ID |
| `triage-last-run` | `auto-issue-triage` | `auto-issue-triage` | ISO 8601 timestamp | Guards against over-frequent triage runs (cost control) |
| `last-deployment-url` | `deploy-to-vercel` | `rollback`, `post-deploy-followup` | URL string | Most recent Vercel deployment URL |
| `notification-log` | `send-notification` | CTO Agent (reporting) | Array of `{ event, timestamp, backend, delivered }` | Audit log of notifications sent |
| `rollback-log` | `rollback` | CTO Agent (reporting) | Array of `{ rolledBackAt, fromUrl, reason, healthStatus }` | Audit log of production rollbacks |
| `approval-platform` | `onboarding`, `setup-cto.sh` | `await-merge-approval`, `send-notification` | `telegram` \| `slack` \| `discord` | Where to send founder approval requests |

**Rules:**
- Never create a new memory key without adding it to this table
- Keys are global across all agents — name collisions silently overwrite data
- Use the exact key names listed — casing matters

---

## Design principles

**Hermes-native, not Hermes-wrapped.** Skills load into Hermes as first-class citizens. No wrapper process, proxy, or daemon.

**Opinionated defaults, pluggable internals.** Vercel is the default. If you need Railway, every skill documents how to substitute it.

**Engine-agnostic at the routing layer.** `choose-engine` makes a recommendation based on task type. Claude Code and Codex are peers.

**Honest about human steps.** Claude Design requires human interaction. The workflow documents this rather than pretending it can be automated.

**Tested pitfalls only.** The Pitfalls section of each skill lists only observed failure modes.

**Progressive.** Works without Claude Design, without monitoring, without Slack. Each layer adds capability without requiring the ones below it to be fully configured.
