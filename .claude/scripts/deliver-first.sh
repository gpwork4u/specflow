#!/usr/bin/env bash
# deliver-first.sh — 1 個 Bash call 完成 deliver-first 4 步：fetch+rebase → 開分支 → empty commit → push + draft PR
# 目的：把 4 個 tool call 合成 1 個，避免 agent 漏第 4 步（v2/v3 ui-designer 那種沒開 PR 的 bug 結構性消除）
#
# Usage:
#   deliver-first.sh <issue_num> <slug> <title> <labels> [<branch_prefix>]
#   branch_prefix default: "feature/"
#   for qa lane: branch_prefix="test/" slug="sprint-N-e2e"
#   for design lane: branch_prefix="design/" slug="sprint-N-components"
#
# Output (stdout): draft PR number（無前綴）
# Exit non-zero 才算失敗。

set -e
ISSUE_NUM="$1"
SLUG="$2"
TITLE="$3"
LABELS="$4"
BRANCH_PREFIX="${5:-feature/}"

if [ -z "$ISSUE_NUM" ] || [ -z "$SLUG" ] || [ -z "$TITLE" ] || [ -z "$LABELS" ]; then
  echo "Usage: $0 <issue_num> <slug> <title> <labels> [<branch_prefix>]" >&2
  exit 2
fi

# qa/design 不用 issue_num 在前的格式，用 branch_prefix + slug 直接
case "$BRANCH_PREFIX" in
  test/|design/) BRANCH="${BRANCH_PREFIX}${SLUG}" ;;
  *) BRANCH="${BRANCH_PREFIX}${ISSUE_NUM}-${SLUG}" ;;
esac

# 步驟 1: fetch + rebase 防 race
git fetch -q origin
git checkout -q main
git pull -q --rebase origin main 2>/dev/null || true   # 沒 upstream 改動就 OK

# 步驟 2: 開 branch（若已存在直接 checkout，可重入）
if git show-ref --verify --quiet "refs/heads/${BRANCH}"; then
  git checkout -q "${BRANCH}"
else
  git checkout -q -b "${BRANCH}"
fi

# 步驟 3: empty commit 鎖 branch
git commit --allow-empty -q -m "chore: [WIP] start #${ISSUE_NUM}"

# 步驟 4: push + open draft PR
git push -u -q origin "${BRANCH}"

# 已有 PR 就不重開
EXISTING_PR=$(gh pr list --head "${BRANCH}" --json number --jq '.[0].number' 2>/dev/null || true)
if [ -n "$EXISTING_PR" ] && [ "$EXISTING_PR" != "null" ]; then
  echo "$EXISTING_PR"
else
  gh pr create --draft \
    --title "[WIP] ${TITLE}" \
    --body "Closes #${ISSUE_NUM}

[WIP] Implementation in progress. Created by deliver-first.sh." \
    --label "${LABELS}" \
    --json number --jq .number
fi
