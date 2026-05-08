#!/usr/bin/env bash

HERMES_DIR="$HOME/.hermes"
SKILLS_DIR="$HERMES_DIR/skills"
WORKFLOWS_DIR="$HERMES_DIR/workflows"
PASS=0
FAIL=0

check() {
  local label="$1"
  local path="$2"
  if [ -e "$path" ]; then
    echo "[OK]      $label"
    PASS=$((PASS + 1))
  else
    echo "[MISSING] $label → $path"
    FAIL=$((FAIL + 1))
  fi
}

echo "Oh My Hermes — verify install"
echo "=============================="
echo ""

if command -v hermes &>/dev/null; then
  echo "[OK]      hermes command found"
  PASS=$((PASS + 1))
else
  echo "[MISSING] hermes not in PATH — install Hermes Agent first"
  FAIL=$((FAIL + 1))
fi

check "~/.hermes/"            "$HERMES_DIR"
check "~/.hermes/skills/"     "$SKILLS_DIR"
check "~/.hermes/workflows/"  "$WORKFLOWS_DIR"

echo ""
echo "Skills:"
check "create-skill"               "$SKILLS_DIR/create-skill.md"
check "clarify-requirements"       "$SKILLS_DIR/clarify-requirements.md"
check "product-brief"              "$SKILLS_DIR/product-brief.md"
check "design-handoff"             "$SKILLS_DIR/design-handoff.md"
check "choose-engine"              "$SKILLS_DIR/choose-engine.md"
check "implement-with-claude-code" "$SKILLS_DIR/implement-with-claude-code.md"
check "implement-with-codex"       "$SKILLS_DIR/implement-with-codex.md"
check "deploy-to-vercel"           "$SKILLS_DIR/deploy-to-vercel.md"
check "connect-supabase"           "$SKILLS_DIR/connect-supabase.md"
check "setup-monitoring"           "$SKILLS_DIR/setup-monitoring.md"
check "health-check"               "$SKILLS_DIR/health-check.md"
check "send-notification"          "$SKILLS_DIR/send-notification.md"
check "post-deploy-followup"       "$SKILLS_DIR/post-deploy-followup.md"
check "manage-github-issues"       "$SKILLS_DIR/manage-github-issues.md"
check "create-github-pr"           "$SKILLS_DIR/create-github-pr.md"

echo ""
echo "Workflows:"
check "idea-to-deploy"     "$WORKFLOWS_DIR/idea-to-deploy.md"
check "design-to-code"     "$WORKFLOWS_DIR/design-to-code.md"
check "deploy-and-monitor" "$WORKFLOWS_DIR/deploy-and-monitor.md"
check "github-ops"         "$WORKFLOWS_DIR/github-ops.md"

echo ""
echo "=============================="
echo "Passed: $PASS   Failed: $FAIL"
if [ "$FAIL" -eq 0 ]; then
  echo ""
  echo "Oh My Hermes install looks good."
  echo "Next: cd into your project and run scripts/bootstrap.sh"
else
  echo ""
  echo "Install incomplete — run install.sh to fix missing items."
fi
