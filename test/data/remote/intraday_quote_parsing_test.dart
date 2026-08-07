import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:daredevil/data/models/twse/intraday_quote.dart';

/// 盤中即時報價解析(TWSE MIS,2026-08-08)。
///
/// fixture 為 2026-08-08 live 快照(收盤後取,含 2330/3231/6538 三檔)。
/// 這支 API 的價格欄位在**盤中無成交時會是 '-'**,且欄位名極短,踩過的
/// 坑要靠 fixture 鎖住。
void main() {
  final raw =
      jsonDecode(
            File('test/fixtures/twse_mis_intraday.json').readAsStringSync(),
          )
          as Map<String, dynamic>;

  test('🚨 fixture 全量解析,價格與昨收正確', () {
    final quotes = IntradayQuote.parseResponse(raw);
    expect(quotes.length, 3);

    final tsmc = quotes['2330']!;
    expect(tsmc.name, '台積電');
    expect(tsmc.price, 2370.0);
    expect(tsmc.previousClose, 2365.0);
    expect(tsmc.high, 2395.0);
    expect(tsmc.low, 2355.0);
  });

  test('rtcode 非 0000 → 視為失敗回空(不把錯誤當報價用)', () {
    expect(IntradayQuote.parseResponse({'rtcode': '5001'}), isEmpty);
    expect(IntradayQuote.parseResponse(const {}), isEmpty);
  });

  test('🚨 成交價為 "-"(無成交)時退回 pz/o,再退回昨收', () {
    // MIS 在無成交時 z='-';盤前更可能連 pz 都沒有
    final noTrade = {
      'rtcode': '0000',
      'msgArray': [
        {'c': '9999', 'n': 'X', 'z': '-', 'pz': '105.0', 'y': '100.0'},
        {'c': '8888', 'n': 'Y', 'z': '-', 'o': '99.0', 'y': '100.0'},
        {'c': '7777', 'n': 'Z', 'z': '-', 'y': '100.0'},
      ],
    };
    final q = IntradayQuote.parseResponse(noTrade);
    expect(q['9999']!.price, 105.0, reason: 'z 無效 → 取 pz(試撮價)');
    expect(q['8888']!.price, 99.0, reason: 'pz 也無 → 取開盤');
    expect(q['7777']!.price, 100.0, reason: '全無 → 退回昨收,不給 0');
  });

  test('代號或昨收缺失的列直接丟棄(不產生無效報價)', () {
    final dirty = {
      'rtcode': '0000',
      'msgArray': [
        {'c': '', 'z': '100.0', 'y': '99.0'},
        {'c': '1234', 'z': '-', 'y': '-'},
        {'c': '5678', 'z': '50.0', 'y': '49.0'},
      ],
    };
    final q = IntradayQuote.parseResponse(dirty);
    expect(q.keys.toList(), ['5678']);
  });

  test('漲跌幅由現價與昨收算出', () {
    final q = IntradayQuote.parseResponse(raw)['2330']!;
    expect(q.changePercent, closeTo((2370 / 2365 - 1) * 100, 1e-9));
  });
}
