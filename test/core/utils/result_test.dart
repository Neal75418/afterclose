import 'package:afterclose/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ==========================================
  // Result.success
  // ==========================================
  group('Result.success', () {
    test('isSuccess returns true', () {
      const result = Result<int>.success(42);
      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.data, equals(42));
      expect(result.error, isNull);
      expect(result.exception, isNull);
    });

    test('map transforms value', () {
      const result = Result<int>.success(10);
      final mapped = result.map((v) => v * 2);

      expect(mapped.isSuccess, isTrue);
      expect(mapped.data, equals(20));
    });

    test('flatMap chains results', () {
      const result = Result<int>.success(10);
      final chained = result.flatMap((v) => Result<String>.success('value=$v'));

      expect(chained.isSuccess, isTrue);
      expect(chained.data, equals('value=10'));
    });

    test('fold executes onSuccess', () {
      const result = Result<int>.success(5);
      final folded = result.fold(
        onSuccess: (v) => 'ok:$v',
        onFailure: (e, ex) => 'fail:$e',
      );

      expect(folded, equals('ok:5'));
    });

    test('getOrThrow returns data', () {
      const result = Result<String>.success('hello');
      expect(result.getOrThrow(), equals('hello'));
    });

    test('getOrDefault returns data (ignores default)', () {
      const result = Result<int>.success(42);
      expect(result.getOrDefault(0), equals(42));
    });

    test('getOrElse returns data (ignores compute)', () {
      const result = Result<int>.success(42);
      expect(result.getOrElse(() => 999), equals(42));
    });

    test('equality works for same values', () {
      const a = Result<int>.success(42);
      const b = Result<int>.success(42);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  // ==========================================
  // Result.failure
  // ==========================================
  group('Result.failure', () {
    test('isFailure returns true', () {
      const result = Result<int>.failure('oops');
      expect(result.isFailure, isTrue);
      expect(result.isSuccess, isFalse);
      expect(result.data, isNull);
      expect(result.error, equals('oops'));
    });

    test('preserves exception object', () {
      final ex = Exception('test error');
      final result = Result<int>.failure('oops', ex);
      expect(result.exception, equals(ex));
    });

    test('map propagates failure', () {
      const result = Result<int>.failure('oops');
      final mapped = result.map((v) => v * 2);

      expect(mapped.isFailure, isTrue);
      expect(mapped.error, equals('oops'));
    });

    test('flatMap propagates failure', () {
      const result = Result<int>.failure('oops');
      final chained = result.flatMap(
        (v) => const Result<String>.success('never'),
      );

      expect(chained.isFailure, isTrue);
      expect(chained.error, equals('oops'));
    });

    test('fold executes onFailure', () {
      const result = Result<int>.failure('bad');
      final folded = result.fold(
        onSuccess: (v) => 'ok:$v',
        onFailure: (e, ex) => 'fail:$e',
      );

      expect(folded, equals('fail:bad'));
    });

    test('getOrThrow throws exception when present', () {
      const result = Result<int>.failure('oops', FormatException('bad input'));

      expect(() => result.getOrThrow(), throwsA(isA<FormatException>()));
    });

    test('getOrThrow throws StateError when no exception', () {
      const result = Result<int>.failure('oops');

      expect(() => result.getOrThrow(), throwsA(isA<StateError>()));
    });

    test('getOrDefault returns default value', () {
      const result = Result<int>.failure('oops');
      expect(result.getOrDefault(99), equals(99));
    });

    test('getOrElse computes alternative', () {
      const result = Result<int>.failure('oops');
      expect(result.getOrElse(() => 123), equals(123));
    });

    test('equality works for same error', () {
      const a = Result<int>.failure('oops');
      const b = Result<int>.failure('oops');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  // ==========================================
  // runCatching / runCatchingAsync
  // ==========================================
  group('runCatching', () {
    test('returns success when action succeeds', () {
      final result = runCatching(() => 42);

      expect(result.isSuccess, isTrue);
      expect(result.data, equals(42));
    });

    test('returns failure when action throws', () {
      final result = runCatching<int>(() => throw Exception('boom'));

      expect(result.isFailure, isTrue);
      expect(result.error, contains('boom'));
      expect(result.exception, isA<Exception>());
    });

    test('includes error prefix when provided', () {
      final result = runCatching<int>(
        () => throw Exception('boom'),
        errorPrefix: 'MyModule',
      );

      expect(result.error, startsWith('MyModule: '));
    });
  });

  group('runCatchingAsync', () {
    test('returns success for async action', () async {
      final result = await runCatchingAsync(() async => 42);

      expect(result.isSuccess, isTrue);
      expect(result.data, equals(42));
    });

    test('returns failure for async throw', () async {
      final result = await runCatchingAsync<int>(
        () async => throw Exception('async boom'),
      );

      expect(result.isFailure, isTrue);
      expect(result.error, contains('async boom'));
    });
  });
}
