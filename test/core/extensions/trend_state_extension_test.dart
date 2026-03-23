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

    group('case sensitivity', () {
      test('lowercase up uses default emoji', () {
        const trend = 'up';
        expect(trend.trendEmoji, equals('➡️'));
      });

      test('lowercase down uses default emoji', () {
        const trend = 'down';
        expect(trend.trendEmoji, equals('➡️'));
      });

      test('mixed case Up uses default emoji', () {
        const trend = 'Up';
        expect(trend.trendEmoji, equals('➡️'));
      });
    });
  });
}
