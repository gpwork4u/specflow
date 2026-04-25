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
#   state.sh log <message>                     # append 一行 audit log
#   state.sh show                              # 印出整份 state

STATE_DIR=".specflow"
STATE_FILE="$STATE_DIR/state.json"
LOG_FILE="$STATE_DIR/audit.log"

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
  "updated_at": null
}
EOF
  fi
}

now() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }

cmd="${1:-show}"
shift || true

case "$cmd" in
  init)
    ensure_state
    echo "✅ state initialized at $STATE_FILE"
    ;;
  set)
    ensure_state
    path="$1"; value="$2"
    tmp=$(mktemp)
    jq --arg ts "$(now)" "(.$path) |= ($value) | .updated_at = \$ts" "$STATE_FILE" > "$tmp"
    mv "$tmp" "$STATE_FILE"
    ;;
  get)
    ensure_state
    jq -r ".$1 // empty" "$STATE_FILE"
    ;;
  phase)
    ensure_state
    phase="$1"; next="${2:-}"
    tmp=$(mktemp)
    jq --arg p "$phase" --arg n "$next" --arg ts "$(now)" \
      '.phase = $p | .next_action = $n | .updated_at = $ts' "$STATE_FILE" > "$tmp"
    mv "$tmp" "$STATE_FILE"
    echo "[$(now)] phase=$phase next=$next" >> "$LOG_FILE"
    ;;
  agent-add)
    ensure_state
    type="$1"; issue="$2"; pr="${3:-null}"; branch="${4:-}"; status="${5:-running}"
    tmp=$(mktemp)
    jq --arg t "$type" --argjson i "$issue" --argjson p "${pr:-null}" \
       --arg b "$branch" --arg s "$status" --arg ts "$(now)" \
       '.in_flight_agents += [{"type":$t,"issue":$i,"pr":$p,"branch":$b,"status":$s,"started_at":$ts}] | .updated_at = $ts' \
       "$STATE_FILE" > "$tmp"
    mv "$tmp" "$STATE_FILE"
    ;;
  agent-done)
    ensure_state
    pr="$1"
    tmp=$(mktemp)
    jq --argjson p "$pr" --arg ts "$(now)" \
      '.in_flight_agents |= map(select(.pr != $p)) | .updated_at = $ts' "$STATE_FILE" > "$tmp"
    mv "$tmp" "$STATE_FILE"
    ;;
  log)
    ensure_state
    echo "[$(now)] $*" >> "$LOG_FILE"
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
