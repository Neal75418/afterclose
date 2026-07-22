import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/services/alert_evaluation_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/price_data_generators.dart';

/// [AlertEvaluationService] 的 RSI/KD 警示檢查與 AnalysisCoordinatorService
/// 修復前重複同一份 gap-naive 擷取邏輯（sibling bug，同一 root cause）。
/// 此檔案原本沒有測試覆蓋，這裡補上聚焦於 gap-awareness 的迴歸測試。
void main() {
  late AlertEvaluationService service;

  setUp(() {
    service = AlertEvaluationService();
  });

  PriceAlertEntry rsiOverboughtAlert({double targetValue = 70.0}) {
    return PriceAlertEntry(
      id: 1,
      symbol: 'TEST',
      alertType: AlertParams.typeRsiOverbought,
      targetValue: targetValue,
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );
  }

  AlertEvaluationContext contextFor(List<DailyPriceEntry> indicatorData) {
    return AlertEvaluationContext(
      currentPrices: {'TEST': indicatorData.last.close ?? 0},
      priceChanges: const {},
      volumeDataMap: const {},
      priceHistoryMap: const {},
      indicatorDataMap: {'TEST': indicatorData},
      warningSymbols: const {},
      disposalSymbols: const {},
    );
  }

  group('RSI_OVERBOUGHT — gap-awareness', () {
    test(
      'does NOT fire on a phantom spike fabricated by bridging a halt gap',
      () {
        final now = DateTime(2026, 1, 1);
        final entries = <DailyPriceEntry>[
          for (int i = 0; i < 70; i++)
            createTestPrice(
              date: now.add(Duration(days: i)),
              close: 100.0 + (i.isEven ? 0.3 : -0.3),
              volume: 1000,
            ),
          // 兩日停牌
          createTestPrice(
            date: now.add(const Duration(days: 70)),
            close: null,
            volume: 0,
          ),
          createTestPrice(
            date: now.add(const Duration(days: 71)),
            close: null,
            volume: 0,
          ),
          // 復牌當日：若跨缺口價差被誤採計，會虛假觸發 RSI 超買警示
          createTestPrice(
            date: now.add(const Duration(days: 72)),
            close: 250.0,
            volume: 1000,
          ),
        ];

        final result = service.evaluateAlerts([
          rsiOverboughtAlert(),
        ], contextFor(entries));

        expect(result.triggered, isEmpty);
      },
    );

    test('still fires on a genuine (non-gapped) RSI overbought run', () {
      final now = DateTime(2026, 1, 1);
      final entries = List.generate(
        30,
        (i) => createTestPrice(
          date: now.add(Duration(days: i)),
          close: 100.0 + i * 2.0, // 持續上漲，無缺口 → 真正的 RSI 超買
          volume: 1000,
        ),
      );

      final result = service.evaluateAlerts([
        rsiOverboughtAlert(),
      ], contextFor(entries));

      expect(result.triggered, hasLength(1));
    });
  });
}
