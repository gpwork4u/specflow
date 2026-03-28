---
name: specflow:release
description: 確認當前 sprint release，關閉 milestone，自動推進到下一個 sprint。必須 QA 完整測試通過才能 release。觸發關鍵字："release", "發佈", "上線"。
user-invocable: true
allowed-tools: Read, Bash, Agent
argument-hint: "[sprint編號]"
---

# Sprint Release 確認

確認當前 sprint 的交付成果，關閉 milestone，自動推進下一個 sprint。
**QA 完整測試必須通過才能 release。**

## 流程

### 第一步：Release 前置檢查（Gate）

**以下條件全部通過才能 release，任一未通過則阻擋：**

```bash
SPRINT="{current_sprint}"
BLOCK=false

# 1. QA issue 必須已關閉（代表完整測試通過）
OPEN_QA=$(gh issue list --label "qa" --milestone "$SPRINT" --state open --json number --jq 'length')
if [ "$OPEN_QA" -gt 0 ]; then
  echo "❌ BLOCKED: QA issue 尚未關閉（完整測試未通過）"
  BLOCK=true
fi

# 2. 所有 feature issues 必須已關閉
OPEN_FEATURES=$(gh issue list --label "feature" --milestone "$SPRINT" --state open --json number --jq 'length')
if [ "$OPEN_FEATURES" -gt 0 ]; then
  echo "❌ BLOCKED: 有 $OPEN_FEATURES 個 feature issue 未關閉"
  BLOCK=true
fi

# 3. 所有 bug issues 必須已關閉
OPEN_BUGS=$(gh issue list --label "bug" --milestone "$SPRINT" --state open --json number --jq 'length')
if [ "$OPEN_BUGS" -gt 0 ]; then
  echo "❌ BLOCKED: 有 $OPEN_BUGS 個 bug issue 未關閉"
  BLOCK=true
fi

# 4. 所有 PR 必須已合併
OPEN_PRS=$(gh pr list --state open --json headRefName --jq '[.[] | select(.headRefName | startswith("feature/") or startswith("fix/") or startswith("test/"))] | length')
if [ "$OPEN_PRS" -gt 0 ]; then
  echo "❌ BLOCKED: 有 $OPEN_PRS 個 PR 未合併"
  BLOCK=true
fi

# 5. Test Report 必須存在且為 ALL PASSED
if [ ! -f "test/reports/sprint-{N}-test-report.md" ]; then
  echo "❌ BLOCKED: Test Report 不存在（QA 尚未執行完整測試）"
  BLOCK=true
elif ! grep -q "ALL TESTS PASSED" "test/reports/sprint-{N}-test-report.md"; then
  echo "❌ BLOCKED: Test Report 顯示有失敗的測試"
  BLOCK=true
fi

# 6. 驗證報告必須存在且為 PASS
if [ ! -f "specs/verify-sprint-{N}.md" ]; then
  echo "❌ BLOCKED: 驗證報告不存在（請先執行 /specflow:verify）"
  BLOCK=true
fi
```

如果 `BLOCK=true`，列出所有阻擋項目，**不執行 release**。
提示使用者需要先解決阻擋項目。

### 第二步：產出 Sprint 報告

```bash
gh issue comment {epic_number} --body "$(cat <<'BODY'
## 🚀 Sprint {N} Released

### 交付功能
- #{feature} F-001: {名稱} ✅
- #{feature} F-002: {名稱} ✅

### 完整測試結果
| 測試類型 | 結果 |
|----------|------|
| Unit Tests | ✅ passed |
| API E2E Tests | ✅ passed |
| Browser Tests | ✅ passed |
| 三維度驗證 | ✅ PASS |

### 數據摘要
| 項目 | 數量 |
|------|------|
| Feature Issues | X |
| Pull Requests | X |
| Bugs 修復 | X |

### PRs
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

## Release Gate 總結

| # | 檢查項目 | 必須 | 來源 |
|---|----------|------|------|
| 1 | QA issue 已關閉 | ✅ | QA 完整測試通過後才會關閉 |
| 2 | 所有 feature issues 已關閉 | ✅ | PR merge 自動關閉 |
| 3 | 所有 bug issues 已關閉 | ✅ | fix PR merge 自動關閉 |
| 4 | 所有 PR 已合併 | ✅ | engineer + qa + design 的 PR |
| 5 | Test Report ALL PASSED | ✅ | `test/reports/sprint-{N}-test-report.md` |
| 6 | 驗證報告 PASS | ✅ | verifier 三維度檢查 |

**缺任何一項都不能 release。**

Test Report 包含：
- Docker Compose 環境狀態
- Unit Tests 結果
- API E2E Tests 結果
- Browser Tests 結果（agent-browser）
- Scenario 覆蓋率
- 發現的問題清單
