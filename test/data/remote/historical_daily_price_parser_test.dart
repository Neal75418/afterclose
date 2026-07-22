// 歷史全市場行情 parser 測試（資料缺口修復）
//
// 背景：TWSE STOCK_DAY_ALL 與 TPEx daily_close_quotes 自 2026-06 起忽略
// 歷史 date 參數（memory: afterclose_twse_stock_day_all_no_date）。
// 替代端點（2026-07-12 活體驗證）：
//   TWSE  MI_INDEX?date=yyyyMMdd&type=ALLBUT0999 → tables[] 內含
//         「每日收盤行情」表（fields 以 證券代號 開頭）
//   TPEx  /www/zh-tw/afterTrading/otc?date=yyyy/MM/dd&type=EW
// fixture 取自真實回應削減版。
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/remote/tpex_client.dart';
import 'package:afterclose/data/remote/twse_client.dart';

void main() {
  group('TwseClient.parseMiIndexDailyPrices', () {
    final fixture = {
      'stat': 'OK',
      'date': '20240315',
      'tables': [
        {
          'title': '113年03月15日 價格指數(臺灣證券交易所)',
          'fields': ['指數', '收盤指數'],
          'data': [
            ['寶島股價指數', '22,467.27'],
          ],
        },
        {
          'title': '113年03月15日 每日收盤行情(全部(不含權證、牛熊證))',
          'fields': [
            '證券代號',
            '證券名稱',
            '成交股數',
            '成交筆數',
            '成交金額',
            '開盤價',
            '最高價',
            '最低價',
            '收盤價',
            '漲跌(+/-)',
            '漲跌價差',
            '最後揭示買價',
            '最後揭示買量',
            '最後揭示賣價',
            '最後揭示賣量',
            '本益比',
          ],
          'data': [
            [
              '2330',
              '台積電',
              '30,000,000',
              '50,000',
              '30,000,000,000',
              '1,000.00',
              '1,010.00',
              '990.00',
              '995.00',
              '<p style= color:green>-</p>',
              '5.00',
              '994.00',
              '1',
              '995.00',
              '2',
              '25.00',
            ],
            [
              '0056',
              '元大高股息',
              '28,781,228',
              '17,472',
              '1,118,671,837',
              '38.71',
              '39.03',
              '38.64',
              '39.02',
              '<p style= color:red>+</p>',
              '0.30',
              '39.01',
              '1',
              '39.02',
              '231',
              '0.00',
            ],
            // 停牌股：價格欄 '--'
            [
              '9999',
              '停牌股',
              '0',
              '0',
              '0',
              '--',
              '--',
              '--',
              '--',
              '<p> </p>',
              '0.00',
              '--',
              '0',
              '--',
              '0',
              '0.00',
            ],
          ],
        },
      ],
    };

    test('取「每日收盤行情」表、欄位對映與漲跌號正確', () {
      final prices = TwseClient.parseMiIndexDailyPrices(
        fixture,
        DateTime(2024, 3, 15),
      );
      expect(prices.length, 3);

      final tsmc = prices.firstWhere((p) => p.code == '2330');
      expect(tsmc.date, DateTime(2024, 3, 15));
      expect(tsmc.open, 1000.0);
      expect(tsmc.high, 1010.0);
      expect(tsmc.low, 990.0);
      expect(tsmc.close, 995.0);
      expect(tsmc.volume, 30000000);
      expect(tsmc.change, -5.0, reason: '漲跌號 (-) × 漲跌價差 5.00');

      final etf = prices.firstWhere((p) => p.code == '0056');
      expect(etf.change, 0.30, reason: '漲跌號 (+) × 0.30');
    });

    test('停牌股（-- 價格）→ 欄位為 null、不 crash', () {
      final prices = TwseClient.parseMiIndexDailyPrices(
        fixture,
        DateTime(2024, 3, 15),
      );
      final halted = prices.firstWhere((p) => p.code == '9999');
      expect(halted.close, isNull);
      expect(halted.open, isNull);
    });

    test('回應日期 ≠ 請求日期 → 回空（端點失效防護，同 backfill 原則）', () {
      final prices = TwseClient.parseMiIndexDailyPrices(
        fixture,
        DateTime(2024, 3, 18), // 請求 18 號、fixture 是 15 號
      );
      expect(prices, isEmpty);
    });

    test('無收盤行情表（假日 stat 異常）→ 空', () {
      final holiday = {'stat': 'OK', 'date': '20240316', 'tables': <Object>[]};
      expect(
        TwseClient.parseMiIndexDailyPrices(holiday, DateTime(2024, 3, 16)),
        isEmpty,
      );
    });
  });

  group('TpexClient.parseAfterTradingOtcDailyPrices', () {
    final fixture = {
      'stat': 'ok',
      'date': '20240315',
      'tables': [
        {
          'title': '上櫃股票每日收盤行情(不含定價)',
          'fields': [
            '代號',
            '名稱',
            '收盤 ',
            '漲跌',
            '開盤 ',
            '最高 ',
            '最低',
            '成交股數  ',
            ' 成交金額(元)',
            ' 成交筆數 ',
          ],
          'data': [
            [
              '5347',
              '世界',
              '95.10',
              '-1.20',
              '96.00',
              '96.50',
              '94.80',
              '12,345,678',
              '1,175,000,000',
              '8,888',
            ],
            [
              '006201',
              '元大富櫃50',
              '46.85',
              '+0.51',
              '46.52',
              '47.80',
              '46.52',
              '200,019',
              '7,273,620',
              '28',
            ],
            // 除息日漲跌欄非數字
            [
              '4444',
              '除息股',
              '50.00',
              '除息',
              '49.80',
              '50.20',
              '49.50',
              '1,000',
              '50,000',
              '10',
            ],
          ],
        },
      ],
    };

    test('欄位對映（TPEx 收盤在前、成交股數在第 8 欄）', () {
      final prices = TpexClient.parseAfterTradingOtcDailyPrices(
        fixture,
        DateTime(2024, 3, 15),
      );
      expect(prices.length, 3);

      final v = prices.firstWhere((p) => p.code == '5347');
      expect(v.date, DateTime(2024, 3, 15));
      expect(v.close, 95.10);
      expect(v.change, -1.20);
      expect(v.open, 96.00);
      expect(v.high, 96.50);
      expect(v.low, 94.80);
      expect(v.volume, 12345678);
    });

    test('漲跌欄非數字（除息）→ change null、其餘照常', () {
      final prices = TpexClient.parseAfterTradingOtcDailyPrices(
        fixture,
        DateTime(2024, 3, 15),
      );
      final ex = prices.firstWhere((p) => p.code == '4444');
      expect(ex.change, isNull);
      expect(ex.close, 50.0);
    });

    test('回應日期 ≠ 請求日期 → 空（TPEx 舊端點正是這樣壞的）', () {
      expect(
        TpexClient.parseAfterTradingOtcDailyPrices(
          fixture,
          DateTime(2024, 3, 18),
        ),
        isEmpty,
      );
    });
  });
}
