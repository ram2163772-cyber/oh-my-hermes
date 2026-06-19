#!/usr/bin/env bash
# validate-skills.sh — lints skill frontmatter and checks cross-references
# Checks: required frontmatter fields, referenced skills exist, no broken links.
# Run before committing skill changes.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$(dirname "$SCRIPT_DIR")/skills"

PASS=0
FAIL=0
WARN=0

ok()   { echo "  [OK]   $1"; PASS=$((PASS+1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }
warn() { echo "  [WARN] $1"; WARN=$((WARN+1)); }

REQUIRED_FIELDS=(name description version tags)

echo "Oh My Hermes — skill validation"
echo "================================"
echo ""

if [ ! -d "$SKILLS_DIR" ]; then
  echo "[ERROR] skills/ directory not found at $SKILLS_DIR"
  exit 1
fi

# Collect all skill names for cross-reference checking
declare -A SKILL_EXISTS
for skill_file in "$SKILLS_DIR"/*.md; do
  [ -f "$skill_file" ] || continue
  skill_name=$(grep -m1 '^name:' "$skill_file" 2>/dev/null | sed 's/^name:[[:space:]]*//' | tr -d '"')
  if [ -n "$skill_name" ]; then
    SKILL_EXISTS["$skill_name"]=1
  fi
  # Also index by filename stem
  stem=$(basename "$skill_file" .md)
  SKILL_EXISTS["$stem"]=1
done

echo "Skills found: ${#SKILL_EXISTS[@]}"
echo ""

for skill_file in "$SKILLS_DIR"/*.md; do
  [ -f "$skill_file" ] || continue
  stem=$(basename "$skill_file" .md)
  echo "── $stem"

  # ── 1. Has frontmatter ─────────────────────────────────────────────────────
  first_line=$(head -1 "$skill_file")
  if [ "$first_line" != "---" ]; then
    fail "$stem: missing frontmatter opening ---"
    continue
  fi

  # ── 2. Required fields present ─────────────────────────────────────────────
  for field in "${REQUIRED_FIELDS[@]}"; do
    if grep -qE "^${field}:" "$skill_file"; then
      ok "$stem: has '$field'"
    else
      fail "$stem: missing required field '$field'"
    fi
  done

  # ── 3. Required sections present ───────────────────────────────────────────
  for section in "When to Use" "Prerequisites" "Procedure" "Verification"; do
    if grep -qE "^## ${section}" "$skill_file"; then
      ok "$stem: has '## $section'"
    else
      fail "$stem: missing '## $section' section"
    fi
  done

  # ── 4. Cross-reference check — skills referenced with backticks ───────────
  # Matches patterns like: `skill-name` inside a skill reference context
  while IFS= read -r ref; do
    ref_clean=$(echo "$ref" | tr -d '`')
    if [ -n "${SKILL_EXISTS[$ref_clean]}" ]; then
      ok "$stem: reference '$ref_clean' resolves"
    else
      warn "$stem: reference '$ref_clean' not found in skills/ — may be a workflow or external command"
    fi
  done < <(grep -oE '\`[a-z][a-z0-9-]+\`' "$skill_file" | sort -u | grep -v '\`bash\`\|\`json\`\|\`ok\`\|\`status\`\|\`true\`\|\`false\`\|\`null\`\|\`in-progress\`\|\`wontfix\`\|\`blocked\`\|\`needs-design\`\|\`current-task\`\|\`notification-log\`\|\`github-repo\`\|\`last-deployment-url\`\|\`rollback-log\`\|\`triage-last-run\`\|\`task-id-issue' 2>/dev/null || true)

  # ── 5. No hardcoded secrets ────────────────────────────────────────────────
  if grep -Eqi '(api_key|token|password|secret)\s*=\s*[a-z0-9_-]{20,}' "$skill_file" 2>/dev/null; then
    fail "$stem: possible hardcoded secret detected — review file"
  else
    ok "$stem: no hardcoded secrets detected"
  fi

  echo ""
done

echo "================================"
printf "Passed: %d   Warned: %d   Failed: %d\n" $PASS $WARN $FAIL
echo ""

if [ "$FAIL" -gt 0 ]; then
  echo "Skill validation failed. Fix failures before committing."
  exit 1
elif [ "$WARN" -gt 0 ]; then
  echo "Skills valid. Review warnings above — cross-references may be workflow names or external commands."
  exit 0
else
  echo "All skills valid."
  exit 0
fi
