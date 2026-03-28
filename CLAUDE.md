# SpecFlow - 自動化專案交付工作流

## 概述

使用者只需做兩件事：
1. **與 spec agent 對話** — 確認需求、API contract、技術架構、sprint 規劃
2. **確認 release** — 每個 sprint 完成後確認發佈

## 角色分工

| 角色 | 職責 | 建立的 Issue |
|------|------|-------------|
| **spec-writer** | 與使用者討論需求和架構 | Epic, Sprint |
| **tech-lead** | 讀取 spec，開 issue 分配工作 | Feature（給 engineer）, QA（給 qa） |
| **engineer** | 認領 feature / bug issue，發 PR | — |
| **qa-engineer** | 認領 QA issue，寫 e2e test，回報 bug | Bug |

## 流程

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

## GitHub Issue 架構

### 層級關係（透過 task list sub-tasks 串連）

```
Epic #1（spec + 架構 + 所有功能規格）
├── Sprint 1 #2
│   ├── Feature F-001 #3（engineer 認領）
│   ├── Feature F-002 #4（engineer 認領）
│   ├── QA Sprint 1 #5（qa 認領）
│   └── Bug #8（如有，engineer 認領）
├── Sprint 2 #6
│   ├── Feature F-003 #7
│   ├── QA Sprint 2 #9
│   └── ...
```

### Labels
| Label | 顏色 | 用途 |
|-------|------|------|
| `spec` | 綠 #0E8A16 | Spec 規格 |
| `epic` | 深藍 #3E4B9E | Epic 總覽 |
| `sprint` | 淺藍 #C5DEF5 | Sprint 追蹤 |
| `feature` | 藍 #1D76DB | 功能需求（engineer 工作項目） |
| `qa` | 紫 #D876E3 | QA 測試（qa 工作項目） |
| `bug` | 紅 #B60205 | Bug（engineer 工作項目） |
| `blocked` | 黃綠 #E4E669 | 被阻塞 |
| `in-progress` | 藍 #0075CA | 進行中 |
| `ready-for-review` | 紫 #7057FF | 等待 Review |
| `ready-for-qa` | 紫 #D876E3 | 等待 QA 驗證 |

### Milestones
每個 Sprint 一個 Milestone。所有 agent 只處理當前 sprint。

## 指令

| 指令 | 用途 | 使用者參與 |
|------|------|-----------|
| `/init` | 初始化 labels + templates | 首次一次 |
| `/start [主題]` | 啟動完整流程 | 對話確認 spec |
| `/release` | 確認 sprint release | 確認 |

## 語言

全程使用繁體中文。
