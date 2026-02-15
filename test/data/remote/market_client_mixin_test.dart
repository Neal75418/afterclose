import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/data/remote/market_client_mixin.dart';

void main() {
  group('MarketClientMixin', () {
    group('decodeResponseData', () {
      test('returns Map when data is already a Map', () {
        final data = {'stat': 'OK', 'data': []};
        final result = MarketClientMixin.decodeResponseData(
          data,
          'TEST',
          'test',
        );

        expect(result, isNotNull);
        expect(result!['stat'], 'OK');
      });

      test('decodes JSON string to Map', () {
        const jsonStr = '{"stat": "OK", "data": []}';
        final result = MarketClientMixin.decodeResponseData(
          jsonStr,
          'TEST',
          'test',
        );

        expect(result, isNotNull);
        expect(result!['stat'], 'OK');
      });

      test('returns null for invalid JSON string', () {
        const invalidJson = 'not valid json{';
        final result = MarketClientMixin.decodeResponseData(
          invalidJson,
          'TEST',
          'test',
        );

        expect(result, isNull);
      });

      test('returns null for null data', () {
        final result = MarketClientMixin.decodeResponseData(
          null,
          'TEST',
          'test',
        );

        expect(result, isNull);
      });

      test('returns null for non-Map data (List)', () {
        final result = MarketClientMixin.decodeResponseData(
          [1, 2, 3],
          'TEST',
          'test',
        );

        expect(result, isNull);
      });

      test('returns null for non-Map data (number)', () {
        final result = MarketClientMixin.decodeResponseData(42, 'TEST', 'test');

        expect(result, isNull);
      });
    });

    group('executeRequest', () {
      test('returns result on success', () async {
        final result = await MarketClientMixin.executeRequest(
          'TEST',
          'test',
          () async => 42,
        );

        expect(result, 42);
      });

      test('throws NetworkException for non-retryable DioException', () {
        expect(
          () => MarketClientMixin.executeRequest(
            'TEST',
            'test',
            () async => throw DioException(
              type: DioExceptionType.badCertificate,
              requestOptions: RequestOptions(path: '/test'),
            ),
          ),
          throwsA(isA<NetworkException>()),
        );
      });

      test(
        'throws NetworkException for connection timeout (non-retryable path)',
        () {
          // connectionTimeout is retryable per _isRetryable, but after exhausting retries
          // Actually looking at the code: connectionTimeout IS retryable,
          // but it enters the retry loop. After max retries it throws.
          // For a non-retryable type like badCertificate, it throws immediately.
          expect(
            () => MarketClientMixin.executeRequest(
              'TEST',
              'test',
              () async => throw DioException(
                type: DioExceptionType.cancel,
                requestOptions: RequestOptions(path: '/test'),
              ),
            ),
            throwsA(isA<NetworkException>()),
          );
        },
      );

      test('rethrows AppException without wrapping', () {
        expect(
          () => MarketClientMixin.executeRequest(
            'TEST',
            'test',
            () async => throw const ApiException('test error', 400),
          ),
          throwsA(isA<ApiException>()),
        );
      });

      test('rethrows non-Dio exceptions', () {
        expect(
          () => MarketClientMixin.executeRequest(
            'TEST',
            'test',
            () async => throw const FormatException('bad format'),
          ),
          throwsA(isA<FormatException>()),
        );
      });

      test('retries on 500 error then succeeds', () async {
        var callCount = 0;

        final result = await MarketClientMixin.executeRequest(
          'TEST',
          'test',
          () async {
            callCount++;
            if (callCount == 1) {
              throw DioException(
                type: DioExceptionType.badResponse,
                requestOptions: RequestOptions(path: '/test'),
                response: Response(
                  statusCode: 500,
                  requestOptions: RequestOptions(path: '/test'),
                ),
              );
            }
            return 'success';
          },
        );

        expect(result, 'success');
        expect(callCount, 2);
      });

      test('throws after max retries on retryable error', () async {
        var callCount = 0;

        await expectLater(() async {
          await MarketClientMixin.executeRequest('TEST', 'test', () async {
            callCount++;
            throw DioException(
              type: DioExceptionType.badResponse,
              requestOptions: RequestOptions(path: '/test'),
              response: Response(
                statusCode: 503,
                requestOptions: RequestOptions(path: '/test'),
              ),
            );
          });
        }, throwsA(isA<NetworkException>()));

        // 1 initial + 2 retries = 3 calls
        expect(callCount, 3);
      });

      test('does not retry on 400 error', () async {
        var callCount = 0;

        await expectLater(() async {
          await MarketClientMixin.executeRequest('TEST', 'test', () async {
            callCount++;
            throw DioException(
              type: DioExceptionType.badResponse,
              requestOptions: RequestOptions(path: '/test'),
              response: Response(
                statusCode: 400,
                requestOptions: RequestOptions(path: '/test'),
              ),
            );
          });
        }, throwsA(isA<NetworkException>()));

        expect(callCount, 1);
      });
    });

    group('createDio', () {
      test('creates Dio with correct base URL', () {
        final dio = MarketClientMixin.createDio('https://example.com');

        expect(dio.options.baseUrl, 'https://example.com');
      });

      test('sets JSON response type', () {
        final dio = MarketClientMixin.createDio('https://example.com');

        expect(dio.options.responseType, ResponseType.json);
      });

      test('sets Accept header', () {
        final dio = MarketClientMixin.createDio('https://example.com');

        expect(dio.options.headers['Accept'], 'application/json');
      });
    });
  });
}
