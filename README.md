# Oh My Hermes

[![Stars](https://img.shields.io/github/stars/salomondiei08/oh-my-hermes?style=flat-square)](https://github.com/salomondiei08/oh-my-hermes/stargazers)
[![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)
[![Hermes](https://img.shields.io/badge/Hermes-v0.13%2B-orange?style=flat-square)](https://hermes-agent.nousresearch.com)

A skill and agent pack for [Hermes Agent](https://hermes-agent.nousresearch.com) that turns it into an autonomous CTO — triaging GitHub issues, implementing fixes, reviewing code, and asking for your approval before anything ships.

Once set up, you talk to a bot on Telegram (or Slack, Discord, WhatsApp). The bot handles the rest.

---

## How it works

```
You message the bot
       ↓
Hermes triages your GitHub issues
       ↓
Implements the top priority
       ↓
Reviews the code for security issues
       ↓
Sends you: "PR ready — reply YES or NO"
       ↓
You reply YES → ships to production
```

No terminal. No dashboards. Just messages.

---

## Get started

**Step 1 — Install Hermes and connect your messaging app**

Follow the [Hermes quickstart](https://hermes-agent.nousresearch.com/docs/getting-started/quickstart). Takes about 10 minutes. At the end you have a bot you can message on Telegram (or Slack, Discord, etc.).

**Step 2 — Install Oh My Hermes**

```bash
curl -fsSL https://raw.githubusercontent.com/salomondiei08/oh-my-hermes/main/install.sh | bash
```

**Step 3 — Message your bot**

```
set up the CTO loop
```

The bot will ask for your GitHub repo, walk you through creating a token, confirm your production URL, and configure everything. No terminal needed after Step 2.

> AI agent? See [INSTALL_FOR_AGENTS.md](INSTALL_FOR_AGENTS.md).

---

## What's included

**23 skills** — covering the full app lifecycle: requirements, design handoff, deployment, monitoring, GitHub ops, PR review, security, and the autonomous CTO loop.

**6 agents** — each with a defined role and kanban ownership:

| Agent | What it does |
|---|---|
| CTO | Orchestrates everything, reports to you daily |
| PM | Triages GitHub issues, writes tickets |
| Dev | Implements tickets, creates PRs |
| QA | Reviews PRs, checks build and health |
| Security | Scans for secrets, OWASP issues, CVEs |
| Ops | Deploys, monitors production, handles incidents |

**5 workflows** — idea-to-deploy, design-to-code, deploy-and-monitor, GitHub ops, CTO loop.

---

## What you do

You get a message like this:

```
PR #12 ready — Fix login redirect for new users

What changed:
Users who signed up but hadn't verified their email were being
sent to a broken page. They now see a "Check your inbox" screen.

Build: passing  |  Preview: healthy (180ms)  |  No secrets found

Preview: https://myapp-fix-login.vercel.app

Reply YES to ship. Reply NO and tell me why.
```

Reply YES. It merges, deploys, health-checks, and confirms back to you.

---

## Default stack

| Layer | Default |
|---|---|
| Hosting | Vercel |
| Database | Supabase |
| Notifications | Telegram / Slack |
| Error tracking | Sentry |
| Monitoring | Uptime Kuma |

All pluggable. Each skill documents how to substitute.

---

## Uninstall

```bash
bash /path/to/oh-my-hermes/scripts/uninstall.sh
```

Removes all skills, workflows, and profiles. Hermes memory and gateway are untouched.

---

## Star history

[![Star History Chart](https://api.star-history.com/svg?repos=salomondiei08/oh-my-hermes&type=Date)](https://star-history.com/#salomondiei08/oh-my-hermes&Date)

---

## Optional: GBrain memory backbone

[GBrain](https://github.com/garrytan/gbrain) gives Hermes a richer, self-updating knowledge graph. Install alongside Hermes:

```bash
git clone https://github.com/garrytan/gbrain.git ~/gbrain && cd ~/gbrain
curl -fsSL https://bun.sh/install | bash && export PATH="$HOME/.bun/bin:$PATH"
bun install && bun link && gbrain init
```

Do not use `npm install -g gbrain` — a squatter package exists under that name.

---

## Docs

Full documentation, architecture details, and skill reference: [docs/](docs/)

---

## License

MIT
