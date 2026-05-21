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

cat > design/open-questions.md <<EOF
# Open Questions (Refs #${ISSUE_NUM})

> design 沒明確涵蓋的情境記在這裡（hover / empty / error / a11y 違規等），**不腦補**自行補設定。

EOF

# v7 註：handoff 表（components-handoff.md / ux-text-handoff.md）刻意**不**在 scaffold 建立。
# 原因：tech-lead 在 contract phase 已直接從 design-source 寫好 contracts/dom.md + ux-text.md，
# handoff 是事後驗證（低價值），不該佔 scaffold budget。ui-designer 把 budget 花在元件 spec
# （v5 模式產 1400+ 行 vs v6 加 handoff stub 只剩 62 行）。handoff 若有餘力收尾再寫。

# commit + push（只推 token shell + open-questions，很輕）
if [ -x .claude/scripts/commit-progress.sh ]; then
  bash .claude/scripts/commit-progress.sh "chore: scaffold design tokens skeleton + open-questions" "$ISSUE_NUM"
else
  git add design/
  git commit -q -m "chore: scaffold design tokens skeleton

Refs #${ISSUE_NUM}"
  git push -q
fi

echo "✅ design scaffold committed + pushed (3 token JSON shell + open-questions；handoff 留收尾寫，優先元件 spec)"
