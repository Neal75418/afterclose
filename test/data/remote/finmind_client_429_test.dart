// 429 不做 client 端重試（2026-07-23 稽核修復）
//
// FinMind 是小時配額型限流：429 重試只會再燒配額（每次 retry 還會
// recordCall 進預算追蹤），正確路徑是立即拋 RateLimitException →
// 預算 cooldown → rateLimitedAbort 止血。原 _isRetryable 有 429 特例
// 會退避重試 3 次，與 MarketClientMixin（4xx 一律不重試）不一致。
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/data/remote/finmind_client.dart';

class MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
  });

  test('429 → 立即拋 RateLimitException、不重試（恰好 1 次請求）', () async {
    final mockDio = MockDio();
    var calls = 0;
    when(
      () => mockDio.get<dynamic>(
        any(),
        queryParameters: any(named: 'queryParameters'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((inv) async {
      calls++;
      throw DioException(
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/data'),
          statusCode: 429,
        ),
        requestOptions: RequestOptions(path: '/data'),
      );
    });
    final client = FinMindClient(dio: mockDio, baseDelay: Duration.zero);

    await expectLater(
      () => client.getDailyPrices(stockId: '2330', startDate: '2026-07-01'),
      throwsA(isA<RateLimitException>()),
    );
    expect(calls, 1, reason: '429 不得重試（原 bug：退避重試 3 次多燒配額）');
  });

  test('5xx 仍照常重試後拋 NetworkException', () async {
    final mockDio = MockDio();
    var calls = 0;
    when(
      () => mockDio.get<dynamic>(
        any(),
        queryParameters: any(named: 'queryParameters'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((inv) async {
      calls++;
      throw DioException(
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/data'),
          statusCode: 503,
        ),
        requestOptions: RequestOptions(path: '/data'),
      );
    });
    final client = FinMindClient(
      dio: mockDio,
      maxRetries: 2,
      baseDelay: Duration.zero,
    );

    await expectLater(
      () => client.getDailyPrices(stockId: '2330', startDate: '2026-07-01'),
      throwsA(isA<NetworkException>()),
    );
    expect(calls, greaterThan(1), reason: '5xx 應保留重試行為');
  });
}
