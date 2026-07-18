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

    group('trendColorFor', () {
      // 斷言對象是「與 getPriceColor 解析出同一個色」而非各別常數：
      // 常數等式（trendColor == AppTheme.upColor）兩邊指向同一份宣告，
      // 改壞色值時一起變、恆為真，抓不到漂移。改對照 getPriceColor 後，
      // 色值本身的合格性由 semantic_colors_test 的對比度守門負責，
      // 這裡只負責「趨勢有沒有對應到正確的多空方向與正確的主題側」。
      for (final brightness in Brightness.values) {
        test('UP 對應上漲色（$brightness）', () {
          const trend = 'UP';
          expect(
            trend.trendColorFor(brightness),
            equals(AppTheme.getPriceColor(1, brightness)),
          );
        });

        test('DOWN 對應下跌色（$brightness）', () {
          const trend = 'DOWN';
          expect(
            trend.trendColorFor(brightness),
            equals(AppTheme.getPriceColor(-1, brightness)),
          );
        });

        for (final flat in <String?>['SIDEWAYS', null, 'RANGE']) {
          test('${flat ?? 'null'} 對應平盤色（$brightness）', () {
            expect(
              flat.trendColorFor(brightness),
              equals(AppTheme.getFlatColor(brightness)),
            );
          });
        }
      }

      test('淺色主題的下跌與平盤不得沿用深色主題色值', () {
        // trendColor 舊實作恆回傳深色色值，淺色主題下 #2ED573 對白底
        // 1.93:1、#A1A1A1 2.58:1，兩個消費端（stock_card 趨勢圖示、
        // stock_detail_header 趨勢 chip）都因此低於圖形物件門檻。
        expect(
          'DOWN'.trendColorFor(Brightness.light),
          isNot('DOWN'.trendColorFor(Brightness.dark)),
        );
        expect(
          'SIDEWAYS'.trendColorFor(Brightness.light),
          isNot('SIDEWAYS'.trendColorFor(Brightness.dark)),
        );
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
