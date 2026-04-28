# SpecFlow - 自動化專案交付工作流

## 概述

使用者只需做兩件事：
1. **與 spec agent 對話** — 確認需求、技術偏好、sprint 規劃
2. **確認 release** — 每個 sprint 完成後確認發佈

## 角色分工

| 角色 | 職責 | 工作目錄 | 產出 | Model |
|------|------|---------|------|-------|
| **spec-writer** | 與使用者討論需求 | `specs/` | Epic + Sprint issues | opus |
| **tech-lead** | 技術 survey + 開 issue 分配工作 | `specs/` | tech-survey.md + Feature/QA/Design issues | opus |
| **ui-designer** | 建立可重用 UI component dataset | `design/` | Design tokens + 元件規格 + 範例 | sonnet |
| **engineer** | 認領 feature / bug，寫程式 + unit test（分 backend / frontend / pipeline 三個 lane，每 lane 1 個）| `dev/` | PR（Closes #issue） | sonnet |
| **qa-engineer** | 認領 QA issue，撰寫 playwright-bdd step definitions | `test/` | Step Definitions PR + Bug issues（附截圖） | sonnet |
| **code-review** | 審查 PR 品質、spec 一致性、安全性 | 唯讀 | PR Review（approve / request changes） | sonnet |
| **verifier** | 三維度驗證（以 .feature + Cucumber report 為基準） | `specs/` | 驗證報告 | sonnet |

> **Model 配置原則**：spec-writer 與 tech-lead 用 opus（前者要互動釐清需求、後者要做技術選型與架構決策，影響整個 sprint 的方向）；engineer 寫程式、qa 寫測試、ui-designer、verifier、code-review 用 sonnet（已有清楚 spec/scenario 可循的結構化工作）。整體 token 成本約節省 60-65%。

## 目錄分區

```
project/
├── design/           ← 🎨 UI Designer 專屬（tokens + 元件規格）
│   ├── tokens/
│   ├── components/
│   ├── pages/
│   └── assets/
├── dev/              ← 🔧 Engineer 專屬（程式碼 + unit tests）
│   ├── src/
│   └── __tests__/
├── test/             ← 🧪 QA 專屬（playwright-bdd BDD tests）
│   ├── features/          ← .feature 檔案（從 specs/ 複製）
│   ├── steps/             ← Step definitions（Given/When/Then 實作）
│   ├── support/           ← Hooks, fixtures, helpers
│   ├── playwright.config.ts
│   ├── screenshots/
│   └── reports/
├── specs/            ← 📖 Spec + Tech Survey + Gherkin 場景
│   ├── overview.md
│   ├── tech-survey.md
│   ├── features/          ← .md（API contract）+ .feature（Gherkin 場景）
│   ├── dependencies.md
│   ├── logs/              ← Sprint 工作日誌
│   └── changes/
```

**各角色只動自己的目錄。**

## 流程

```
使用者操作              背景自動執行
──────────            ─────────────
/specflow:start ──→ spec-writer（前景互動，選擇題提問）
  │                       │  產出：specs/ + Epic + Sprint issues
  │ 確認 spec            ▼
  │                 tech-lead（背景）
  │                       │  上網 survey → tech-survey.md
  │                       │  開 Feature + QA + Design issues
  │                 ┌─────┼─────┐
  │                 ▼     ▼     ▼
  │           engineer  qa    ui-designer   ← 同時啟動
  │           dev/實作  test/ design/元件
  │                 └─────┬─────┘
  │                       ▼
  │                 code-review（sonnet，每個 PR 自動審查）
  │                       │
  │              ┌─ REQUEST_CHANGES → engineer 修改 → 重新 review（最多 3 輪）
  │              └─ APPROVED ↓
  │                 merge PR（需 1 approval + conversations resolved）
  │                       ▼
  │                 Sprint BDD 測試（自動觸發 via GitHub Actions）
  │                 docker compose up → unit + playwright-bdd → test report
  │                       │
  │              ┌─ 失敗 → bug issue（附截圖）→ 修復 → 重測 ─┐
  │              └─ 通過 ↓                                   │
  │                 verifier（三維度驗證）                     │
  │                       │                                  │
  │              ┌─ FAIL → 修復 → 重驗 ──────────────────────┘
  │              └─ PASS ↓
  │                 自動產出工作日誌 → 關閉 milestone
  │                       │
  │                 ┌─ 有下一個 sprint → 自動啟動
  │                 └─ 全部完成 → 通知使用者
  │
/specflow:release ──→ 部署 production（使用者確認後執行）
```

## GitHub Issue 架構

```
Epic #1（索引 + 需求）
├── Sprint 1 #2
│   ├── Feature F-001 #3（engineer）
│   ├── Feature F-002 #4（engineer）
│   ├── Design Sprint 1 #5（ui-designer）
│   ├── QA Sprint 1 #6（qa-engineer）
│   └── Bug #9（如有，附截圖）
```

### Labels
| Label | 用途 |
|-------|------|
| `spec` | Spec 規格 |
| `epic` | Epic 總覽 |
| `sprint` | Sprint 追蹤 |
| `feature` | 功能需求（engineer） |
| `design` | UI 設計（ui-designer） |
| `qa` | QA 測試（qa-engineer） |
| `bug` | Bug（engineer） |
| `code-review` | Code Review |
| `change` | Change Request（既有專案新需求） |
| `backend` | Backend lane（與 feature/bug 並用） |
| `frontend` | Frontend lane（與 feature/bug 並用） |
| `pipeline` | Pipeline / DevOps lane（與 feature/bug 並用） |

## 指令

| 指令 | 用途 | 使用者參與 |
|------|------|-----------|
| `/specflow:init` | 初始化 labels + templates | 首次一次 |
| `/specflow:doctor` | 環境工具檢查 | 缺工具時引導安裝 |
| `/specflow:start [主題]` | 啟動完整流程 | 對話確認 spec |
| `/specflow:resume` | 從 .specflow/state.json 接續上次中斷處 | 不需要 |
| `/specflow:change [描述]` | 已完成專案新增 Change Request | 對話確認影響範圍 |
| `/specflow:verify` | 三維度驗證 sprint | 不需要（自動） |
| `/specflow:release` | 部署 production | 確認部署 |

## Lane 制（同類型 agent 同時最多 1 個）

每個 sprint 同時最多 5 個 background agent 在跑：

| Lane | Agent | 同時數 | Issue label |
|------|-------|--------|-------------|
| backend | engineer | 1 | `feature,backend` 或 `bug,backend` |
| frontend | engineer | 1 | `feature,frontend` 或 `bug,frontend` |
| pipeline | engineer | 1 | `feature,pipeline` 或 `bug,pipeline` |
| qa | qa-engineer | 1 | `qa` |
| ui | ui-designer | 1 | `design` |

每個 agent 在自己 lane 內 loop：認領未 assigned 的 issue → 實作 → PR → 認領下一個直到 lane 清空。

**為什麼 lane 制**：
- 避免多個同類 agent 在同一 worktree / 同一目錄改檔的 race condition
- 控制 token 消耗（同類 issue 共用 context cache）
- 簡化 merge 順序（同 lane 循序，不同 lane 並行）

**Tech-lead 必須給每個 feature/bug issue 標 lane**（backend / frontend / pipeline 三選一）。混合性質的 feature 拆成兩個 issue 分屬不同 lane。

## Resumability（context 中斷後接續）

所有持久狀態都在兩個地方：
- **GitHub Issues / Milestones / PRs**（source of truth）
- **`.specflow/state.json`**（local cache，記錄當前 phase + in-flight agents）

對話 context 不是狀態。被 `/clear` 或關掉 session 後，`/specflow:resume` 會從 state.json + GitHub 重建狀態繼續執行。

## Change Request（已完成專案的新需求）

Release 後若要新增/修改功能：
- `/specflow:change [描述]` — spec-writer 評估影響、append 新 scenario 到既有 .feature（既有 scenario 自動變回歸測試）、建立新 sprint milestone，後續走標準流程
- 既有 scenario 不刪，要 deprecate 用 `@deprecated` Gherkin tag 標記

## 自動測試（BDD 驅動）

Spec-writer 產出 Gherkin `.feature` 檔案 → QA 撰寫 step definitions → playwright-bdd 將場景轉為 Playwright tests。

**兩層 CI 測試**：
1. `pr-test.yml` — PR 開啟/推 commit 時，跑該 PR 涉及的 feature 子集（fail-fast）
2. `sprint-test.yml` — sprint 內所有 feature/design/bug issue 關閉後，跑完整 BDD（Coverage check 強制 = `specs/features/` 內所有 scenario 都被執行）

**本機與 CI 共用同一份腳本** `.claude/scripts/run-sprint-tests.sh`：
- 啟動 docker → unit tests → 同步 .feature → bddgen → playwright test → coverage check
- 環境變數 `SKIP_DOCKER=1` 可跳過 docker（服務已在跑時用）
- 任一階段失敗 exit 非 0，不再 `continue-on-error` 讓 PR 假性通過

**每個 sprint 結束時，.feature 檔案中的所有場景都必須通過 = 功能驗證完成。**

## 前置工具

- [Docker](https://docs.docker.com/get-docker/) + [Docker Compose](https://docs.docker.com/compose/install/) — 本地部署 + CI 測試
- [Playwright](https://playwright.dev/) — `npm install -D @playwright/test && npx playwright install`
- [playwright-bdd](https://vitalets.github.io/playwright-bdd/) — `npm install -D playwright-bdd @cucumber/cucumber`

## 語言

全程使用繁體中文。
