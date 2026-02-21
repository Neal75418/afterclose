import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:afterclose/presentation/providers/watchlist_types.dart';
import 'package:afterclose/presentation/widgets/warning_badge.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    EasyLocalization.logger.enableLevels = [];
  });

  // ==================================================
  // WatchlistSort
  // ==================================================

  group('WatchlistSort', () {
    test('has 7 values', () {
      expect(WatchlistSort.values, hasLength(7));
    });

    test('each has non-empty label', () {
      for (final sort in WatchlistSort.values) {
        expect(sort.label, isNotEmpty, reason: sort.name);
      }
    });
  });

  // ==================================================
  // WatchlistGroup
  // ==================================================

  group('WatchlistGroup', () {
    test('has 3 values', () {
      expect(WatchlistGroup.values, hasLength(3));
    });

    test('contains none, status, trend', () {
      expect(WatchlistGroup.values, contains(WatchlistGroup.none));
      expect(WatchlistGroup.values, contains(WatchlistGroup.status));
      expect(WatchlistGroup.values, contains(WatchlistGroup.trend));
    });

    test('each has non-empty label', () {
      for (final group in WatchlistGroup.values) {
        expect(group.label, isNotEmpty, reason: group.name);
      }
    });
  });

  // ==================================================
  // WatchlistStatus
  // ==================================================

  group('WatchlistStatus', () {
    test('has 3 values', () {
      expect(WatchlistStatus.values, hasLength(3));
    });

    test('signal icon is fire', () {
      expect(WatchlistStatus.signal.icon, '🔥');
    });

    test('volatile icon is eyes', () {
      expect(WatchlistStatus.volatile.icon, '👀');
    });

    test('quiet icon is sleeping', () {
      expect(WatchlistStatus.quiet.icon, '😴');
    });

    test('each has non-empty label', () {
      for (final status in WatchlistStatus.values) {
        expect(status.label, isNotEmpty, reason: status.name);
      }
    });
  });

  // ==================================================
  // WatchlistTrend
  // ==================================================

  group('WatchlistTrend', () {
    test('has 3 values', () {
      expect(WatchlistTrend.values, hasLength(3));
    });

    test('up icon is chart up', () {
      expect(WatchlistTrend.up.icon, '📈');
    });

    test('down icon is chart down', () {
      expect(WatchlistTrend.down.icon, '📉');
    });

    test('sideways icon is arrow right', () {
      expect(WatchlistTrend.sideways.icon, '➡️');
    });

    test('each has non-empty label', () {
      for (final trend in WatchlistTrend.values) {
        expect(trend.label, isNotEmpty, reason: trend.name);
      }
    });
  });

  // ==================================================
  // WatchlistItemData
  // ==================================================

  group('WatchlistItemData', () {
    test('minimal constructor', () {
      const item = WatchlistItemData(symbol: '2330');
      expect(item.symbol, '2330');
      expect(item.stockName, isNull);
      expect(item.market, isNull);
      expect(item.latestClose, isNull);
      expect(item.priceChange, isNull);
      expect(item.trendState, isNull);
      expect(item.score, isNull);
      expect(item.hasSignal, isFalse);
      expect(item.addedAt, isNull);
      expect(item.recentPrices, isEmpty);
      expect(item.reasons, isEmpty);
      expect(item.warningType, isNull);
    });

    test('full constructor', () {
      final item = WatchlistItemData(
        symbol: '2330',
        stockName: '台積電',
        market: 'TWSE',
        latestClose: 600.0,
        priceChange: 2.5,
        trendState: 'UP',
        score: 80.0,
        hasSignal: true,
        addedAt: DateTime(2026, 1, 1),
        recentPrices: [590.0, 595.0, 600.0],
        reasons: ['VOLUME_SPIKE'],
        warningType: WarningBadgeType.attention,
      );
      expect(item.symbol, '2330');
      expect(item.stockName, '台積電');
      expect(item.warningType, WarningBadgeType.attention);
    });
  });

  group('WatchlistItemData.status', () {
    test('returns signal when hasSignal is true', () {
      const item = WatchlistItemData(symbol: '2330', hasSignal: true);
      expect(item.status, WatchlistStatus.signal);
    });

    test('returns volatile when priceChange >= 3', () {
      const item = WatchlistItemData(symbol: '2330', priceChange: 3.0);
      expect(item.status, WatchlistStatus.volatile);
    });

    test('returns volatile when priceChange <= -3', () {
      const item = WatchlistItemData(symbol: '2330', priceChange: -5.0);
      expect(item.status, WatchlistStatus.volatile);
    });

    test('returns quiet when priceChange < 3', () {
      const item = WatchlistItemData(symbol: '2330', priceChange: 2.0);
      expect(item.status, WatchlistStatus.quiet);
    });

    test('returns quiet when priceChange is null', () {
      const item = WatchlistItemData(symbol: '2330');
      expect(item.status, WatchlistStatus.quiet);
    });

    test('signal takes priority over volatile', () {
      const item = WatchlistItemData(
        symbol: '2330',
        hasSignal: true,
        priceChange: 10.0,
      );
      expect(item.status, WatchlistStatus.signal);
    });
  });

  group('WatchlistItemData.trend', () {
    test('UP → WatchlistTrend.up', () {
      const item = WatchlistItemData(symbol: '2330', trendState: 'UP');
      expect(item.trend, WatchlistTrend.up);
    });

    test('DOWN → WatchlistTrend.down', () {
      const item = WatchlistItemData(symbol: '2330', trendState: 'DOWN');
      expect(item.trend, WatchlistTrend.down);
    });

    test('SIDEWAYS → WatchlistTrend.sideways', () {
      const item = WatchlistItemData(symbol: '2330', trendState: 'SIDEWAYS');
      expect(item.trend, WatchlistTrend.sideways);
    });

    test('null → WatchlistTrend.sideways', () {
      const item = WatchlistItemData(symbol: '2330');
      expect(item.trend, WatchlistTrend.sideways);
    });

    test('unknown string → WatchlistTrend.sideways', () {
      const item = WatchlistItemData(symbol: '2330', trendState: 'UNKNOWN');
      expect(item.trend, WatchlistTrend.sideways);
    });
  });

  group('WatchlistItemData.statusIcon', () {
    test('delegates to status.icon', () {
      const signalItem = WatchlistItemData(symbol: '2330', hasSignal: true);
      expect(signalItem.statusIcon, '🔥');

      const quietItem = WatchlistItemData(symbol: '2330');
      expect(quietItem.statusIcon, '😴');
    });
  });
}
