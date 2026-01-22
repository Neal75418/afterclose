---
description: 提交前預防 CI 失敗的檢查流程
---

# 提交前 CI 預防檢查

// turbo-all

## 快速檢查 (必做)

1. 執行格式化
```bash
dart format .
```

2. 執行靜態分析
```bash
flutter analyze --no-fatal-infos
```

3. 執行測試
```bash
flutter test
```

## 常見 CI 失敗原因與解決方案

| 失敗類型 | 原因 | 解法 |
|----------|------|------|
| `dart format` | 程式碼格式不符 | 執行 `dart format .` |
| `flutter analyze` | 缺少 const、未使用 import 等 | 根據提示修正，或確認是 info 級別 |
| `flutter test` | 測試案例失敗 | 檢查測試輸出並修正邏輯 |
| 建構子參數不匹配 | Model 欄位變更未更新測試 | 檢查 `.g.dart` 中的 Entry 類別定義 |

## 完整 CI 模擬

```bash
# 模擬完整 CI 流程
flutter pub get && \
dart run build_runner build --delete-conflicting-outputs && \
dart format --output=none --set-exit-if-changed . && \
flutter analyze --no-fatal-infos && \
flutter test
```

## 提交後 CI 失敗處理

1. 查看 GitHub Actions 失敗 log
2. 根據失敗步驟執行對應的本地檢查
3. 修復後再次提交
