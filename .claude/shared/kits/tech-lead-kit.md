# tech-lead kit — 模板與 issue body（按需 Read，非常駐）

> tech-lead.md 在產出 survey / contract / 開 issue 時才 Read 本檔。

---

## 1. `specs/tech-survey.md` 範本

```markdown
# 技術選型調查報告

## 調查日期
{date}

## 1. 框架選型
### 候選方案
| 方案 | 版本 | Stars | 優點 | 缺點 | 適用場景 |
|------|------|-------|------|------|---------|
| Next.js | 14.x | 120k | SSR/SSG、生態豐富 | bundle 較大 | 全端應用 |
| Remix | 2.x | 28k | nested routes、web 標準 | 生態較小 | 表單密集 |
### 決策
選擇 **{framework}**，理由：{引用 survey 發現}

## 2. 資料庫選型 / 3. ORM / 4. UI 元件庫 / 5. 認證方案
（同上格式）

## 6. 其他 Library
| 用途 | 選擇 | 替代方案 | 選擇理由 |
|------|------|---------|---------|

## 7. 參考資料
- [連結] {標題}
```

WebSearch 範例主題：`Next.js 14 vs Remix vs Nuxt 2024`、`PostgreSQL vs MySQL {use case} benchmark`、`prisma vs drizzle vs typeorm`、`shadcn/ui vs radix comparison`、`{framework} auth best practices`、`{db} docker compose production`。

---

## 2. Infrastructure 生成（第二步 B）

讀 `specs/infra.md`（spec-writer 產出）+ tech-survey 選型，生成 `dev/docker-compose.example.yml` + `dev/.env.example`（基於實際選型，非通用範本）。**必含**：infra.md 列出的所有服務、每服務 health check、`depends_on` + `condition: service_healthy`、使用者指定 port mapping、volume 持久化。`.env.example` 含所有服務連線變數。

---

## 3. Contract 三件套範本

### contracts/api.md
```markdown
# API Contract
> 任何 lane 要新增/改 endpoint：先動此檔 → review → 再寫程式碼。Backend 是 owner。

## §1 Sent Records
### GET /api/sent
- Auth: Bearer token
- Query: `?limit=50&cursor={id}`
- Response 200: `{ "records": [...], "nextCursor": null }`
- Errors:
  | Status | code | 條件 |
  |--------|------|------|
  | 401 | UNAUTHORIZED | token 失效 |
  | 422 | INVALID_CURSOR | cursor 不存在 |
### POST /api/dev/inject-ws-event  （dev only — 標 @dev tag）
```

### contracts/dom.md
```markdown
# DOM Contract（testid + selector 慣例）
> 命名：kebab-case，scope-prefix-noun（`sent-record-card`，非 `card1`）。新元件先登記再開發。

## §1 SentRecordCard
- testid: `sent-record-card`
- 出現位置: `dev/src/pages/Sent/RecordList.tsx`
- 子元素 testid: `sent-record-card-status-badge`、`sent-record-card-approve-btn`

## §2 EmptyState
- testid: `empty-state` — 全域共用
```

### contracts/ux-text.md
```markdown
# UX Text Contract
> 所有面向使用者字串在此登記。frontend/qa 從 contracts.ts 讀，不 hardcode。

## §1 Toast
| key | 文字 | 觸發 |
|-----|------|------|
| saved | 已儲存 | PUT /api/* 成功 |
| approveSent | 已送出 | POST /api/sent/:id/approve 成功 |
| networkError | 網路錯誤 | fetch 失敗 |

## §2 Button labels
| key | 文字 | 出現位置 |
|-----|------|---------|
| save | 儲存 | 表單 submit |
| cancel | 取消 | Modal footer |
```

### specs/contracts.ts（frontend/backend/qa 共用 import）
```typescript
// 由 tech-lead 在 contract phase 維護
export const TESTIDS = {
  sentRecordCard: 'sent-record-card',
  sentRecordCardApproveBtn: 'sent-record-card-approve-btn',
  emptyState: 'empty-state',
} as const;
export const API_PATHS = {
  sentList: '/api/sent',
  sentApprove: (id: string) => `/api/sent/${id}/approve`,
} as const;
export const TOAST = { saved: '已儲存', approveSent: '已送出', networkError: '網路錯誤' } as const;
export const BUTTON = { save: '儲存', cancel: '取消' } as const;
```

用法：frontend `import { TESTIDS, TOAST, API_PATHS } from '../../specs/contracts'`；qa playwright 同樣 import；Go backend 用 codegen 或手寫 const 對齊 api.md。任一方改名 → TS 編譯失敗 / contract-check.sh 偵測，不會等到 e2e 才發現。

每個 feature/qa issue body 必加：
```
### Contracts
- API: specs/contracts/api.md §1
- DOM: specs/contracts/dom.md §1
- UX Text: specs/contracts/ux-text.md §1
- 共用 import: specs/contracts.ts (TESTIDS.sentRecordCard, TOAST.approveSent, API_PATHS.sentList)
```

---

## 4. `specs/dependencies.md` 範本

```markdown
# Sprint {N} 依賴圖譜

## 依賴關係
UI Design（元件庫）
├── F-002 (User Dashboard) ── 需要 UI 元件
F-001 (User Model)
├── F-002 (User CRUD)
└── F-003 (Auth)
F-004 (Product Model)  ── 無依賴

## 拓撲排序
### Wave 0（先行）: UI Design 元件庫, F-001 User Model
### Wave 1（Wave 0 完成後）: F-002, F-003, F-004
## QA: 與 Wave 0 同時開始撰寫 test script

## Contract owner
| Contract | Owner lane | 動到的話流程 |
|----------|-----------|-------------|
| api.md §1 | backend | 先發 backend PR 改 api.md + 實作 → merge → frontend/qa follow |
| dom.md §SentRecordCard | frontend | frontend 改 → qa 跟著改 step 引用 |
| ux-text.md §Toast | frontend | spec-writer 同步改 spec .md 中 AC 字串 assertion |
```

---

## 5. gh issue body 範本

### Feature Issue（engineer）
```bash
gh issue create --title "📝 [Feature] F-{編號}: {功能名稱}" \
  --label "feature,{backend|frontend|pipeline}" --milestone "{current_sprint}" --body "$(cat <<'BODY'
## 功能描述
{描述}

## 使用者故事
As a {角色}, I want {功能}, so that {價值}

## Spec 檔案（單一來源 — 不貼全文，按路徑讀）
- API Contract / Data Model / Acceptance Criteria 全文在 `specs/features/f{N}-{name}.md`
- 3 行摘要：{做什麼、關鍵 endpoint、AC 條數}
- engineer 確認每條 AC 都有對應實作；QA 把每條 AC 轉成一個 Playwright test()
- ⚠️ 勿在 issue body 貼 spec 全文（會被 engineer+QA+review+verifier 重複付費；spec .md 才是 SoT，貼進 issue 會漂移）

## 技術選型
見 `specs/tech-survey.md`

## Contracts（必填，引用 specs/contracts/）
- API: `specs/contracts/api.md §X`
- DOM: `specs/contracts/dom.md §X`
- UX Text: `specs/contracts/ux-text.md §X`
- Import 用：`specs/contracts.ts` → TESTIDS.xxx / TOAST.xxx / API_PATHS.xxx
- ⚠️ hardcoded path/testid/文字一律改成 import contracts.ts，contract-check.sh 會在 PR 阻擋

## Design Reference（frontend / design issue 必填）
- Local HTML: `specs/design-source/index.html`（讀本地，不要 WebFetch 線上）
- Section/元件: {grep keyword 或 anchor}
- Screenshot: `specs/design-source/screenshots/{page}.png`
- 頁面在 design 上的位置: {描述}
- ⚠️ Frontend pixel-perfect 還原；design 沒涵蓋的 hover/empty/error → 開 issue 標 `design-question`，不自行決定

## 實作指引
### 需建立檔案（dev/ 下）
- `dev/src/...`
### Unit Tests（dev/__tests__/ 下）
- `dev/__tests__/...`
### 關鍵邏輯
1. {描述}

## 依賴
- Wave: {n}　依賴：無 / #{other}
BODY
)"
```

### UI Design Issue（ui-designer）
```bash
gh issue create --title "🎨 [Design] Sprint {N} UI Components" --label "design" \
  --milestone "{current_sprint}" --body "$(cat <<'BODY'
## UI Design - Sprint {N}
### 設計範圍（本 sprint 需 UI 的功能）
- #{f2} F-002: {名稱}
### 需要的頁面/元件
**頁面**: [ ] {Page} — 對應 #{feature}
**共用元件**: [ ] Button variants / Form inputs / Data table / Modal / Toast / Navigation
### 設計系統要求
可重用、color/typography/spacing tokens、響應式 mobile-first、WCAG 2.1 AA
### Design Reference
- Local HTML: `specs/design-source/index.html`（不 WebFetch 線上）
- Screenshot: `specs/design-source/screenshots/`
### 技術限制
見 `specs/tech-survey.md` UI 元件庫選型
### 產出目錄: `design/`
### 相關: Sprint #{sprint_issue} / Epic #{epic}
BODY
)"
```

### QA Issue（qa-engineer）
```bash
gh issue create --title "🧪 [QA] Sprint {N} E2E Test" --label "qa" \
  --milestone "{current_sprint}" --body "$(cat <<'BODY'
## QA E2E Test - Sprint {N}
### 測試框架: 純 Playwright（@playwright/test，無 BDD / playwright-bdd / bddgen）
### 測試範圍
| Feature | Spec | AC 數 |
|---------|------|-------|
| F-{N}: {名稱} | `specs/features/f{N}-{name}.md` | {N} |
### 工作內容
1. 為 sprint plan 列出的每個 feature 建 `test/e2e/f{N}-{name}.spec.ts`
2. spec .md 每條 AC → 一個 `test('[Happy/Error/Edge] {AC 描述}', ...)`
3. 設定 `test/playwright.config.ts`（純 Playwright）
4. 從 `specs/contracts.ts` import TESTIDS/API_PATHS/TOAST，禁 hardcoded literal
5. 發 PR
### 撰寫重點
- API: HTTP methods、status/body/error codes、auth token（fixture 管理）
- UI（如有）: 導航、表單提交、文字/元素可見性（用 contracts.ts 字串）、URL 驗證
### 相關: Sprint #{sprint_issue} / Epic #{epic} / 依賴圖譜 `specs/dependencies.md`
BODY
)"
```

### Sprint Issue 更新 comment
```bash
gh issue comment {sprint_issue_number} --body "$(cat <<'BODY'
## 📋 Tech Lead 規劃完成
### 技術調查: 見 `specs/tech-survey.md`
### Feature Issues（Engineer）
- [ ] #{f1} F-001: {名稱}
### UI Design Issue: - [ ] #{design} Sprint {N} UI Components
### QA Issue: - [ ] #{qa} Sprint {N} E2E Test
### 依賴圖譜: 見 `specs/dependencies.md`
### 並行策略
Wave 0（先行）: #{design}, #{f1}（無 UI 依賴）, #{qa}（寫 test）
Wave 1（Wave 0 完成）: #{f2}, #{f3}
BODY
)"
```
