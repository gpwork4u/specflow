#!/bin/sh
set -eu

# SpecFlow GitHub 初始化 Script
# 用途：建立 issue labels、issue templates、PR template
# 用法：sh init-github.sh [owner/repo]
# 相容 macOS 內建 sh/bash (無需 bash 4+)

REPO="${1:-}"

if [ -z "$REPO" ]; then
  REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || true)
  if [ -z "$REPO" ]; then
    echo "❌ 請提供 repo：sh init-github.sh owner/repo"
    exit 1
  fi
fi

echo "🚀 初始化 SpecFlow GitHub 設定: $REPO"
echo "================================================"

# ---- Labels ----
echo ""
echo "📌 建立 Issue Labels..."

create_label() {
  name="$1"; color="$2"; desc="$3"
  if gh label create "$name" --repo "$REPO" --color "$color" --description "$desc" --force 2>/dev/null; then
    echo "  ✅ $name"
  else
    echo "  ⚠️  $name (可能已存在)"
  fi
}

# 類型
create_label "spec"             "0E8A16" "Spec 規格文件"
create_label "epic"             "3E4B9E" "Epic 總覽"
create_label "sprint"           "C5DEF5" "Sprint 追蹤"
create_label "feature"          "1D76DB" "功能需求"
create_label "design"           "F9D0C4" "UI 設計"
create_label "qa"               "D876E3" "測試相關"
create_label "bug"              "B60205" "Bug 缺陷"
# 狀態
create_label "blocked"          "E4E669" "被阻塞"
create_label "in-progress"      "0075CA" "進行中"
create_label "ready-for-review" "7057FF" "等待 Review"
create_label "ready-for-qa"     "D876E3" "等待 QA 驗證"
create_label "code-review"      "6F42C1" "Code Review"

# ---- Issue Templates ----
echo ""
echo "📝 建立 Issue Templates..."

TEMPLATE_DIR=".github/ISSUE_TEMPLATE"
mkdir -p "$TEMPLATE_DIR"

cat > "$TEMPLATE_DIR/feature.yml" << 'TEMPLATE'
name: "📝 Feature"
description: "定義一個功能需求"
labels: ["feature"]
body:
  - type: textarea
    id: description
    attributes:
      label: 功能描述
      placeholder: 描述這個功能要做什麼
    validations:
      required: true
  - type: textarea
    id: user-story
    attributes:
      label: 使用者故事
      value: |
        As a [角色],
        I want [功能],
        so that [價值]
    validations:
      required: true
  - type: textarea
    id: api-contract
    attributes:
      label: API Contract
      placeholder: |
        ### `POST /api/v1/resource`
        **Request Body**:
        ```json
        {}
        ```
        **Response 200**:
        ```json
        {}
        ```
        **Error Responses**:
        | Status | Code | 條件 |
        |--------|------|------|
    validations:
      required: true
  - type: textarea
    id: acceptance-criteria
    attributes:
      label: 接受標準 & 測試場景
      placeholder: |
        ### Happy Path
        - [ ] AC-1: 描述
        ### Error Handling
        - [ ] AC-2: 描述
        ### Edge Cases
        - [ ] AC-3: 描述
    validations:
      required: true
  - type: dropdown
    id: priority
    attributes:
      label: 優先級
      options:
        - P0 - Must Have
        - P1 - Should Have
        - P2 - Nice to Have
    validations:
      required: true
TEMPLATE

cat > "$TEMPLATE_DIR/bug.yml" << 'TEMPLATE'
name: "🐛 Bug Report"
description: "回報一個 bug"
labels: ["bug"]
body:
  - type: textarea
    id: description
    attributes:
      label: Bug 描述
    validations:
      required: true
  - type: textarea
    id: steps
    attributes:
      label: 重現步驟
      placeholder: |
        1. 步驟 1
        2. 步驟 2
        3. 步驟 3
    validations:
      required: true
  - type: textarea
    id: expected
    attributes:
      label: 預期行為
    validations:
      required: true
  - type: textarea
    id: actual
    attributes:
      label: 實際行為
    validations:
      required: true
  - type: dropdown
    id: severity
    attributes:
      label: 嚴重程度
      options:
        - Critical
        - High
        - Medium
        - Low
    validations:
      required: true
  - type: input
    id: failed-test
    attributes:
      label: 失敗的測試
      placeholder: "test case name or file path"
  - type: input
    id: feature-ref
    attributes:
      label: 相關 Feature
      placeholder: "#issue_number"
TEMPLATE

echo "  ✅ feature.yml"
echo "  ✅ bug.yml"

# ---- PR Template ----
echo ""
echo "📋 建立 PR Template..."

mkdir -p ".github"
cat > ".github/PULL_REQUEST_TEMPLATE.md" << 'PRTEMPLATE'
## Summary
<!-- 簡述這個 PR 做了什麼 -->

## Changes
<!-- 列出主要變更 -->
- `file` - description

## 驗收標準檢查
<!-- 從 issue 複製驗收標準 -->
- [ ] 標準 1

## 測試
<!-- 描述測試結果 -->

## Related Issues
<!-- 使用 Closes 連結 feature/bug issue -->
Closes #
PRTEMPLATE

echo "  ✅ PULL_REQUEST_TEMPLATE.md"

# ---- Branch Protection (Ruleset) ----
echo ""
echo "🔒 設定 Branch Protection Rules..."

RULESET_PAYLOAD=$(cat << 'RULESETJSON'
{
  "name": "main-protection",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/main"],
      "exclude": []
    }
  },
  "rules": [
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 1,
        "dismiss_stale_reviews_on_push": true,
        "require_last_push_approval": false,
        "required_review_thread_resolution": true
      }
    }
  ]
}
RULESETJSON
)

if echo "$RULESET_PAYLOAD" | gh api "repos/$REPO/rulesets" --method POST --input - > /dev/null 2>&1; then
  echo "  ✅ Branch protection ruleset created"
  echo "     - Require 1 approval before merge"
  echo "     - Require all conversations resolved"
  echo "     - Dismiss stale reviews on new push"
else
  echo "  ⚠️  Branch protection ruleset (may already exist or insufficient permissions)"
  echo "     Please manually enable in Settings > Rules > Rulesets:"
  echo "     - Require pull request reviews (1 approval)"
  echo "     - Require conversation resolution before merge"
  echo "     - Dismiss stale reviews on push"
fi

# ---- 完成 ----
echo ""
echo "================================================"
echo "✅ SpecFlow 初始化完成！"
echo ""
echo "下一步："
echo "  1. 將 .github/ 目錄 commit 到 repo"
echo "  2. 使用 /specflow:start 開始專案"
echo ""
echo "Labels 清單："
gh label list --repo "$REPO" --json name,color,description --jq '.[] | "  \(.name): \(.description)"' 2>/dev/null || echo "  (請手動確認)"
