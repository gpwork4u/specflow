#!/bin/sh
set -eu

# SpecFlow Design Sync
# 用途：把 Claude design URL 下載到 specs/design-source/ 作為本地設計參照
# 為什麼要 download：
#   1. WebFetch 每次都打網路、慢、會用掉 token
#   2. design URL 可能被使用者更新，下載快照可以 freeze 一個版本
#   3. engineer 開發時直接讀本地檔案，可離線、可 diff、可 grep
#   4. 截圖可以給 visual review / 之後做 pixel diff
#
# 用法：
#   sync-design.sh <design-url>
#   或 sync-design.sh   （從 specs/design-source.md 讀 URL）
#
# 產出：
#   specs/design-source.md            元數據（URL + timestamp + page list）
#   specs/design-source/index.html    主 HTML
#   specs/design-source/{page}.html   每個 sub-page（如有）
#   specs/design-source/screenshots/  每頁截圖（PNG）
#   specs/design-source/assets/       下載的圖片 / icon

URL="${1:-}"
OUTDIR="specs/design-source"
META="specs/design-source.md"

if [ -z "$URL" ]; then
  [ ! -f "$META" ] && { echo "🔴 沒給 URL，且 $META 也不存在"; exit 1; }
  URL=$(grep -oE 'https://claude\.(ai|com)/[^ )]+' "$META" | head -1)
fi

[ -z "$URL" ] && { echo "🔴 找不到 design URL"; exit 1; }

echo "📥 Sync design from: $URL"
mkdir -p "$OUTDIR/screenshots" "$OUTDIR/assets"

# 1. 下載主 HTML
echo "→ Download HTML"
curl -fsSL "$URL" -o "$OUTDIR/index.html" || {
  echo "🔴 下載 HTML 失敗（URL 可能過期或需要登入）"
  echo "   → 使用者需在 Claude design 重新 share 或 export，再給新 URL"
  exit 1
}

# 2. 用 playwright 截圖（如果裝了）
if command -v npx > /dev/null 2>&1 && [ -f test/package.json ]; then
  echo "→ Screenshot pages with playwright"
  ( cd test && npx playwright screenshot --browser chromium --full-page \
    --wait-for-timeout 3000 \
    "$URL" "../$OUTDIR/screenshots/main.png" 2>&1 | tail -3 ) || \
    echo "   ⚠️  截圖失敗（不阻塞，HTML 已下載可用）"
else
  echo "→ Skip screenshot (playwright 未裝)；裝完跑："
  echo "   cd test && npx playwright install chromium"
fi

# 3. 解析 HTML 抽出所有 sub-page / iframe URL（如有）
SUBPAGES=""
if [ -f "$OUTDIR/index.html" ]; then
  SUBPAGES=$(grep -oE 'href="[^"]+"|src="[^"]+"' "$OUTDIR/index.html" \
    | grep -oE 'https?://[^"]+' \
    | grep -v 'cdn\|fonts\|googleapis' \
    | sort -u)
fi

# 4. 寫 metadata
TIMESTAMP=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
cat > "$META" <<EOF
# Design Source

> ⚠️ 這是 Claude design URL 的本地快照。所有 frontend 開發**只**參照本目錄，不要依賴遠端 URL（可能被使用者更新）。
> 要刷新請跑：\`bash .claude/scripts/sync-design.sh\`

## Source
- **URL**: $URL
- **Last synced**: $TIMESTAMP
- **Local snapshot**: \`specs/design-source/\`

## Files
- \`specs/design-source/index.html\` — 主 HTML（curl 下載）
- \`specs/design-source/screenshots/\` — playwright 截圖（pixel-perfect 對照用）
- \`specs/design-source/assets/\` — 圖片 / icon 等資源

## Sub-pages / Resources
$(if [ -n "$SUBPAGES" ]; then echo "$SUBPAGES" | sed 's/^/- /'; else echo "(無)"; fi)

## How to use

### Frontend engineer
1. 讀 \`specs/design-source/index.html\` 對照元件結構（grep 找你要做的 component）
2. 看 \`specs/design-source/screenshots/main.png\` 對照視覺
3. 不要 WebFetch 線上 URL（除非本地快照過舊）

### UI designer
- 從 HTML 抽 design tokens（color / spacing / font）寫進 \`design/tokens/\`
- 從 HTML 找 testid / aria-label，整理成 handoff 給 tech-lead 寫進 \`specs/contracts/dom.md\`
- 從 HTML 抽所有面向使用者的字串，寫進 \`design/ux-text-handoff.md\`

### Spec writer
- 從 HTML 反推使用者流程，寫進 \`specs/features/*.feature\`
- 看不到的部份（backend / data）用 AskUserQuestion 補
EOF

echo ""
echo "✅ Design synced to $OUTDIR/"
echo "   - HTML: $(wc -c < "$OUTDIR/index.html" | tr -d ' ') bytes"
echo "   - Screenshot: $(ls "$OUTDIR/screenshots/" 2>/dev/null | wc -l | tr -d ' ') files"
echo "   - Metadata: $META"
