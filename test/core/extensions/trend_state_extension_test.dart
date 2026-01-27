import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/extensions/trend_state_extension.dart';
import 'package:afterclose/core/theme/app_theme.dart';

void main() {
  group('TrendStateExtension', () {
    group('trendEmoji', () {
      test('returns up emoji for UP trend', () {
        const trend = 'UP';
        expect(trend.trendEmoji, equals('📈'));
      });

      test('returns down emoji for DOWN trend', () {
        const trend = 'DOWN';
        expect(trend.trendEmoji, equals('📉'));
      });

      test('returns sideways emoji for SIDEWAYS trend', () {
        const trend = 'SIDEWAYS';
        expect(trend.trendEmoji, equals('➡️'));
      });

      test('returns sideways emoji for RANGE trend', () {
        const trend = 'RANGE';
        expect(trend.trendEmoji, equals('➡️'));
      });

      test('returns sideways emoji for null', () {
        const String? trend = null;
        expect(trend.trendEmoji, equals('➡️'));
      });

      test('returns sideways emoji for unknown value', () {
        const trend = 'UNKNOWN';
        expect(trend.trendEmoji, equals('➡️'));
      });

      test('returns sideways emoji for empty string', () {
        const trend = '';
        expect(trend.trendEmoji, equals('➡️'));
      });
    });

    group('trendIconData', () {
      test('returns trending_up_rounded for UP trend', () {
        const trend = 'UP';
        expect(trend.trendIconData, equals(Icons.trending_up_rounded));
      });

      test('returns trending_down_rounded for DOWN trend', () {
        const trend = 'DOWN';
        expect(trend.trendIconData, equals(Icons.trending_down_rounded));
      });

      test('returns trending_flat_rounded for SIDEWAYS trend', () {
        const trend = 'SIDEWAYS';
        expect(trend.trendIconData, equals(Icons.trending_flat_rounded));
      });

      test('returns trending_flat_rounded for null', () {
        const String? trend = null;
        expect(trend.trendIconData, equals(Icons.trending_flat_rounded));
      });

      test('returns trending_flat_rounded for unknown value', () {
        const trend = 'INVALID';
        expect(trend.trendIconData, equals(Icons.trending_flat_rounded));
      });
    });

    group('trendColor', () {
      test('returns upColor for UP trend', () {
        const trend = 'UP';
        expect(trend.trendColor, equals(AppTheme.upColor));
      });

      test('returns downColor for DOWN trend', () {
        const trend = 'DOWN';
        expect(trend.trendColor, equals(AppTheme.downColor));
      });

      test('returns neutralColor for SIDEWAYS trend', () {
        const trend = 'SIDEWAYS';
        expect(trend.trendColor, equals(AppTheme.neutralColor));
      });

      test('returns neutralColor for null', () {
        const String? trend = null;
        expect(trend.trendColor, equals(AppTheme.neutralColor));
      });

      test('returns neutralColor for RANGE trend', () {
        const trend = 'RANGE';
        expect(trend.trendColor, equals(AppTheme.neutralColor));
      });
    });

    group('trendKey', () {
      test('returns up for UP trend', () {
        const trend = 'UP';
        expect(trend.trendKey, equals('up'));
      });

      test('returns down for DOWN trend', () {
        const trend = 'DOWN';
        expect(trend.trendKey, equals('down'));
      });

      test('returns sideways for SIDEWAYS trend', () {
        const trend = 'SIDEWAYS';
        expect(trend.trendKey, equals('sideways'));
      });

      test('returns sideways for null', () {
        const String? trend = null;
        expect(trend.trendKey, equals('sideways'));
      });

      test('returns sideways for unknown value', () {
        const trend = 'UNKNOWN';
        expect(trend.trendKey, equals('sideways'));
      });
    });

    group('boolean helpers', () {
      test('isUpTrend returns true for UP', () {
        const trend = 'UP';
        expect(trend.isUpTrend, isTrue);
      });

      test('isUpTrend returns false for DOWN', () {
        const trend = 'DOWN';
        expect(trend.isUpTrend, isFalse);
      });

      test('isUpTrend returns false for null', () {
        const String? trend = null;
        expect(trend.isUpTrend, isFalse);
      });

      test('isDownTrend returns true for DOWN', () {
        const trend = 'DOWN';
        expect(trend.isDownTrend, isTrue);
      });

      test('isDownTrend returns false for UP', () {
        const trend = 'UP';
        expect(trend.isDownTrend, isFalse);
      });

      test('isDownTrend returns false for null', () {
        const String? trend = null;
        expect(trend.isDownTrend, isFalse);
      });

      test('isSidewaysTrend returns true for SIDEWAYS', () {
        const trend = 'SIDEWAYS';
        expect(trend.isSidewaysTrend, isTrue);
      });

      test('isSidewaysTrend returns true for null', () {
        const String? trend = null;
        expect(trend.isSidewaysTrend, isTrue);
      });

      test('isSidewaysTrend returns true for RANGE', () {
        const trend = 'RANGE';
        expect(trend.isSidewaysTrend, isTrue);
      });

      test('isSidewaysTrend returns false for UP', () {
        const trend = 'UP';
        expect(trend.isSidewaysTrend, isFalse);
      });

      test('isSidewaysTrend returns false for DOWN', () {
        const trend = 'DOWN';
        expect(trend.isSidewaysTrend, isFalse);
      });
    });

    group('case sensitivity', () {
      test('lowercase up is not recognized as UP', () {
        const trend = 'up';
        expect(trend.isUpTrend, isFalse);
        expect(trend.isSidewaysTrend, isTrue);
      });

      test('lowercase down is not recognized as DOWN', () {
        const trend = 'down';
        expect(trend.isDownTrend, isFalse);
        expect(trend.isSidewaysTrend, isTrue);
      });

      test('mixed case Up is not recognized as UP', () {
        const trend = 'Up';
        expect(trend.isUpTrend, isFalse);
        expect(trend.trendEmoji, equals('➡️'));
      });
    });
  });
}
