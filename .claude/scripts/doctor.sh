#!/bin/sh
set -u

# SpecFlow Doctor
# 用途：檢查跑流程前的工具與環境
# 結果：印出 markdown 表格 + 寫到 .specflow/doctor-report.md
# Exit code：0 = 全綠或只缺可選項；1 = 缺必要工具

REPORT_DIR=".specflow"
REPORT_FILE="$REPORT_DIR/doctor-report.md"
mkdir -p "$REPORT_DIR"

PASS=0
FAIL=0
WARN=0

results=""

check() {
  name="$1"; required="$2"; cmd="$3"; install_hint="$4"
  if eval "$cmd" >/dev/null 2>&1; then
    version=$(eval "$cmd" 2>/dev/null | head -1)
    results="${results}| ✅ | $name | $version | — |\n"
    PASS=$((PASS+1))
  else
    if [ "$required" = "yes" ]; then
      results="${results}| ❌ | $name | (missing) | $install_hint |\n"
      FAIL=$((FAIL+1))
    else
      results="${results}| ⚠️ | $name | (missing) | $install_hint |\n"
      WARN=$((WARN+1))
    fi
  fi
}

echo "🩺 SpecFlow Doctor"
echo "=================="
echo ""

check "git"            yes "git --version"          "https://git-scm.com/downloads"
check "gh CLI"         yes "gh --version | head -1" "brew install gh"
check "gh auth"        yes "gh auth status"         "gh auth login"
check "jq"             yes "jq --version"           "brew install jq"
check "node (>=20)"    yes "node --version"         "brew install node@20"
check "npm"            yes "npm --version"          "(comes with node)"
check "docker"         no  "docker --version"       "https://docs.docker.com/get-docker/"
check "docker compose" no  "docker compose version" "(included in Docker Desktop)"

# Project structure (optional, only matters after spec phase)
struct_msg=""
[ -d specs ] && struct_msg="${struct_msg}specs ✓ "
[ -d dev ]   && struct_msg="${struct_msg}dev ✓ "
[ -d test ]  && struct_msg="${struct_msg}test ✓ "
[ -d design ] && struct_msg="${struct_msg}design ✓ "
[ -z "$struct_msg" ] && struct_msg="(not initialized — first run)"

# GitHub repo
repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || echo "(not a gh repo)")

{
  printf '# SpecFlow Doctor Report\n\n'
  printf 'Generated: %s\n\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
  printf '## Tools\n\n'
  printf '| Status | Tool | Version | Install |\n'
  printf '|--------|------|---------|----------|\n'
  printf '%b' "$results"
  printf '\n## Project\n\n'
  printf '%s\n' "- Repo: $repo"
  printf '%s\n' "- Structure: $struct_msg"
  printf '\n## Summary\n\n'
  printf '%s\n' "- Pass: $PASS"
  printf '%s\n' "- Warn: $WARN"
  printf '%s\n' "- Fail: $FAIL"
} > "$REPORT_FILE"

cat "$REPORT_FILE"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "❌ 有 $FAIL 個必要工具缺失。請先安裝後再執行 specflow 流程。"
  exit 1
fi

if [ "$WARN" -gt 0 ]; then
  echo ""
  echo "⚠️  有 $WARN 個可選工具缺失（Docker 用於本機 BDD 測試環境，建議安裝）。"
fi

echo ""
echo "✅ Doctor 檢查通過"
exit 0
