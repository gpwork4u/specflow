# spec-writer kit — 模板與發佈指令（按需 Read，非常駐）

> spec-writer.md 在需要產出檔案/發佈時才 Read 本檔。AskUserQuestion 完整規範見 `.claude/shared/question-ui.md`。

---

## 1. Feature Spec 檔案格式（`specs/features/f{NNN}-{name}.md`）

```markdown
# F-{編號}: {功能名稱}

## Status: active
## Sprint: 1
## Priority: P0

## 使用者故事
As a {角色}, I want {功能}, so that {價值}

## API Contract

### `POST /api/v1/resource`
Auth：Bearer token

Request Body:
| Field | Type | Required | Constraints |
|-------|------|----------|-------------|
| field_a | string | yes | max 100 chars |
| field_b | integer | no | >= 0, default 0 |

Response 201:
```json
{ "id": "uuid", "field_a": "string", "created_at": "ISO 8601" }
```

Error Responses:
| Status | Code | Condition |
|--------|------|-----------|
| 400 | INVALID_INPUT | field_a 為空或超過 100 字 |
| 401 | UNAUTHORIZED | token 無效或缺失 |
| 409 | DUPLICATE | field_a 已存在（大小寫不敏感）|

## Data Model

```
Resource {
  id: UUID (PK, auto-generated)
  field_a: VARCHAR(100) NOT NULL UNIQUE
  field_b: INTEGER DEFAULT 0 CHECK (field_b >= 0)
  created_at: TIMESTAMP NOT NULL DEFAULT NOW()
  updated_at: TIMESTAMP NOT NULL DEFAULT NOW()
}
```

## Business Rules
1. field_a 不可重複，大小寫不敏感
2. field_b 必須 >= 0
3. 刪除為 soft delete

## Acceptance Criteria

### Happy Path
- [ ] AC-1: 已登入使用者用合法 payload 呼叫 `POST /api/v1/resource`，回 201 + 帶 id 的物件
- [ ] AC-2: 同使用者 `GET /api/v1/resource` 可拿回剛建立的 resource

### Error Handling
- [ ] AC-3: 未登入呼叫回 401 / `UNAUTHORIZED`
- [ ] AC-4: field_a 為空字串回 400 / `INVALID_INPUT`

### Edge Cases
- [ ] AC-5: field_a 剛好 100 字 → 過（201）
- [ ] AC-6: field_a 含特殊字元（emoji / 空白 / SQL keyword）→ 不影響建立

QA 會將每條 AC 轉成一個 Playwright `test()` 在 `test/e2e/f{NNN}-{name}.spec.ts`。
```

規範：每 feature 一檔；AC 用 checkbox + ID（AC-N）；至少 Happy + Error + Edge 三類；AC 具體可測（「response code 為 'OK'」而非「含 success」）；面向使用者字串用 `{TOAST.xxx}`/`{TESTIDS.xxx}` placeholder。

---

## 2. Infrastructure 設定檔（`specs/infra.md`）

```markdown
# Infrastructure 設定

## 開發環境模式
Docker Compose 全包 / 混合模式 / 全本機 / 自有環境

## 服務配置
| 服務 | Image | Port（Host） | Port（Container） | 備註 |
|------|-------|-------------|-------------------|------|
| app | build from Dockerfile | 3000 | 3000 | |
| db | postgres:16-alpine | 5432 | 5432 | |
| redis | redis:7-alpine | 6379 | 6379 | 選配 |

## Port 衝突
- 無 / {使用者指定的調整}

## 環境變數
| 變數 | 預設值 | 說明 |
|------|--------|------|
| DATABASE_URL | postgresql://user:pass@db:5432/app | DB 連線 |
| REDIS_URL | redis://redis:6379 | Redis（如有）|
| APP_PORT | 3000 | App 服務 port |
| NODE_ENV | development | 環境模式 |

## Health Check
- App: `GET http://localhost:{APP_PORT}/health`
- DB: `pg_isready` / `mysqladmin ping`

## 使用者備註
{特殊需求：已有外部 DB、需要 VPN 等}
```

---

## 3. Delta 變更格式（跨 Sprint 修改既有功能，`specs/changes/sprint-N-changes.md`）

```markdown
# Sprint 2 Changes

## MODIFIED: F-001 Resource 管理
### API Contract Changes
- ADDED endpoint: `PATCH /api/v1/resource/:id` for partial update
- MODIFIED `POST /api/v1/resource`: added optional field `field_c`
### Data Model Changes
- ADDED field: `field_c: VARCHAR(50) NULL`
### New Acceptance Criteria（追加到 specs/features/f001-*.md，不刪舊 AC）
- [ ] AC-8: 對既有 resource `PATCH` 帶 `{ field_b: 99 }` → 200，field_b 變 99，field_a 不變

## ADDED: F-005 Notification
（完整新功能 spec）

## REMOVED: F-003 Legacy Export
Migration: 用 F-004 Batch Export 替代
```

變更確認後更新主檔案，舊 changes 歸檔到 `specs/changes/archive/`。Deprecate 既有 AC 用刪除線 `~~AC-X~~` + comment，不直接刪。

---

## 4. GitHub 發佈指令

### 4.1 Labels（首次，可改用 `bash .claude/scripts/init-github.sh`）

```bash
gh label create "spec" --color "0E8A16" --description "Spec 規格文件" --force
gh label create "epic" --color "3E4B9E" --description "Epic 總覽" --force
gh label create "sprint" --color "C5DEF5" --description "Sprint 追蹤" --force
gh label create "feature" --color "1D76DB" --description "功能需求" --force
gh label create "qa" --color "D876E3" --description "測試相關" --force
gh label create "bug" --color "B60205" --description "Bug 缺陷" --force
gh label create "design" --color "FBCA04" --description "UI 設計" --force
gh label create "backend" --color "5319E7" --description "Backend lane" --force
gh label create "frontend" --color "0E8A16" --description "Frontend lane" --force
gh label create "pipeline" --color "006B75" --description "Pipeline lane" --force
gh label create "change" --color "E99695" --description "Change Request" --force
```

### 4.2 本地 specs/ 目錄

```bash
mkdir -p specs/features specs/sprints specs/changes specs/changes/archive
```

寫入 `specs/overview.md`、`specs/infra.md`、每個 `specs/features/f{N}-{name}.md`、每個 `specs/sprints/sprint-N.md`（該 sprint 的 feature ID 清單，決定 e2e scope）。

### 4.3 Sprint Milestones

```bash
gh api repos/{owner}/{repo}/milestones -f title="Sprint 1: {目標}" -f description="{描述}" -f state="open"
```

### 4.4 Epic Issue（功能用清單索引，不貼全文）

```bash
gh issue create --title "📋 [Spec] {專案名稱} - 總覽" --label "spec,epic" --body "$(cat <<'BODY'
## 專案概述
- **目標**：
- **目標使用者**：
- **核心價值主張**：

## 技術架構
（從 specs/overview.md 彙整）

## 功能需求索引
| 編號 | 名稱 | Sprint | 優先級 | Spec 檔案 |
|------|------|--------|--------|-----------|
| F-001 | {名稱} | Sprint 1 | P0 | `specs/features/f001-xxx.md` |
| F-002 | {名稱} | Sprint 1 | P1 | `specs/features/f002-xxx.md` |

## Sprint 規劃
- [ ] Sprint 1: {目標}
- [ ] Sprint 2: {目標}

## 非功能需求
BODY
)"
```

### 4.5 Sprint Issues

```bash
gh issue create --title "🏃 [Sprint {N}] {Sprint 目標}" --label "sprint" \
  --milestone "Sprint {N}: {目標}" --body "$(cat <<'BODY'
## Sprint {N}: {目標}

### 功能範圍
- F-001: {名稱}（`specs/features/f001-xxx.md`）
- F-002: {名稱}（`specs/features/f002-xxx.md`）

### 工作項目
（由 Tech Lead 建立後更新）

### 完成標準
- [ ] 所有 feature PR 已合併
- [ ] E2E 測試全部通過
- [ ] 無 open 的 bug
- [ ] Verify 三維度檢查通過

### 相關
- Epic: #{epic_number}
BODY
)"
```

---

## 5. 階段性 AskUserQuestion 範本（語法見 question-ui.md，此處只列題目骨架）

- **專案類型**：API 後端 / 全端應用 / CLI 工具
- **技術架構（批次，一次 ≤4 題）**：語言（TS/Python/Go）｜資料庫（PostgreSQL/MySQL/MongoDB/SQLite）｜認證（JWT/Session/OAuth2）｜部署（Docker/Serverless/VPS）
- **本地環境**：開發模式（Docker Compose 全包〔附 compose preview〕/ 混合 / 全本機 / 已有環境）→ 額外服務多選（Redis/RabbitMQ/MinIO/不需要）→ port 衝突（全用預設 / 需調整）
- **Sprint 劃分**：2 Sprints〔preview: S1 基礎CRUD+Auth / S2 進階+整合〕vs 3 Sprints〔preview: S1 模型+API / S2 Auth+權限 / S3 進階〕
- **最終發佈確認**：發佈 / 再修改 / 只存本地

compose preview 範例字串：
```
services:
  app:
    build: .
    ports: ["3000:3000"]
    depends_on: { db: { condition: service_healthy } }
  db:
    image: postgres:16-alpine
    ports: ["5432:5432"]
```
