#!/usr/bin/env bash
set -e

echo "=== Oh My Hermes — Container ==="
echo ""

# Smoke test mode: validate skills/CLIs without installing full Hermes runtime
if [ "${TEST_MODE}" = "1" ]; then
  echo "TEST MODE — validating skills and CLIs (Hermes runtime not required)"
  echo ""

  # Bootstrap a fake ~/.hermes structure so install.sh works
  mkdir -p "$HOME/.hermes/skills" "$HOME/.hermes/workflows" "$HOME/.hermes/agents"

  echo "[1/3] Installing Oh My Hermes..."
  bash /oh-my-hermes/install.sh

  echo ""
  echo "[2/3] Running smoke tests..."
  bash /oh-my-hermes/docker/test.sh
  exit $?
fi

# Normal mode: install full Hermes runtime
echo "[1/4] Installing Hermes Agent..."
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"

if ! command -v hermes &>/dev/null; then
  echo "[ERROR] Hermes install failed."
  exit 1
fi
echo "[1/4] Hermes installed: $(hermes --version 2>/dev/null)"

echo "[2/4] Installing Oh My Hermes..."
bash /oh-my-hermes/install.sh

echo ""
echo "[3/4] Verifying..."
bash /oh-my-hermes/scripts/verify.sh

echo ""
echo "[4/4] Setup complete."
echo ""
echo "  hermes model             # connect your LLM provider"
echo "  hermes gateway setup     # connect Telegram/Slack"
echo "  gh auth login            # authenticate GitHub CLI"
echo "  vercel login             # authenticate Vercel"
echo "  supabase login           # authenticate Supabase"
echo ""
echo "  Then tell Hermes:"
echo "  'Set up the CTO loop for [owner/repo], send approvals on Telegram'"
