---
name: specflow:update
description: 更新本機 SpecFlow 安裝到 upstream 最新版。Fetch 最新 .claude/ 與 CLAUDE.md，顯示變更摘要，保留本地自訂後套用。觸發關鍵字："update", "升級", "更新 specflow"。
user-invocable: true
allowed-tools: Read, Write, Edit, Bash, AskUserQuestion
---

# SpecFlow Update — 升級到 upstream 最新版

把本機的 `.claude/`、`CLAUDE.md`、`.github/workflows/` 同步到 [gpwork4u/specflow](https://github.com/gpwork4u/specflow) main branch 的最新版本。

## 不會動的東西

- `specs/`, `dev/`, `test/`, `design/` — 你的專案內容
- `.specflow/state.json` — 進度狀態（schema 變動時走 migration，不直接覆蓋）
- 你對 `.claude/agents/*.md` 或 `CLAUDE.md` 做的本地改動 — 會先 diff 給你看，保留或合併由你選

## 步驟

### 1. 確認當前版本

```bash
LOCAL_VERSION_FILE=".specflow/version"
LOCAL_SHA=""
[ -f "$LOCAL_VERSION_FILE" ] && LOCAL_SHA=$(cat "$LOCAL_VERSION_FILE")
echo "本機版本: ${LOCAL_SHA:-（未記錄，視為首次更新）}"
```

### 2. 取得 upstream 最新版

```bash
TMPDIR=$(mktemp -d)
git clone --depth 50 https://github.com/gpwork4u/specflow.git "$TMPDIR/specflow" 2>&1 | tail -3
UPSTREAM_SHA=$(cd "$TMPDIR/specflow" && git rev-parse HEAD)
echo "Upstream 最新: $UPSTREAM_SHA"

if [ "$LOCAL_SHA" = "$UPSTREAM_SHA" ]; then
  echo "✅ 已是最新版"
  rm -rf "$TMPDIR"
  exit 0
fi
```

### 3. 顯示 changelog（本機版本之後的 commit）

```bash
if [ -n "$LOCAL_SHA" ]; then
  echo ""
  echo "📋 自上次更新以來的變更："
  echo ""
  ( cd "$TMPDIR/specflow" && git log --oneline --no-merges "$LOCAL_SHA..HEAD" 2>/dev/null \
    || git log --oneline --no-merges -20 ) | head -30
  echo ""
fi
```

### 4. Diff 本機自訂

對照「本機現有檔案」和「upstream 對應檔案」，找出本機改過、且 upstream 也改了的檔案 → 衝突需手動決定。

```bash
CONFLICT_FILES=""
LOCAL_ONLY=""
SAFE_UPDATE=""

for f in $(cd "$TMPDIR/specflow" && find .claude CLAUDE.md .github/workflows -type f 2>/dev/null); do
  UPSTREAM_FILE="$TMPDIR/specflow/$f"
  LOCAL_FILE="$f"

  if [ ! -f "$LOCAL_FILE" ]; then
    LOCAL_ONLY="$LOCAL_ONLY $f"
    continue
  fi

  if cmp -s "$UPSTREAM_FILE" "$LOCAL_FILE"; then
    continue  # 完全相同
  fi

  # 本機與 upstream 都不同 — 檢查是否本機有自訂（用 git log 看本機 commit 是否動過）
  LOCAL_MODIFIED=$(git log --oneline -- "$LOCAL_FILE" 2>/dev/null | head -1)
  if [ -n "$LOCAL_MODIFIED" ] && [ -n "$LOCAL_SHA" ]; then
    # 用 git 判斷：upstream 的 LOCAL_SHA 版本和本機現有檔案是否一致
    UPSTREAM_AT_LOCAL_SHA=$(cd "$TMPDIR/specflow" && git show "$LOCAL_SHA:$f" 2>/dev/null || echo "")
    LOCAL_CONTENT=$(cat "$LOCAL_FILE")
    if [ "$UPSTREAM_AT_LOCAL_SHA" != "$LOCAL_CONTENT" ]; then
      CONFLICT_FILES="$CONFLICT_FILES $f"
      continue
    fi
  fi

  SAFE_UPDATE="$SAFE_UPDATE $f"
done

echo ""
echo "🔄 可安全更新（本機未改動）：$(echo $SAFE_UPDATE | wc -w) 個檔案"
echo "🆕 新增檔案：$(echo $LOCAL_ONLY | wc -w) 個"
echo "⚠️  衝突（本機有自訂）：$(echo $CONFLICT_FILES | wc -w) 個"
[ -n "$CONFLICT_FILES" ] && echo "$CONFLICT_FILES" | tr ' ' '\n' | sed 's/^/    /'
```

### 5. 詢問如何處理衝突

```javascript
AskUserQuestion({
  questions: [{
    question: "更新策略？",
    header: "Update",
    multiSelect: false,
    options: [
      { label: "全部覆蓋 (Recommended for clean install)", description: "用 upstream 版本覆蓋所有檔案。本機自訂會丟失。建議先 commit 本機改動。" },
      { label: "只更新無衝突的", description: "安全更新沒有本機自訂的檔案，衝突檔案保留本機版本，跑 update 後手動 merge。" },
      { label: "保留衝突備份再覆蓋", description: "把本機衝突檔複製到 .specflow/backup-{timestamp}/，再用 upstream 版本覆蓋，事後可比對 merge。" },
      { label: "取消", description: "不更新，先去檢查本機改動。" }
    ]
  }]
})
```

### 6. 套用更新

根據選擇執行：

```bash
case "$STRATEGY" in
  "全部覆蓋")
    cp -R "$TMPDIR/specflow/.claude/." .claude/
    cp "$TMPDIR/specflow/CLAUDE.md" CLAUDE.md
    mkdir -p .github/workflows
    cp -R "$TMPDIR/specflow/.github/workflows/." .github/workflows/
    ;;
  "只更新無衝突的")
    for f in $SAFE_UPDATE $LOCAL_ONLY; do
      mkdir -p "$(dirname "$f")"
      cp "$TMPDIR/specflow/$f" "$f"
    done
    ;;
  "保留衝突備份再覆蓋")
    BACKUP=".specflow/backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP"
    for f in $CONFLICT_FILES; do
      mkdir -p "$BACKUP/$(dirname "$f")"
      cp "$f" "$BACKUP/$f"
    done
    cp -R "$TMPDIR/specflow/.claude/." .claude/
    cp "$TMPDIR/specflow/CLAUDE.md" CLAUDE.md
    mkdir -p .github/workflows
    cp -R "$TMPDIR/specflow/.github/workflows/." .github/workflows/
    echo "📦 衝突檔備份在 $BACKUP/"
    ;;
  "取消")
    rm -rf "$TMPDIR"
    exit 0
    ;;
esac
```

### 7. State schema migration

`state.json` 結構如果有新欄位（例如這版加的 `lane_closed` / `sprint_test_outcome`），補進舊檔案不覆蓋既有值：

```bash
if [ -f .specflow/state.json ]; then
  # 確保所有預期欄位存在；缺的補預設值
  tmp=$(mktemp)
  jq '
    . + {
      lane_closed: (.lane_closed // {feature: false, design: false, qa: false, bug: false}),
      sprint_test_outcome: (.sprint_test_outcome // null)
    }
  ' .specflow/state.json > "$tmp" && mv "$tmp" .specflow/state.json
  echo "✅ state.json schema 已對齊"
fi
```

### 8. 紀錄新版本 + 提示後續

```bash
echo "$UPSTREAM_SHA" > .specflow/version
rm -rf "$TMPDIR"

echo ""
echo "✅ SpecFlow 已更新到 $(echo $UPSTREAM_SHA | cut -c1-7)"
echo ""
echo "建議後續："
echo "  1. 檢查 .github/workflows/ 是否需要 commit + push"
echo "  2. 如果 init-github.sh 有更新（labels / branch protection）→ 重跑 /specflow:init"
echo "  3. 如果有衝突備份，比對 .specflow/backup-*/ 與當前檔案決定 merge"
echo ""
echo "本機 commit 變更："
echo "  git add .claude/ CLAUDE.md .github/workflows/ .specflow/version"
echo "  git commit -m 'chore: update specflow to $(echo $UPSTREAM_SHA | cut -c1-7)'"
```

## 重要原則

1. **不動使用者內容**：`specs/`, `dev/`, `test/`, `design/`, `.specflow/state.json` 的業務資料只動 schema 不動 value
2. **本機自訂可保留**：透過 git log 偵測本機是否動過 SpecFlow 檔案，動過就標衝突請使用者決定
3. **冪等**：跑兩次結果相同（state.json migration 用 `// fallback` 不覆蓋）
4. **可追溯**：寫 `.specflow/version` 紀錄當前 SHA，下次 update 才能算 changelog

## 失敗 / 取消後

- 沒有 partial state — `cp -R` 是 atomic 不會半套
- 真要回滾：用 git 回到 update 前的 commit，或從 `.specflow/backup-*/` 拷回衝突檔
