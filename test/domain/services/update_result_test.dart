import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/domain/services/update_service.dart';

void main() {
  group('UpdateResult', () {
    late UpdateResult result;

    setUp(() {
      result = UpdateResult(date: DateTime(2026, 1, 15));
    });

    group('recordError', () {
      test('should add error message to errors list', () {
        result.recordError('價格同步失敗', Exception('timeout'));

        expect(result.errors, ['價格同步失敗']);
      });

      test(
        'should set hasRateLimitError when exception is RateLimitException',
        () {
          expect(result.hasRateLimitError, isFalse);

          result.recordError('價格同步失敗: rate limit', const RateLimitException());

          expect(result.hasRateLimitError, isTrue);
          expect(result.errors, hasLength(1));
        },
      );

      test('should not set hasRateLimitError for other exceptions', () {
        result.recordError('DB 錯誤', const DatabaseException('connection'));

        expect(result.hasRateLimitError, isFalse);
      });

      test('should accumulate multiple errors', () {
        result.recordError('Error 1', Exception('e1'));
        result.recordError('Error 2', const RateLimitException());
        result.recordError('Error 3', Exception('e3'));

        expect(result.errors, hasLength(3));
        expect(result.hasRateLimitError, isTrue);
      });
    });

    group('summary', () {
      test('should return skip message when skipped', () {
        result.skipped = true;
        result.message = '非交易日';

        expect(result.summary, '非交易日');
      });

      test('should return default skip message when message is null', () {
        result.skipped = true;

        expect(result.summary, '跳過更新');
      });

      test('should return failure message with errors when not success', () {
        result.success = false;
        result.errors.add('價格失敗');
        result.errors.add('法人失敗');

        expect(result.summary, '更新失敗: 價格失敗, 法人失敗');
      });

      test('should return success summary with counts', () {
        result.success = true;
        result.stocksAnalyzed = 150;
        result.recommendationsGenerated = 10;

        expect(result.summary, '分析 150 檔，產生 10 個推薦');
      });
    });
  });
}
