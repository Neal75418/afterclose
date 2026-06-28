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
        RAS["RuleAccuracyService<br/>(規則準確度統計)"]
    end

    US --> Syncers
    US --> Helpers
    US -->|fail-safe| PostUpdate
```

## Update 元件

- **Coordinator**: `UpdateService` — 協調所有 syncer 執行順序 + 錯誤處理
- **10 Syncers**: 各自從 External API 拉取特定類別資料（stock list、price、institutional、market data、fundamental、news、market index、TDCC holding、dividend、insider transfer）
- **3 Helpers**: `BatchDataBuilder`（組裝批次寫入 DTO）、`BatchDataLoader`（批次載入 DB）、`CandidateSelector`（選出評分候選）
- **Post-Update**: `RuleAccuracyService` 在更新後 fail-safe 聚合 per-rule 命中率統計（caller 仍 await，但錯誤不會中斷更新；從 `daily_reason` 算 unbiased，寫 `rule_accuracy`，供個股詳情規則表現顯示）
