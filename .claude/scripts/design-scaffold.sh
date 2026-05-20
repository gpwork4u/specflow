#!/usr/bin/env bash
# design-scaffold.sh — 1 個 Bash 建 design dataset 骨架 + commit + push
# 用於 ui-designer 避開「cap before handoff」的問題（v5 ui-designer 寫到 component spec 撞 cap，
# 來不及寫 components-handoff.md / ux-text-handoff.md → tech-lead 後續對齊不到 contracts）
# 設計原則：先建 token JSON 空殼 + handoff 表頭，讓 handoff 結構**永遠存在**，agent 之後填內容
#
# Usage:
#   design-scaffold.sh <issue_num>
#   前提：deliver-first.sh 已跑過（branch + draft PR 已建）
#
# Exit non-zero 才算失敗。

set -e
ISSUE_NUM="$1"
[ -z "$ISSUE_NUM" ] && { echo "Usage: $0 <issue_num>" >&2; exit 2; }

mkdir -p design/tokens design/components design/pages design/assets

# 已有骨架就 skip（idempotent）
if [ -f design/tokens/colors.json ] && [ -f design/components-handoff.md ]; then
  echo "(scaffold 已存在，skip)"
  exit 0
fi

# Token JSON 骨架（agent 之後從 styles.css 填真實值）
cat > design/tokens/colors.json <<'EOF'
{
  "color": {
    "primary": {},
    "neutral": {},
    "success": {},
    "warning": {},
    "error": {},
    "background": {},
    "foreground": {},
    "border": {}
  },
  "_TODO": "Fill from specs/design-source/styles.css"
}
EOF

cat > design/tokens/typography.json <<'EOF'
{
  "font": {
    "family": {},
    "size": {},
    "weight": {},
    "lineHeight": {}
  },
  "_TODO": "Fill from specs/design-source/styles.css"
}
EOF

cat > design/tokens/spacing.json <<'EOF'
{
  "spacing": {},
  "radius": {},
  "shadow": {},
  "_TODO": "Fill from specs/design-source/styles.css"
}
EOF

# Handoff stubs — tech-lead 在 contract phase 對齊用，必須**先存在**
cat > design/components-handoff.md <<EOF
# Components Handoff (WIP — Refs #${ISSUE_NUM})

> 從 \`specs/design-source/components.jsx\` + \`pages-*.jsx\` 抽出的 testid 對應表。
> tech-lead 在 contract phase 吸進 \`specs/contracts/dom.md\`。

| testid | 元件 | 出現位置 | 備註 |
|--------|------|---------|------|

EOF

cat > design/ux-text-handoff.md <<EOF
# UX Text Handoff (WIP — Refs #${ISSUE_NUM})

> 從 \`specs/design-source/\` 抽出的面向使用者字串對應表。
> tech-lead 在 contract phase 吸進 \`specs/contracts/ux-text.md\`。

## Toast
| key | 文字 | 觸發情境 |
|-----|------|---------|

## Button labels
| key | 文字 | 出現位置 |
|-----|------|---------|

## Form labels
| key | 文字 | 表單 |
|-----|------|------|

## Status labels
| key | 文字 | 狀態 |
|-----|------|------|

EOF

cat > design/open-questions.md <<EOF
# Open Questions (Refs #${ISSUE_NUM})

> design 沒明確涵蓋的情境記在這裡（hover / empty / error / a11y 違規等），
> **不腦補**自行補設定。

EOF

# commit + push
if [ -x .claude/scripts/commit-progress.sh ]; then
  bash .claude/scripts/commit-progress.sh "chore: scaffold design dataset skeleton (tokens + handoff stubs)" "$ISSUE_NUM"
else
  git add design/
  git commit -q -m "chore: scaffold design dataset skeleton

Refs #${ISSUE_NUM}"
  git push -q
fi

echo "✅ design scaffold committed + pushed (tokens JSON + handoff 表頭 + open-questions 全建立，後續填內容)"
