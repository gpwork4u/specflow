# SpecFlow - 自動化專案交付工作流

## 概述

使用者只需做兩件事：
1. **與 spec agent 對話** — 確認需求、API contract、技術架構、sprint 規劃
2. **確認 release** — 每個 sprint 完成後確認發佈

## 角色分工

| 角色 | 職責 | 產出 |
|------|------|------|
| **spec-writer** | 與使用者討論需求和架構 | `specs/` 目錄 + Epic + Sprint issues |
| **tech-lead** | 讀取 spec，分析依賴，開 issue | Feature issues + QA issue + `specs/dependencies.md` |
| **engineer** | 認領 feature / bug issue，發 PR | PR（Closes #issue） |
| **qa-engineer** | 認領 QA issue，寫 e2e test | Test PR + Bug issues |
| **verifier** | 三維度驗證 sprint 交付品質 | `specs/verify-sprint-{N}.md` |

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
  │              └─ PASS → 通知使用者
  │
/release ──→ 關閉 milestone → 自動推進下一個 sprint
```

## Source of Truth：`specs/` 目錄

```
specs/
├── overview.md                  # 專案概述 + 技術架構
├── dependencies.md              # 依賴圖譜（tech-lead 自動產生）
├── verify-sprint-{N}.md         # 驗證報告
├── features/
│   ├── f001-{name}.md           # Feature spec（含 WHEN/THEN scenarios）
│   └── f002-{name}.md
└── changes/                     # Delta 變更（跨 sprint 修改既有功能）
    ├── sprint-2-changes.md      # ADDED / MODIFIED / REMOVED
    └── archive/
```

## Scenario 格式（WHEN/THEN）

所有接受標準使用 scenario 格式，可直接轉為 test case：

```markdown
#### Scenario: 建立 resource 成功
GIVEN 使用者已登入
WHEN POST /api/v1/resource with { "field_a": "test" }
THEN response status = 201
AND response body matches { "id": any(string) }
```

## GitHub Issue 架構

```
Epic #1（索引 + 架構）
├── Sprint 1 #2
│   ├── Feature F-001 #3（engineer，含 scenarios）
│   ├── Feature F-002 #4（engineer，含 scenarios）
│   ├── QA Sprint 1 #5（qa，含 scenario 清單）
│   └── Bug #8（如有，engineer）
```

### Labels
| Label | 用途 |
|-------|------|
| `spec` | Spec 規格 |
| `epic` | Epic 總覽 |
| `sprint` | Sprint 追蹤 |
| `feature` | 功能需求（engineer 工作項目） |
| `qa` | QA 測試（qa 工作項目） |
| `bug` | Bug（engineer 工作項目） |

## 指令

| 指令 | 用途 | 使用者參與 |
|------|------|-----------|
| `/init` | 初始化 labels + templates | 首次一次 |
| `/start [主題]` | 啟動完整流程 | 對話確認 spec |
| `/verify` | 三維度驗證 sprint | 不需要 |
| `/release` | 確認 sprint release | 確認 |

## 語言

全程使用繁體中文。
