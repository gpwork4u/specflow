#!/bin/sh
set -eu

# SpecFlow State Helper
# 用途：讀寫 .specflow/state.json，讓流程可以在 /clear 之後接續
# 用法：
#   state.sh init                              # 初始化空 state
#   state.sh set <key.path> <json-value>       # 設定欄位（dot path）
#   state.sh get <key.path>                    # 讀欄位
#   state.sh phase <phase-id> <next-action>    # 紀錄目前 phase + 下一步
#   state.sh agent-add <type> <issue> <pr> <branch> <status>
#   state.sh agent-done <pr>                   # 從 in_flight 移除
#   state.sh lane-close <feature|design|qa|bug>   # 標記 lane 全關
#   state.sh lane-status                          # 印 4 lane 狀態
#   state.sh log <message>                     # append 一行 audit log
#   state.sh show                              # 印出整份 state
#
# 並發安全：lane 制最多 5 個背景 agent 同時寫 state.json。所有寫入經
# _locked 序列化（flock；macOS 無 flock 退回 mkdir 原子鎖），避免
# jq>tmp;mv 的 read-modify-write lost-update。

STATE_DIR=".specflow"
STATE_FILE="$STATE_DIR/state.json"
LOG_FILE="$STATE_DIR/audit.log"
LOCK_FILE="$STATE_DIR/state.lock"

ensure_state() {
  mkdir -p "$STATE_DIR"
  if [ ! -f "$STATE_FILE" ]; then
    cat > "$STATE_FILE" <<'EOF'
{
  "epic": null,
  "current_sprint": null,
  "phase": "init",
  "last_action": null,
  "next_action": null,
  "in_flight_agents": [],
  "open_questions": [],
  "lane_closed": {
    "feature": false,
    "design": false,
    "qa": false,
    "bug": false
  },
  "sprint_base_sha": null,
  "sprint_test_outcome": null,
  "sprint_review_outcome": null,
  "updated_at": null
}
EOF
  fi
}

now() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }

# 序列化鎖：優先 flock（Linux/CI），退回 mkdir 原子鎖（macOS 無 flock）。
_locked() {
  mkdir -p "$STATE_DIR"
  if command -v flock >/dev/null 2>&1; then
    exec 9>"$LOCK_FILE"; flock 9
    "$@"
  else
    i=0
    until mkdir "$LOCK_FILE.d" 2>/dev/null; do
      i=$((i+1)); [ "$i" -gt 100 ] && rm -rf "$LOCK_FILE.d" && mkdir "$LOCK_FILE.d"
      sleep 0.1
    done
    trap 'rm -rf "$LOCK_FILE.d"' EXIT
    "$@"
    rm -rf "$LOCK_FILE.d"; trap - EXIT
  fi
}

cmd="${1:-show}"
shift || true

w_set() {
  path="$1"; value="$2"
  tmp=$(mktemp)
  jq --arg ts "$(now)" "(.$path) |= ($value) | .updated_at = \$ts" "$STATE_FILE" > "$tmp"
  mv "$tmp" "$STATE_FILE"
}
w_phase() {
  phase="$1"; next="${2:-}"
  tmp=$(mktemp)
  jq --arg p "$phase" --arg n "$next" --arg ts "$(now)" \
    '.phase = $p | .next_action = $n | .updated_at = $ts' "$STATE_FILE" > "$tmp"
  mv "$tmp" "$STATE_FILE"
  echo "[$(now)] phase=$phase next=$next" >> "$LOG_FILE"
}
w_agent_add() {
  type="$1"; issue="$2"; pr="${3:-null}"; branch="${4:-}"; status="${5:-running}"
  tmp=$(mktemp)
  jq --arg t "$type" --argjson i "$issue" --argjson p "${pr:-null}" \
     --arg b "$branch" --arg s "$status" --arg ts "$(now)" \
     '.in_flight_agents += [{"type":$t,"issue":$i,"pr":$p,"branch":$b,"status":$s,"started_at":$ts}] | .updated_at = $ts' \
     "$STATE_FILE" > "$tmp"
  mv "$tmp" "$STATE_FILE"
}
w_agent_done() {
  pr="$1"
  tmp=$(mktemp)
  jq --argjson p "$pr" --arg ts "$(now)" \
    '.in_flight_agents |= map(select(.pr != $p)) | .updated_at = $ts' "$STATE_FILE" > "$tmp"
  mv "$tmp" "$STATE_FILE"
}
w_lane_close() {
  lane="$1"
  tmp=$(mktemp)
  jq --arg l "$lane" --arg ts "$(now)" \
    '.lane_closed[$l] = true | .updated_at = $ts' "$STATE_FILE" > "$tmp"
  mv "$tmp" "$STATE_FILE"
  echo "[$(now)] lane-close $lane" >> "$LOG_FILE"
}

case "$cmd" in
  init)
    ensure_state
    echo "✅ state initialized at $STATE_FILE"
    ;;
  set)
    ensure_state
    _locked w_set "$1" "$2"
    ;;
  get)
    ensure_state
    jq -r ".$1 // empty" "$STATE_FILE"
    ;;
  phase)
    ensure_state
    _locked w_phase "$1" "${2:-}"
    ;;
  agent-add)
    ensure_state
    _locked w_agent_add "$1" "$2" "${3:-null}" "${4:-}" "${5:-running}"
    ;;
  agent-done)
    ensure_state
    _locked w_agent_done "$1"
    ;;
  lane-close)
    ensure_state
    lane="$1"
    case "$lane" in
      feature|design|qa|bug) ;;
      *) echo "lane must be feature|design|qa|bug" >&2; exit 1 ;;
    esac
    _locked w_lane_close "$lane"
    # v5 P5.2: lane-close 後自動跑 sweep-missing-prs 兜底
    # 為什麼放 lock 外：sweep 跑 gh API 可能秒級慢，不該卡住其他 state.sh 寫入
    # 環境變數 SPECFLOW_SKIP_SWEEP=1 可關（測試用）
    if [ -z "${SPECFLOW_SKIP_SWEEP:-}" ] && [ -x .claude/scripts/sweep-missing-prs.sh ]; then
      echo "🔧 lane-close $lane → 自動跑 sweep-missing-prs.sh 兜底..." >&2
      bash .claude/scripts/sweep-missing-prs.sh 2>&1 | sed 's/^/  [sweep] /' >&2 || true
    fi
    ;;
  lane-status)
    ensure_state
    jq -r '.lane_closed | to_entries[] | "\(.key)=\(.value)"' "$STATE_FILE"
    ;;
  log)
    ensure_state
    _locked sh -c "echo \"[$(now)] $*\" >> \"$LOG_FILE\""
    ;;
  show)
    ensure_state
    cat "$STATE_FILE"
    ;;
  *)
    echo "Unknown command: $cmd" >&2
    exit 1
    ;;
esac
