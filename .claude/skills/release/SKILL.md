---
name: release
description: 確認當前 sprint release，關閉 milestone，自動推進到下一個 sprint。觸發關鍵字："release", "發佈", "上線"。
user-invocable: true
allowed-tools: Read, Bash, Agent
argument-hint: "[sprint編號]"
---

# Sprint Release 確認

確認當前 sprint 的交付成果，關閉 milestone，自動推進下一個 sprint。

## 流程

### 第一步：Sprint 驗證

確認當前 sprint 所有工作已完成：

```bash
SPRINT="{current_sprint}"

# 檢查是否有未關閉的 feature
OPEN_FEATURES=$(gh issue list --label "feature" --milestone "$SPRINT" --state open --json number --jq 'length')

# 檢查是否有未關閉的 bug
OPEN_BUGS=$(gh issue list --label "bug" --milestone "$SPRINT" --state open --json number --jq 'length')

# 檢查是否有未關閉的 QA
OPEN_QA=$(gh issue list --label "qa" --milestone "$SPRINT" --state open --json number --jq 'length')

# 檢查是否有未合併的 PR
OPEN_PRS=$(gh pr list --state open --json headRefName --jq '[.[] | select(.headRefName | startswith("feature/") or startswith("fix/") or startswith("test/"))] | length')
```

如果有未完成的項目，列出清單讓使用者確認是否仍要 release。

### 第二步：產出 Sprint 報告

```bash
gh issue comment {epic_number} --body "$(cat <<'BODY'
## 🚀 Sprint {N} Released

### 交付功能
- #{feature} F-001: {名稱} ✅
- #{feature} F-002: {名稱} ✅

### 數據摘要
| 項目 | 數量 |
|------|------|
| Feature Issues | X |
| Pull Requests | X |
| E2E Test Cases | X |
| Bugs 修復 | X |

### PRs
- #{pr} {title}
- #{pr} {title}
BODY
)"
```

### 第三步：關閉 Sprint Milestone

```bash
MILESTONE_NUMBER=$(gh api repos/{owner}/{repo}/milestones --jq '.[] | select(.title | startswith("Sprint {N}")) | .number')
gh api repos/{owner}/{repo}/milestones/$MILESTONE_NUMBER -X PATCH -f state="closed"
```

### 第四步：關閉 Sprint Issue

```bash
gh issue close {sprint_issue_number} --reason completed
```

### 第五步：自動推進下一個 Sprint

```bash
NEXT_SPRINT=$(gh api repos/{owner}/{repo}/milestones --jq '[.[] | select(.state=="open") | select(.title | startswith("Sprint"))] | sort_by(.title) | .[0].title')
```

如果有下一個 sprint：
1. 通知使用者：「Sprint {N} 已 release，自動推進到 {next_sprint}」
2. 自動啟動 tech-lead → (engineer + qa 並行) 的背景流程

如果沒有下一個 sprint：
1. 通知使用者：「所有 sprint 已完成！專案交付完畢。」

## 重要提醒

- 全程使用繁體中文
- Release 前必須確認所有 feature、bug、qa issue 已關閉
- 自動推進下一個 sprint 時，使用者不需要額外操作
