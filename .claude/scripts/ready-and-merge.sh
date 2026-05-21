#!/usr/bin/env bash
# ready-and-merge.sh — draft PR 收尾三合一：gh pr ready → 等 CI → squash merge
# 目的：把 engineer/qa 收尾的 3 個 Bash 省到 1 個（省 turn budget）
#
# Usage:
#   ready-and-merge.sh <pr_number>
#
# 行為：
# - draft → ready
# - 等 build-and-lint CI（若 repo 沒設 CI workflow，gh pr checks 立即回，視為通過）
# - CI 綠 → squash merge + delete branch
# - CI 紅 → exit 1（caller 去修）
# Exit non-zero 才算失敗。

set -e
PR="$1"
[ -z "$PR" ] && { echo "Usage: $0 <pr_number>" >&2; exit 2; }

# draft → ready（已 ready 會報錯，吞掉）
gh pr ready "$PR" 2>/dev/null || true

# 等 CI。沒有任何 check 時 gh pr checks 回非 0（"no checks reported"），視為通過
CHECKS_OUT=$(gh pr checks "$PR" --watch 2>&1 || true)
if echo "$CHECKS_OUT" | grep -qiE 'fail|error'; then
  echo "🔴 CI 失敗，不 merge：" >&2
  echo "$CHECKS_OUT" | grep -iE 'fail|error' >&2
  exit 1
fi

gh pr merge "$PR" --squash --delete-branch
echo "✅ PR #${PR} merged (squash)"
