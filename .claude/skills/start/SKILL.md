---
name: start
description: 啟動完整的 specflow 專案流程。使用者只需與 spec agent 對話確認需求和架構，之後 tech-lead → (engineer + qa 並行) → verify → release 全部自動背景執行。觸發關鍵字："start", "開始", "啟動專案", "新專案"。
user-invocable: true
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Agent
argument-hint: "[專案主題]"
---

# SpecFlow 完整流程 Orchestrator

使用者只需做兩件事：
1. **與 spec agent 對話** — 確認需求、API contract、技術架構、sprint 規劃
2. **確認 release** — 每個 sprint 完成後確認

## 完整流程

### Phase 1：初始化（自動）

```bash
LABEL_COUNT=$(gh label list --json name --jq 'length')
if [ "$LABEL_COUNT" -lt 7 ]; then
  bash .claude/scripts/init-github.sh
fi
mkdir -p specs/features specs/changes specs/changes/archive
```

### Phase 2：Spec 討論（使用者參與）

啟動 spec-writer agent（**前景，需使用者互動**）：
- `subagent_type: "spec-writer"`
- `run_in_background: false`
- 傳入 $ARGUMENTS

spec-writer 產出：
- `specs/` 目錄下的 spec 檔案（source of truth）
- Epic Issue + Sprint Issues
- Sprint Milestones

### Phase 3：Tech Lead 規劃（背景自動）

啟動 tech-lead agent（**背景**）：
- `subagent_type: "tech-lead"`
- `run_in_background: true`

tech-lead：
1. 讀取 `specs/` 目錄，自動分析依賴圖譜
2. 建立 feature issues（含 WHEN/THEN scenarios + 實作指引）
3. 建立 QA issue（含 scenarios 清單）
4. 產出 `specs/dependencies.md`

### Phase 4：Engineer + QA 同時啟動（背景並行）

tech-lead 完成後，根據 `specs/dependencies.md` 的 wave 分組：

#### Engineer Agents
```
Wave 1（無依賴）：同時啟動
  Agent(subagent_type="engineer", run_in_background=true, isolation="worktree")

Wave 2（有依賴）：等 Wave 1 完成
  Agent(subagent_type="engineer", run_in_background=true, isolation="worktree")
```

#### QA Agent（與 Wave 1 同時）
```
Agent(subagent_type="qa-engineer", run_in_background=true, isolation="worktree")
```

### Phase 5：測試驗證（全部完成後自動）

所有 engineer PR + QA test PR 完成後：
1. 執行 e2e tests
2. 全部通過 → Phase 5.5
3. 有失敗 → QA 建 bug issue → engineer 修復 → 重測（最多 3 輪）

### Phase 5.5：三維度驗證（背景自動）

```
Agent(subagent_type="verifier", run_in_background=true)
```

Verifier 檢查：
- **Completeness**：所有 spec 有實作？所有 scenario 有 test？
- **Correctness**：實作行為符合 spec？API/error codes 一致？
- **Coherence**：程式碼風格統一？設計決策被遵守？

結果：
- PASS → Phase 6
- WARNING → Phase 6（附帶建議）
- FAIL → 建 bug issue → engineer 修復 → 重新驗證

### Phase 6：Sprint 完成通知（使用者確認）

```
✅ Sprint {N} 完成！

📊 摘要：
Features: X | PRs: X | E2E Tests: X passed | Bugs fixed: X
Verify: PASS ✅

驗證報告：specs/verify-sprint-{N}.md
請使用 /release 確認發佈。
```

## 重要

- **只有 spec 討論和 release 確認需要使用者**
- `specs/` 目錄是 source of truth，所有 agent 從這裡讀取規格
- 依賴分析自動化，不需手動判斷 wave
- 三維度驗證確保交付品質
