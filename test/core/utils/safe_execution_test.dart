import 'dart:async';
import 'package:daredevil/core/exceptions/app_exception.dart';
import 'package:daredevil/core/utils/safe_execution.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('guardSync', () {
    test('成功時回傳 action 結果、不記錄錯誤', () async {
      final errors = <String>[];

      final result = await guardSync(
        tag: 'T',
        label: '測試同步',
        fallback: 0,
        errors: errors,
        errorLabel: '測試',
        action: () async => 42,
      );

      expect(result, 42);
      expect(errors, isEmpty);
    });

    test('RateLimitException 必須 rethrow', () async {
      await expectLater(
        guardSync<int>(
          tag: 'T',
          label: '測試同步',
          fallback: 0,
          action: () async => throw const RateLimitException(),
        ),
        throwsA(isA<RateLimitException>()),
      );
    });

    test('NetworkException 必須 rethrow', () async {
      await expectLater(
        guardSync<int>(
          tag: 'T',
          label: '測試同步',
          fallback: 0,
          action: () async => throw const NetworkException('down'),
        ),
        throwsA(isA<NetworkException>()),
      );
    });

    test('generic 失敗回 fallback 並收集到 errors', () async {
      final errors = <String>[];

      final result = await guardSync(
        tag: 'T',
        label: '測試同步',
        fallback: -1,
        errors: errors,
        errorLabel: '全市場估值',
        action: () async => throw Exception('boom'),
      );

      expect(result, -1);
      expect(errors, hasLength(1));
      expect(errors.first, startsWith('全市場估值: '));
    });

    test('未提供 errors 時 generic 失敗僅回 fallback（log-only）', () async {
      final result = await guardSync(
        tag: 'T',
        label: '測試同步',
        fallback: 7,
        action: () async => throw Exception('boom'),
      );

      expect(result, 7);
    });
  });

  group('awaitPairSettled / safeAwaitPair(2026-07-30 async 衛生)', () {
    test('雙來源同時 NetworkException:rethrow 一個、零 unhandled async error', () async {
      final unhandled = <Object>[];
      await runZonedGuarded(() async {
        Future<List<int>> failing() async {
          throw const NetworkException('斷網', null);
        }

        // zone 內不可用 expectLater:斷言失敗的 error 無法跨 zone 邊界,
        // 會卡滿 30s timeout 而非乾淨失敗(同 warning_repository_test 教訓)
        Object? thrown;
        try {
          await safeAwaitPair(
            failing(),
            failing(),
            firstDefault: const <int>[],
            secondDefault: const <int>[],
            tag: 'T',
            firstDescription: 'a 失敗',
            secondDescription: 'b 失敗',
          );
        } catch (e) {
          thrown = e;
        }
        expect(thrown, isA<NetworkException>());
        // 讓可能的無主 rejection 有機會浮出
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
      }, (e, st) => unhandled.add(e));
      expect(
        unhandled,
        isEmpty,
        reason:
            '舊寫法(先啟動再逐一 await)在第一個 rethrow 後,第二個 '
            'future 的 rejection 無人監聽 → zone 層 unhandled;pair helper '
            '必須同時掛好兩邊 listener',
      );
    });

    test('RateLimitException 優先 rethrow(即使另一邊是 generic 失敗)', () async {
      Future<int> rateLimited() async =>
          throw const RateLimitException('429', null);
      Future<int> generic() async => throw StateError('boom');
      await expectLater(
        safeAwaitPair(
          generic(),
          rateLimited(),
          firstDefault: -1,
          secondDefault: -1,
          tag: 'T',
          firstDescription: 'a',
          secondDescription: 'b',
        ),
        throwsA(isA<RateLimitException>()),
      );
    });

    test('generic 失敗各自 fallback,另一邊成功值保留', () async {
      Future<int> ok() async => 42;
      Future<int> generic() async => throw StateError('boom');
      final (a, b) = await safeAwaitPair(
        ok(),
        generic(),
        firstDefault: -1,
        secondDefault: -1,
        tag: 'T',
        firstDescription: 'a',
        secondDescription: 'b',
      );
      expect(a, 42);
      expect(b, -1);
    });

    test('兩邊皆成功直接回傳', () async {
      final (a, b) = await safeAwaitPair(
        Future.value(1),
        Future.value('x'),
        firstDefault: 0,
        secondDefault: '',
        tag: 'T',
        firstDescription: 'a',
        secondDescription: 'b',
      );
      expect((a, b), (1, 'x'));
    });

    test('awaitPairSettled 提供 per-source 錯誤(呼叫端要旗標的場景)', () async {
      Future<int> ok() async => 7;
      Future<int> generic() async => throw StateError('boom');
      final (r1, r2) = await awaitPairSettled(ok(), generic());
      expect(r1.value, 7);
      expect(r1.error, isNull);
      expect(r2.error, isA<StateError>());
    });
  });
}
