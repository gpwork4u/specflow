# SpecFlow

基於 Claude Code 的自動化專案交付工作流。透過多個 AI agent 協作，將「需求討論 → 技術規劃 → 實作 → 測試」的完整流程自動化。

使用者只需要做兩件事：

1. 與 spec agent **對話確認需求**
2. 每個 sprint 完成後**確認 release**

其餘全部由 agent 背景自動完成。

---

## 前置需求

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) 已安裝
- [GitHub CLI (`gh`)](https://cli.github.com/) 已安裝並登入
- 目標 GitHub repo 已建立

## 快速開始

```bash
# 1. Clone 到你的專案目錄，或複製 .claude/ 資料夾到既有專案
cp -r .claude/ /path/to/your/project/.claude/

# 2. 進入專案，啟動 Claude Code
cd /path/to/your/project
claude

# 3. 初始化 GitHub labels 和 templates
/init

# 4. 開始！
/start 我的專案名稱
```

---

## 工作流程

```
使用者操作              背景自動執行
──────────            ─────────────
/start 對話 ──→ spec-writer（前景互動）
  │                       │  建立：Epic + Sprint issues
  │ 確認 spec            ▼
  │                 tech-lead（背景）
  │                       │  建立：Feature issues + QA issue
  │                 ┌─────┴─────┐
  │                 ▼           ▼
  │           engineer ×N    qa-engineer        ← 同時啟動
  │           認領 feature   認領 QA issue
  │           各自發 PR      撰寫 e2e test + 發 PR
  │                 └─────┬─────┘
  │                       ▼
  │                 執行 e2e tests
  │                       │
  │              ┌─ 失敗 → bug issue → engineer 修復 → 重測 ─┐
  │              └─ 通過 → 通知使用者                         │
  │                       ▲                                  │
  │                       └──────────────────────────────────┘
/release ──→ 關閉 milestone → 自動推進下一個 sprint
```

### Phase 詳細說明

| Phase | 做什麼 | 誰執行 | 使用者參與 |
|-------|--------|--------|-----------|
| 1. 初始化 | 建立 GitHub labels、issue templates | 自動 | 首次執行 `/init` |
| 2. Spec 討論 | 討論需求、API contract、技術架構、sprint 規劃 | spec-writer | **對話互動** |
| 3. 工作分配 | 讀取 spec，開 feature issue 給 engineer、QA issue 給 qa | tech-lead | 背景自動 |
| 4a. 實作 | 認領 feature issue，獨立分支開發，發 PR（`Closes #issue`） | engineer ×N | 背景並行 |
| 4b. 測試撰寫 | 根據 API contract 撰寫 e2e test script，發 PR | qa-engineer | 背景同步 |
| 5. 測試驗證 | 執行 e2e tests，通過則完成，失敗建 bug issue | qa-engineer | 背景自動 |
| 5.5 Bug 修復 | 認領 bug issue，修復，發 PR，QA 重新驗證 | engineer | 背景自動 |
| 6. Release | 確認 sprint 交付，關閉 milestone，推進下一 sprint | 自動 | **確認 release** |

---

## Agent 角色

### spec-writer — 產品規格專家

與使用者互動討論需求，產出的 spec 包含：
- 技術架構（語言、框架、資料庫、部署）
- 每個功能的完整 API contract（endpoint、request/response schema、error codes）
- Data model 定義
- 接受標準與測試場景（讓 QA 可同步寫測試）

**建立的 Issue**：Epic（含完整規格）、Sprint（追蹤進度）

### tech-lead — 技術主管

讀取 spec，分析依賴關係，為 engineer 和 QA 開出工作 issue：
- Feature issue — 含 API contract + 實作指引（要建立/修改的檔案、關鍵邏輯）
- QA issue — 含測試範圍 + test case 清單

**建立的 Issue**：Feature（給 engineer）、QA（給 qa-engineer）

### engineer — 軟體工程師

認領 feature 或 bug issue，在獨立分支上實作，完成後發 PR 連結 issue。多個 engineer agent 可背景並行處理不同 feature。

**每個 engineer 獨立運作**：
- 獨立 git worktree（避免衝突）
- 獨立分支（`feature/{issue}-xxx` 或 `fix/{issue}-xxx`）
- PR 使用 `Closes #{issue}` 自動關閉對應 issue

### qa-engineer — QA 工程師

認領 QA issue，根據 feature issue 的 API contract 撰寫 e2e test script **程式碼**（不是文件）。與 engineer 同時啟動，不需要等實作完成。

**工作流程**：
1. 根據 spec 撰寫 test script → 發 PR
2. Engineer 完成後執行測試
3. 失敗 → 建 bug issue → engineer 修復 → 重測

---

## GitHub Issue 架構

### 層級關係

透過 issue body 中的 task list（`- [ ] #issue`）串連層級：

```
Epic #1（spec + 架構 + 所有功能規格）
├── Sprint 1 #2（sprint 追蹤）
│   ├── Feature F-001 #3（engineer 認領）
│   ├── Feature F-002 #4（engineer 認領）
│   ├── QA Sprint 1 #5（qa-engineer 認領）
│   └── Bug #8（如有，engineer 認領）
├── Sprint 2 #6
│   ├── Feature F-003 #7
│   ├── QA Sprint 2 #9
│   └── ...
```

### Issue 類型

| 類型 | 標題格式 | Label | 建立者 | 執行者 |
|------|---------|-------|--------|--------|
| Epic | `📋 [Spec] 專案 - 總覽` | `spec`, `epic` | spec-writer | — |
| Sprint | `🏃 [Sprint N] 目標` | `sprint` | spec-writer | — |
| Feature | `📝 [Feature] F-XXX: 名稱` | `feature` | tech-lead | engineer |
| QA | `🧪 [QA] Sprint N E2E Test` | `qa` | tech-lead | qa-engineer |
| Bug | `🐛 [Bug] 描述` | `bug` | qa-engineer | engineer |

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

### Milestones

每個 Sprint 對應一個 GitHub Milestone。所有 agent 只處理當前 sprint milestone 下的 issues。

---

## 指令

### 主要指令

| 指令 | 說明 | 使用者參與 |
|------|------|-----------|
| `/init` | 初始化 GitHub repo 的 labels 和 issue templates | 首次執行一次 |
| `/start [主題]` | 啟動完整流程：spec 對話 → 自動到底 | 對話確認 spec |
| `/release` | 確認當前 sprint release，自動推進下一個 | 確認發佈 |

### 進階指令（個別階段控制）

| 指令 | 說明 |
|------|------|
| `/spec [主題]` | 僅啟動 spec 討論 |
| `/plan` | 僅啟動 tech-lead 開 issue |
| `/implement [issue#]` | 僅啟動 engineer + qa 並行實作 |
| `/qa` | 僅啟動 QA 撰寫 test |

一般情況下只需要 `/start` 和 `/release`，進階指令用於需要單獨控制某個階段時。

---

## 通訊機制

所有 agent 之間的溝通**完全透過 GitHub Issues 和 PR**：

```
spec-writer ──建立──→ Epic issue（完整規格）
                          │
tech-lead ───讀取────────┘
     │
     ├──建立──→ Feature issue ──→ engineer 認領 ──→ PR（Closes #feature）
     │
     └──建立──→ QA issue ──→ qa-engineer 認領 ──→ test PR
                                                      │
                                                  執行測試
                                                      │
                                              失敗 → Bug issue ──→ engineer 認領 ──→ fix PR（Closes #bug）
```

### 為什麼用 GitHub Issues？

- **可追溯**：每個 PR 連結回 issue，issue 連結回 spec
- **可見性**：所有工作進度在 GitHub 上一目了然
- **解耦**：agent 之間不直接通訊，透過 issue 非同步協作
- **人類可介入**：任何時候使用者都可以直接在 issue 上留言、修改、關閉

---

## 並行執行策略

Tech Lead 分析 feature 間的依賴關係後，engineer agents 採用 wave-based 並行：

```
Wave 1（無依賴）：Feature A, Feature B, QA ── 全部同時啟動
                         │
Wave 2（有依賴）：Feature C（依賴 A）── 等 Wave 1 完成後啟動
```

每個 engineer agent 運行在獨立的 git worktree 中，互不干擾。

---

## 目錄結構

```
your-project/
├── .claude/
│   ├── agents/                  # Agent 定義
│   │   ├── spec-writer.md       # 產品規格專家
│   │   ├── tech-lead.md         # 技術主管
│   │   ├── engineer.md          # 軟體工程師
│   │   └── qa-engineer.md       # QA 工程師
│   ├── skills/                  # Skill 定義（使用者可呼叫的指令）
│   │   ├── init/SKILL.md        # /init
│   │   ├── start/SKILL.md       # /start
│   │   ├── release/SKILL.md     # /release
│   │   ├── spec/SKILL.md        # /spec
│   │   ├── plan/SKILL.md        # /plan
│   │   ├── implement/SKILL.md   # /implement
│   │   └── qa/SKILL.md          # /qa
│   └── scripts/
│       └── init-github.sh       # GitHub 初始化腳本
├── .github/                     # （/init 建立）
│   ├── ISSUE_TEMPLATE/
│   │   ├── feature.yml
│   │   └── bug.yml
│   └── PULL_REQUEST_TEMPLATE.md
├── CLAUDE.md                    # 專案指令（Claude Code 自動讀取）
└── README.md
```

---

## 自訂與擴展

### 調整 Agent 行為

編輯 `.claude/agents/*.md` 中的 prompt 內容：
- 修改 `model` 欄位切換模型（opus / sonnet / haiku）
- 修改 `maxTurns` 調整 agent 最大執行輪數
- 修改 `tools` 限制可用工具
- 修改 prompt 中的模板格式調整 issue / PR 的內容結構

### 調整 Labels

編輯 `.claude/scripts/init-github.sh` 中的 `LABELS` 陣列，新增或修改 label。

### 新增 Skill

在 `.claude/skills/{skill-name}/SKILL.md` 建立新的 skill 檔案，即可用 `/{skill-name}` 呼叫。

---

## 授權

MIT
