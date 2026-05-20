#!/usr/bin/env bash
# dispatch-impl.sh — 為每個 lane 建立 isolated demo clone，回 path 給 caller spawn agent
# 目的：杜絕 v3 出現的 cross-lane 共寫 working tree 污染（qa 撞 design tokens 那種）
#
# Usage:
#   dispatch-impl.sh <repo_owner/name> <lane>
#   lane: backend / frontend / qa / design / pipeline
#
# Output (stdout): clone 絕對路徑（caller 把 cwd 設這裡 spawn agent）
# 若 clone 已存在，做 fetch + rebase 不重新 clone（節省時間）。

set -e
REPO="$1"
LANE="$2"
CLONES_DIR="${CLONES_DIR:-/tmp/specflow-lane-clones}"

if [ -z "$REPO" ] || [ -z "$LANE" ]; then
  echo "Usage: $0 <repo_owner/name> <lane>" >&2
  exit 2
fi

mkdir -p "$CLONES_DIR"
TARGET="$CLONES_DIR/$(echo "$REPO" | tr '/' '-')-${LANE}"

if [ -d "$TARGET/.git" ]; then
  # 已存在：fetch + rebase（保留本地工作）
  cd "$TARGET"
  git fetch -q origin
  # 若在 main 且 clean，rebase 到最新；否則只 fetch
  if git symbolic-ref -q --short HEAD | grep -qx 'main'; then
    git pull -q --rebase origin main 2>/dev/null || true
  fi
else
  # clone（用 ssh 比 https 不會卡權限）
  git clone -q "git@github.com:${REPO}.git" "$TARGET" 2>&1 | grep -v setValue || true
fi

echo "$TARGET"
