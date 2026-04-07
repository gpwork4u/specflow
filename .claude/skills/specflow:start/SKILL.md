---
name: specflow:start
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
1. **上網 survey 技術選型**（WebSearch + WebFetch），產出 `specs/tech-survey.md`
2. 讀取 `specs/` 目錄，自動分析依賴圖譜，產出 `specs/dependencies.md`
3. 建立 feature issues（含 scenarios + 實作指引 + 技術選型）
4. 建立 QA issue（含 scenarios 清單）
5. 建立 design issue（含 UI 元件清單，如 sprint 有 UI 功能）

### Phase 4：Engineer + QA + UI Designer 同時啟動（背景並行）

tech-lead 完成後，根據 `specs/dependencies.md` 的 wave 分組：

#### Wave 0（先行，同時啟動）
```
# UI Designer — 建立 component dataset
Agent(subagent_type="ui-designer", run_in_background=true, isolation="worktree")

# QA — 撰寫 test scripts
Agent(subagent_type="qa-engineer", run_in_background=true, isolation="worktree")

# Engineer（無 UI 依賴的 feature）
Agent(subagent_type="engineer", run_in_background=true, isolation="worktree")
```

#### Wave 1（Wave 0 完成後）
```
# Engineer（需要 UI 元件的 feature，等 ui-designer 完成）
Agent(subagent_type="engineer", run_in_background=true, isolation="worktree")
```

### Phase 4.5：Code Review（每個 PR 完成後自動觸發）

Engineer 或 QA 發 PR 後，**自動啟動 code-review agent** 進行審查：

```
# 使用 sonnet 模型（只讀不寫，節省 token 成本）
Agent(subagent_type="code-review", run_in_background=true)
  input: PR #{pr_number}, Issue #{issue_number}
```

**Review Loop（最多 3 輪）**：
1. code-review agent 審查 PR → APPROVE / REQUEST_CHANGES
2. REQUEST_CHANGES → 通知對應的 engineer/qa agent 處理 review comments → 推送修正
3. code-review agent 重新 review
4. APPROVED → PR ready to merge

**重要**：
- Branch protection 要求 1 approval + 所有 conversation resolved 才能 merge
- code-review 使用 sonnet 模型，因為只需要閱讀和判斷，不需要生成程式碼
- engineer 已有處理 review comments 的機制（見 engineer.md 第七步）
- 所有 PR 通過 review 並合併後 → Phase 5

### Phase 5：Sprint 完整測試（全部完成後自動）

所有 engineer PR + QA test PR **通過 code review 並合併後**，QA 執行 sprint 完整測試：
1. 用 `dev/docker-compose.yml` 啟動完整服務環境
2. 對跑起來的服務執行 API e2e tests
3. 對跑起來的服務執行 Playwright browser tests
4. 停止服務
5. 全部通過 → Phase 5.5
6. 有失敗 → QA 建 bug issue（附截圖）→ engineer 修復 → 重測（最多 3 輪）

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

### Phase 6：自動產出工作日誌 + 關閉 Sprint

**QA 完整測試通過 + 三維度驗證通過後自動執行，不需使用者介入。**

1. 產出 Sprint 工作日誌到 `specs/logs/sprint-{N}-log.md`
2. 在 Epic issue 留言 Sprint 報告
3. 關閉 Sprint Milestone + Sprint Issue
4. 通知使用者 Sprint 完成摘要

```
✅ Sprint {N} 完成！

📊 摘要：
Features: X | PRs: X | Bugs fixed: X

🧪 完整測試結果（docker compose 環境）：
  Unit Tests: X passed
  API E2E Tests: X passed
  Browser Tests: X passed (Playwright)

✅ Verify: PASS（Completeness + Correctness + Coherence）

📋 工作日誌：specs/logs/sprint-{N}-log.md
驗證報告：specs/verify-sprint-{N}.md
```

### Phase 7：自動推進下一個 Sprint

如果有下一個 sprint milestone，**自動啟動** Phase 3（tech-lead）→ Phase 4（engineer + qa）→ ...

如果所有 sprint 都完成，通知使用者：
```
🎉 所有 Sprint 完成！專案開發完畢。
使用 /specflow:release 部署到 production。
```

## 重要

- **只有 spec 討論需要使用者互動**
- **Sprint 之間的推進完全自動**，不需手動 release
- `/specflow:release` 僅用於 production 部署確認
- `specs/` 目錄是 source of truth，所有 agent 從這裡讀取規格
- 依賴分析自動化，不需手動判斷 wave
- 三維度驗證確保交付品質
