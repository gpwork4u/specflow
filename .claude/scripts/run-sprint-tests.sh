#!/bin/sh
set -eu

# SpecFlow Sprint Test Runner（純 Playwright，無 BDD）
# 用法：
#   run-sprint-tests.sh [test-glob]
#     test-glob = "all"（預設）跑當前 sprint 所有 e2e
#               = "test/e2e/f001*.spec.ts" 跑特定 feature
# 環境變數：
#   BASE_URL          測試目標 URL（預設 http://localhost:3000）
#   SPRINT            當前 sprint 名稱（如 "Sprint 1"），用來從 specs/sprints/ 讀 scope
#   SKIP_DOCKER=1     不啟動 docker compose（假設服務已在跑）
#   SKIP_HEALTH=1     不等 health check
# Exit code：0 = 全部測試通過；非 0 = 任一階段失敗

TEST_GLOB="${1:-all}"
BASE_URL="${BASE_URL:-http://localhost:3000}"
SPRINT="${SPRINT:-}"
REPORT_DIR="test/reports"
SCREENSHOT_DIR="test/screenshots"

mkdir -p "$REPORT_DIR" "$SCREENSHOT_DIR"

log() { printf '\n=== %s ===\n' "$*"; }
fail() { echo "❌ $*" >&2; exit 1; }

# ---- 1. 啟動 docker（除非略過）----
if [ "${SKIP_DOCKER:-0}" != "1" ]; then
  log "Starting docker compose"
  ( cd dev && \
    [ -f docker-compose.yml ] || cp docker-compose.example.yml docker-compose.yml; \
    [ -f .env ] || cp .env.example .env; \
    docker compose up -d --build )

  if [ "${SKIP_HEALTH:-0}" != "1" ]; then
    log "Waiting for health check at $BASE_URL/health"
    for i in $(seq 1 30); do
      if curl -sf "$BASE_URL/health" > /dev/null 2>&1; then
        echo "✅ Services ready"
        break
      fi
      [ "$i" = "30" ] && fail "Service health check timeout"
      printf '.'; sleep 2
    done
  fi
fi

cleanup() {
  EXIT_CODE=$?
  log "Cleanup (exit=$EXIT_CODE)"

  if [ "${SKIP_DOCKER:-0}" != "1" ]; then
    ( cd dev && docker compose down -v --remove-orphans ) 2>/dev/null || true
  fi

  if [ "$EXIT_CODE" = "0" ]; then
    rm -rf test/test-results 2>/dev/null || true
    rm -rf test/screenshots 2>/dev/null || true
    echo "✅ Cleaned: docker stack + test-results + screenshots"
  else
    echo "⚠️  保留 test/test-results + test/screenshots + test/reports 供 debug"
    echo "    debug 完跑：bash .claude/scripts/local-checks.sh cleanup"
  fi
}
trap cleanup EXIT

# ---- 2. Unit tests ----
log "Unit tests"
if [ -f dev/package.json ]; then
  ( cd dev && npm ci --silent 2>/dev/null || npm install --silent )
  ( cd dev && npm test ) || fail "Unit tests failed"
elif [ -f dev/go.mod ]; then
  ( cd dev && go test ./... ) || fail "Go tests failed"
fi

# ---- 3. 解析 sprint scope（從 specs/sprints/sprint-N.md 抓 feature 清單） ----
log "Resolve sprint scope"
SCOPE_FILES=""
if [ "$TEST_GLOB" != "all" ]; then
  SCOPE_FILES="$TEST_GLOB"
elif [ -n "$SPRINT" ]; then
  SPRINT_NUM=$(echo "$SPRINT" | grep -oE '[0-9]+' | head -1)
  PLAN="specs/sprints/sprint-${SPRINT_NUM}.md"
  if [ -f "$PLAN" ]; then
    # 從 sprint plan 抽 feature ID（格式 F-NNN 或 fNNN）
    FIDS=$(grep -oE '[Ff]-?[0-9]{3}' "$PLAN" | tr '[:upper:]' '[:lower:]' | tr -d '-' | sort -u)
    for fid in $FIDS; do
      for f in test/e2e/${fid}*.spec.ts; do
        [ -f "$f" ] && SCOPE_FILES="$SCOPE_FILES $f"
      done
    done
    echo "Sprint scope: $FIDS → $(echo $SCOPE_FILES | wc -w) test files"
  else
    echo "⚠️  $PLAN 不存在，跑所有 e2e"
    SCOPE_FILES="test/e2e/"
  fi
else
  SCOPE_FILES="test/e2e/"
fi

[ -z "$SCOPE_FILES" ] && fail "找不到任何 e2e test file，sprint plan 或 test/e2e/ 是否完整？"

# ---- 4. Playwright e2e tests ----
log "Playwright e2e tests"
( cd test && npm ci --silent 2>/dev/null || npm install --silent )
( cd test && npx playwright install --with-deps chromium > /dev/null 2>&1 || npx playwright install chromium )

PLAYWRIGHT_JSON="$REPORT_DIR/playwright.json"
HTML_REPORT="$REPORT_DIR/playwright-report"

(
  cd test && \
  BASE_URL="$BASE_URL" npx playwright test $SCOPE_FILES \
    --reporter=json,html \
    > "../$PLAYWRIGHT_JSON" 2>&1
) || {
  echo "❌ E2E tests failed — see $PLAYWRIGHT_JSON"
  if [ -f "$PLAYWRIGHT_JSON" ] && command -v jq > /dev/null; then
    PASS=$(jq '.stats.expected // 0' "$PLAYWRIGHT_JSON" 2>/dev/null || echo "?")
    FAIL=$(jq '.stats.unexpected // 0' "$PLAYWRIGHT_JSON" 2>/dev/null || echo "?")
    echo "   pass=$PASS fail=$FAIL"
  fi
  exit 1
}

# ---- 5. 結果摘要 ----
log "Test summary"
if [ -f "$PLAYWRIGHT_JSON" ] && command -v jq > /dev/null; then
  PASS=$(jq '.stats.expected // 0' "$PLAYWRIGHT_JSON")
  FAIL=$(jq '.stats.unexpected // 0' "$PLAYWRIGHT_JSON")
  SKIPPED=$(jq '.stats.skipped // 0' "$PLAYWRIGHT_JSON")
  echo "Passed: $PASS"
  echo "Failed: $FAIL"
  echo "Skipped: $SKIPPED"
  [ "$FAIL" != "0" ] && fail "$FAIL test(s) failed"
fi

log "✅ All tests passed"
