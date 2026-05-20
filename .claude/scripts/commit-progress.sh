#!/usr/bin/env bash
# commit-progress.sh — git add -A + commit + push 三合一
# 目的：實作期間每次 commit 從 3 tool call 省到 1
#
# Usage:
#   commit-progress.sh "<message>" [<issue_num>]
#
# Exit non-zero 才算失敗（"nothing to commit" 不算錯）。

set -e
MSG="$1"
ISSUE_NUM="${2:-}"

if [ -z "$MSG" ]; then
  echo "Usage: $0 \"<message>\" [<issue_num>]" >&2
  exit 2
fi

git add -A

# 若無 staged 改動，靜默結束
if git diff --cached --quiet; then
  echo "(nothing to commit)"
  exit 0
fi

if [ -n "$ISSUE_NUM" ]; then
  git commit -q -m "${MSG}

Refs #${ISSUE_NUM}"
else
  git commit -q -m "${MSG}"
fi

git push -q
echo "$(git rev-parse --short HEAD) pushed"
