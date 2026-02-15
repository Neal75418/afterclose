import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/data/remote/finmind_client.dart';

void main() {
  group('FinMindClient', () {
    group('Token validation', () {
      test('accepts valid token', () {
        final client = FinMindClient();

        expect(
          () => client.token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.abc123',
          returnsNormally,
        );

        expect(client.token, isNotNull);
      });

      test('rejects token shorter than 20 characters', () {
        final client = FinMindClient();

        expect(
          () => client.token = 'short_token',
          throwsA(isA<InvalidTokenException>()),
        );
      });

      test('rejects token with invalid characters', () {
        final client = FinMindClient();

        expect(
          () => client.token = 'invalid token with spaces!!',
          throwsA(isA<InvalidTokenException>()),
        );
      });

      test('accepts null token', () {
        final client = FinMindClient(token: null);

        expect(client.token, isNull);
      });

      test('can clear token by setting null', () {
        final client = FinMindClient();
        client.token = 'valid_token_that_is_long_enough';
        client.token = null;

        expect(client.token, isNull);
      });

      test('accepts empty string token (treated as no token)', () {
        final client = FinMindClient();

        expect(() => client.token = '', returnsNormally);
      });
    });

    group('isValidTokenFormat', () {
      test('returns true for valid token', () {
        expect(
          FinMindClient.isValidTokenFormat('eyJhbGciOiJIUzI1NiJ9.abc123'),
          isTrue,
        );
      });

      test('returns true for alphanumeric with underscores', () {
        expect(
          FinMindClient.isValidTokenFormat('valid_token_1234567890_ok'),
          isTrue,
        );
      });

      test('returns false for null', () {
        expect(FinMindClient.isValidTokenFormat(null), isFalse);
      });

      test('returns false for empty string', () {
        expect(FinMindClient.isValidTokenFormat(''), isFalse);
      });

      test('returns false for short token', () {
        expect(FinMindClient.isValidTokenFormat('short'), isFalse);
      });

      test('returns false for token with spaces', () {
        expect(
          FinMindClient.isValidTokenFormat('has spaces in it 12345'),
          isFalse,
        );
      });

      test('returns false for token with special chars', () {
        expect(
          FinMindClient.isValidTokenFormat('token!@#\$%^&*()_+1234'),
          isFalse,
        );
      });

      test('accepts JWT-style token with dots and hyphens', () {
        expect(
          FinMindClient.isValidTokenFormat(
            'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoiMTIzNCJ9.abc-def_ghi',
          ),
          isTrue,
        );
      });
    });

    group('Constructor', () {
      test('creates client with default values', () {
        final client = FinMindClient();

        expect(client.token, isNull);
      });

      test('creates client with custom token', () {
        final client = FinMindClient(token: 'valid_token_1234567890_ok');

        expect(client.token, 'valid_token_1234567890_ok');
      });

      test('constructor does not validate token (only setter does)', () {
        // Constructor assigns token directly without validation
        final client = FinMindClient(token: 'short');
        expect(client.token, 'short');
      });
    });
  });
}
