# SpecFlow

基於 Claude Code 的自動化專案交付工作流。透過多個 AI agent 協作，將「需求討論 → 技術規劃 → 實作 → 測試 → 驗證」的完整流程自動化。

使用者只需要做兩件事：

1. 與 spec agent **對話確認需求**
2. 每個 sprint 完成後**確認 release**

其餘全部由 agent 背景自動完成。

**[Demo](https://gpwork4u.github.io/specflow/?repo=gpwork4u%2Fspecflow-demo)** — 查看 SpecFlow 實際運作的範例專案

---

## 安裝

在你的專案 repo 中一行指令安裝：

```bash
# 進入你的專案目錄
cd /path/to/your/project

# 從 GitHub 安裝 SpecFlow skills + agents
git clone --depth 1 https://github.com/gpwork4u/specflow.git /tmp/specflow \
  && cp -r /tmp/specflow/.claude . \
  && cp /tmp/specflow/CLAUDE.md . \
  && rm -rf /tmp/specflow \
  && echo "✅ SpecFlow installed"
```

或者如果你想手動控制：

```bash
# 只複製 .claude/ 和 CLAUDE.md
curl -sL https://github.com/gpwork4u/specflow/archive/refs/heads/main.tar.gz \
  | tar xz --strip-components=1 -C . "specflow-main/.claude" "specflow-main/CLAUDE.md"
```

安裝完成後啟動 Claude Code：

```bash
claude

# 首次使用：初始化 GitHub labels 和 issue templates
/specflow:init

# 開始！
/specflow:start 我的專案名稱
```

## 前置需求

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) 已安裝
- [GitHub CLI (`gh`)](https://cli.github.com/) 已安裝並登入
- [Docker](https://docs.docker.com/get-docker/) + [Docker Compose](https://docs.docker.com/compose/install/) 已安裝（本地部署 + 測試用）
- [Playwright](https://playwright.dev/) 已安裝（QA 瀏覽器測試用）
- 目標 GitHub repo 已建立且已 `git init`

```bash
# 確認 Docker
docker --version && docker compose version

# Playwright 安裝
npm install -D @playwright/test
npx playwright install
```

---

## 工作流程

```
使用者操作              背景自動執行
──────────            ─────────────
/specflow:start 對話 ──→ spec-writer（前景互動）
  │                       │  產出：specs/ + Epic + Sprint issues
  │ 確認 spec            ▼
  │                 tech-lead（背景）
  │                       │  分析依賴 → 開 Feature + QA issues
  │                 ┌─────┴─────┐
  │                 ▼           ▼
  │           engineer ×N    qa-engineer        ← 同時啟動
  │           認領 feature   WHEN/THEN → test script
  │           各自發 PR      發 test PR
  │                 └─────┬─────┘
  │                       ▼
  │                 執行 e2e tests
  │                       │
  │              ┌─ 失敗 → bug issue → engineer 修復 → 重測 ─┐
  │              └─ 通過 ↓                                   │
  │                 verifier（三維度驗證）                     │
  │                       │                                  │
  │              ┌─ FAIL → bug issue → 修復 → 重驗 ──────────┘
  │              └─ PASS ↓
  │                 自動產出工作日誌 → 關閉 milestone
  │                       │
  │                 ┌─ 有下一個 sprint → 自動啟動
  │                 └─ 全部完成 → 通知使用者
  │
/specflow:release ──→ 部署 production（使用者確認後執行）
```

### Phase 詳細說明

| Phase | 做什麼 | 誰執行 | 使用者參與 |
|-------|--------|--------|-----------|
| 1. 初始化 | 建立 GitHub labels、issue templates | 自動 | 首次執行 `/specflow:init` |
| 2. Spec 討論 | 討論需求、API contract、架構、sprint 規劃 | spec-writer | **對話互動** |
| 3. 工作分配 | 分析依賴圖譜，開 feature + QA issues | tech-lead | 背景自動 |
| 4a. 實作 | 在 `dev/` 實作 + 撰寫 unit tests | engineer ×N | 背景並行 |
| 4b. 測試撰寫 | 在 `test/` 撰寫 e2e + browser tests | qa-engineer | 背景同步 |
| 5. 測試驗證 | 執行 unit + e2e + browser tests，失敗建 bug issue（附截圖）| qa-engineer | 背景自動 |
| 5.5 三維度驗證 | Completeness + Correctness + Coherence | verifier | 背景自動 |
| 6. 工作日誌 | 產出 sprint 工作日誌，關閉 milestone | verifier | 背景自動 |
| 7. 自動推進 | 啟動下一個 sprint，或通知使用者全部完成 | 自動 | 背景自動 |

---

## Agent 角色

### spec-writer — 產品規格專家

與使用者互動討論需求，產出：
- `specs/` 目錄（source of truth）
- Epic Issue + Sprint Issues
- Sprint Milestones

Spec 涵蓋：技術架構、API contract、data model、business rules、**WHEN/THEN scenarios**。

### tech-lead — 技術主管

讀取 `specs/` 目錄，自動化分析：
- **依賴圖譜**：用拓撲排序自動決定 feature 的執行順序（wave-based）
- Feature issue — 含 scenarios + 實作指引（建立/修改的檔案、關鍵邏輯）
- QA issue — 含所有 scenarios 清單

**建立的 Issue**：Feature（給 engineer）、QA（給 qa-engineer）

### engineer — 軟體工程師

認領 feature 或 bug issue，**在 `dev/` 目錄下**獨立 worktree 分支實作，發 PR 連結 issue。

職責包含：
- 程式碼實作（`dev/src/`）
- **撰寫 unit tests**（`dev/__tests__/`）
- 確保所有 WHEN/THEN scenarios 能通過

**不碰 `test/` 目錄**（那是 QA 的領域）。

### qa-engineer — QA 工程師

認領 QA issue，**在 `test/` 目錄下**執行雙層測試。與 engineer 同時啟動。

**不碰 `dev/` 目錄**（那是 Engineer 的領域）。

#### 雙層測試策略

| 層級 | 工具 | 時機 | 目的 |
|------|------|------|------|
| **API Tests** | test framework | 與 engineer 同時撰寫 | 驗證 API contract 正確性 |
| **Browser Tests** | [Playwright](https://playwright.dev/) | engineer 完成後執行 | 驗證完整 UI 流程和使用者體驗 |

#### WHEN/THEN → Test 轉換

| Scenario | API Test | Browser Test (Playwright) |
|----------|----------|--------------------------|
| GIVEN | test setup | `page.goto()` + login |
| WHEN | API call | `page.fill()` / `page.click()` |
| THEN | `expect()` | `expect(page.getByText()).toBeVisible()` + `page.screenshot()` |

#### Playwright 核心範例

```typescript
import { test, expect } from '@playwright/test';

test('example', async ({ page }) => {
  await page.goto(BASE_URL);                        // 導航
  await page.waitForLoadState('networkidle');        // 等待載入
  await page.fill('[name="field"]', 'value');        // 互動
  await page.click('button[type="submit"]');         // 點擊
  await page.waitForLoadState('networkidle');        // 等待結果
  await expect(page.getByText('成功')).toBeVisible(); // 驗證
  await page.screenshot({ path: 'result.png' });    // 截圖
});
```

#### Bug Issue 附截圖

API test 或 Browser test 任一失敗時，自動截圖並建立 bug issue 通知 engineer：

```markdown
## Screenshot（測試失敗時的畫面）
![Bug Screenshot](screenshot-url)

## Playwright Trace
下載 trace 進行詳細除錯
```

讓 engineer 不需重現就能直觀理解問題。

### verifier — 驗證專家

在 QA 測試通過後，對整個 sprint 進行三維度驗證：

| 維度 | 檢查什麼 | 嚴重等級 |
|------|---------|---------|
| **Completeness** | 所有 spec 有實作？所有 scenario 有 test？ | CRITICAL |
| **Correctness** | API/error codes 符合 spec？business rules 實作？ | CRITICAL |
| **Coherence** | 目錄結構、命名、error handling 一致？ | WARNING |

---

## Specification-Driven Development

### Source of Truth：`specs/` 目錄

所有規格以 Markdown 檔案維護在 repo 中，是整個工作流的 single source of truth：

```
specs/
├── overview.md                  # 專案概述 + 技術架構
├── dependencies.md              # 依賴圖譜（tech-lead 自動產生）
├── verify-sprint-{N}.md         # 驗證報告（verifier 產生）
├── logs/                        # Sprint 工作日誌
│   └── sprint-{N}-log.md
├── features/
│   ├── f001-{name}.md           # Feature spec（含 WHEN/THEN scenarios）
│   ├── f002-{name}.md
│   └── ...
└── changes/                     # Delta 變更（跨 sprint 修改既有功能）
    ├── sprint-2-changes.md
    └── archive/                 # 已歸檔的變更
```

### WHEN/THEN Scenario 格式

每個接受標準以 scenario 形式撰寫，可直接轉為 test case：

```markdown
#### Scenario: 建立 resource 成功
GIVEN 使用者已登入且有有效 token
WHEN POST /api/v1/resource with { "field_a": "test", "field_b": 42 }
THEN response status = 201
AND response body matches { "id": any(string), "field_a": "test" }
AND database contains record with field_a = "test"
```

QA 直接轉為：

```typescript
test('Scenario: 建立 resource 成功', async () => {
  // GIVEN
  const token = await getAuthToken();
  // WHEN
  const res = await api.post('/api/v1/resource', {
    body: { field_a: 'test', field_b: 42 },
    headers: { Authorization: `Bearer ${token}` }
  });
  // THEN
  expect(res.status).toBe(201);
  // AND
  expect(res.body).toMatchObject({ id: expect.any(String), field_a: 'test' });
});
```

### Delta 變更格式

跨 sprint 修改既有功能時，使用 delta 格式記錄變更意圖：

```markdown
# Sprint 2 Changes

## MODIFIED: F-001 Resource 管理
- ADDED endpoint: `PATCH /api/v1/resource/:id`
- MODIFIED `POST`: added optional field `field_c`

## ADDED: F-005 Notification
（完整新功能 spec）

## REMOVED: F-003 Legacy Export
Migration: 使用 F-004 Batch Export 替代
```

確認後更新主檔案，變更歸檔到 `specs/changes/archive/`。

---

## GitHub Issue 架構

### 層級關係

透過 issue body 中的 task list（`- [ ] #issue`）串連：

```
Epic #1（索引 + 架構）
├── Sprint 1 #2
│   ├── Feature F-001 #3（engineer，含 scenarios）
│   ├── Feature F-002 #4（engineer，含 scenarios）
│   ├── QA Sprint 1 #5（qa，含 scenario 清單）
│   └── Bug #8（如有，附截圖，engineer）
├── Sprint 2 #6
│   └── ...
```

### Labels

| Label | 顏色 | 用途 |
|-------|------|------|
| `spec` | #0E8A16 綠 | Spec 規格 |
| `epic` | #3E4B9E 深藍 | Epic 總覽 |
| `sprint` | #C5DEF5 淺藍 | Sprint 追蹤 |
| `feature` | #1D76DB 藍 | 功能需求 |
| `qa` | #D876E3 紫 | QA 測試 |
| `bug` | #B60205 紅 | Bug |
| `blocked` | #E4E669 黃綠 | 被阻塞 |
| `in-progress` | #0075CA 藍 | 進行中 |
| `ready-for-review` | #7057FF 紫 | 等待 Review |
| `ready-for-qa` | #D876E3 紫 | 等待 QA 驗證 |

---

## 並行執行策略

多個 engineer 和 qa-engineer 同時對**同一個 repo** 進行開發，透過 **git worktree** 隔離彼此的工作區。

### Git Worktree 機制

```
your-project/                          ← 主 worktree（main branch）
│
/tmp/.claude-worktrees/
├── specflow-feature-3-user-auth/      ← Engineer A（branch: feature/3-user-auth）
├── specflow-feature-4-crud-api/       ← Engineer B（branch: feature/4-crud-api）
└── specflow-test-sprint-1-e2e/        ← QA（branch: test/sprint-1-e2e）
```

每個 agent 啟動時，Claude Code 自動建立獨立 worktree，完成後 push branch、發 PR，worktree 自動清理。

### 自動化依賴分析

Tech Lead 自動分析 feature 間的依賴（data model 引用、API 依賴），產出拓撲排序：

```
Wave 1（無依賴，同時啟動）：
┌──────────────────────────────────────────────┐
│  Engineer A     Engineer B     QA Engineer   │
│  Feature #3     Feature #4     QA Issue #5   │
└──────────────────────────────────────────────┘
                     │
                全部完成後
                     │
Wave 2（有依賴）：
┌──────────────────────────────────────────────┐
│  Engineer C                                  │
│  Feature #7（依賴 #3 的 data model）          │
└──────────────────────────────────────────────┘
```

依賴圖譜存放在 `specs/dependencies.md`。

---

## 指令

### 主要指令

| 指令 | 說明 | 使用者參與 |
|------|------|-----------|
| `/specflow:init` | 初始化 GitHub repo 的 labels 和 issue templates | 首次一次 |
| `/specflow:start [主題]` | 啟動完整流程：spec 對話 → 自動到底 | 對話確認 spec |
| `/specflow:verify` | 三維度驗證（Completeness + Correctness + Coherence）| 不需要 |
| `/specflow:release` | 部署 production（所有 sprint 完成後） | 確認部署 |

### 進階指令

| 指令 | 說明 |
|------|------|
| `/specflow:spec [主題]` | 僅啟動 spec 討論 |
| `/specflow:plan` | 僅啟動 tech-lead 開 issue |
| `/specflow:implement [issue#]` | 僅啟動 engineer + qa 並行 |
| `/specflow:qa` | 僅啟動 QA 撰寫 test |

---

## 目錄結構

```
your-project/
├── .claude/
│   ├── settings.json            # 權限設定（auto-accept rules）
│   ├── agents/
│   │   ├── spec-writer.md       # 產品規格專家
│   │   ├── tech-lead.md         # 技術主管
│   │   ├── engineer.md          # 軟體工程師
│   │   ├── qa-engineer.md       # QA 工程師
│   │   └── verifier.md          # 驗證專家
│   ├── skills/
│   │   ├── init/SKILL.md
│   │   ├── start/SKILL.md       # 主要 orchestrator
│   │   ├── release/SKILL.md
│   │   ├── verify/SKILL.md
│   │   ├── spec/SKILL.md
│   │   ├── plan/SKILL.md
│   │   ├── implement/SKILL.md
│   │   └── qa/SKILL.md
│   └── scripts/
│       └── init-github.sh
├── specs/                        # Source of Truth（spec-writer 產生）
│   ├── overview.md
│   ├── dependencies.md           # tech-lead 自動產生
│   ├── verify-sprint-{N}.md      # verifier 產生
│   ├── logs/                     # Sprint 工作日誌
│   │   └── sprint-{N}-log.md
│   ├── features/
│   │   └── f{N}-{name}.md
│   └── changes/
│       └── archive/
├── dev/                          # 🔧 Engineer 專屬
│   ├── src/                      # 程式碼
│   │   ├── models/
│   │   ├── routes/
│   │   ├── validators/
│   │   └── middleware/
│   ├── __tests__/                # Unit tests（Engineer 撰寫）
│   │   ├── models/
│   │   ├── routes/
│   │   └── validators/
│   └── package.json
├── test/                         # 🧪 QA 專屬
│   ├── e2e/                      # API-level tests
│   │   ├── setup.ts
│   │   ├── helpers.ts
│   │   └── f{N}-{name}.test.ts
│   ├── browser/                  # Playwright UI tests
│   │   ├── setup.sh
│   │   ├── helpers.sh
│   │   └── f{N}-{name}.sh
│   └── screenshots/              # 測試截圖（.gitignore）
├── .github/                      # /specflow:init 建立
│   ├── ISSUE_TEMPLATE/
│   └── PULL_REQUEST_TEMPLATE.md
├── CLAUDE.md
└── README.md
```

---

## 引用與致謝

### UI/UX Pro Max Skill

UI Designer agent 的設計規則參考自 [UI/UX Pro Max](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill)（MIT License, by [NextLevelBuilder](https://github.com/nextlevelbuilder)），包含 10 級優先度的 UI/UX 設計規則和 Pre-Delivery Checklist，涵蓋 Accessibility、Touch & Interaction、Performance、Style、Layout、Typography、Animation 等面向。

### OpenSpec

本專案的部分設計受到 [OpenSpec](https://github.com/Fission-AI/OpenSpec) 啟發：

- **WHEN/THEN Scenario 格式** — 將接受標準結構化為可直接轉為 test 的 scenarios
- **Delta 變更格式** — ADDED/MODIFIED/REMOVED 追蹤跨 sprint 的功能修改
- **三維度驗證** — Completeness、Correctness、Coherence 確保交付品質
- **本地 Spec 檔案** — repo 中的 `specs/` 目錄作為 source of truth
- **依賴圖譜** — 拓撲排序自動計算並行策略

---

## 自訂與擴展

### 權限設定（Auto Accept）

專案內建 `.claude/settings.json`，預設 auto-accept 所有 specflow 工作流所需的工具權限：

- **Agent** — 啟動 sub-agent（spec-writer、tech-lead、engineer、qa-engineer、verifier）
- **Bash** — git、gh、docker、node、python 等常用指令
- **檔案操作** — Read、Write、Edit、Glob、Grep
- **網路** — WebSearch、WebFetch

安全限制（deny list）：
- `rm -rf /` / `rm -rf /*`
- `git push --force`
- `git reset --hard`
- `git clean -f`

如需調整，編輯 `.claude/settings.json` 的 `permissions.allow` / `permissions.deny`。

### 調整 Agent 行為

編輯 `.claude/agents/*.md`：
- `model` — 切換模型（opus / sonnet / haiku）
- `maxTurns` — 調整最大執行輪數
- `tools` — 限制可用工具
- prompt 內容 — 調整 issue / PR 的格式

### 調整 Labels

編輯 `.claude/scripts/init-github.sh` 中的 `LABELS` 陣列。

### 新增 Skill

在 `.claude/skills/{name}/SKILL.md` 建立新檔案，即可用 `/{name}` 呼叫。

---

## 授權

MIT
