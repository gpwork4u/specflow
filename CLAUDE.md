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
| **ui-designer** | 建立可重用 UI component dataset | `design/` | Design tokens + 元件規格 + 範例 | opus |
| **engineer** | 認領 feature / bug，寫程式 + unit test | `dev/` | PR（Closes #issue） | opus |
| **qa-engineer** | 認領 QA issue，寫 e2e + browser test | `test/` | Test PR + Bug issues（附截圖） | opus |
| **code-review** | 審查 PR 品質、spec 一致性、安全性 | 唯讀 | PR Review（approve / request changes） | sonnet |
| **verifier** | 三維度驗證 sprint 交付品質 | `specs/` | 驗證報告 | opus |

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
├── test/             ← 🧪 QA 專屬（e2e + browser tests）
│   ├── e2e/
│   ├── browser/
│   └── screenshots/
├── specs/            ← 📖 Spec + Tech Survey
│   ├── overview.md
│   ├── tech-survey.md
│   ├── features/
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
  │                 Sprint 完整測試（自動觸發 via GitHub Actions）
  │                 docker compose up → unit + API + browser → test report
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

## 指令

| 指令 | 用途 | 使用者參與 |
|------|------|-----------|
| `/specflow:init` | 初始化 labels + templates | 首次一次 |
| `/specflow:start [主題]` | 啟動完整流程 | 對話確認 spec |
| `/specflow:verify` | 三維度驗證 sprint | 不需要（自動） |
| `/specflow:release` | 部署 production | 確認部署 |

## 自動測試

當 sprint 的所有 feature/design PR merge 到 main 後，**GitHub Actions 自動執行**：
1. docker compose up（從 example 建立）
2. Unit tests → API E2E tests → Browser tests
3. 產出 test report（commit 到 `test/reports/`）
4. 結果自動回報到 QA issue 和 Sprint issue

不需要手動觸發。

## 前置工具

- [Docker](https://docs.docker.com/get-docker/) + [Docker Compose](https://docs.docker.com/compose/install/) — 本地部署 + CI 測試
- [Playwright](https://playwright.dev/) — `npm install -D @playwright/test && npx playwright install`

## 語言

全程使用繁體中文。
