# CLAUDE.md

本檔案為 Claude Code (claude.ai/code) 提供專案開發指引。

## 專案概述

AfterClose 是一款 **本地優先** 盤後台股市場掃描 App。所有資料處理、分析和推薦都在裝置端完成，無雲端依賴。

**核心原則：**
- 所有資料抓取、分析、推薦都在**裝置端完成**
- **零固定成本**（免費 API + RSS + 本地 SQLite）
- 只處理**盤後批次**資料
- 推薦 = **異常提示**，不是投資建議

## 常用指令

```bash
# 開發
flutter pub get                    # 安裝依賴
flutter run                        # 執行 App (debug)
flutter run --release              # 執行 App (release)

# 程式碼生成 (修改 Drift 表或 Freezed 模型後)
dart run build_runner build --delete-conflicting-outputs

# 測試
flutter test                       # 執行所有測試
flutter test test/widget_test.dart # 執行特定測試

# 品質檢查
flutter analyze                    # 靜態分析
dart format .                      # 格式化程式碼
dart format --output=none --set-exit-if-changed .  # 檢查格式

# 建置
flutter build apk --release        # Android APK
flutter build ios --release        # iOS (需 macOS)
```

## 架構

### 技術堆疊

| 層級 | 技術 |
|:---|:---|
| Framework | Flutter 3.29 + Dart 3.10 |
| State | Riverpod 2.6 |
| Database | Drift 2.27 (SQLite) |
| Network | Dio 5.8 |
| Models | Freezed + json_serializable |
| RSS | xml 6.5 |
| Charts | fl_chart + k_chart_plus |

### 目錄結構

```
lib/
├── main.dart
├── app/                    # App 配置、路由
├── core/                   # 工具類、常數、例外、Result<T>
├── data/
│   ├── database/           # Drift 表、DAO、遷移
│   ├── remote/             # API 客戶端 (TWSE, FinMind)
│   └── repositories/       # 協調本地 + 遠端
├── domain/
│   ├── repositories/       # Repository 介面 (IAnalysisRepository, IPriceRepository)
│   └── services/           # 業務邏輯、Rule Engine、ScoringService
└── presentation/
    ├── providers/          # Riverpod Notifiers
    ├── screens/            # 頁面 Widget
    └── widgets/            # 可重用元件
```

### 資料流

```
API/RSS → Repository → Drift DB → Stream → Riverpod → UI
                ↑                              ↓
            (同步寫入)                    (UI 只讀本地)
```

## 關鍵文件

| 檔案 | 說明 |
|:---|:---|
| [README.md](README.md) | 產品規格、功能、UI 結構 |
| [docs/RULE_ENGINE.md](docs/RULE_ENGINE.md) | 推薦規則 (R1-R8) + SQLite Schema DDL |
| [.agent/skills/flutter-riverpod-architect/SKILL.md](.agent/skills/flutter-riverpod-architect/SKILL.md) | 架構模式與編碼標準 |

## 規則引擎摘要

8 條異常偵測規則，各有評分：

| 規則 | 分數 | 觸發條件 |
|:---|---:|:---|
| REVERSAL_W2S | +35 | 弱轉強反轉 |
| REVERSAL_S2W | +35 | 強轉弱反轉 |
| TECH_BREAKOUT | +25 | 突破壓力位 |
| TECH_BREAKDOWN | +25 | 跌破支撐位 |
| VOLUME_SPIKE | +18 | 量 ≥ 20日均量 × 2 |
| PRICE_SPIKE | +15 | 日漲跌幅 ≥ 5% |
| INSTITUTIONAL_SHIFT | +12 | 法人方向反轉 |
| NEWS_RELATED | +8 | 相關新聞偵測 |

輸出：每日 Top 10，每檔最多 2 條理由。

## 資料來源

| 資料 | 來源 | 說明 |
|:---|:---|:---|
| 台股日價 | **TWSE Open Data** (主) | 免費、無限制、全市場 |
| 台股歷史 | FinMind (備) | 歷史資料補充 |
| 法人籌碼 | FinMind | 三大法人買賣超 |
| 新聞 | RSS | 多源 RSS 聲明 |

## 編碼標準

- **Repository 介面**：使用 `IAnalysisRepository` / `IPriceRepository` 抽象，支援 mock 測試
- **錯誤處理**：使用 `Result<T>` 類別 (`lib/core/utils/result.dart`)，支援 `map`, `flatMap`, `fold`
- **Service 分離**：`ScoringService` 獨立評分邏輯，遵循單一職責原則
- **Riverpod**：使用 `AsyncNotifier` / `Notifier`，避免使用 `StateProvider`
- **Rule Engine**：保持純函數（輸入：資料，輸出：理由）
- **UI**：只從本地資料庫 Stream 讀取，不直接讀網路
- **Dart 3 特性**：使用 Records、Pattern Matching、sealed classes
