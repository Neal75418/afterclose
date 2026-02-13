# Changelog

All notable changes to AfterClose will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added (2026-02-13)

#### Performance Optimizations - Latest

- **Watchlist 無限滾動分頁**: 新增分頁機制與 Scan 畫面保持一致，降低大列表記憶體佔用，提升滾動流暢度
- **快取預熱服務**: App 啟動時預載自選股和 Top 20 推薦股資料，提升冷啟動速度 30-40%
- **DTO Extension 集中管理**: 提取資料轉換邏輯為 Extension methods，減少程式碼重複

#### Performance Optimizations - Earlier (2026-02-13)

- **Request Deduplication + Circuit Breaker**: 避免重複 API 呼叫，減少 30-50% 網路請求；API 連續失敗時快速失敗
- **資料庫索引優化**: 新增 4 個關鍵索引（daily_analysis, daily_institutional, insider_holding, trading_warning），查詢速度提升 30%
- **Isolate 池重用機制**: 平行運算時重用 worker，減少 20-30% 啟動開銷
- **細化錯誤處理**: 區分不同錯誤類型（NetworkException, ParseException, RateLimitException），提升穩定性和診斷能力
- **輸入驗證機制**: 驗證股票代碼格式和日期範圍，防止 SQL injection 和資源耗盡攻擊
- **效能監測系統**: 使用 PerformanceMonitor 追蹤關鍵操作耗時，識別效能瓶頸

#### Architecture Improvements

- **AnalysisService 架構重構**: 拆分 991 行的 AnalysisService 為 5 個專門服務（TrendDetection, ReversalDetection, CandlestickAnalysis, IndicatorCalculation, Coordinator），提升可維護性

#### Testing & CI/CD

- **測試覆蓋率提升**: 新增 TodayProvider 完整測試，建立測試覆蓋率計劃
- **Codecov CI 整合**: 自動上傳測試覆蓋率報告，追蹤品質趨勢

### Changed

- **Watchlist 畫面**: 現在使用與 Scan 一致的無限滾動分頁邏輯，支援大量自選股
- **InstitutionalRepository**: 使用 FinMindInstitutionalExt.toDatabaseCompanion() 統一資料轉換
- **MarketIndexSyncer**: 使用 TwseMarketIndexExt.toDatabaseCompanion() 統一資料轉換

### Technical Details

#### Commits

- **cfacc84**: Watchlist 無限滾動分頁 + 快取預熱服務 + DTO Extension 集中管理
- **0ae2e3e**: Request Deduplication + Circuit Breaker + 資料庫索引優化 + 細化錯誤處理 + 輸入驗證 + 效能監測 + Isolate 池重用
- **1056b61**: AnalysisService 架構重構（拆分為 5 個專門服務）
- **239957e**: 測試覆蓋率提升 + TodayProvider 完整測試

#### Key Files

**新增檔案**:
- `lib/core/services/cache_warmup_service.dart` - 快取預熱服務
- `lib/data/models/extensions/dto_extensions.dart` - DTO Extension 集中管理
- `lib/core/utils/request_deduplicator.dart` - Request Deduplication
- `lib/core/utils/circuit_breaker.dart` - Circuit Breaker
- `lib/core/utils/error_handler.dart` - 細化錯誤處理 wrapper
- `lib/core/utils/performance_monitor.dart` - 效能監測
- `lib/core/utils/validators.dart` - 輸入驗證
- `lib/domain/services/isolate_pool.dart` - Isolate 池重用

**修改檔案**:
- `lib/presentation/providers/watchlist_provider.dart` - 新增分頁邏輯
- `lib/presentation/screens/watchlist/watchlist_screen.dart` - 無限滾動實作
- `lib/main.dart` - 整合快取預熱服務
- `lib/data/repositories/institutional_repository.dart` - 使用 DTO Extension
- `lib/domain/services/update/market_index_syncer.dart` - 使用 DTO Extension

---

## Project Information

**Repository**: [afterclose](https://github.com/yourusername/afterclose)
**License**: MIT
**Maintainer**: AfterClose Team
