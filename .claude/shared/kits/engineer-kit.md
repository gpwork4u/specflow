# engineer kit — Loop / Docker / PR 範本（按需 Read，非常駐）

> engineer.md 在執行 loop / 維護 compose / 發 PR 時才 Read 本檔。

---

## 1. Lane loop（循序清空該 lane 的 feature/bug）

```bash
loop:
  # 認領該 lane 未 assigned 的 feature 或 bug（search 做 OR；--label "a,b" 是 AND）
  ISSUE=$(gh issue list \
    --search "milestone:\"$SPRINT\" label:$LANE no:assignee state:open (label:feature OR label:bug)" \
    --json number,title --jq '.[0]')

  if [ -z "$ISSUE" ] || [ "$ISSUE" = "null" ]; then
    echo "✅ Lane $LANE 已清空"
    bash .claude/scripts/state.sh log "engineer lane=$LANE drained"
    if [ "$LANE" = "backend" ] || [ "$LANE" = "frontend" ] || [ "$LANE" = "pipeline" ]; then
      OPEN_FEATURE=$(gh issue list --milestone "$SPRINT" --label "feature" --state open --json number --jq 'length')
      OPEN_BUG=$(gh issue list --milestone "$SPRINT" --label "bug" --state open --json number --jq 'length')
      [ "$OPEN_FEATURE" = "0" ] && bash .claude/scripts/state.sh lane-close feature
      [ "$OPEN_BUG" = "0" ] && bash .claude/scripts/state.sh lane-close bug
    fi
    exit 0
  fi

  gh issue edit "$NUM" --add-assignee "@me" --add-label "in-progress"
  bash .claude/scripts/state.sh agent-add "engineer-$LANE" "$NUM" null "" "running"

  # ... 執行工作流程一輪 ...

  gh issue edit "$NUM" --remove-label "in-progress" --add-label "ready-for-review"
  bash .claude/scripts/state.sh agent-done "$PR_NUM"
end loop
```

PR 後**不等 review**直接認領下一個。sprint-end code-review 若產 CRITICAL → 變 bug issue → 同 lane engineer 由 loop 再認領（lane 內仍循序）。

---

## 2. dev/ 目錄結構

```
dev/
├── src/{models,routes,validators,middleware,index.ts}
├── __tests__/{models,routes,validators}      # unit tests（engineer 寫）
├── Dockerfile
├── docker-compose.yml          # 本地實際用（.gitignore）
├── docker-compose.example.yml  # 範本（入版控）
├── .env / .env.example
├── package.json / tsconfig.json
```

---

## 3. docker-compose.example.yml 範本

```yaml
services:
  app:
    build: .
    ports: ["${APP_PORT:-3000}:3000"]
    env_file: .env
    depends_on:
      db: { condition: service_healthy }
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: ${DB_USER:-user}
      POSTGRES_PASSWORD: ${DB_PASS:-pass}
      POSTGRES_DB: ${DB_NAME:-app}
    ports: ["${DB_PORT:-5432}:5432"]
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER:-user} -d ${DB_NAME:-app}"]
      interval: 5s
      retries: 5
    volumes: ["db_data:/var/lib/postgresql/data"]
volumes: { db_data: }
```

`.env.example`：`APP_PORT=3000` `NODE_ENV=development` `DATABASE_URL=postgresql://user:pass@db:5432/app` `DB_USER=user` `DB_PASS=pass` `DB_NAME=app` `DB_PORT=5432`。

`.env.example`：`APP_PORT` `NODE_ENV` `DATABASE_URL` `DB_*`。`.gitignore` 必含 `dev/docker-compose.yml`、`dev/.env`。新增依賴服務（DB/Redis/MQ）時更新 example。

> 🛑 **Build context vs repo-root contracts（SpecFlow 固有架構，pipeline lane 必讀）**：`dev/` 的 code `import '../specs/contracts'`（或 `../../`），contracts.ts **在 build context 之外**。若 Dockerfile 用 `build: .`（context=`dev/`），容器內 `tsc`/`vite build` 會找不到 contracts.ts 而失敗。**正解**：context 設 repo root，dockerfile 指到子專案：
> ```yaml
> api:
>   build: { context: .., dockerfile: dev/Dockerfile }   # context=repo root，COPY specs/contracts.ts 進得來
> ```
> 並在 Dockerfile `COPY specs/contracts.ts ./specs/`（或整個 specs/）。**單一 app 用上面的 `build: .` 範本即可；一旦 code import 了 repo-root 的 contracts 就必須改 context。**

> 🛑 **Fullstack 雙子專案**（backend 在 `dev/`、frontend 在 `dev/web/`，見 frontend-scaffold 的隔離邏輯）：compose 要起 `db` + `api`（backend）+ `web`（frontend，`vite preview` 或 nginx）三個 service，各自 Dockerfile、各自 healthcheck，`depends_on` 串成 db→api→web 健康鏈。**先 `ls dev/ dev/web/` 勘查實際結構，不照 issue 字面的目錄假設。**
> 🛑 **寫 `.github/workflows/*.yml` 後 push 前必驗 YAML**（local-checks 不驗 workflow 語法）：`python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" .github/workflows/x.yml`。壞掉的 workflow YAML 在 GitHub 上才報、或帳務擋住時根本不報，本地先擋掉。

驗證（pipeline 收尾建議真的 `docker compose up` 一次，別只信範本）：
```bash
cd dev && docker compose up -d --build && docker compose ps
curl -sf http://localhost:3000/health && echo OK || echo FAIL
docker compose down
```

---

## 4. PR + auto-merge（deliver-first 絕對序列）

### 4a. 認領 issue 後第一個 Bash（deliver-first，不可插別的 tool call）

```bash
DRAFT_PR=$(bash .claude/scripts/deliver-first.sh "$ISSUE_NUM" "$SLUG" "$TITLE" "feature,$LANE")
```

script 內部把 fetch+rebase → 開 branch → empty commit → push + 開 draft PR **4 步合 1 個 Bash**（含 retry / idempotent）。**完成這 1 個 Bash 才能開始 Read spec / 寫 code / npm install**——絕對序列防止本能性「先驗證再 commit」（v2 frontend 試 npm install 先沒推→沒 PR；qa commit 完忘 push→沒 PR）。**不要手打這 4 步，一律走 script**（手打版會繞過 retry / idempotent 防護）。

### 4b. 實作期間每 ~10 檔 commit + push（PR 自動跟上）

```bash
git add -A && git commit -q -m "feat: <progress描述>

Refs #${ISSUE_NUM}"
git push
```

### 4c. 收尾：先填 PR 真實 title/body，再走 ready-and-merge.sh

```bash
gh pr edit "$DRAFT_PR" --title "{Issue 標題}" --body "$(cat <<'BODY'
## Summary
{實作摘要}
## Changes
- `path/to/file` - {變更描述}
## AC 覆蓋
- [x] AC-1: {描述} — 實作完成
## 測試
- {unit / local-checks 結果}
## Design 對照（frontend 必填）
- 實作了 design 的哪幾頁/section
- 與 design 不一致處（如有，附原因）
## Related Issues
Closes #{issue_number}
BODY
)"
bash .claude/scripts/ready-and-merge.sh "$DRAFT_PR"   # ready→等 CI→squash merge 三合一；CI 紅 exit 1
```

issue 回報：
```bash
gh issue comment {issue_number} --body "✅ 實作完成 PR #{pr_number}
變更：- \`path\` {描述}
AC 覆蓋：- [x] AC-1 ...
備註：{偏差/問題，無則省略}"
```
Bug 修復額外：`gh issue comment {feature_number} --body "🔧 Bug #{bug} 已修復，PR #{pr}"`

commit 訊息：`feat: {描述}` / `fix: {描述}` + 空行 + `Refs #{issue_number}`。分支 `feature/{n}-{desc}` 或 `fix/{n}-{desc}`。

---

## 5. Design Gap issue（frontend 發現 design 沒涵蓋時）

```bash
gh issue create --title "🎨 [Design Gap] {缺什麼}" --label "design-question" \
  --milestone "$SPRINT" --body "Frontend 實作 #${ISSUE_NUM} 時發現 design 沒涵蓋：
- {具體描述：如「按鈕 disabled 顏色」/「列表空時顯示什麼」}
請補進 Claude design 後通知 ui-designer 重 fetch + 更新 contracts/。本 issue 阻塞 #${ISSUE_NUM}。"
```

frontend 推 PR 前視覺校驗（人工/visual diff 對照 design 截圖）：
```bash
( cd dev && npm run dev & DEV_PID=$! ); sleep 5
npx playwright screenshot --browser chromium http://localhost:3000/{path} test/screenshots/impl-{component}.png
kill $DEV_PID
# 截圖路徑寫進 PR description，附 design 截圖旁讓使用者比對
```
