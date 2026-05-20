# SpecFlow

支援 **Claude Code** 與 **Codex** 的自動化專案交付工作流。它把「需求討論 → 技術規劃 → 實作 → 測試 → 驗證 → release」整理成一套可以落地的 repo 內文件與 skill 結構。

目前 repo 內同時提供兩套入口：

1. `/.claude/` + `CLAUDE.md`
   給 Claude Code 使用，保留原本多 agent / slash command 工作流。
2. `/.codex/skills/specflow`
   給 Codex 使用，將同一套流程整併成自然語言可觸發的單一 skill。

兩套文件可以 **共存於同一個專案**：

- Claude 讀 `CLAUDE.md` 與 `.claude/`
- Codex 讀 `.codex/skills/specflow/`
- 共同的 source of truth 仍然是 repo 內的 `specs/`
- 不需要二選一，也不需要為了其中一套工具刪除另一套文件

**[Demo](https://gpwork4u.github.io/specflow/?repo=gpwork4u%2Fspecflow-demo)** — 查看 SpecFlow 實際運作的範例專案

---

## 目錄

- [安裝](#安裝)
  - [安裝 Claude 版文件](#安裝-claude-版文件)
  - [安裝 Codex 版文件](#安裝-codex-版文件)
  - [共存建議](#共存建議)
- [前置需求](#前置需求)
- [工作流程](#工作流程)
- [Agent 角色](#agent-角色)
- [Specification-Driven Development](#specification-driven-development)
- [GitHub Issue 架構](#github-issue-架構)
- [並行執行策略](#並行執行策略)
- [指令](#指令)
- [目錄結構](#目錄結構)
  - [文件共存原則](#文件共存原則)
- [引用與致謝](#引用與致謝)
- [自訂與擴展](#自訂與擴展)
- [版本歷程](#版本歷程)
- [授權](#授權)

---

## 安裝

### 安裝 Claude 版文件

如果你要在 Claude Code 中使用，安裝 `.claude/` 與 `CLAUDE.md`：

```bash
# 進入你的專案目錄
cd /path/to/your/project

# 從 GitHub 安裝 Claude 版文件
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

安裝完成後，可用 Claude Code 啟動：

```bash
claude

# 首次使用：初始化 GitHub labels 和 issue templates
/specflow:init

# 開始！
/specflow:start 我的專案名稱
```

### 安裝 Codex 版文件

如果你要在 Codex 中使用，安裝 `.codex/skills/specflow`：

```bash
# 進入你的專案目錄
cd /path/to/your/project

# 從 GitHub 安裝 Codex 版文件
git clone --depth 1 https://github.com/gpwork4u/specflow.git /tmp/specflow \
  && mkdir -p .codex/skills \
  && cp -r /tmp/specflow/.codex/skills/specflow .codex/skills/specflow \
  && rm -rf /tmp/specflow \
  && echo "✅ SpecFlow installed"
```

安裝完成後，可直接在 Codex 以自然語言觸發 `specflow` workflow。

如果你想讓 Claude 與 Codex 共存，直接同時複製 `.claude/`、`CLAUDE.md` 與 `.codex/skills/specflow` 即可。

### 共存建議

- `specs/` 保持為唯一真實規格來源
- Claude 專屬自動化設定放在 `.claude/`
- Codex 專屬 skill 放在 `.codex/skills/`
- README 只描述共用概念與安裝方式，不把某一個工具當成唯一入口
- 若流程規則有更新，優先同步 `specs/` 與兩邊的 workflow 文件，避免行為漂移

## 前置需求

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) 已安裝（若使用 Claude）
- Codex CLI / Codex 工作環境已可使用（若使用 Codex）
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

無論是 Claude 或 Codex，核心流程都圍繞同一組 artifacts：

- `specs/` 負責需求、feature spec、變更與驗證報告
- GitHub issues / PR 負責協作狀態
- `dev/` 與 `test/` 分別隔離工程實作與 QA 驗證

差異主要在「如何觸發」：

- Claude：以 slash commands 與 agent orchestration 為主
- Codex：以自然語言觸發 skill，並直接在當前 workspace 落地

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
  │           認領 feature   AC → e2e .spec.ts
  │           各自發 PR      發 step defs PR
  │                 └─────┬─────┘
  │                       ▼
  │                 執行 Playwright e2e tests
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
| 4b. 測試撰寫 | 在 `test/e2e/` 撰寫 Playwright .spec.ts | qa-engineer | 背景同步 |
| 5. 測試驗證 | 執行 unit + Playwright e2e tests，失敗建 bug issue（附截圖）| qa-engineer | 背景自動 |
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

Spec 涵蓋：技術架構、API contract、data model、business rules、**acceptance criteria 條列**（Happy / Error / Edge）。

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
- 確保所有 acceptance criteria 對應的 e2e tests 能通過

**不碰 `test/` 目錄**（那是 QA 的領域）。

### qa-engineer — QA 工程師

認領 QA issue，**在 `test/` 目錄下**撰寫 Playwright e2e tests。與 engineer 同時啟動。

**不碰 `dev/` 目錄**（那是 Engineer 的領域）。

#### 測試架構（純 Playwright）

| 元件 | 工具 | 用途 |
|------|------|------|
| **Acceptance Criteria** | spec `.md` | Spec-writer 寫的 AC 條列（source of truth） |
| **E2E Tests** | Playwright `.spec.ts` | QA 把每條 AC 轉成的 Playwright test |
| **Test Runner** | Playwright | 執行測試、截圖、trace |
| **Reports** | Playwright JSON + HTML | test 級別的報告 |

#### AC → Playwright Test 對應

| AC 描述 | Playwright Test 實作 |
|--------|---------------------|
| 「已登入呼叫 POST /api/...，回 201」 | `expect((await request.post(API_PATHS.x, ...)).status()).toBe(201)` |
| 「點擊送出按鈕，顯示 toast {TOAST.x}」 | `await page.locator(...).click(); await expect(page.getByText(TOAST.x)).toBeVisible()` |
| 「未登入回 401」 | `expect((await request.post(...)).status()).toBe(401)` |

#### 範例

```typescript
import { test, expect } from '@playwright/test';
import { TESTIDS, API_PATHS, TOAST } from '../../specs/contracts';

test.describe('F-001 Resource', () => {
  test('[Happy] 建立 resource 成功', async ({ request }) => {
    const res = await request.post(API_PATHS.resourceCreate, {
      data: { field_a: 'test' },
    });
    expect(res.status()).toBe(201);
    expect((await res.json()).field_a).toBe('test');
  });

  test('[Error] 未登入回 401', async ({ request }) => {
    expect((await request.post(API_PATHS.resourceCreate)).status()).toBe(401);
  });
});
```

#### Bug Issue 附截圖

E2E test 失敗時，自動截圖並建立 bug issue（附失敗 test 名稱 + Playwright trace）：

```markdown
## 失敗的 Test
test: [Happy] 建立 resource 成功 (test/e2e/f001-resource.spec.ts)

## Screenshot
![Bug Screenshot](screenshot-url)
```

讓 engineer 不需重現就能直觀理解問題。

### verifier — 驗證專家

在 QA 測試通過後，對整個 sprint 進行三維度驗證：

| 維度 | 檢查什麼 | 嚴重等級 |
|------|---------|---------|
| **Completeness** | 所有 spec 有實作？所有 acceptance criteria 對應的 e2e test 通過？ | CRITICAL |
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
├── sprints/
│   └── sprint-{N}.md            # 該 sprint 涵蓋的 feature ID 清單（決定 e2e scope）
├── features/
│   ├── f001-{name}.md           # Feature spec（API contract, data model, business rules, acceptance criteria）
│   ├── f002-{name}.md
│   └── ...
└── changes/                     # Delta 變更（跨 sprint 修改既有功能）
    ├── sprint-2-changes.md
    └── archive/                 # 已歸檔的變更
```

### Acceptance Criteria 格式

每個功能在 `specs/features/f{NNN}-{name}.md` 寫 acceptance criteria 條列：

```markdown
# F-001 Resource 管理

## API Contract
（POST /api/v1/resource — 完整 schema 略）

## Data Model
（Resource entity — 略）

## Business Rules
（略）

## Acceptance Criteria

### Happy Path
- [ ] AC-1: 已登入使用者用合法 payload 呼叫 `POST /api/v1/resource` 回 201 + 帶 id 的物件
- [ ] AC-2: 同使用者用 `GET /api/v1/resource/:id` 拿回剛建立的 resource

### Error Handling
- [ ] AC-3: 未登入呼叫 `POST` 回 401 / `UNAUTHORIZED`
- [ ] AC-4: `field_a` 為空回 400 / `INVALID_INPUT`

### Edge Cases
- [ ] AC-5: `field_a` 100 字過、101 字拒
```

QA 把每條 AC 轉成一個 Playwright `test()`：

```typescript
import { test, expect } from '@playwright/test';
import { API_PATHS } from '../../specs/contracts';

test('[Happy] AC-1 建立 resource 成功', async ({ request }) => {
  const res = await request.post(API_PATHS.resourceCreate, {
    data: { field_a: 'test', field_b: 42 },
  });
  expect(res.status()).toBe(201);
  const body = await res.json();
  expect(typeof body.id).toBe('string');
  expect(body.field_a).toBe('test');
});

test('[Edge] AC-5 field_a 邊界值', async ({ request }) => {
  expect((await request.post(API_PATHS.resourceCreate, { data: { field_a: 'x'.repeat(100) } })).status()).toBe(201);
  expect((await request.post(API_PATHS.resourceCreate, { data: { field_a: 'x'.repeat(101) } })).status()).toBe(400);
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
├── .codex/
│   └── skills/
│       └── specflow/
│           ├── SKILL.md          # Codex 入口，整併 init/spec/plan/implement/qa/verify/release
│           └── references/
│               ├── init.md
│               ├── spec.md
│               ├── plan.md
│               ├── implement.md
│               ├── qa.md
│               ├── verify.md
│               ├── release.md
│               └── roles/
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
├── index.html                    # 文件入口 + Dashboard
├── CLAUDE.md
└── README.md
```

### 文件共存原則

| 路徑 | 主要使用者 | 用途 |
|------|-----------|------|
| `README.md` | 所有人 | 專案總覽、安裝方式、文件導覽 |
| `index.html` | 所有人 | 視覺化文件入口與 GitHub dashboard |
| `CLAUDE.md` | Claude Code | Claude 在 repo 內的主要入口文件 |
| `.claude/` | Claude Code | agents、skills、scripts、權限設定 |
| `.codex/skills/specflow/` | Codex | Codex skill 與對應 phase / role references |
| `specs/` | Claude + Codex + 人類 | 共同 source of truth |

---

## 引用與致謝

### UI/UX Pro Max Skill

UI Designer agent 的設計規則參考自 [UI/UX Pro Max](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill)（MIT License, by [NextLevelBuilder](https://github.com/nextlevelbuilder)），包含 10 級優先度的 UI/UX 設計規則和 Pre-Delivery Checklist，涵蓋 Accessibility、Touch & Interaction、Performance、Style、Layout、Typography、Animation 等面向。

### OpenSpec

本專案的部分設計受到 [OpenSpec](https://github.com/Fission-AI/OpenSpec) 啟發：

- **Markdown acceptance criteria** — 將接受標準結構化為可直接轉成 Playwright e2e tests 的條列
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

## 版本歷程

SpecFlow skill 結構演化紀錄。每一輪都基於 benchmark 量測 + 失敗根因分析後再迭代。詳細實測數據見 [`BENCHMARK-REPORT.md`](./BENCHMARK-REPORT.md)。

### 演化軌跡

```
O1 / O5 / state.sh 並發鎖   →  Slim agent prompts  →  Deliver-first  →  Helper scripts  →  Verify + retry
（infra reliability）           （−64.7% 常駐 prompt）  （v1→v2→v3）        （v3→v4）         （v5）
```

### 各階段重點

#### O1 / O5 / Infra（commit `fe4a524`、`70d081d`）

- **O1**：tech-lead 開 feature issue 不貼 spec 全文，只放路徑 + 3 行摘要（避免 engineer/QA/review/verifier 重複付費 + 與 spec 檔案漂移）
- **O5**：tech-lead 條件式 survey — spec 已釘死技術棧時跳過 WebSearch
- **state.sh 並發鎖**：lane 制最多 5 個背景 agent 同時寫 `.specflow/state.json`，flock / mkdir 退級鎖防 lost-update
- **resume 去脆弱**：GitHub 實況優先 + 子字串模糊比對
- **「無進展即停」停損規則**：同題試 2 次未解 → issue 留言並停止，不繞圈燒 turn

#### O2 Slim agent prompts（commit `0ec27a6` ~ `a1a5ccf`，merged in `953af51`）

把長範例 / 重複 JSON / 範本移到 `.claude/shared/kits/`（按需 Read 非常駐），規則改精簡祈使句。

| Agent | 常駐 prompt 行數 | Δ |
|---|---:|---:|
| spec-writer | 832 → 127 | −85% |
| tech-lead | 584 → 78 | −87% |
| engineer | 499 → 89 | −82% |
| ui-designer | 437 → 55 | −87% |
| verifier | 368 → 52 | −86% |
| qa-engineer | 233 → 52 | −78% |
| code-review | 192 → 192 | 0%（已精簡刻意保留） |
| **合計** | **3145 → 645** | **−79%** |

字元計算：常駐 prompt token 估算 −64.7%。Kit 約 9.5K token 按需 Read 一次，非每 turn 重付。

#### P0 Deliver-first（commit `b27c462`）

v1 benchmark 顯示 4 個 lane agent 全部撞 harness sub-agent cap（~60-65 tool uses / 10-min wall-clock）**前 deliverable 還沒到位** — 0 PR、0 merge。

修正：engineer / qa-engineer / ui-designer 強制反轉順序 — 建分支 → 立刻 commit 骨架 → push → 開 draft PR → **然後**才迭代。撞 cap 時 draft PR 已存在，下次 agent 可接續。

#### P0+ Absolute sequence（commit `22cd5f1`）

v2 benchmark 顯示 deliver-first 只達 50% — frontend agent 試 `npm install` 先沒推、qa agent commit 完忘 push。

修正：序列絕對化，agent 認領 issue 後**前 4 個 Bash 必須是** `fetch+rebase → checkout -b → empty commit → push + gh pr create --draft`。加環境噪音容忍規則 + 跨 lane race 規則。

#### P0+1+2+3 Helper scripts（commit `989d020`）

v3 仍有 25% PR 漏（ui-designer 跳 empty commit + 漏 gh pr create）。引入 4 個 helper script 把 deliver-first 4 步壓成 1 個 Bash call，結構性消除漏步：

| Script | 作用 |
|---|---|
| `deliver-first.sh` | 4 步合 1 個 Bash：fetch+rebase → 開 branch → empty commit → push + draft PR |
| `commit-progress.sh` | git add+commit+push 三合一（實作期間每次 commit 從 3 turn 省到 1） |
| `dispatch-impl.sh` | 為每 lane 建立 isolated demo clone（`/tmp/specflow-lane-clones/...-<lane>/`）杜絕 cross-lane working tree 污染 |
| `sweep-missing-prs.sh` | 掃所有 push 了但沒 PR 的 branch，自動補開 draft PR（從 commit message 抓 `#N` 推 issue） |

#### P5 Verify + retry + auto-sweep（commit `2a913ae`）

v4 benchmark 發現 `deliver-first.sh` 內部 `gh pr create` 偶發無效（手動同 args 跑卻成功）。修正：

- **`deliver-first.sh`**：加 explicit `--head <BRANCH> --base main` 避開 gh 自動偵測；PR 建立後**主動 verify**（不信 gh exit code），最多 retry 3 次中間 sleep 2s 防 GitHub API indexing race
- **`state.sh lane-close`**：寫完 state 後自動觸發 `sweep-missing-prs.sh` 兜底，lane drain 後不依賴 orchestrator 記得手動跑

### Benchmark 量測（請假系統 MVP，6 features，~90-100 AC）

| 維度 | v1 | v2 | v3 | v4 | v5 |
|---|---:|---:|---:|---:|---:|
| Total tokens | 541K | 498K | 508K | 512K | **497K** |
| 4-lane tokens | 369K | 376K | 344K | ~342K | 353K |
| WebSearch（tech-lead） | 2 | 0 | 1 | 0 | **0** |
| Branch pushed to remote | 3/4 | 3/4 | 4/4 | 4/4 | **4/4** |
| **Agent-driven PR open** | 0/4 | 2/4 | 3/4 | 2/4 | **4/4** ✅ |
| **PRs MERGED to main** | 0/4 | 0/4 | 0/4 | 0/4 | **2/4** 🎉 |
| End-to-end deliverable | 0/4 | 2/4 | 3/4 | 4/4 | **4/4** |
| Cross-lane 污染 | n/a | 0 | 1/4 | 0/4 | **0/4** |
| Token / Merged PR | ∞ | ∞ | ∞ | ∞ | **248K** |

**v5 是目前最佳狀態** — 第一次達成「agent 把 PR 從建立到 merge 端到端走完」。v1~v4 累積的修正路徑（O2 slim → P0 deliver-first → P0+ 絕對序列 → P0+1+2+3 helpers → P5 verify+retry + auto-sweep）疊起來把 reliability 從 0% PR 拉到 100% PR 開 + 50% PR merge，token 消耗持平於 v1。

### 關鍵設計原則（從 benchmark 累積出來的教訓）

1. **可靠度 > 省 token**：瘦身漏掉一條架構關鍵規則比不瘦身更糟。所有 hard gate（contract 三件套、frontend pixel-perfect、E2E workflow gate、sprint scope gate）的 bash 留在精簡 prompt **行內**，不移 kit
2. **frontmatter maxTurns 不是 hard limit**：v3 觀察到每個 agent 都跑過 frontmatter 設的上限，真正的 cap 來自 harness 端（~60-65 tool uses / 10 min wall-clock）
3. **保險帶比保險閘穩**：與其追求 100% helper 成功，不如保證「branch push + 安全網掃描」雙保險
4. **prompt 強度有極限**：v2→v3 把「立刻 commit」改成「絕對序列」只把可靠度從 50% → 75%；要繼續上靠的是「把流程壓成 1 個 script 讓 agent 不可能漏步」這種結構性手段
5. **multi-agent 共寫同 dir 是真實 race**：worktree 隔離只隔 agent 自己的工作空間；4 個 agent cd 到同一 demo dir 仍會互看 untracked 檔，需要 per-lane clone（不只 worktree）解

### 持續改進方向

- 觀察 `deliver-first.sh` retry 機制在實際使用中的命中率
- 把 sweep 接到 GitHub Actions 在 sprint workflow 失敗時也跑
- 抽 BENCHMARK-REPORT.md 的「演化」作 case study 給其他 multi-agent skill 開發者參考

---

## 授權

MIT
