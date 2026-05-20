---
name: specflow:resume
description: 從 .specflow/state.json 讀取 SpecFlow 流程進度，重建狀態後繼續執行。在 /clear context 之後、或重開 session 時用來接續工作。觸發關鍵字："resume", "繼續", "接續"。
user-invocable: true
allowed-tools: Read, Bash, Agent, AskUserQuestion
---

# SpecFlow Resume — 從上次中斷處接續

## 為什麼需要這個

SpecFlow 流程跨多個 phase 可能持續好幾小時，對話 context 會被 `/clear` 或溢出截斷。
所有持久狀態都寫在 `.specflow/state.json` + GitHub Issues，這個 skill 從這些 source of truth 重建狀態繼續跑。

## 步驟

### 1. 讀取 state file

```bash
bash .claude/scripts/state.sh show
```

如果檔案不存在 → 告知使用者「沒有進行中的流程，請用 `/specflow:start` 開始」。

### 2. 從 GitHub 重建即時狀態

對照 state.json 與當前 GitHub 狀態（避免依賴可能過時的 in_flight_agents）：

```bash
# 當前 sprint milestone
gh api "repos/:owner/:repo/milestones?state=open&sort=title" --jq '[.[] | select(.title | startswith("Sprint"))][0]'

# Sprint 內未關閉的 issue
gh issue list --milestone "$SPRINT" --state open --json number,title,labels,assignees

# 進行中的 PR
gh pr list --state open --json number,title,headRefName,statusCheckRollup,reviewDecision
```

### 3. 報告當前狀態給使用者

用簡短格式（**不要 dump 整個 state.json**）：

```
📍 接續 Sprint {N}（phase: {phase}）

進行中：
- PR #47 (engineer, feature F-002) — review 第 2/3 輪
- PR #48 (qa) — APPROVED, waiting merge
- Issue #51 (bug) — open

下一步：{next_action}
```

### 4. 詢問如何繼續

```javascript
AskUserQuestion({
  questions: [{
    question: "要從這裡繼續嗎？",
    header: "Resume",
    multiSelect: false,
    options: [
      { label: "繼續 (Recommended)", description: "從 next_action 接著跑" },
      { label: "重新評估", description: "我想看更多細節再決定" },
      { label: "重來這個 phase", description: "把當前 phase 重跑一次" }
    ]
  }]
})
```

### 5. 根據 phase 路由到對應 orchestrator

決策前**先讀 `lane_closed` + GitHub 即時狀態**，避免重啟已完成的 lane：

```bash
LANE_CLOSED=$(bash .claude/scripts/state.sh get lane_closed)
SPRINT_TEST_OUTCOME=$(bash .claude/scripts/state.sh get sprint_test_outcome)
SPRINT="{current_sprint}"

# 用 GitHub 即時資料校正（state.json 可能過時）
OPEN_FEATURE=$(gh issue list --milestone "$SPRINT" --label "feature" --state open --json number --jq 'length')
OPEN_DESIGN=$(gh issue list --milestone "$SPRINT" --label "design" --state open --json number --jq 'length')
OPEN_QA=$(gh issue list --milestone "$SPRINT" --label "qa" --state open --json number --jq 'length')
OPEN_BUG=$(gh issue list --milestone "$SPRINT" --label "bug" --state open --json number --jq 'length')

ALL_LANES_CLOSED="false"
[ "$OPEN_FEATURE" = "0" ] && [ "$OPEN_DESIGN" = "0" ] && [ "$OPEN_QA" = "0" ] && [ "$OPEN_BUG" = "0" ] && ALL_LANES_CLOSED="true"
```

| phase | 跳過條件 | 接續動作 |
|-------|---------|---------|
| `phase-2-spec` | — | 啟動 spec-writer 繼續討論 |
| `phase-3-techlead` | feature/qa/design issues 已存在 → 跳到 phase-4 | 啟動 tech-lead（背景） |
| `phase-4-impl` | `ALL_LANES_CLOSED=true` → 跳到 phase-5 | 只啟動 `OPEN_$LANE > 0` 的 lane（不要重啟已 drained） |
| `phase-4.5-review` | open PR 已全部 APPROVED → 跳到 phase-4-impl 等 merge | 對 open 且 review pending 的 PR 啟動 code-review |
| `phase-5-e2e` | `sprint_test_outcome=success` → 跳到 phase-5.5；`failure` → 確認最新 bug issue 是否已關，否則回 phase-4 | 輪詢 sprint-test workflow 結果 |
| `phase-5.5-verify` | sprint issue 已 closed → 跳到 phase-7 | 啟動 verifier |
| `phase-6-close` | milestone 已 closed → phase-7 | 產出 sprint log + 關 milestone（verifier 會做） |
| `phase-7-next` | — | 詢問是否進入下一個 sprint |

> **phase 字串只做提示，用子字串模糊比對不要精確 ==**（phase 命名會演進：`phase-cr-*`、`phase-5-bdd`/`phase-5-e2e` 等都可能出現 → 精確表必過時 → resume 破功）。以上 `跳過條件` 的 GitHub 即時狀態才是路由依據；phase 字串與 GitHub 推斷衝突時**一律以 GitHub 為準**。比對範例：`case "$phase" in *spec*) … *techlead*|*plan*) … *impl*|*engineer*) … *review*) … *e2e*|*bdd*|*test*) … *verify*) … *close*) … *next*) … esac`。

**重啟 lane 前的去重邏輯**：

```bash
for LANE in backend frontend pipeline; do
  COUNT=$(gh issue list --milestone "$SPRINT" --label "$LANE" --state open --json number --jq 'length')
  ASSIGNED_OPEN=$(gh issue list --milestone "$SPRINT" --label "$LANE,in-progress" --state open --json number --jq 'length')
  # 已 drained 不啟動
  [ "$COUNT" = "0" ] && echo "lane=$LANE 已 drained，跳過" && continue
  # 已有 in-progress 表示前一個 agent 還在跑（worktree 還在），不重啟
  [ "$ASSIGNED_OPEN" -gt "0" ] && echo "lane=$LANE 已有 in-progress issue，跳過" && continue
  # 啟動該 lane
  # Agent(subagent_type="engineer", run_in_background=true, prompt="lane=$LANE, sprint=$SPRINT")
done
```

## 重要原則

- **GitHub Issues 是 source of truth**，state.json 只是 cache，衝突時以 GitHub 為準
- 不要重複建立已存在的 issue / milestone / PR
- 重啟 background agent 前先檢查對應 PR 是否已存在（避免重複工作）
