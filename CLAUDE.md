# CLAUDE.md

本檔案為 Claude Code 提供專案開發指引。

## 專案概述

AfterClose - 本地優先盤後台股掃描 App。所有資料處理在裝置端完成，無雲端依賴。

**核心原則**：零固定成本 | 盤後批次 | 推薦 = 異常提示

## 常用指令

```bash
flutter pub get                    # 安裝依賴
flutter test                       # 執行測試
dart run build_runner build --delete-conflicting-outputs  # 程式碼生成
```

## 架構

```text
lib/
├── core/           # 工具類、常數、Result<T>
├── data/
│   ├── database/   # Drift (SQLite)
│   ├── remote/     # API (TWSE, FinMind)
│   └── repositories/
├── domain/services/  # Rule Engine, ScoringService
└── presentation/
    ├── providers/  # Riverpod Notifiers
    └── screens/    # UI
```

**資料流**：API → Repository → Drift DB → Riverpod → UI（UI 只讀本地）

## 關鍵文件

- [docs/RULE_ENGINE.md](docs/RULE_ENGINE.md) - 規則引擎 (45 條規則)
- [.agent/skills/flutter-riverpod-architect/SKILL.md](.agent/skills/flutter-riverpod-architect/SKILL.md) - 架構模式

## 編碼標準

- **Repository**：使用 `IAnalysisRepository` 介面，支援 mock
- **錯誤處理**：`Result<T>` (`lib/core/utils/result.dart`)
- **Riverpod**：`AsyncNotifier` / `StateNotifier`，避免 `StateProvider`
- **Rule Engine**：純函數（輸入資料，輸出理由）
- **Dart 3**：Records、Pattern Matching
