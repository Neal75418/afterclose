import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/safe_execution.dart';
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
}
