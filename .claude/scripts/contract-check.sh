#!/bin/sh
set -eu

# SpecFlow Contract Checker
# 用途：阻擋 hardcoded path / testid / toast 文字 — 都必須走 specs/contracts.ts
# 用法：
#   contract-check.sh                    # 檢查 dev/ test/ 全部
#   contract-check.sh --diff <base>      # 只檢查 PR diff（CI 用）
# Exit code：0 = 全綠；1 = 有違規
#
# 為什麼用 grep 不用 LLM：每個 PR 都跑、要快、規則清楚。
# 規則（詳見 specs/contracts/）：
#   1. data-testid="..." 字面值禁用 → 改 import TESTIDS
#   2. fetch("/api/...") / axios.get("/api/...") 字面值禁用 → 改 API_PATHS
#   3. toast.xxx("中文字串") 字面值禁用 → 改 TOAST.xxx
#   4. page.locator('[data-testid="..."]') 字面值禁用 → 改用 TESTIDS

MODE="${1:-full}"
BASE="${2:-origin/main}"
ROOT="${ROOT:-.}"

cd "$ROOT"

# 沒有 contracts/ 目錄 = 還沒進 contract phase（早期專案）→ skip
if [ ! -f specs/contracts.ts ] && [ ! -d specs/contracts ]; then
  echo "ℹ️  specs/contracts.ts / specs/contracts/ 尚未建立，跳過 contract check（tech-lead 還沒進 contract phase）"
  exit 0
fi

if [ "$MODE" = "--diff" ]; then
  FILES=$(git diff --name-only "$BASE...HEAD" -- 'dev/**' 'test/**' | grep -E '\.(ts|tsx|js|jsx|go)$' || true)
else
  FILES=$(find dev test -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' -o -name '*.go' \) 2>/dev/null || true)
fi

[ -z "$FILES" ] && { echo "ℹ️  沒有要檢查的檔案"; exit 0; }

VIOLATIONS=0
report() {
  echo "❌ $1"
  VIOLATIONS=$((VIOLATIONS + 1))
}

# 1. Hardcoded testid 字面值（僅 .ts/.tsx 檢查；.spec.ts、.feature 寫的 step 也檢查）
echo "🔍 Check 1: hardcoded data-testid"
HITS=$(echo "$FILES" | xargs grep -nE 'data-testid="[a-z][a-z0-9-]*"' 2>/dev/null || true)
if [ -n "$HITS" ]; then
  echo "$HITS" | while IFS= read -r line; do
    report "$line  ← 改 data-testid={TESTIDS.xxx}"
  done
fi

# 2. Hardcoded /api/ 路徑字串（fetch / axios / mux.HandleFunc 等）
echo "🔍 Check 2: hardcoded /api/ paths"
HITS=$(echo "$FILES" | xargs grep -nE '"/api/[a-zA-Z0-9/_:-]+"' 2>/dev/null \
  | grep -vE '(specs/contracts\.ts|specs/contracts/api\.md)' \
  | grep -vE '//\s*allow-hardcoded-path' || true)
if [ -n "$HITS" ]; then
  echo "$HITS" | while IFS= read -r line; do
    report "$line  ← 改 API_PATHS.xxx"
  done
fi

# 3. Hardcoded toast / 中文 UI 字串
# 偵測 toast.success("...") / toast.error("...") / Toast.show("...")
echo "🔍 Check 3: hardcoded toast/UI text"
HITS=$(echo "$FILES" | xargs grep -nE '(toast|Toast)\.(success|error|info|warning|show)\(["'"'"'][^"'"'"']+["'"'"']' 2>/dev/null \
  | grep -vE 'TOAST\.' || true)
if [ -n "$HITS" ]; then
  echo "$HITS" | while IFS= read -r line; do
    report "$line  ← 改 toast.xxx(TOAST.yyy)"
  done
fi

# 4. Playwright locator 中 hardcoded testid
echo "🔍 Check 4: hardcoded testid in test selectors"
HITS=$(echo "$FILES" | xargs grep -nE 'data-testid="[a-z][a-z0-9-]*"\]' 2>/dev/null \
  | grep -E '(locator|querySelector|getByTestId)' \
  | grep -vE 'TESTIDS\.' || true)
if [ -n "$HITS" ]; then
  echo "$HITS" | while IFS= read -r line; do
    report "$line  ← 改 page.locator(\`[data-testid=\"\${TESTIDS.xxx}\"]\`) 或 getByTestId(TESTIDS.xxx)"
  done
fi

# 5. 偵測新增 testid / api path 是否同步更新 contracts.ts
if [ "$MODE" = "--diff" ]; then
  echo "🔍 Check 5: new contract entries synced to contracts.ts"
  CONTRACTS_CHANGED=$(git diff --name-only "$BASE...HEAD" -- 'specs/contracts.ts' 'specs/contracts/' | wc -l | tr -d ' ')
  NEW_TESTIDS=$(git diff "$BASE...HEAD" -- 'dev/**' 'test/**' | grep -E '^\+.*data-testid=' | wc -l | tr -d ' ')
  NEW_PATHS=$(git diff "$BASE...HEAD" -- 'dev/**' 'test/**' | grep -E '^\+.*"/api/' | wc -l | tr -d ' ')
  TOTAL_NEW=$((NEW_TESTIDS + NEW_PATHS))

  if [ "$TOTAL_NEW" -gt "0" ] && [ "$CONTRACTS_CHANGED" = "0" ]; then
    report "PR 新增了 $TOTAL_NEW 處 testid/path，但 specs/contracts.ts 或 specs/contracts/*.md 都沒動。任何新 contract entry 必須先寫進 contracts.ts。"
  fi
fi

echo ""
if [ "$VIOLATIONS" = "0" ]; then
  echo "✅ Contract check passed"
  exit 0
else
  echo "🔴 Contract check failed: $VIOLATIONS 處違規"
  echo ""
  echo "如何修：把 hardcoded 字串換成從 specs/contracts.ts import：（範例）"
  echo "  ❌ <button data-testid=\"approve-btn\">送出</button>"
  echo "  ✅ import { TESTIDS, BUTTON } from '../../../specs/contracts';"
  echo "     <button data-testid={TESTIDS.approveBtn}>{BUTTON.send}</button>"
  echo ""
  echo "確認此違規是合理 exception → 在那行加 // allow-hardcoded-path 註解。"
  exit 1
fi
