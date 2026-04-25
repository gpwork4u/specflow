# SpecFlow Question UI Interface 規範

所有需要使用者做決策的地方，**必須**使用 `AskUserQuestion` tool 提供一致的 TTY 介面。
**禁止**用純文字 markdown 列出選項讓使用者手動輸入。

## 為什麼

- 一致的 UI 體驗 — 使用者每次看到相同的互動介面
- 防止格式混亂 — 不會因為 agent 不同而有不同的提問風格
- 可操作性 — 使用者用選擇器點選，而非手打「A」或「B」
- 自動帶入 "Other" — 使用者始終可以自由輸入

## AskUserQuestion Tool 規格

```
AskUserQuestion({
  questions: [
    {
      question: "完整問句，結尾加問號",     // 必填
      header: "短標籤",                    // 必填，≤12 字元，如 "資料庫" "框架" "Port"
      multiSelect: false,                  // true = 可多選
      options: [                           // 2-4 個選項
        {
          label: "選項名稱",              // 1-5 個詞，簡潔
          description: "說明這個選項的意義、優缺點、適用場景",
          preview: "（選填）程式碼片段、設定範例、ASCII mockup"
        }
      ]
    }
  ]
})
```

## 設計原則

### 1. 每次最多 4 個問題
一次呼叫可包含 1-4 個問題。**相關聯的問題一起問**，不相關的分開問。

### 2. 推薦選項放第一個
如果有推薦選項，放在 options 陣列第一個，label 後加 `(Recommended)`。

### 3. Header 短小精幹
`header` 是 chip 標籤，最多 12 字元。用來標識問題類別：

| 場景 | header 範例 |
|------|------------|
| 選擇框架 | `"框架"` |
| 選擇資料庫 | `"資料庫"` |
| 選擇 port | `"Port"` |
| 確認是否繼續 | `"確認"` |
| 選擇認證方式 | `"認證"` |
| 選擇部署方式 | `"部署"` |
| 基礎設施 | `"Infra"` |
| Sprint 規劃 | `"Sprint"` |

### 4. 善用 preview 做視覺比較
當選項涉及**程式碼、設定檔、架構圖**時，使用 `preview` 欄位：

```javascript
{
  label: "PostgreSQL (Recommended)",
  description: "最成熟的開源關聯式資料庫",
  preview: "services:\n  db:\n    image: postgres:16-alpine\n    ports:\n      - \"5432:5432\"\n    environment:\n      POSTGRES_USER: user\n      POSTGRES_PASSWORD: pass\n      POSTGRES_DB: app"
}
```

### 5. multiSelect 用於非互斥選項
選擇基礎服務（DB + Cache + Queue）時用 `multiSelect: true`。
選擇框架（Next.js vs Remix）時用 `multiSelect: false`。

### 6. description 包含優缺點和建議
不要只寫名稱，要寫為什麼選或不選：

```javascript
// ✅ 好
{ label: "JWT Token", description: "無狀態，適合 API-first 架構。前後端分離首選。" }

// ❌ 差
{ label: "JWT Token", description: "一種認證方式" }
```

## 常見問答模式

### 模式 A：單選技術選型
```javascript
AskUserQuestion({
  questions: [{
    question: "認證機制要用哪種？",
    header: "認證",
    multiSelect: false,
    options: [
      { label: "JWT Token (Recommended)", description: "無狀態，適合 API-first 架構，前後端分離" },
      { label: "Session Cookie", description: "簡單直覺，適合 SSR 應用" },
      { label: "OAuth 2.0", description: "支援第三方登入（Google, GitHub），但實作較複雜" }
    ]
  }]
})
```

### 模式 B：多選基礎服務
```javascript
AskUserQuestion({
  questions: [{
    question: "需要哪些基礎服務？",
    header: "Infra",
    multiSelect: true,
    options: [
      { label: "PostgreSQL", description: "關聯式資料庫，預設 port 5432" },
      { label: "Redis", description: "快取 / Session store，預設 port 6379" },
      { label: "RabbitMQ", description: "訊息佇列，預設 port 5672" },
      { label: "MinIO", description: "S3 相容物件儲存，預設 port 9000" }
    ]
  }]
})
```

### 模式 C：帶 preview 的設定比較
```javascript
AskUserQuestion({
  questions: [{
    question: "Docker Compose 設定要用哪種模式？",
    header: "Infra",
    multiSelect: false,
    options: [
      {
        label: "全容器化 (Recommended)",
        description: "App + DB + 其他服務全部容器化，一鍵啟動",
        preview: "services:\n  app:\n    build: .\n    ports:\n      - \"3000:3000\"\n    depends_on:\n      db:\n        condition: service_healthy\n  db:\n    image: postgres:16-alpine\n    ports:\n      - \"5432:5432\""
      },
      {
        label: "混合模式",
        description: "DB 用 Docker，App 在本機跑（適合 hot reload）",
        preview: "services:\n  db:\n    image: postgres:16-alpine\n    ports:\n      - \"5432:5432\"\n\n# App 在本機執行：\n# npm run dev"
      }
    ]
  }]
})
```

### 模式 D：確認 / 是否繼續
```javascript
AskUserQuestion({
  questions: [{
    question: "Spec 已準備好，要發佈到 GitHub Issues 嗎？",
    header: "確認",
    multiSelect: false,
    options: [
      { label: "發佈", description: "建立 Epic + Sprint issues 到 GitHub" },
      { label: "再修改", description: "回到 spec 繼續調整" }
    ]
  }]
})
```

### 模式 E：Infra 確認（Sprint 測試前）
```javascript
AskUserQuestion({
  questions: [
    {
      question: "Sprint 測試環境準備好了嗎？",
      header: "Infra",
      multiSelect: false,
      options: [
        { label: "自動部署 (Recommended)", description: "使用 docker compose up 自動啟動所有服務" },
        { label: "已在運行", description: "服務已經在跑了，直接執行測試" },
        { label: "需要調整", description: "我需要先修改 port 或設定" }
      ]
    },
    {
      question: "App 服務的 URL 是？",
      header: "URL",
      multiSelect: false,
      options: [
        { label: "http://localhost:3000 (Recommended)", description: "Docker Compose 預設" },
        { label: "http://localhost:8000", description: "Python/FastAPI 預設" },
        { label: "http://localhost:8080", description: "Go/Java 預設" }
      ]
    }
  ]
})
```

### 模式 F：多題組合（相關聯的問題一起問）
```javascript
AskUserQuestion({
  questions: [
    {
      question: "專案類型是？",
      header: "專案類型",
      multiSelect: false,
      options: [
        { label: "API 後端", description: "純 API，前端另外做" },
        { label: "全端應用", description: "前端 + 後端" },
        { label: "CLI 工具", description: "命令列工具" }
      ]
    },
    {
      question: "主要程式語言？",
      header: "語言",
      multiSelect: false,
      options: [
        { label: "TypeScript (Recommended)", description: "型別安全，適合中大型專案" },
        { label: "Python", description: "簡潔快速，豐富的 ML/Data 生態" },
        { label: "Go", description: "高效能，適合微服務" }
      ]
    }
  ]
})
```

## 禁止事項

1. **禁止用 markdown 列 A/B/C 選項** — 所有選擇題必須用 AskUserQuestion
2. **禁止超過 4 個選項** — 如果超過，拆分成多個問題或歸納分類
3. **禁止空的 description** — 每個選項都要有說明
4. **禁止問開放式問題** — 除非真的需要自由輸入（使用者可以選 "Other"）
5. **禁止一次問超過 4 個問題** — 分批問，保持聚焦
