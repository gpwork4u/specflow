#!/usr/bin/env bash
# sweep-missing-prs.sh — 對於有 push branch 但沒開 PR 的情況自動補開 draft PR
# 目的：v3 ui-designer 那種「push 了但忘 gh pr create」的安全網
#
# 跑時機：4 lane 全 drained 後 orchestrator 跑一次；可在 lane-close hook 或 verifier 前
#
# Usage: sweep-missing-prs.sh
#
# 規則：
# - 掃 remote 所有非 main 分支
# - 對應 PR 不存在 → 看 branch 第一個 commit message 抓 "#NNN" 推 issue
# - 從該 issue label 推 PR label，建 draft PR
# - 無法推 issue 的 branch 跳過（人工處理）

set -e
git fetch -q origin --prune

CREATED=0
SKIPPED=0

for B in $(git ls-remote --heads origin 2>/dev/null | awk '{print $2}' | sed 's|refs/heads/||' | grep -v setValue); do
  [ "$B" = "main" ] && continue

  # 該 branch 有 open PR?
  PR_COUNT=$(gh pr list --head "$B" --state open --json number --jq 'length' 2>/dev/null || echo "0")
  if [ "$PR_COUNT" -gt 0 ]; then
    continue
  fi

  # 找 issue num（從 branch 的 commit messages 抓 #NNN）
  ISSUE_NUM=$(git log "origin/$B" ^origin/main --pretty=%s 2>/dev/null | grep -oE '#[0-9]+' | head -1 | tr -d '#')
  if [ -z "$ISSUE_NUM" ]; then
    # 從 branch 名抓（feature/3-xxx）
    ISSUE_NUM=$(echo "$B" | grep -oE '^[a-z]+/([0-9]+)' | grep -oE '[0-9]+' | head -1)
  fi

  if [ -z "$ISSUE_NUM" ]; then
    echo "⚠️  Skip $B (無法推 issue num)"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  # 從 issue label 推 PR label
  ISSUE_LABELS=$(gh issue view "$ISSUE_NUM" --json labels --jq '[.labels[].name] | join(",")' 2>/dev/null || echo "")
  PR_LABEL="${ISSUE_LABELS:-feature}"

  echo "🔧 補開 PR for $B (issue #${ISSUE_NUM}, labels=${PR_LABEL})"
  gh pr create --draft \
    --head "$B" --base main \
    --title "[WIP] auto-recovery: $B" \
    --body "Closes #${ISSUE_NUM}

⚠️ Auto-created by sweep-missing-prs.sh — agent pushed branch but didn't open PR (deliver-first step 4 missed).

This PR exists as a recovery safety net. Verify the branch content before marking ready." \
    --label "$PR_LABEL" 2>&1 | grep -v setValue || echo "  ❌ failed"
  CREATED=$((CREATED + 1))
done

echo ""
echo "📋 sweep result: created=$CREATED, skipped=$SKIPPED"
