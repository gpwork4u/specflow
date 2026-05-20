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

`.gitignore` 必含 `dev/docker-compose.yml`、`dev/.env`。新增依賴服務（DB/Redis/MQ）時更新 example。

驗證：
```bash
cd dev && docker compose up -d --build && docker compose ps
docker compose logs app --tail 20
curl -sf http://localhost:3000/health && echo OK || echo FAIL
docker compose down
```

---

## 4. PR + auto-merge（無 per-PR review）

```bash
PR_NUM=$(gh pr create --title "{Issue 標題}" --label "feature,${LANE}" \
  --milestone "${SPRINT}" --body "$(cat <<'BODY'
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
)" --json number --jq .number)

gh pr checks "$PR_NUM" --watch || { echo "🔴 build-and-lint 失敗，修完再來"; exit 1; }
gh pr merge "$PR_NUM" --squash --delete-branch
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
