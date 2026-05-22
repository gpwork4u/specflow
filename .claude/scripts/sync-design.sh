#!/bin/sh
set -eu

# SpecFlow Design Sync
# 用途：把 Claude design URL 下載到 specs/design-source/ 作為本地設計參照
# 為什麼要 download：
#   1. WebFetch 每次都打網路、慢、會用掉 token
#   2. design URL 可能被使用者更新，下載快照可以 freeze 一個版本
#   3. engineer 開發時直接讀本地檔案，可離線、可 diff、可 grep
#
# 支援兩種來源格式（自動偵測）：
#   A. 單頁 HTML（舊 claude.ai/design 分享頁）— curl 直接存成 index.html
#   B. handoff bundle（新 claude.ai/design「匯出給 coding agent」，api.anthropic.com）
#      實際是 gzip+tar，內含 README + chats/（設計意圖）+ project/（HTML/CSS/JSX 原型 + 截圖）
#
# 用法：
#   sync-design.sh <design-url>
#   或 sync-design.sh   （從 specs/design-source.md 讀 URL）
#
# 產出：
#   specs/design-source.md            元數據（URL + timestamp + 檔案清單 + 攝取格式）
#   specs/design-source/index.html    主 HTML（bundle 取 project/index.html）
#   specs/design-source/*.jsx|*.css   bundle 的元件原始碼（testid / 字串 / 結構的真實來源）
#   specs/design-source/screenshots/  截圖（bundle 內建，或 playwright 補拍）
#   specs/design-source/chats/        設計對話（bundle 才有，記錄使用者意圖 — 反推 spec 必讀）
#   specs/design-source/assets/       圖片 / icon

URL="${1:-}"
OUTDIR="specs/design-source"
META="specs/design-source.md"

if [ -z "$URL" ]; then
  [ ! -f "$META" ] && { echo "🔴 沒給 URL，且 $META 也不存在"; exit 1; }
  # 同時支援 claude.ai/com 與 api.anthropic.com 的 design URL
  URL=$(grep -oE 'https://(claude\.(ai|com)|api\.anthropic\.com)/[^ )]+' "$META" | head -1)
fi

[ -z "$URL" ] && { echo "🔴 找不到 design URL"; exit 1; }

echo "📥 Sync design from: $URL"
rm -rf "$OUTDIR"
mkdir -p "$OUTDIR/screenshots" "$OUTDIR/assets"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# 1. 下載原始 payload（--compressed 處理 transport 層 gzip；payload 本身可能還是 tar.gz）
echo "→ Download payload"
curl -fsSL --compressed "$URL" -o "$TMP/payload" || {
  echo "🔴 下載失敗（URL 可能過期或需要登入）"
  echo "   → 使用者需在 Claude design 重新 share / export，再給新 URL"
  exit 1
}

# 2. 偵測格式：gzip(tar) bundle vs 純 HTML
KIND=$(file -b "$TMP/payload" 2>/dev/null || echo unknown)
INGEST="html"
case "$KIND" in
  *gzip*|*"tar archive"*)
    # 可能是 .tar.gz 或裸 tar；先嘗試 gunzip，失敗就當裸 tar
    if gunzip -c "$TMP/payload" > "$TMP/payload.tar" 2>/dev/null; then
      TARFILE="$TMP/payload.tar"
    else
      TARFILE="$TMP/payload"
    fi
    if tar -tf "$TARFILE" >/dev/null 2>&1; then
      INGEST="bundle"
    fi
    ;;
esac

if [ "$INGEST" = "bundle" ]; then
  echo "→ 偵測為 handoff bundle（tar）→ 解開"
  mkdir -p "$TMP/x"
  tar -xf "$TARFILE" -C "$TMP/x"

  # 找 project 目錄（含 index.html 的那層）；找不到就用 bundle 根
  PROJ=$(find "$TMP/x" -type d -name project | head -1)
  [ -z "$PROJ" ] && PROJ=$(dirname "$(find "$TMP/x" -name index.html | head -1)")
  [ -z "$PROJ" ] && { echo "🔴 bundle 內找不到 project/ 或 index.html"; exit 1; }

  # 攤平 project 內容到 OUTDIR（保留 screenshots/ assets/ 子目錄）
  cp -R "$PROJ"/. "$OUTDIR"/ 2>/dev/null || true
  mkdir -p "$OUTDIR/screenshots" "$OUTDIR/assets"

  # README + chats（設計意圖，spec-writer 反推需求必讀）
  README=$(find "$TMP/x" -maxdepth 3 -iname "README.md" | head -1)
  [ -n "$README" ] && cp "$README" "$OUTDIR/BUNDLE-README.md"
  CHATS=$(find "$TMP/x" -type d -name chats | head -1)
  [ -n "$CHATS" ] && { mkdir -p "$OUTDIR/chats"; cp -R "$CHATS"/. "$OUTDIR/chats"/ 2>/dev/null || true; }
else
  echo "→ 偵測為單頁 HTML"
  cp "$TMP/payload" "$OUTDIR/index.html"
  # 舊格式才需要 playwright 補截圖（bundle 已內建截圖，且新 README 明示不必截圖）
  if command -v npx > /dev/null 2>&1 && [ -f test/package.json ]; then
    echo "→ Screenshot with playwright"
    ( cd test && npx playwright screenshot --browser chromium --full-page \
      --wait-for-timeout 3000 "$URL" "../$OUTDIR/screenshots/main.png" 2>&1 | tail -3 ) || \
      echo "   ⚠️  截圖失敗（不阻塞，HTML 已下載）"
  fi
fi

[ -f "$OUTDIR/index.html" ] || { echo "🔴 攝取後仍無 index.html"; exit 1; }

# 3. 列出元件原始碼 / 截圖 供 metadata
SHOTS=$(find "$OUTDIR/screenshots" -type f 2>/dev/null | sed "s#$OUTDIR/##;s/^/- /")
[ -z "$SHOTS" ] && SHOTS="- (無)"

# 依攝取格式預先組好分歧的段落（避免 metadata heredoc 內巢狀邏輯）
if [ "$INGEST" = "bundle" ]; then
  COMP_LIST=$(find "$OUTDIR" -maxdepth 1 -type f \( -name '*.jsx' -o -name '*.tsx' -o -name '*.css' \) -exec basename {} \; 2>/dev/null | sort | sed 's#^#- `specs/design-source/#;s#$#`#')
  SRC_BLOCK="- 元件原始碼（**testid / 面向使用者字串 / 結構的真實來源，grep 這些檔不是 index.html**）：
$COMP_LIST
- \`specs/design-source/chats/\` — 設計對話（**spec-writer 反推需求前必讀**，使用者意圖在這裡）
- \`specs/design-source/BUNDLE-README.md\` — 原 bundle 的 coding-agent 指引"
  SPEC_STEP="1. **先讀 \`chats/\`** — 使用者與設計助手的完整來回，意圖在這裡，別跳過
2. 讀 \`index.html\` + 跟著它 import 的 \`*.jsx\`，理解頁面 / 元件 / 資料模型"
  UI_FROM="\`*.jsx\` + \`styles.css\`"
  UI_TESTID="\`*.jsx\`"
  FE_STEP="grep **\`specs/design-source/*.jsx\`**（元件 / 字串 / testid 在這裡，index.html 只是 loader 殼）"
else
  SRC_BLOCK="- （單頁 HTML，無額外元件檔）"
  SPEC_STEP="1. 從 \`index.html\` 反推使用者流程"
  UI_FROM="HTML / CSS"
  UI_TESTID="HTML"
  FE_STEP="grep \`index.html\` 對照元件結構"
fi

# 4. 寫 metadata
TIMESTAMP=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
cat > "$META" <<EOF
# Design Source

> ⚠️ 這是 Claude design 的本地快照。所有 frontend 開發**只**參照本目錄，不要依賴遠端 URL（可能被使用者更新）。
> 要刷新請跑：\`bash .claude/scripts/sync-design.sh\`

## Source
- **URL**: $URL
- **Last synced**: $TIMESTAMP
- **攝取格式**: $INGEST  （bundle = 新 handoff tar / html = 舊單頁）
- **Local snapshot**: \`specs/design-source/\`

## Files
- \`specs/design-source/index.html\` — 主 HTML
$SRC_BLOCK
- \`specs/design-source/screenshots/\` — 截圖（pixel-perfect 對照）
$SHOTS

## How to use

### Spec writer（反推需求）
$SPEC_STEP
3. 看不到的部份（backend / data / 業務邏輯）用 AskUserQuestion 補

### UI designer（抽 tokens / handoff）
- 從 $UI_FROM 抽 design tokens 寫 \`design/tokens/\`
- 從 $UI_TESTID 找 testid / aria-label → handoff 給 tech-lead 寫 \`specs/contracts/dom.md\`
- 抽所有面向使用者字串 → \`design/ux-text-handoff.md\`

### Frontend engineer（pixel-perfect）
1. $FE_STEP
2. 看 \`screenshots/\` 對照視覺
3. 不要 WebFetch 線上 URL（除非本地快照過舊）
EOF

echo ""
echo "✅ Design synced to ${OUTDIR}/（格式：${INGEST}）"
echo "   - HTML: $(wc -c < "$OUTDIR/index.html" | tr -d ' ') bytes"
echo "   - 元件原始碼: $(find "$OUTDIR" -maxdepth 1 -type f \( -name '*.jsx' -o -name '*.tsx' \) | wc -l | tr -d ' ') 檔"
echo "   - Screenshot: $(find "$OUTDIR/screenshots" -type f 2>/dev/null | wc -l | tr -d ' ') files"
echo "   - Chats: $(find "$OUTDIR/chats" -type f 2>/dev/null | wc -l | tr -d ' ') files"
echo "   - Metadata: $META"
