// Unit tests for 第 9 階段 強股回檔進場 rules (Mode C v2)。
//
// 2026-06-20 早期體檢 (workflow wf_9ac59f2a) 後補：原 commit 51e5e8a 3 條新 rule
// 零 evaluate() 覆蓋，0-fire 無法區分「過嚴」vs「bug」。這份 test 鎖定**修正後**
// 的閾值：
// - KD_HIGH_PULLBACK 窗口 [60,80) + prevKdK≥78 + drop≤30（修數學矛盾）
// - HAMMER_AT_SUPPORT touch ±4% + close≤ma20*1.06（修過嚴）
// - PATTERN_HAMMER 已移回 Mode A（不在此檔測）

import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/constants/reason_type.dart';
import 'package:afterclose/core/constants/rule_enums.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/models/analysis_context.dart';
import 'package:afterclose/domain/models/technical_indicators.dart';
import 'package:afterclose/domain/services/rules/pullback_rules.dart';
import 'package:afterclose/domain/services/rules/stock_rules.dart';

void main() {
  // --- fixtures ---

  /// 建 [count] 根日 K，baseline close=[baseClose]。overrides 用 index→entry 覆寫。
  /// index 0 = 最舊、count-1 = 今日。
  List<DailyPriceEntry> buildPrices({
    required int count,
    double baseClose = 100,
    Map<int, DailyPriceEntry> overrides = const {},
  }) {
    return [
      for (var i = 0; i < count; i++)
        overrides[i] ??
            DailyPriceEntry(
              symbol: 'TEST',
              date: DateTime(2026, 1, 1).add(Duration(days: i)),
              open: baseClose,
              high: baseClose + 1,
              low: baseClose - 1,
              close: baseClose,
              volume: 1000,
            ),
    ];
  }

  DailyPriceEntry candle({
    required int dayIdx,
    double? open,
    double? high,
    double? low,
    double? close,
    double? volume,
  }) => DailyPriceEntry(
    symbol: 'TEST',
    date: DateTime(2026, 1, 1).add(Duration(days: dayIdx)),
    open: open,
    high: high,
    low: low,
    close: close,
    volume: volume,
  );

  AnalysisContext ctx(TechnicalIndicators ind) => AnalysisContext(
    trendState: TrendState.up,
    evaluationTime: DateTime(2026, 1, 22),
    indicators: ind,
  );

  StockData stock(List<DailyPriceEntry> prices) =>
      StockData(symbol: 'TEST', prices: prices);

  // ============================================================
  // HealthyPullbackToMa20Rule
  // ============================================================
  group('HealthyPullbackToMa20Rule', () {
    const rule = HealthyPullbackToMa20Rule();
    // 黃金路徑：bull stack 105>100>95、past20=90 (ma20 100>94.5)、今日收黑、量縮、
    // 距 MA20 0%、過去 5 日有紅 K
    final goldenInd = const TechnicalIndicators(
      ma5: 105,
      ma20: 100,
      ma60: 95,
      volumeMA20: 1000,
    );
    List<DailyPriceEntry> goldenPrices() => buildPrices(
      count: 21,
      overrides: {
        0: candle(dayIdx: 0, open: 90, high: 91, low: 89, close: 90), // past20
        15: candle(
          dayIdx: 15,
          open: 98,
          high: 100,
          low: 97,
          close: 99,
        ), // 紅 K（past 5 內）
        19: candle(
          dayIdx: 19,
          open: 102,
          high: 103,
          low: 101,
          close: 102,
        ), // yesterday
        20: candle(
          dayIdx: 20,
          open: 101,
          high: 101,
          low: 99,
          close: 100,
          volume: 800,
        ), // today 收黑 + 量縮
      },
    );

    test('fires on ideal pullback setup', () {
      final r = rule.evaluate(ctx(goldenInd), stock(goldenPrices()));
      expect(r, isNotNull);
      expect(r!.type, ReasonType.pullbackToMa20);
      expect(r.score, 15);
    });

    test('returns null when ma20 unavailable', () {
      final ind = const TechnicalIndicators(
        ma5: 105,
        ma60: 95,
        volumeMA20: 1000,
      );
      expect(rule.evaluate(ctx(ind), stock(goldenPrices())), isNull);
    });

    test('returns null when history < 21', () {
      final prices = goldenPrices().sublist(0, 20);
      expect(rule.evaluate(ctx(goldenInd), stock(prices)), isNull);
    });

    test('returns null when not bull stack (ma5 < ma20)', () {
      final ind = const TechnicalIndicators(
        ma5: 95,
        ma20: 100,
        ma60: 95,
        volumeMA20: 1000,
      );
      expect(rule.evaluate(ctx(ind), stock(goldenPrices())), isNull);
    });

    test('returns null when not strong over past 20d', () {
      // past20Close = 99, ma20=100 not > 99*1.05=103.95
      final prices = goldenPrices();
      prices[0] = candle(dayIdx: 0, open: 99, high: 100, low: 98, close: 99);
      expect(rule.evaluate(ctx(goldenInd), stock(prices)), isNull);
    });

    test('returns null when today is up (close >= yesterday)', () {
      final prices = goldenPrices();
      prices[20] = candle(
        dayIdx: 20,
        open: 101,
        high: 104,
        low: 100,
        close: 103,
        volume: 800,
      );
      expect(rule.evaluate(ctx(goldenInd), stock(prices)), isNull);
    });

    test('returns null when volume not shrunk', () {
      final prices = goldenPrices();
      prices[20] = candle(
        dayIdx: 20,
        open: 101,
        high: 101,
        low: 99,
        close: 100,
        volume: 1000, // >= volumeMA20*0.85
      );
      expect(rule.evaluate(ctx(goldenInd), stock(prices)), isNull);
    });

    test('returns null on limit-down day', () {
      final prices = goldenPrices();
      // yesterday 102 → today 92 = -9.8% 跌停
      prices[20] = candle(
        dayIdx: 20,
        open: 95,
        high: 95,
        low: 91,
        close: 92,
        volume: 800,
      );
      expect(rule.evaluate(ctx(goldenInd), stock(prices)), isNull);
    });

    test('returns null on cascading decline (no red K in past 5)', () {
      final prices = goldenPrices();
      // 15 改黑 K
      prices[15] = candle(dayIdx: 15, open: 100, high: 100, low: 97, close: 98);
      expect(rule.evaluate(ctx(goldenInd), stock(prices)), isNull);
    });
  });

  // ============================================================
  // HealthyPullbackToMa10Rule — 2026-06-20 B2 淺回檔（close > ma20 與 MA20 互斥）
  // ============================================================
  group('HealthyPullbackToMa10Rule', () {
    const rule = HealthyPullbackToMa10Rule();
    // 黃金路徑：ma10 100 > ma20 95 > ma60 90、close 100 距 ma10 0%、close > ma20、
    // past20=90 (ma10 100>94.5)、今日收黑、量縮、過去 5 日有紅 K
    final goldenInd = const TechnicalIndicators(
      ma10: 100,
      ma20: 95,
      ma60: 90,
      volumeMA20: 1000,
    );
    List<DailyPriceEntry> goldenPrices() => buildPrices(
      count: 21,
      overrides: {
        0: candle(dayIdx: 0, open: 90, high: 91, low: 89, close: 90), // past20
        15: candle(dayIdx: 15, open: 98, high: 100, low: 97, close: 99), // 紅 K
        19: candle(dayIdx: 19, open: 102, high: 103, low: 101, close: 102), // 昨
        20: candle(
          dayIdx: 20,
          open: 101,
          high: 101,
          low: 99,
          close: 100,
          volume: 800,
        ), // 今日收黑 + 量縮
      },
    );

    test('fires on ideal shallow pullback to MA10', () {
      final r = rule.evaluate(ctx(goldenInd), stock(goldenPrices()));
      expect(r, isNotNull);
      expect(r!.type, ReasonType.pullbackToMa10);
      expect(r.score, 12);
    });

    test('null when close <= ma20 (deep — let MA20 rule handle)', () {
      // close=94 <= ma20=95 → 不算淺回檔
      final prices = goldenPrices();
      prices[20] = candle(
        dayIdx: 20,
        open: 95,
        high: 95,
        low: 93,
        close: 94,
        volume: 800,
      );
      expect(rule.evaluate(ctx(goldenInd), stock(prices)), isNull);
    });

    test('null when not mid-term bull stack (ma10 <= ma20)', () {
      final ind = const TechnicalIndicators(
        ma10: 95,
        ma20: 100,
        ma60: 90,
        volumeMA20: 1000,
      );
      expect(rule.evaluate(ctx(ind), stock(goldenPrices())), isNull);
    });

    test('null when too far above MA10 (> +2.5%)', () {
      // close=103 距 ma10 100 = +3% > 2.5%
      final prices = goldenPrices();
      prices[20] = candle(
        dayIdx: 20,
        open: 104,
        high: 104,
        low: 102,
        close: 103,
        volume: 800,
      );
      // close 103 > ma20 95、今日 103 < 昨 102? no → 也擋。改昨日更高確保只測距離
      prices[19] = candle(
        dayIdx: 19,
        open: 105,
        high: 106,
        low: 104,
        close: 105,
      );
      expect(rule.evaluate(ctx(goldenInd), stock(prices)), isNull);
    });

    test('null when today up', () {
      final prices = goldenPrices();
      prices[20] = candle(
        dayIdx: 20,
        open: 100,
        high: 101,
        low: 99,
        close: 100.5,
        volume: 800,
      );
      // 昨日 102 → 今 100.5 收黑... 改昨日 100 讓今日漲
      prices[19] = candle(dayIdx: 19, open: 99, high: 100, low: 98, close: 99);
      expect(rule.evaluate(ctx(goldenInd), stock(prices)), isNull);
    });

    test('null when volume not shrunk', () {
      final prices = goldenPrices();
      prices[20] = candle(
        dayIdx: 20,
        open: 101,
        high: 101,
        low: 99,
        close: 100,
        volume: 1000,
      );
      expect(rule.evaluate(ctx(goldenInd), stock(prices)), isNull);
    });

    test('null when ma10 unavailable', () {
      final ind = const TechnicalIndicators(
        ma20: 95,
        ma60: 90,
        volumeMA20: 1000,
      );
      expect(rule.evaluate(ctx(ind), stock(goldenPrices())), isNull);
    });
  });

  // ============================================================
  // KdHighLevelPullbackRule — 修正後窗口 [60,80) + prevKdK>=78 + drop<=30
  // ============================================================
  group('KdHighLevelPullbackRule (fixed window)', () {
    const rule = KdHighLevelPullbackRule();
    AnalysisContext kdCtx({
      double? kdK,
      double? kdD,
      double? prevKdK,
      double ma20 = 100,
      double ma60 = 95,
      double close = 100,
    }) => AnalysisContext(
      trendState: TrendState.up,
      evaluationTime: DateTime(2026, 1, 22),
      indicators: TechnicalIndicators(
        kdK: kdK,
        kdD: kdD,
        prevKdK: prevKdK,
        ma20: ma20,
        ma60: ma60,
      ),
    );
    List<DailyPriceEntry> closeAt(double c) {
      final p = buildPrices(count: 21);
      p[20] = candle(dayIdx: 20, open: c, high: c + 1, low: c - 1, close: c);
      return p;
    }

    test('fires on ideal KD pullback (prevK=85, K=70, K>D)', () {
      final r = rule.evaluate(
        kdCtx(kdK: 70, kdD: 65, prevKdK: 85),
        stock(closeAt(100)),
      );
      expect(r, isNotNull);
      expect(r!.type, ReasonType.kdHighPullback);
      expect(r.score, 12);
    });

    test('fires at window low boundary K=60 (inclusive)', () {
      final r = rule.evaluate(
        kdCtx(kdK: 60, kdD: 55, prevKdK: 85),
        stock(closeAt(100)),
      );
      expect(r, isNotNull);
    });

    test('null below window K=59.9', () {
      final r = rule.evaluate(
        kdCtx(kdK: 59.9, kdD: 55, prevKdK: 85),
        stock(closeAt(100)),
      );
      expect(r, isNull);
    });

    test('null at/above window high K=80 (exclusive)', () {
      final r = rule.evaluate(
        kdCtx(kdK: 80, kdD: 70, prevKdK: 90),
        stock(closeAt(100)),
      );
      expect(r, isNull);
    });

    test('fires just below window high K=79.9', () {
      final r = rule.evaluate(
        kdCtx(kdK: 79.9, kdD: 70, prevKdK: 90),
        stock(closeAt(100)),
      );
      expect(r, isNotNull);
    });

    test('null when dead cross (K <= D)', () {
      final r = rule.evaluate(
        kdCtx(kdK: 65, kdD: 70, prevKdK: 85),
        stock(closeAt(100)),
      );
      expect(r, isNull);
    });

    test('fires at prevKdK=78 boundary (inclusive)', () {
      final r = rule.evaluate(
        kdCtx(kdK: 70, kdD: 65, prevKdK: 78),
        stock(closeAt(100)),
      );
      expect(r, isNotNull);
    });

    test('null when prevKdK=77 (below 78)', () {
      final r = rule.evaluate(
        kdCtx(kdK: 70, kdD: 65, prevKdK: 77),
        stock(closeAt(100)),
      );
      expect(r, isNull);
    });

    test('null when bearish MA stack (ma20 <= ma60)', () {
      final r = rule.evaluate(
        kdCtx(kdK: 70, kdD: 65, prevKdK: 85, ma20: 95, ma60: 100),
        stock(closeAt(100)),
      );
      expect(r, isNull);
    });

    test('null when close below ma20*0.99', () {
      final r = rule.evaluate(
        kdCtx(kdK: 70, kdD: 65, prevKdK: 85, ma20: 100),
        stock(closeAt(98)), // 98 < 99
      );
      expect(r, isNull);
    });

    test('null when single-day drop > 30 (panic)', () {
      // prevK=100 → K=65, drop=35 > 30
      final r = rule.evaluate(
        kdCtx(kdK: 65, kdD: 60, prevKdK: 100),
        stock(closeAt(100)),
      );
      expect(r, isNull);
    });

    test('fires at drop=30 boundary (inclusive)', () {
      // prevK=95 → K=65, drop=30
      final r = rule.evaluate(
        kdCtx(kdK: 65, kdD: 60, prevKdK: 95),
        stock(closeAt(100)),
      );
      expect(r, isNotNull);
    });

    test('null when KD missing', () {
      final r = rule.evaluate(
        kdCtx(kdK: null, kdD: 65, prevKdK: 85),
        stock(closeAt(100)),
      );
      expect(r, isNull);
    });
  });

  // ============================================================
  // HammerAtSupportRule — 修正後 touch ±4% + close <= ma20*1.06
  // ============================================================
  group('HammerAtSupportRule (widened)', () {
    const rule = HammerAtSupportRule();
    final indGolden = const TechnicalIndicators(ma20: 100, ma60: 95);

    // hammer: open=101 close=100.5 high=101 low=97（下影線 3.5 >= body 0.5*2、
    // 上影線 0 <= body 0.5*0.5、body 0.5 >= range 4*0.05）。
    // low 97 距 ma20 100 = 3% ≤ 4%；close 100.5 ≤ ma20*1.06=106；過去強勢 past20=90。
    List<DailyPriceEntry> hammerPrices({
      double low = 97,
      double close = 100.5,
    }) {
      final p = buildPrices(count: 21);
      p[0] = candle(dayIdx: 0, open: 90, high: 91, low: 89, close: 90);
      p[20] = candle(
        dayIdx: 20,
        open: 101,
        high: 101,
        low: low,
        close: close,
        volume: 1000,
      );
      return p;
    }

    test('fires hammer at MA20 support within ±4%', () {
      final r = rule.evaluate(ctx(indGolden), stock(hammerPrices()));
      expect(r, isNotNull);
      expect(r!.type, ReasonType.hammerAtSupport);
      expect(r.score, 18);
    });

    test('null when low away from support (> 4%)', () {
      // low=94 距 ma20 100 = 6% > 4%；同時也離 ma60 95 = 1.05% ≤4% → 改 ma60 也遠
      final p = hammerPrices(low: 80); // 遠離 MA20(100) 與 MA60(95)
      // 重建 hammer 形狀但 low 太遠：open=101 close=100.5 high=101 low=80
      expect(rule.evaluate(ctx(indGolden), stock(p)), isNull);
    });

    test('null when bearish MA stack (ma20 <= ma60)', () {
      final ind = const TechnicalIndicators(ma20: 95, ma60: 100);
      expect(rule.evaluate(ctx(ind), stock(hammerPrices())), isNull);
    });

    test('null when not strong over past 20d', () {
      final p = hammerPrices();
      p[0] = candle(dayIdx: 0, open: 99, high: 100, low: 98, close: 99);
      expect(rule.evaluate(ctx(indGolden), stock(p)), isNull);
    });

    test('null when not hammer shape (long upper shadow)', () {
      final p = buildPrices(count: 21);
      p[0] = candle(dayIdx: 0, open: 90, high: 91, low: 89, close: 90);
      // 倒錘子：上影線長
      p[20] = candle(
        dayIdx: 20,
        open: 100,
        high: 105,
        low: 99.5,
        close: 100.5,
        volume: 1000,
      );
      expect(rule.evaluate(ctx(indGolden), stock(p)), isNull);
    });

    test('null when close in high zone (> ma20*1.06)', () {
      // close=107 > 106；但要維持 hammer 形狀
      final p = buildPrices(count: 21);
      p[0] = candle(dayIdx: 0, open: 90, high: 91, low: 89, close: 90);
      p[20] = candle(
        dayIdx: 20,
        open: 107.5,
        high: 107.5,
        low: 103,
        close: 107,
        volume: 1000,
      );
      expect(rule.evaluate(ctx(indGolden), stock(p)), isNull);
    });

    test('null on limit-down day', () {
      final p = hammerPrices();
      // yesterday=100 (baseline) → today close 89 = -11%
      p[19] = candle(dayIdx: 19, open: 100, high: 101, low: 99, close: 100);
      p[20] = candle(
        dayIdx: 20,
        open: 92,
        high: 92,
        low: 88,
        close: 89,
        volume: 1000,
      );
      expect(rule.evaluate(ctx(indGolden), stock(p)), isNull);
    });
  });

  // ============================================================
  // ETF guard — 四條回檔規則對 ETF（00 開頭）一律不觸發
  //
  // 2026-06-20 mode tab 全濾 ETF 的判斷（「ETF 走勢平滑、淺回檔幾乎
  // 天天成立 = 雜訊」）下放到 rule 層源頭：假訊號不再灌分數（掃描頁
  // 訊號區曾有 9 檔 ETF 靠 pullback 訊號進入）、校準樣本不再被污染。
  // ============================================================
  group('Regime gate（大盤非上升趨勢一律 null）', () {
    // 2026-07-10 回放分段實證：回檔進場 edge 幾乎全來自多頭 regime
    // （MA20 60D 均報酬 多頭 +6.47% vs 空頭 -0.65%、各 ~4K 樣本）。
    AnalysisContext regimeCtx(TechnicalIndicators ind, bool? uptrend) =>
        AnalysisContext(
          trendState: TrendState.up,
          evaluationTime: DateTime(2026, 1, 22),
          indicators: ind,
          isMarketUptrend: uptrend,
        );

    final ma20Ind = const TechnicalIndicators(
      ma5: 105,
      ma20: 100,
      ma60: 95,
      volumeMA20: 1000,
    );
    List<DailyPriceEntry> ma20Golden() => buildPrices(
      count: 21,
      overrides: {
        0: candle(dayIdx: 0, open: 90, high: 91, low: 89, close: 90),
        15: candle(dayIdx: 15, open: 98, high: 100, low: 97, close: 99),
        19: candle(dayIdx: 19, open: 102, high: 103, low: 101, close: 102),
        20: candle(
          dayIdx: 20,
          open: 101,
          high: 101,
          low: 99,
          close: 100,
          volume: 800,
        ),
      },
    );

    test('空頭 regime 時四條回檔規則不觸發', () {
      const rule = HealthyPullbackToMa20Rule();
      // sanity：多頭 regime 同 setup 會 fire
      expect(
        rule.evaluate(regimeCtx(ma20Ind, true), stock(ma20Golden())),
        isNotNull,
      );
      expect(
        rule.evaluate(regimeCtx(ma20Ind, false), stock(ma20Golden())),
        isNull,
      );
    });

    test('regime 未知（null）不擋——permissive 語意', () {
      const rule = HealthyPullbackToMa20Rule();
      expect(
        rule.evaluate(regimeCtx(ma20Ind, null), stock(ma20Golden())),
        isNotNull,
      );
    });

    test('MA10/Hammer/KD 三條同樣被空頭 regime 擋下', () {
      // MA10
      const ma10Rule = HealthyPullbackToMa10Rule();
      final ma10Ind = const TechnicalIndicators(
        ma10: 100,
        ma20: 95,
        ma60: 90,
        volumeMA20: 1000,
      );
      expect(
        ma10Rule.evaluate(regimeCtx(ma10Ind, false), stock(ma20Golden())),
        isNull,
      );
      // Hammer
      const hammerRule = HammerAtSupportRule();
      final hammerInd = const TechnicalIndicators(ma20: 100, ma60: 95);
      final hp = buildPrices(count: 21);
      hp[0] = candle(dayIdx: 0, open: 90, high: 91, low: 89, close: 90);
      hp[20] = candle(
        dayIdx: 20,
        open: 101,
        high: 101,
        low: 97,
        close: 100.5,
        volume: 1000,
      );
      expect(
        hammerRule.evaluate(regimeCtx(hammerInd, true), stock(hp)),
        isNotNull,
      );
      expect(
        hammerRule.evaluate(regimeCtx(hammerInd, false), stock(hp)),
        isNull,
      );
      // KD
      const kdRule = KdHighLevelPullbackRule();
      final kdInd = const TechnicalIndicators(
        kdK: 70,
        kdD: 65,
        prevKdK: 85,
        ma20: 100,
        ma60: 95,
      );
      final kp = buildPrices(count: 21);
      kp[20] = candle(dayIdx: 20, open: 100, high: 101, low: 99, close: 100);
      expect(kdRule.evaluate(regimeCtx(kdInd, true), stock(kp)), isNotNull);
      expect(kdRule.evaluate(regimeCtx(kdInd, false), stock(kp)), isNull);
    });
  });

  group('ETF guard（00 開頭代碼一律 null）', () {
    StockData etf(List<DailyPriceEntry> prices) =>
        StockData(symbol: '00878', prices: prices);

    test('HealthyPullbackToMa20Rule 對 ETF 不觸發（同 setup 個股會 fire）', () {
      const rule = HealthyPullbackToMa20Rule();
      final ind = const TechnicalIndicators(
        ma5: 105,
        ma20: 100,
        ma60: 95,
        volumeMA20: 1000,
      );
      final prices = buildPrices(
        count: 21,
        overrides: {
          0: candle(dayIdx: 0, open: 90, high: 91, low: 89, close: 90),
          15: candle(dayIdx: 15, open: 98, high: 100, low: 97, close: 99),
          19: candle(dayIdx: 19, open: 102, high: 103, low: 101, close: 102),
          20: candle(
            dayIdx: 20,
            open: 101,
            high: 101,
            low: 99,
            close: 100,
            volume: 800,
          ),
        },
      );
      // sanity：同 setup 個股確實 fire（測試有區分力）
      expect(rule.evaluate(ctx(ind), stock(prices)), isNotNull);
      expect(rule.evaluate(ctx(ind), etf(prices)), isNull);
    });

    test('HealthyPullbackToMa10Rule 對 ETF 不觸發', () {
      const rule = HealthyPullbackToMa10Rule();
      final ind = const TechnicalIndicators(
        ma10: 100,
        ma20: 95,
        ma60: 90,
        volumeMA20: 1000,
      );
      final prices = buildPrices(
        count: 21,
        overrides: {
          0: candle(dayIdx: 0, open: 90, high: 91, low: 89, close: 90),
          15: candle(dayIdx: 15, open: 98, high: 100, low: 97, close: 99),
          19: candle(dayIdx: 19, open: 102, high: 103, low: 101, close: 102),
          20: candle(
            dayIdx: 20,
            open: 101,
            high: 101,
            low: 99,
            close: 100,
            volume: 800,
          ),
        },
      );
      expect(rule.evaluate(ctx(ind), stock(prices)), isNotNull);
      expect(rule.evaluate(ctx(ind), etf(prices)), isNull);
    });

    test('HammerAtSupportRule 對 ETF 不觸發', () {
      const rule = HammerAtSupportRule();
      final ind = const TechnicalIndicators(ma20: 100, ma60: 95);
      final prices = buildPrices(count: 21);
      prices[0] = candle(dayIdx: 0, open: 90, high: 91, low: 89, close: 90);
      prices[20] = candle(
        dayIdx: 20,
        open: 101,
        high: 101,
        low: 97,
        close: 100.5,
        volume: 1000,
      );
      expect(rule.evaluate(ctx(ind), stock(prices)), isNotNull);
      expect(rule.evaluate(ctx(ind), etf(prices)), isNull);
    });

    test('KdHighLevelPullbackRule 對 ETF 不觸發', () {
      const rule = KdHighLevelPullbackRule();
      final kdCtx = AnalysisContext(
        trendState: TrendState.up,
        evaluationTime: DateTime(2026, 1, 22),
        indicators: const TechnicalIndicators(
          kdK: 70,
          kdD: 65,
          prevKdK: 85,
          ma20: 100,
          ma60: 95,
        ),
      );
      final prices = buildPrices(count: 21);
      prices[20] = candle(
        dayIdx: 20,
        open: 100,
        high: 101,
        low: 99,
        close: 100,
      );
      expect(rule.evaluate(kdCtx, stock(prices)), isNotNull);
      expect(rule.evaluate(kdCtx, etf(prices)), isNull);
    });
  });
}
