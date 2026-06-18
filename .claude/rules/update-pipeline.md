---
paths:
  - "lib/domain/services/update/**"
  - "lib/data/remote/**"
  - "**/syncer*"
  - "**/Syncer*"
  - "**/BatchData*"
  - "**/rule_accuracy*"
---

# Update Pipeline

```mermaid
%%{init: {'theme': 'dark'}}%%
graph TB
    US["UpdateService<br/>(Coordinator)"]

    subgraph Syncers["10 Syncers"]
        SLS["StockListSyncer"]
        HPS["HistoricalPriceSyncer"]
        IS["InstitutionalSyncer"]
        MDU["MarketDataUpdater"]
        FS["FundamentalSyncer"]
        NS["NewsSyncer"]
        MIS["MarketIndexSyncer"]
        THS["TdccHoldingSyncer"]
        DS["DividendSyncer"]
        ITS["InsiderTransferSyncer"]
    end

    subgraph Helpers["3 Helpers"]
        BDB["BatchDataBuilder"]
        BDL["BatchDataLoader"]
        CS["CandidateSelector"]
    end

    subgraph PostUpdate["Post-Update"]
        RAS["RuleAccuracyService<br/>(推薦績效驗證)"]
    end

    US --> Syncers
    US --> Helpers
    US -->|非阻塞| PostUpdate
```

## Update 元件

- **Coordinator**: `UpdateService` — 協調所有 syncer 執行順序 + 錯誤處理
- **10 Syncers**: 各自從 External API 拉取特定類別資料（stock list、price、institutional、market data、fundamental、news、market index、TDCC holding、dividend、insider transfer）
- **3 Helpers**: `BatchDataBuilder`（組裝批次寫入 DTO）、`BatchDataLoader`（批次載入 DB）、`CandidateSelector`（選出評分候選）
- **Post-Update**: `RuleAccuracyService` 在更新後非阻塞執行推薦績效回測（多週期驗證）
