# 測試覆蓋率補充計劃

## 當前狀況

- **測試總數**: 1054 個
- **執行時間**: ~9 秒
- **Presentation 層測試**: 僅 3 個檔案
  - `test/presentation/providers/watchlist_state_test.dart`
  - `test/presentation/providers/stock_detail_find_previous_price_test.dart`
  - `test/presentation/mappers/summary_localizer_test.dart`

## 未覆蓋的關鍵組件

### 🔴 高優先級（核心功能）

#### 1. Today Provider (`lib/presentation/providers/today_provider.dart`)
- **重要性**: ⭐⭐⭐⭐⭐ 核心功能
- **預估工作量**: 2-3 小時
- **測試範圍**:
  - 初始狀態載入
  - 重新整理邏輯
  - 錯誤處理
  - 狀態轉換（loading → success/error）
- **示範檔案**: `test/presentation/providers/today_provider_test.dart` ✅

#### 2. Scan Provider (`lib/presentation/providers/scan_provider.dart`)
- **重要性**: ⭐⭐⭐⭐⭐ 核心功能
- **預估工作量**: 2-3 小時
- **測試範圍**:
  - 篩選條件應用
  - 排序邏輯
  - 分頁載入
  - 評分計算結果展示

#### 3. Stock Detail Provider (`lib/presentation/providers/stock_detail_provider.dart`)
- **重要性**: ⭐⭐⭐⭐ 重要功能
- **預估工作量**: 2-3 小時
- **測試範圍**:
  - 股票資料載入
  - 分析結果顯示
  - 圖表資料準備
  - 技術指標計算

### 🟠 中優先級（重要功能）

#### 4. Custom Screening Provider
- **預估工作量**: 2 小時
- **測試範圍**: SQL 篩選、條件組合

#### 5. Backtest Provider
- **預估工作量**: 2 小時
- **測試範圍**: 回測邏輯、結果計算

#### 6. Portfolio Provider
- **預估工作量**: 1.5 小時
- **測試範圍**: 持倉計算、損益統計

### 🟡 低優先級（輔助功能）

#### 7. Event Calendar Provider
- **預估工作量**: 1 小時

#### 8. Price Alert Provider
- **預估工作量**: 1 小時

## Widget 測試補充計劃

### 主要 Screen 測試

#### 1. Today Screen
- **檔案**: `test/presentation/screens/today/today_screen_test.dart`
- **工作量**: 2 小時
- **測試範圍**:
  - Widget 樹渲染
  - Tab 切換
  - 重新整理功能
  - 錯誤狀態顯示

#### 2. Scan Screen
- **檔案**: `test/presentation/screens/scan/scan_screen_test.dart`
- **工作量**: 2-3 小時
- **測試範圍**:
  - 篩選條件 UI
  - 列表渲染
  - 無限滾動
  - 排序切換

#### 3. Stock Detail Screen
- **檔案**: `test/presentation/screens/stock_detail/stock_detail_screen_test.dart`
- **工作量**: 3-4 小時
- **測試範圍**:
  - 詳情頁面渲染
  - 圖表顯示
  - Tab 切換
  - 加入自選股

## 大型服務測試補充計劃

### 1. UpdateService
- **檔案**: `test/domain/services/update_service_test.dart`
- **工作量**: 3-4 小時
- **重要性**: ⭐⭐⭐⭐⭐
- **測試範圍**:
  - 同步流程協調
  - 錯誤處理和重試
  - 進度追蹤
  - Rate Limit 處理
  - 各 Syncer 的呼叫順序

### 2. AnalysisService
- **檔案**: `test/domain/services/analysis_service_test.dart`
- **工作量**: 4-5 小時
- **重要性**: ⭐⭐⭐⭐⭐
- **測試範圍**:
  - 各種技術分析場景
  - 趨勢檢測邏輯
  - 反轉檢測邏輯
  - K線型態識別
  - 邊界條件處理

## 邊界情況測試補充

### 需要補充的邊界測試

1. **空列表處理**
   - 空自選股清單
   - 空搜尋結果
   - 無歷史資料

2. **Null 值處理**
   - 缺失價格資料
   - 缺失基本面資料
   - 缺失技術指標

3. **極端數值**
   - 超大股價（>10000）
   - 超小股價（<1）
   - 異常成交量（0 或極大值）

4. **時間相關**
   - 假日/停牌
   - 市場開盤前/後
   - 資料延遲

5. **網路問題**
   - API timeout
   - 連線中斷
   - Rate Limit

## 實施計劃

### Phase 1: 核心 Provider 測試（第 1-2 週）

```
Week 1:
- [ ] Today Provider 測試 ✅ (示範)
- [ ] Scan Provider 測試
- [ ] Stock Detail Provider 測試

Week 2:
- [ ] Custom Screening Provider 測試
- [ ] Backtest Provider 測試
- [ ] Portfolio Provider 測試
```

### Phase 2: Widget 測試（第 3-4 週）

```
Week 3:
- [ ] Today Screen Widget 測試
- [ ] Scan Screen Widget 測試

Week 4:
- [ ] Stock Detail Screen Widget 測試
- [ ] 其他 Screen Widget 測試
```

### Phase 3: 大型服務測試（第 5-6 週）

```
Week 5:
- [ ] UpdateService 測試
- [ ] AnalysisService 測試（Part 1）

Week 6:
- [ ] AnalysisService 測試（Part 2）
- [ ] 邊界情況測試補充
```

### Phase 4: 目標達成（第 7-8 週）

```
Week 7:
- [ ] 剩餘輔助功能測試
- [ ] 邊界測試完善

Week 8:
- [ ] 測試覆蓋率驗證（目標 70%+）
- [ ] CI 集成驗證
- [ ] 文件更新
```

## 測試範本

### Provider 測試範本

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

// Mock dependencies
class MockRepository extends Mock implements SomeRepository {}

void main() {
  late MockRepository mockRepo;
  late ProviderContainer container;

  setUp(() {
    mockRepo = MockRepository();
    container = ProviderContainer(
      overrides: [
        someRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('SomeProvider', () {
    test('initial state is loading', () {
      final state = container.read(someProvider);
      expect(state.isLoading, isTrue);
    });

    test('loads data successfully', () async {
      when(() => mockRepo.getData()).thenAnswer((_) async => mockData);

      await container.read(someProvider.notifier).load();

      final state = container.read(someProvider);
      expect(state.isLoading, isFalse);
      expect(state.data, isNotNull);
    });

    test('handles error gracefully', () async {
      when(() => mockRepo.getData()).thenThrow(Exception('Error'));

      await container.read(someProvider.notifier).load();

      final state = container.read(someProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, isNotNull);
    });
  });
}
```

### Widget 測試範本

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('SomeScreen renders correctly', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: SomeScreen(),
        ),
      ),
    );

    // Verify widgets
    expect(find.text('Expected Text'), findsOneWidget);
    expect(find.byType(SomeWidget), findsOneWidget);
  });

  testWidgets('SomeScreen handles tap', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: SomeScreen(),
        ),
      ),
    );

    // Tap button
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    // Verify result
    expect(find.text('Updated Text'), findsOneWidget);
  });
}
```

## 驗證標準

### 覆蓋率目標

- **整體覆蓋率**: 70%+
- **Presentation 層**: 60%+
- **Domain 層**: 80%+
- **Data 層**: 75%+

### 品質標準

- 所有測試必須通過
- 無 flaky tests
- 測試執行時間 < 30 秒
- 測試命名清晰易懂
- 包含邊界測試

## 工具和資源

### 測試框架

- `flutter_test` - Flutter 官方測試框架
- `mocktail` - Mock 框架
- `flutter_riverpod` - 狀態管理測試支援

### 覆蓋率工具

```bash
# 生成覆蓋率報告
flutter test --coverage

# 查看覆蓋率（需安裝 lcov）
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### CI 整合

已配置 Codecov 自動上傳覆蓋率報告到 CI，每次 PR 都會顯示覆蓋率變化。

## 總結

**預估總工作量**: 30-40 小時

**實施建議**:
1. 優先完成高優先級 Provider 測試
2. 每週補充 2-3 個組件的測試
3. 持續追蹤覆蓋率變化
4. 定期 review 測試品質

**示範檔案**: `test/presentation/providers/today_provider_test.dart`（已完成）

---

*最後更新: 2026-02-13*
