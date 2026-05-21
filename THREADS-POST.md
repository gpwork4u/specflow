# SpecFlow 優化 — Threads 貼文（草稿）

> 每則 ≤500 字，可直接複製。串接成一個 thread。

---

**1/10**

我做了一件有點 meta 的事：用 AI（Claude Code）去優化「一套讓 AI 自己跑開發流程的系統」。

而且不是憑感覺改 —— 是建真實 demo 專案當 benchmark，跑完整流程、量數據、翻 log 找根因、再迭代。前後 7 輪。

過程比想像中更像在做系統可靠度工程 🧵

---

**2/10**

背景：SpecFlow 是我寫的多 agent 開發流程。spec → 技術規劃 → 5 個 agent 平行（backend / frontend / pipeline / qa / 設計）→ 測試 → 驗證，全部以 GitHub issue / PR 為協作中心。

這次想驗證一件事：我把 agent 的 prompt 大砍 79% 之後，可靠度有沒有掉？

---

**3/10**

第一個反直覺：**prompt 瘦了 79%，總 token 幾乎沒省。**

因為 prompt cache 把多數收益吃掉（系統 prompt 大多快取命中只收 1 成），真正的成本在 output + 工具 I/O。

該看的指標不是「每次跑多少 token」，是「每個真實交付物多少 token」。

---

**4/10**

然後 v1 benchmark 我傻眼：5 個 agent 把 code 都寫好了，**0 個 PR、0 個 merge。**

翻 log（grep stop_reason）發現：每個 agent 都在「正要 commit / 開 PR」那一刻被砍掉 —— 撞到 harness 的 sub-agent 上限（約 60-65 次工具呼叫 / 10 分鐘）。

預算全花在做事，還沒交付就被切。

---

**5/10**

更意外：agent 設定檔的 `maxTurns` **根本不是 hard limit**。log 顯示每個都跑超過自己設的上限。真正天花板在 harness 端，改設定沒用。

所以解法不是「給更多預算」，是**反轉順序**。

---

**6/10**

我定了一條叫 deliver-first 的規則：

agent 認領任務後，第一件事就是開分支 → 空 commit → push → 開 draft PR。**然後**才開始寫 code。

這樣就算後面撞牆，draft PR 已在 GitHub，下一個 agent 接著推。從「全有或全無」變「至少保底」。

---

**7/10**

但光寫在 prompt 裡只有 50% agent 照做 —— 有的想「先 npm install 確認能 build」、有的「commit 完忘了 push」。

**prompt 的說服力有極限。**

最後把那 4 步包成一支 script，agent 跑一行搞定全部，想跳步都沒辦法。可靠度拉到接近 100%。

---

**8/10**

最關鍵的一課：

要 agent 穩定做對，不是寫更兇的 prompt，是**把流程壓成它不可能做錯的單一動作**。

配上一個「掃描沒開 PR 的分支自動補開」的安全網 —— 保險帶比保險閘穩，helper 偶爾失手也兜得回來。

---

**9/10**

最大的盲點在 review 才抓到：

我前 6 輪都從主 session 手動分派 agent。結果**使用者實際入口的那個指令，根本沒接上這些修正**。等於辛苦修的東西，真正用的人完全吃不到 😅

修掉這個，優化才對使用者可見。

---

**10/10**

用 AI 優化 AI 流程，最有意思的不是「AI 幫我寫 code」，是把它當**可量測、可迭代的工程系統**：

- 每個改動都有 benchmark 數據（不是感覺變好）
- 失敗就翻 log 找根因，像 debug 分散式系統
- 設計「結構性防呆」而非寄望 agent 每次都聰明

完整 7 輪紀錄都開源在 repo 👇
github.com/gpwork4u/specflow

---

## 心得敘事版（較短、較個人，7 則）

**1/7**

上個月我做了一套讓 AI 自己跑開發的多 agent 流程（SpecFlow）。做完之後一直在修修改改 —— 這個 prompt 太囉嗦砍一點、那個 agent 忘記做某步補一條規則、token 好像吃多再瘦一下。

全憑感覺。

直到某天我停下來想：我到底有沒有真的讓它變好，還是只是「感覺」變好？🧵

---

**2/7**

我發現我從來沒**認真量過這個流程的數據**。沒 baseline、沒對照、沒算過跑一次花多少 token、產出幾個能用的 PR。

我在憑直覺調一個看不到內部的黑盒子。

於是我做了個決定：請 Claude Code 幫我寫一份 benchmark 實驗，然後**連續跑它**。

---

**3/7**

一跑就是 7 輪。每輪建一個全新的 demo 專案，讓完整流程跑到底，量三個數字：總 token、agent 開了幾個 PR、幾個真的 merge。

然後翻 log 找根因、改一個東西、再跑一輪。

「優化」第一次變成有憑有據的事，而不是猜。

---

**4/7**

第一個打臉：我先把 prompt 瘦身 79%，自我感覺良好。結果總 token 幾乎沒省。

因為 prompt cache 把收益吃掉了，真正的成本在 output 和工具 I/O。

該看的不是「每次跑多少 token」，是「每個交付物多少 token」。

---

**5/7**

更傻眼的：第一輪 4 個 agent 把 code 都寫好了，**一個 PR 都沒開。**

翻 log 才懂 —— 它們都在「正要 commit」那刻被系統上限切斷，預算全花在做事，沒走到交付。

解法：反轉順序，先開 PR 再寫 code。撞牆也保底。

---

**6/7**

最關鍵的一課：要 agent 穩定做對，**不是寫更兇的 prompt，是把流程壓成它不可能做錯的單一動作。**

我把「開分支→commit→push→開PR」包成一支 script，agent 跑一行搞定，想跳步都沒辦法。可靠度從 50% 拉到接近 100%。

---

**7/7**

跑完 7 輪最大的收穫不是「修好了流程」，是心態轉變：

調 AI 流程不是「寫 prompt 的藝術」，是**可靠度工程**。沒 benchmark 就沒優化，只有自我安慰。

如果你也在調 AI 工作流，我最想說的是：**先別急著改 prompt，先想辦法量它。**

完整紀錄 👇
github.com/gpwork4u/specflow

---

## 備用 hook（可換 1/10 開頭）

- 「我花了一個週末用 AI debug 另一個 AI —— 跑了 7 輪 benchmark，發現的東西顛覆我對 prompt engineering 的認知。」
- 「prompt 砍 79%，token 沒省。這個結果逼我重新理解 AI agent 的成本到底花在哪。」
- 「為什麼我的 5 個 AI agent 把功能寫完了，卻一個都沒交付？翻 log 的故事 🧵」
