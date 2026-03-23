import 'package:afterclose/domain/services/api_connection_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = ApiConnectionService();

  // ==========================================
  // testFinMindConnection — pre-validation
  // ==========================================
  group('testFinMindConnection', () {
    test('returns noToken error when token is null', () async {
      final result = await service.testFinMindConnection(null);

      expect(result.success, isFalse);
      expect(result.error, equals(ApiTestError.noToken));
      expect(result.errorMessage, contains('Token'));
    });

    test('returns noToken error when token is empty', () async {
      final result = await service.testFinMindConnection('');

      expect(result.success, isFalse);
      expect(result.error, equals(ApiTestError.noToken));
    });

    test('returns invalidToken error when token too short', () async {
      // Token must be >= 20 chars
      final result = await service.testFinMindConnection('short');

      expect(result.success, isFalse);
      expect(result.error, equals(ApiTestError.invalidToken));
    });

    test('returns invalidToken error when token has invalid chars', () async {
      // Token must match ^[a-zA-Z0-9_.\-]+$ and >= 20 chars
      const invalidToken = 'invalid@token#with!special\$chars';
      final result = await service.testFinMindConnection(invalidToken);

      expect(result.success, isFalse);
      expect(result.error, equals(ApiTestError.invalidToken));
    });
  });
}
