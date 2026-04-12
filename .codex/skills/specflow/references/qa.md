# QA Phase

在使用者要建立 QA 計畫、撰寫 e2e / browser tests、或驗證 feature coverage 時使用。

## Goal

依 spec 建立測試覆蓋，不等待所有實作都完成才開始。

## Workflow

1. 讀取 feature spec 與 acceptance criteria。
2. 先補齊測試清單：
   - happy path
   - edge cases
   - failure cases
3. 在 repo 內建立或更新：
   - `test/e2e/`
   - `test/browser/`
   - 必要的 fixtures / screenshots 路徑
4. 若功能尚未完成，先建立待啟用或可逐步完成的測試骨架。

## Rules

- QA 以 spec 為依據，不以目前實作缺陷當作真相。
- spec 不夠明確時，先補規格或列出待確認問題。
- 若 repo 尚未有測試框架，先建立最小可執行樣板，不要過度搭建。
