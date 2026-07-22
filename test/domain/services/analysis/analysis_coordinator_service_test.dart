import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/services/analysis/analysis_coordinator_service.dart';
import 'package:afterclose/domain/services/ohlcv_data.dart';
import 'package:afterclose/domain/services/technical_indicator_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/price_data_generators.dart';

/// [AnalysisCoordinatorService.calculateTechnicalIndicators] 是 gap-bridging
/// root cause 修復的主要呼叫端（把 priceHistory 轉為 AnalysisContext 用的
/// RSI/KD 指標，直接餵給規則引擎）。這裡驗證停牌缺口不再被靜默橋接。
void main() {
  late AnalysisCoordinatorService coordinator;

  setUp(() {
    coordinator = AnalysisCoordinatorService();
  });

  group('calculateTechnicalIndicators — RSI gap-awareness', () {
    test('RSI reflects gap-aware calculation, not the bridged phantom spike, '
        'when priceHistory has a halt right before today', () {
      final now = DateTime(2026, 1, 1);
      final entries = <DailyPriceEntry>[
        for (int i = 0; i < 70; i++)
          createTestPrice(
            date: now.add(Duration(days: i)),
            close: 100.0 + (i.isEven ? 0.3 : -0.3),
            volume: 1000,
          ),
        // 兩日停牌（無成交）
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
        // 復牌當日（今天）：若跨缺口的價差被誤採計為單一交易日變動，
        // 會產生虛假極端 RSI
        createTestPrice(
          date: now.add(const Duration(days: 72)),
          close: 250.0,
          volume: 1000,
        ),
      ];

      final indicators = coordinator.calculateTechnicalIndicators(entries);

      expect(indicators, isNotNull);
      expect(indicators!.rsi, isNotNull);
      // 缺口前最後穩定值附近（震盪走平 → RSI 中性），遠低於橋接後的極端值
      expect(indicators.rsi!, lessThan(60.0));

      // 對照組：舊行為（extractOhlcv 後直接 calculateRSI，不帶 gapBefore）
      // 會把跨缺口的價差當成單一交易日變動，產生虛假極端 RSI——用來證明
      // 這不是「兩種算法剛好差不多」而是有意義的修正。
      final bridgedOhlcv = entries.extractOhlcv();
      final bridgedRsi = TechnicalIndicatorService()
          .calculateRSI(bridgedOhlcv.closes, period: 14)
          .last;
      expect(bridgedRsi, isNotNull);
      expect(bridgedRsi!, greaterThan(90.0));
    });

    test('RSI unaffected when there is no gap anywhere in priceHistory', () {
      final now = DateTime(2026, 1, 1);
      final entries = List.generate(
        70,
        (i) => createTestPrice(
          date: now.add(Duration(days: i)),
          close: 100.0 + i * 0.2,
          volume: 1000,
        ),
      );

      final indicators = coordinator.calculateTechnicalIndicators(entries);

      expect(indicators, isNotNull);
      expect(indicators!.rsi, isNotNull);
      // 持續上升無缺口 → RSI 偏高屬正常（非缺口造成的虛假訊號）
      expect(indicators.rsi!, greaterThan(50.0));
    });
  });

  group('calculateTechnicalIndicators — KD prevK/prevD freshness', () {
    test(
      'prevKdK/prevKdD are null when a halt gap sits immediately before today '
      '(stale-guard: len-2 would not actually be "yesterday")',
      () {
        final now = DateTime(2026, 1, 1);
        final entries = <DailyPriceEntry>[
          for (int i = 0; i < 65; i++)
            createTestPrice(
              date: now.add(Duration(days: i)),
              close: 100.0 + (i % 10).toDouble(),
              volume: 1000,
            ),
          // 昨天停牌
          createTestPrice(
            date: now.add(const Duration(days: 65)),
            close: null,
            volume: 0,
          ),
          // 今天
          createTestPrice(
            date: now.add(const Duration(days: 66)),
            close: 105.0,
            volume: 1000,
          ),
        ];

        final indicators = coordinator.calculateTechnicalIndicators(entries);

        expect(indicators, isNotNull);
        // 今日自身的 K/D 仍可正常計算（RSV 視窗本身沒有問題）
        expect(indicators!.kdK, isNotNull);
        expect(indicators.kdD, isNotNull);
        // 但「前一日」不是真的前一交易日，寧可 null 讓交叉/回檔規則自然略過
        expect(indicators.prevKdK, isNull);
        expect(indicators.prevKdD, isNull);
      },
    );

    test('prevKdK/prevKdD keep their normal (non-null) value when there is no '
        'gap before today', () {
      final now = DateTime(2026, 1, 1);
      final entries = List.generate(
        67,
        (i) => createTestPrice(
          date: now.add(Duration(days: i)),
          close: 100.0 + (i % 10).toDouble(),
          volume: 1000,
        ),
      );

      final indicators = coordinator.calculateTechnicalIndicators(entries);

      expect(indicators, isNotNull);
      expect(indicators!.kdK, isNotNull);
      expect(indicators.kdD, isNotNull);
      expect(indicators.prevKdK, isNotNull);
      expect(indicators.prevKdD, isNotNull);
    });
  });
}
