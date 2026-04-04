---
name: specflow:release
description: 部署 production。所有 sprint 完成後（或使用者決定部署時），執行 production 部署流程。觸發關鍵字："release", "發佈", "上線", "deploy", "部署"。
user-invocable: true
allowed-tools: Read, Bash, Agent
argument-hint: "[版本號]"
---

# Production 部署確認

當所有 sprint 開發完成（或使用者決定部署當前進度），執行 production 部署。
**Sprint 之間的推進是自動的，不需要手動 release。**

## 流程

### 第一步：部署前置檢查（Gate）

**以下條件全部通過才能部署，任一未通過則阻擋：**

```bash
BLOCK=false

# 1. 確認沒有進行中的 sprint（所有 sprint milestone 已關閉）
OPEN_SPRINTS=$(gh api repos/{owner}/{repo}/milestones?state=open --jq '[.[] | select(.title | startswith("Sprint"))] | length')
if [ "$OPEN_SPRINTS" -gt 0 ]; then
  echo "⚠️ 警告: 有 $OPEN_SPRINTS 個 sprint 尚未完成"
  echo "（可繼續部署已完成的部分，或等待全部完成）"
fi

# 2. 所有已關閉 sprint 的 test report 必須 ALL PASSED
for report in test/reports/sprint-*-test-report.md; do
  [ -f "$report" ] || continue
  if ! grep -q "ALL TESTS PASSED" "$report"; then
    echo "❌ BLOCKED: $report 顯示有失敗的測試"
    BLOCK=true
  fi
done

# 3. 所有驗證報告必須為 PASS
for verify in specs/verify-sprint-*.md; do
  [ -f "$verify" ] || continue
  if grep -q "🔴 FAIL" "$verify"; then
    echo "❌ BLOCKED: $verify 驗證失敗"
    BLOCK=true
  fi
done

# 4. 沒有 open 的 bug issues
OPEN_BUGS=$(gh issue list --label "bug" --state open --json number --jq 'length')
if [ "$OPEN_BUGS" -gt 0 ]; then
  echo "❌ BLOCKED: 有 $OPEN_BUGS 個 bug issue 未修復"
  BLOCK=true
fi

# 5. main 分支沒有未合併的 PR
OPEN_PRS=$(gh pr list --state open --json headRefName --jq '[.[] | select(.headRefName | startswith("feature/") or startswith("fix/") or startswith("test/"))] | length')
if [ "$OPEN_PRS" -gt 0 ]; then
  echo "❌ BLOCKED: 有 $OPEN_PRS 個 PR 未合併"
  BLOCK=true
fi
```

如果 `BLOCK=true`，列出所有阻擋項目，**不執行部署**。

### 第二步：產出 Release 總報告

彙整所有 sprint 的工作日誌，產出完整的 release 報告：

```bash
gh issue comment {epic_number} --body "$(cat <<'BODY'
## 🚀 Production Release

### 完成的 Sprint
（列出所有已完成的 sprint 及其工作日誌連結）

### 交付功能總覽
（從各 sprint 工作日誌彙整）

### 測試結果
所有 sprint 測試均 ✅ PASS
所有 sprint 驗證均 ✅ PASS

### 工作日誌
（列出所有 `specs/logs/sprint-{N}-log.md` 連結）
BODY
)"
```

### 第三步：建立 Release Tag

```bash
VERSION="${ARGUMENTS:-v1.0.0}"
git tag -a "$VERSION" -m "Release $VERSION"
git push origin "$VERSION"

# 建立 GitHub Release
gh release create "$VERSION" \
  --title "Release $VERSION" \
  --notes "$(cat <<'NOTES'
## Release $VERSION

### 包含的 Sprint
（列出所有 sprint）

### 主要功能
（從工作日誌彙整）

### 工作日誌
（連結到 specs/logs/）
NOTES
)"
```

### 第四步：關閉 Epic Issue

```bash
gh issue close {epic_number} --reason completed
```

## 部署 Gate 總結

| # | 檢查項目 | 必須 | 來源 |
|---|----------|------|------|
| 1 | Test Report ALL PASSED | ✅ | 各 sprint 的 `test/reports/` |
| 2 | 驗證報告 PASS | ✅ | 各 sprint 的 `specs/verify-sprint-{N}.md` |
| 3 | 無 open bugs | ✅ | GitHub Issues |
| 4 | 所有 PR 已合併 | ✅ | GitHub PRs |

**缺任何一項都不能部署。**

Test Report 包含：
- Docker Compose 環境狀態
- Unit Tests 結果
- API E2E Tests 結果
- Browser Tests 結果（Playwright）
- Scenario 覆蓋率
- 發現的問題清單
