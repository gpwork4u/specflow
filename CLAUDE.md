# SpecFlow - 自動化專案交付工作流

## 概述

使用者只需做三件事：
1. **在 [Claude design](https://claude.ai/design) 完成 UI 設計**，把網址交給 spec agent
2. **與 spec agent 對話** — 補齊 design 看不到的部份（backend / data / 業務邏輯），規劃 sprint
3. **確認 release** — 每個 sprint 完成後確認發佈

> 純 backend / API 專案可跳過 step 1，spec agent 走傳統討論模式。

## 角色分工

| 角色 | 職責 | 工作目錄 | 產出 | Model |
|------|------|---------|------|-------|
| **spec-writer** | 從 Claude design URL 反推需求，補齊 backend / data / 業務邏輯 | `specs/` | design-source.md + Epic + Sprint issues | opus |
| **tech-lead** | 技術 survey + Contract 三件套 + 開 issue 分配工作 | `specs/` | tech-survey.md + contracts/ + Feature/QA/Design issues | opus |
| **ui-designer** | 從 Claude design URL 抽 design tokens + 元件 + 字串清單（不從零設計） | `design/` | Design tokens + 元件 handoff + 字串 handoff | sonnet |
| **engineer** | 認領 feature / bug，寫程式 + unit test（分 backend / frontend / pipeline 三個 lane，每 lane 1 個）| `dev/` | PR（Closes #issue） | sonnet |
| **qa-engineer** | 認領 QA issue，撰寫 Playwright e2e tests（純 Playwright，無 BDD） | `test/` | e2e tests PR + Bug issues（附截圖） | sonnet |
| **code-review** | Sprint 結束時對整個 sprint 做一次全面審查（contract 對齊 / spec 一致性 / 安全性 / 跨 lane） | 唯讀 | `sprint-N-review.md` + CRITICAL bug issues | sonnet |
| **verifier** | 三維度驗證（以 spec acceptance criteria + Playwright report 為基準） | `specs/` | 驗證報告 | sonnet |

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
├── test/             ← 🧪 QA 專屬（純 Playwright e2e tests）
│   ├── e2e/               ← Playwright .spec.ts（檔名 fNNN-*.spec.ts 對應 feature）
│   ├── support/           ← Hooks, fixtures, helpers
│   ├── playwright.config.ts
│   ├── screenshots/
│   └── reports/
├── specs/            ← 📖 Spec + Tech Survey + Acceptance Criteria + Contracts
│   ├── design-source.md   ← 🎨 元數據（URL + last-synced timestamp）
│   ├── design-source/     ← 🎨 本地 design 快照（sync-design.sh 下載）
│   │   ├── index.html         ← design HTML 全文
│   │   ├── screenshots/       ← 頁面截圖（pixel 對照用）
│   │   └── assets/            ← 圖片 / icon
│   ├── overview.md
│   ├── tech-survey.md
│   ├── sprints/           ← 每個 sprint 的 feature ID 清單（決定 e2e scope）
│   ├── features/          ← .md（API contract + data model + acceptance criteria）
│   ├── contracts/         ← 🔒 Single source of truth (tech-lead 維護)
│   │   ├── api.md         ← path / method / schema
│   │   ├── dom.md         ← testid / selector（從 design-source 抽出）
│   │   └── ux-text.md     ← toast / label / button 文字（從 design-source 抽出）
│   ├── contracts.ts       ← 上述三個檔的 TS export，frontend/qa/backend 共用 import
│   ├── dependencies.md
│   ├── logs/              ← Sprint 工作日誌
│   └── changes/
```

**各角色只動自己的目錄。**

## 流程

```
使用者操作                       背景自動執行
──────────                     ─────────────
[在 Claude design 完成 UI 設計]
  │ 提供設計稿 URL
  ▼
/specflow:start ──→ spec-writer（前景互動）
  │                       │  WebFetch design URL → specs/design-source.md
  │                       │  反推 spec + 補齊 backend/data/業務邏輯（AskUserQuestion）
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
  │                       │  每個 PR：CI build-and-lint 過 → auto-merge（無 per-PR review）
  │                       ▼
  │                 4 lane drain（feature/design/qa/bug 全關）
  │                       ▼
  │                 Sprint e2e 測試（本地跑，不在 CI）
  │                 docker compose up → playwright → playwright report
  │                       │
  │              ┌─ 失敗 → bug issue（附截圖）→ 修復 → 重測 ─┐
  │              └─ 通過 ↓                                   │
  │                 sprint code review（一次性全面審查）       │
  │                       │                                  │
  │              ┌─ CRITICAL → 建 bug issue → 重啟 lane ─────┤
  │              └─ PASS / WARNING ↓                         │
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
| `/specflow:update` | 升級 SpecFlow 到 upstream 最新版（含本地自訂偵測 + state.json migration） | 確認衝突處理策略 |

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
- `/specflow:change [描述]` — spec-writer 評估影響、append 新 AC 到既有 spec .md（既有 AC 對應的 e2e tests 自動變回歸測試）、建立新 sprint milestone，後續走標準流程
- 既有 AC 不刪，要 deprecate 用刪除線 `~~AC-X~~` + comment 標記

## 自動測試（純 Playwright，無 BDD）

Spec-writer 在 `specs/features/*.md` 寫 acceptance criteria 條列 → QA 把每條 AC 轉成一個 Playwright `test()` 寫在 `test/e2e/fNNN-*.spec.ts`。

**Unit / contract 在本地（push 前），e2e 在 CI（sprint 收斂時）。**

### CI（GitHub Actions）兩個 workflow

1. **`pr-test.yml` — build-and-lint**（每個 PR）
   - `dev/` 能 `tsc --noEmit` / `npm run build` / `go build ./...` 過
   - `test/` 能 `tsc --noEmit` 過
   - linter 沒紅
   - 只擋「連編譯都過不了」的 PR

2. **`sprint-test.yml` — Sprint E2E Test**（4 lane 全關時）
   - 觸發：`issues.closed` 事件，gate 檢查 `feature/design/qa/bug` 4 個 label 都沒有 open issue 才跑
   - 跑 `bash .claude/scripts/run-sprint-tests.sh all`（docker compose + playwright + report）
   - Artifacts（playwright trace / 截圖 / report）保留 30 天在 actions run
   - 失敗 → 自動建 bug issue（label 從失敗 test 推 lane）→ engineer 修 → 關 bug → workflow 自動再次觸發

### 本地（agent 在 push 前必跑）

`bash .claude/scripts/local-checks.sh`（engineer / qa agent 在 push 前的強制 gate）：
- `unit` — `dev/` 的 unit tests
- `contract` — grep-based hardcoded testid / api / toast 文字檢查

任一失敗，agent 不准 push。E2E **不在這裡跑**，留給 sprint-test.yml。

### Verifier hard gate

verifier 啟動前讀最近一次「Sprint E2E Test」workflow 的 conclusion（不是 state.json — workflow result 是真理）。沒 success 就 short-circuit。

### 測試完自動清理

每次 `run-sprint-tests.sh` 結束（trap EXIT）：
- **成功** → `docker compose down -v --remove-orphans` + 清 `test/test-results` `screenshots`（reports 留給 verifier）
- **失敗** → 只關 docker；保留 `test-results` `screenshots` `reports` 給人類 debug

`verifier` PASS 後：
- 把 `test/reports/playwright.{json,playwright-report/}` archive 到 `specs/logs/sprint-N-artifacts/`（入版控做歷史追溯）
- 跑 `local-checks.sh cleanup` 把 `test/` 全清，下個 sprint 從乾淨狀態起跑

手動清理：`bash .claude/scripts/local-checks.sh cleanup` — 把所有測試暫存（含 reports）歸零，docker 一併下架。debug 完不想留就跑這個。

### Sprint scope 規則

spec-writer 在 `specs/sprints/sprint-N.md` 列出該 sprint 涵蓋的 feature ID。沒列到的 feature 在 sprint-test 不會跑。

QA 寫 e2e tests **只實作當前 sprint scope，不能多做**：
- 只為 `specs/sprints/sprint-N.md` 列出的 feature 建立 `test/e2e/fNNN-*.spec.ts`
- 不為未來 sprint 預寫 e2e
- 不自行擴充 spec 沒寫的驗證項目
- support helpers 只放當前 sprint 已用到的

## Contract 三件套（避免 lane 之間互不對齊）

| 檔案 | 內容 | 誰用 | Owner |
|------|------|------|-------|
| `specs/contracts/api.md` | path / method / JSON schema / error codes | backend impl + frontend client + qa request mock | backend lane |
| `specs/contracts/dom.md` | testid 名稱 + 出現位置 + selector 慣例 | frontend component + qa selector | frontend lane |
| `specs/contracts/ux-text.md` | toast / label / button 文字 | frontend i18n + qa assertion | frontend lane（spec-writer 同步） |
| `specs/contracts.ts` | 上述三個檔案的 TS typed export | 所有 lane import | tech-lead 自動產出/維護 |

**規則**：
1. tech-lead 在 contract phase（spec → impl 之間）產出這三個檔案，沒寫完不開 issue
2. 任何 lane 動到 contract → 先發 PR 改 contract → owner approve → 其他 lane follow
3. `dev/` `test/` 內**禁止 hardcoded** path / testid / 中文字串 — 必須 import `specs/contracts.ts`
4. PR 時 `.claude/scripts/contract-check.sh` 會 grep diff 阻擋違規
5. **跨 lane endpoint 必須拆獨立 issue**（如 `WS-Refactor backend` 先做 + `WS-Refactor frontend` 後做），不允許混合 lane

**好處**：任一方改名 → TS 編譯失敗或 contract-check 紅燈，不會等到 e2e run 才發現「frontend 用 `userCard`、qa 找 `user-card`」這種對不上的問題。

**驗證閘門順序（不可跳級）**：
```
本地 local-checks.sh（unit + contract）通過
  ↓ push → CI build-and-lint 過 → auto-merge
四 lane 全關（feature/design/qa/bug）
  ↓ orchestrator 跑 local-checks.sh e2e
e2e 全綠 → state.sprint_test_outcome=success
  ↓ sprint code review（一次性全面審查）
review PASS
  ↓ verifier 三維度驗證
verifier PASS
  ↓ 自動產出 sprint log，可進 release
```

verifier 啟動前會先檢查 `state.json.sprint_test_outcome == "success"`，否則直接 short-circuit 並提示「修 e2e 再來」。

**本地測試腳本** `.claude/scripts/run-sprint-tests.sh`：
- 啟動 docker → unit tests → 從 sprint plan 解析 scope → playwright test → 結果摘要
- 環境變數 `SKIP_DOCKER=1` 可跳過 docker（服務已在跑時用）
- `SPRINT="Sprint N"` 決定要跑哪些 e2e（從 specs/sprints/sprint-N.md 讀 feature ID）
- 任一階段失敗 exit 非 0

**每個 sprint 結束時，sprint scope 內的 acceptance criteria 對應的 e2e tests 全部通過 = 功能驗證完成。**

## 前置工具

- [Docker](https://docs.docker.com/get-docker/) + [Docker Compose](https://docs.docker.com/compose/install/) — 本地部署 + 測試環境
- [Playwright](https://playwright.dev/) — `npm install -D @playwright/test && npx playwright install`

## 語言

全程使用繁體中文。
