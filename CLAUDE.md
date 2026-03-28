# SpecFlow - 自動化專案交付工作流

## 概述

使用者只需做兩件事：
1. **與 spec agent 對話** — 確認需求、技術偏好、sprint 規劃
2. **確認 release** — 每個 sprint 完成後確認發佈

## 角色分工

| 角色 | 職責 | 工作目錄 | 產出 |
|------|------|---------|------|
| **spec-writer** | 與使用者討論需求 | `specs/` | Epic + Sprint issues |
| **tech-lead** | 技術 survey + 開 issue 分配工作 | `specs/` | tech-survey.md + Feature/QA/Design issues |
| **ui-designer** | 建立可重用 UI component dataset | `design/` | Design tokens + 元件規格 + 範例 |
| **engineer** | 認領 feature / bug，寫程式 + unit test | `dev/` | PR（Closes #issue） |
| **qa-engineer** | 認領 QA issue，寫 e2e + browser test | `test/` | Test PR + Bug issues（附截圖） |
| **verifier** | 三維度驗證 sprint 交付品質 | `specs/` | 驗證報告 |

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
  │                 Sprint 完整測試（Release Gate）
  │                 docker compose up → unit + API + browser → test report
  │                       │
  │              ┌─ 失敗 → bug issue（附截圖）→ 修復 → 重測 ─┐
  │              └─ 通過 ↓                                   │
  │                 verifier（三維度驗證）                     │
  │                       │                                  │
  │              ┌─ FAIL → 修復 → 重驗 ──────────────────────┘
  │              └─ PASS → 通知使用者
  │
/specflow:release ──→ Release Gate → 關閉 milestone → 下一個 sprint
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

## 指令

| 指令 | 用途 | 使用者參與 |
|------|------|-----------|
| `/specflow:init` | 初始化 labels + templates | 首次一次 |
| `/specflow:start [主題]` | 啟動完整流程 | 對話確認 spec |
| `/specflow:verify` | 三維度驗證 sprint | 不需要 |
| `/specflow:release` | 確認 sprint release | 確認 |

## 前置工具

- [Docker](https://docs.docker.com/get-docker/) + [Docker Compose](https://docs.docker.com/compose/install/) — 本地部署 + release 前完整測試
- [agent-browser](https://github.com/vercel-labs/agent-browser) — `npm install -g agent-browser && agent-browser install`

## 語言

全程使用繁體中文。
