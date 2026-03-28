# SpecFlow - 自動化專案交付工作流

## 概述

使用者只需做兩件事：
1. **與 spec agent 對話** — 確認需求、API contract、技術架構、sprint 規劃
2. **確認 release** — 每個 sprint 完成後確認發佈

## 角色分工

| 角色 | 職責 | 工作目錄 | 產出 |
|------|------|---------|------|
| **spec-writer** | 與使用者討論需求和架構 | `specs/` | Epic + Sprint issues |
| **tech-lead** | 讀取 spec，分析依賴，開 issue | `specs/` | Feature + QA issues |
| **engineer** | 認領 feature / bug，寫程式 + unit test | `dev/` | PR（Closes #issue） |
| **qa-engineer** | 認領 QA issue，寫 e2e + browser test | `test/` | Test PR + Bug issues（附截圖） |
| **verifier** | 三維度驗證 sprint 交付品質 | `specs/` | 驗證報告 |

## 目錄分區

```
project/
├── dev/              ← 🔧 Engineer 專屬（程式碼 + unit tests）
│   ├── src/
│   └── __tests__/
├── test/             ← 🧪 QA 專屬（e2e + browser tests）
│   ├── e2e/
│   ├── browser/
│   └── screenshots/
├── specs/            ← 📖 Spec（spec-writer + tech-lead 管理）
│   ├── overview.md
│   ├── features/
│   ├── dependencies.md
│   └── changes/
```

**Engineer 不碰 `test/`，QA 不碰 `dev/`。**

## 流程

```
使用者操作              背景自動執行
──────────            ─────────────
/start 對話 ──→ spec-writer（前景互動）
  │                       │  產出：specs/ + Epic + Sprint issues
  │ 確認 spec            ▼
  │                 tech-lead（背景）
  │                       │  分析依賴 → 開 Feature + QA issues
  │                 ┌─────┴─────┐
  │                 ▼           ▼
  │           engineer ×N    qa-engineer        ← 同時啟動
  │           dev/ 實作      test/ 撰寫 e2e + browser test
  │           + unit test
  │           各自發 PR      發 test PR
  │                 └─────┬─────┘
  │                       ▼
  │                 執行 unit + e2e + browser tests
  │                       │
  │              ┌─ 失敗 → bug issue（附截圖）→ engineer 修復 → 重測 ─┐
  │              └─ 通過 ↓                                          │
  │                 verifier（三維度驗證）                            │
  │                       │                                         │
  │              ┌─ FAIL → bug issue → 修復 → 重驗 ─────────────────┘
  │              └─ PASS → 通知使用者
  │
/release ──→ 關閉 milestone → 自動推進下一個 sprint
```

## 測試分工

| 測試類型 | 負責角色 | 目錄 | 工具 |
|----------|---------|------|------|
| Unit Tests | Engineer | `dev/__tests__/` | test framework |
| API E2E Tests | QA | `test/e2e/` | test framework |
| Browser E2E Tests | QA | `test/browser/` | agent-browser |

## GitHub Issue 架構

```
Epic #1（索引 + 架構）
├── Sprint 1 #2
│   ├── Feature F-001 #3（engineer，含 scenarios）
│   ├── Feature F-002 #4（engineer，含 scenarios）
│   ├── QA Sprint 1 #5（qa，含 scenario 清單）
│   └── Bug #8（如有，附截圖，engineer）
```

### Labels
| Label | 用途 |
|-------|------|
| `spec` | Spec 規格 |
| `epic` | Epic 總覽 |
| `sprint` | Sprint 追蹤 |
| `feature` | 功能需求（engineer） |
| `qa` | QA 測試（qa） |
| `bug` | Bug（engineer） |

## 指令

| 指令 | 用途 | 使用者參與 |
|------|------|-----------|
| `/init` | 初始化 labels + templates | 首次一次 |
| `/start [主題]` | 啟動完整流程 | 對話確認 spec |
| `/verify` | 三維度驗證 sprint | 不需要 |
| `/release` | 確認 sprint release | 確認 |

## 前置工具

- [agent-browser](https://github.com/vercel-labs/agent-browser) — `npm install -g agent-browser && agent-browser install`

## 語言

全程使用繁體中文。
