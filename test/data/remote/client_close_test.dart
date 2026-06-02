// Smoke tests — confirm close() on each Dio-holding client is safe to call.
//
// 驗證 4 個新加的 close() 方法行為：
//   1. 呼叫 close() 不會 throw
//   2. 重複呼叫不會 throw（Dio.close() 本身允許重複呼叫）
//
// 不驗證 socket FD 釋放等系統層細節 — 那是 Dio 自己的 contract。
// 這份 smoke test 的存在意義：未來改 close() 實作（加 cache clear、加
// timer cancel 等）若意外 throw 會被立刻發現。

import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/remote/rss_parser.dart';
import 'package:afterclose/data/remote/tdcc_client.dart';
import 'package:afterclose/data/remote/tpex_client.dart';
import 'package:afterclose/data/remote/twse_client.dart';

void main() {
  group('client close() smoke tests', () {
    test('TwseClient.close() does not throw', () {
      final client = TwseClient();
      expect(() => client.close(), returnsNormally);
    });

    test('TwseClient.close() is idempotent', () {
      final client = TwseClient();
      client.close();
      expect(() => client.close(), returnsNormally);
    });

    test('TpexClient.close() does not throw', () {
      final client = TpexClient();
      expect(() => client.close(), returnsNormally);
    });

    test('TpexClient.close() is idempotent', () {
      final client = TpexClient();
      client.close();
      expect(() => client.close(), returnsNormally);
    });

    test('TdccClient.close() does not throw', () {
      final client = TdccClient();
      expect(() => client.close(), returnsNormally);
    });

    test('TdccClient.close() is idempotent', () {
      final client = TdccClient();
      client.close();
      expect(() => client.close(), returnsNormally);
    });

    test('RssParser.close() does not throw', () {
      final parser = RssParser();
      expect(() => parser.close(), returnsNormally);
    });

    test('RssParser.close() is idempotent', () {
      final parser = RssParser();
      parser.close();
      expect(() => parser.close(), returnsNormally);
    });
  });
}
