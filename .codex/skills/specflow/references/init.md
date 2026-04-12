# Init Phase

在使用者要初始化 SpecFlow repo 設定時使用。

## Goal

建立最小必要的 GitHub labels 與專案骨架，讓後續 spec / sprint 流程能運作。

## Default Workflow

1. 確認 repo 身分：
   - 優先從使用者輸入取得 `owner/repo`
   - 否則從 git remote 或目前 connector context 推斷
2. 檢查 `.claude/scripts/init-github.sh` 是否存在，可直接重用：
   - `bash .claude/scripts/init-github.sh {owner/repo}`
3. 若無法直接操作 GitHub：
   - 在 `specs/` 或 repo 根目錄產出 labels/checklist 草稿
   - 明確列出使用者之後可執行的命令

## Expected Labels

- `spec`
- `epic`
- `sprint`
- `feature`
- `design`
- `qa`
- `bug`
- `code-review`

若原 repo 已有等價 labels，不要重複建立。

## Output

至少完成其中一種：

- 實際初始化成功
- 產出可直接執行的初始化命令與 checklist

## Constraints

- 不要假設 `gh` 已登入
- 不要假設使用者有 admin 權限
- 若權限不足，停在安全的替代方案
