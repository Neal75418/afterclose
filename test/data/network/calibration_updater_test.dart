// Unit tests for CalibrationUpdater.
//
// Uses a real in-memory `AppDatabase.forTesting()` so the
// `CalibrationCacheDaoMixin` transaction behaviour is exercised end-to-
// end. Dio is mocked via mocktail to simulate network responses and
// failures. AppClock is a mutable fake so 24h gate tests are
// deterministic.
//
// Scenario coverage (design doc §6.1):
// 1.  24h gate skip
// 2.  First run → Success
// 3.  Hash match → UpToDate
// 4.  Hash updated (new version) → Success
// 5.  Manifest fetch — DioException network → Transient (no touch)
// 6.  Manifest fetch — HTTP 500 → Transient
// 7.  JSON fetch — timeout → Transient
// 8.  Hash mismatch on short → Permanent (touch)
// 9.  Hash mismatch on long → Permanent (touch)
// 10. Manifest malformed (missing field) → Permanent (touch)
// 11. Manifest malformed (invalid JSON body) → Permanent (touch)
// 12. Manifest malformed (bad sha256 length) → Permanent
// 13. Empty manifest body → Permanent
// 14. minimum_app_version exceeds current → UpToDate (touch)
// 15. minimum_app_version equal to current → proceeds
// 16. minimum_app_version with +build suffix → proceeds
// 17. Transient touch invariant — lastCheckedAt unchanged
// 18. Permanent touch invariant — lastCheckedAt advanced
// 19-20. Never-throws — generic Exception / StateError both become Transient

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:afterclose/core/utils/clock.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/network/calibration_fetch_result.dart';
import 'package:afterclose/data/network/calibration_updater.dart';

// ============================================================================
// Test doubles
// ============================================================================

class _MockDio extends Mock implements Dio {}

class _MutableClock implements AppClock {
  _MutableClock(this._now);
  DateTime _now;
  void setTo(DateTime t) => _now = t;
  @override
  DateTime now() => _now;
}

class _FakeRequestOptions extends Fake implements RequestOptions {}

// Well-known URLs used throughout the tests. Override default jsDelivr
// via constructor so values are deterministic in tests.
const _manifestUrl = 'https://test.example/manifest.json';
const _shortUrl = 'https://test.example/short.json';
const _longUrl = 'https://test.example/long.json';

// Tiny valid calibration JSON bodies. Hashes are computed at runtime
// via [_sha256] so there's never a hand-maintained value that could
// drift from the actual content.
const _shortBody =
    '{"schema_version": 1, "rules": {"REVERSAL_W2S": {"score": 28, "hit_rate": 0.6, "samples": 100}}}';
const _longBody =
    '{"schema_version": 1, "rules": {"REVERSAL_W2S": {"score": 32, "hit_rate": 0.58, "samples": 95}}}';

String _sha256(String s) => sha256.convert(utf8.encode(s)).toString();

/// SHA-256 of [_shortBody] — computed at first access, cached
final String _shortHash = _sha256(_shortBody);
final String _longHash = _sha256(_longBody);

String _buildManifestJson({
  String version = '2026-04-12',
  String shortUrl = _shortUrl,
  String longUrl = _longUrl,
  String? shortHash,
  String? longHash,
  String minimumAppVersion = '1.0.0',
}) {
  return jsonEncode({
    'schema_version': 1,
    'version': version,
    'generated_at': '2026-04-12T10:30:00.000Z',
    'short': {
      'url': shortUrl,
      'sha256': shortHash ?? _shortHash,
      'rule_count': 58,
      'filename': 'rule_scores_calibrated_short.json',
    },
    'long': {
      'url': longUrl,
      'sha256': longHash ?? _longHash,
      'rule_count': 61,
      'filename': 'rule_scores_calibrated_long.json',
    },
    'minimum_app_version': minimumAppVersion,
  });
}

/// Wrap a body string into a Dio `Response<String>` with status 200
Response<String> _ok(String body, String url) => Response<String>(
  data: body,
  statusCode: 200,
  requestOptions: RequestOptions(path: url),
);

/// Stub Dio.get to return [response] for a given URL
void _stubGet(_MockDio dio, String url, Response<String> response) {
  when(
    () => dio.get<String>(url, options: any(named: 'options')),
  ).thenAnswer((_) async => response);
}

/// Stub Dio.get to throw [error] for a given URL
void _stubGetThrows(_MockDio dio, String url, Object error) {
  when(
    () => dio.get<String>(url, options: any(named: 'options')),
  ).thenThrow(error);
}

CalibrationUpdater _buildUpdater({
  required _MockDio dio,
  required AppDatabase database,
  required AppClock clock,
  String appVersion = '1.0.0',
  Duration interval = const Duration(hours: 24),
}) {
  return CalibrationUpdater(
    dio: dio,
    database: database,
    clock: clock,
    appVersion: appVersion,
    manifestUrl: _manifestUrl,
    checkInterval: interval,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeRequestOptions());
    registerFallbackValue(Options());
  });

  late AppDatabase db;
  late _MockDio dio;
  late _MutableClock clock;

  setUp(() {
    db = AppDatabase.forTesting();
    dio = _MockDio();
    clock = _MutableClock(DateTime.utc(2026, 4, 12, 10, 0));
  });

  tearDown(() async {
    await db.close();
  });

  // ==========================================================================
  // 24h gate
  // ==========================================================================

  group('24h gate', () {
    test('recent lastCheckedAt → UpToDate without any HTTP call', () async {
      await db.touchCalibrationLastCheckedAt(DateTime.utc(2026, 4, 12, 9, 0));
      clock.setTo(DateTime.utc(2026, 4, 12, 10, 0));

      final updater = _buildUpdater(dio: dio, database: db, clock: clock);
      final result = await updater.checkAndUpdate();

      expect(result, isA<CalibrationFetchUpToDate>());
      expect((result as CalibrationFetchUpToDate).reason, 'within_24h_gate');
      verifyNever(() => dio.get<String>(any(), options: any(named: 'options')));
    });

    test('exactly 24h elapsed → still triggers fetch', () async {
      await db.touchCalibrationLastCheckedAt(DateTime.utc(2026, 4, 11, 10, 0));
      clock.setTo(DateTime.utc(2026, 4, 12, 10, 0));

      _stubGet(dio, _manifestUrl, _ok(_buildManifestJson(), _manifestUrl));
      _stubGet(dio, _shortUrl, _ok(_shortBody, _shortUrl));
      _stubGet(dio, _longUrl, _ok(_longBody, _longUrl));

      final updater = _buildUpdater(dio: dio, database: db, clock: clock);
      final result = await updater.checkAndUpdate();

      expect(
        result,
        isA<CalibrationFetchSuccess>(),
        reason: '24h exactly should NOT be less than 24h → gate not triggered',
      );
    });
  });

  // ==========================================================================
  // Happy path + hash match
  // ==========================================================================

  group('happy path', () {
    test('first run (empty cache) → Success + full DB write', () async {
      _stubGet(dio, _manifestUrl, _ok(_buildManifestJson(), _manifestUrl));
      _stubGet(dio, _shortUrl, _ok(_shortBody, _shortUrl));
      _stubGet(dio, _longUrl, _ok(_longBody, _longUrl));

      final updater = _buildUpdater(dio: dio, database: db, clock: clock);
      final result = await updater.checkAndUpdate();

      expect(result, isA<CalibrationFetchSuccess>());
      expect((result as CalibrationFetchSuccess).version, '2026-04-12');

      final cached = await db.getCachedCalibration();
      expect(cached.version, '2026-04-12');
      expect(cached.shortJson, _shortBody);
      expect(cached.longJson, _longBody);
      expect(cached.shortHash, _shortHash);
      expect(cached.longHash, _longHash);
      expect(cached.lastCheckedAt, clock.now());
    });

    test('hash match → UpToDate + only touches lastCheckedAt', () async {
      await db.writeCalibration(
        version: '2026-04-12',
        shortJson: _shortBody,
        longJson: _longBody,
        shortHash: _shortHash,
        longHash: _longHash,
        checkedAt: DateTime.utc(2026, 4, 11, 10, 0),
      );
      clock.setTo(DateTime.utc(2026, 4, 12, 10, 0));

      _stubGet(dio, _manifestUrl, _ok(_buildManifestJson(), _manifestUrl));

      final updater = _buildUpdater(dio: dio, database: db, clock: clock);
      final result = await updater.checkAndUpdate();

      expect(result, isA<CalibrationFetchUpToDate>());
      expect(
        (result as CalibrationFetchUpToDate).reason,
        contains('hash_match'),
      );

      // Manifest was fetched but JSONs were not (short-circuit)
      verify(
        () => dio.get<String>(_manifestUrl, options: any(named: 'options')),
      ).called(1);
      verifyNever(
        () => dio.get<String>(_shortUrl, options: any(named: 'options')),
      );
      verifyNever(
        () => dio.get<String>(_longUrl, options: any(named: 'options')),
      );

      final cached = await db.getCachedCalibration();
      expect(cached.version, '2026-04-12');
      expect(cached.lastCheckedAt, clock.now());
    });

    test('new manifest (different hash) → Success overwrites cache', () async {
      await db.writeCalibration(
        version: '2026-03-15',
        shortJson: '{"old": true}',
        longJson: '{"old": true}',
        shortHash: '0' * 64,
        longHash: '1' * 64,
        checkedAt: DateTime.utc(2026, 4, 11, 10, 0),
      );
      clock.setTo(DateTime.utc(2026, 4, 12, 10, 0));

      _stubGet(dio, _manifestUrl, _ok(_buildManifestJson(), _manifestUrl));
      _stubGet(dio, _shortUrl, _ok(_shortBody, _shortUrl));
      _stubGet(dio, _longUrl, _ok(_longBody, _longUrl));

      final updater = _buildUpdater(dio: dio, database: db, clock: clock);
      final result = await updater.checkAndUpdate();

      expect(result, isA<CalibrationFetchSuccess>());

      final cached = await db.getCachedCalibration();
      expect(cached.version, '2026-04-12');
      expect(cached.shortJson, _shortBody);
      expect(cached.longJson, _longBody);
    });
  });

  // ==========================================================================
  // Transient failures
  // ==========================================================================

  group('transient failures', () {
    test('DioException network → TransientFailure, no touch', () async {
      _stubGetThrows(
        dio,
        _manifestUrl,
        DioException(
          requestOptions: RequestOptions(path: _manifestUrl),
          type: DioExceptionType.connectionError,
          message: 'Connection refused',
        ),
      );

      final updater = _buildUpdater(dio: dio, database: db, clock: clock);
      final result = await updater.checkAndUpdate();

      expect(result, isA<CalibrationFetchTransientFailure>());
      expect(
        (result as CalibrationFetchTransientFailure).cause,
        contains('connectionError'),
      );

      final cached = await db.getCachedCalibration();
      expect(
        cached.lastCheckedAt,
        isNull,
        reason: 'transient failure must not touch lastCheckedAt',
      );
    });

    test('DioException HTTP 500 → TransientFailure', () async {
      _stubGet(
        dio,
        _manifestUrl,
        Response<String>(
          data: 'Internal Server Error',
          statusCode: 500,
          requestOptions: RequestOptions(path: _manifestUrl),
        ),
      );

      final updater = _buildUpdater(dio: dio, database: db, clock: clock);
      final result = await updater.checkAndUpdate();

      expect(result, isA<CalibrationFetchTransientFailure>());
      final cached = await db.getCachedCalibration();
      expect(cached.lastCheckedAt, isNull);
    });

    test('timeout on JSON fetch → TransientFailure', () async {
      _stubGet(dio, _manifestUrl, _ok(_buildManifestJson(), _manifestUrl));
      _stubGetThrows(
        dio,
        _shortUrl,
        DioException(
          requestOptions: RequestOptions(path: _shortUrl),
          type: DioExceptionType.receiveTimeout,
          message: 'Receive timed out',
        ),
      );
      _stubGet(dio, _longUrl, _ok(_longBody, _longUrl));

      final updater = _buildUpdater(dio: dio, database: db, clock: clock);
      final result = await updater.checkAndUpdate();

      expect(result, isA<CalibrationFetchTransientFailure>());
      final cached = await db.getCachedCalibration();
      expect(cached.lastCheckedAt, isNull);
    });
  });

  // ==========================================================================
  // Hash mismatch
  // ==========================================================================

  group('hash mismatch', () {
    test(
      'short body tampered → PermanentFailure, touches lastCheckedAt',
      () async {
        _stubGet(dio, _manifestUrl, _ok(_buildManifestJson(), _manifestUrl));
        _stubGet(dio, _shortUrl, _ok('{"tampered": true}', _shortUrl));
        _stubGet(dio, _longUrl, _ok(_longBody, _longUrl));

        final updater = _buildUpdater(dio: dio, database: db, clock: clock);
        final result = await updater.checkAndUpdate();

        expect(result, isA<CalibrationFetchPermanentFailure>());
        expect(
          (result as CalibrationFetchPermanentFailure).reason,
          'hash_mismatch',
        );

        final cached = await db.getCachedCalibration();
        expect(cached.shortJson, isNull);
        expect(
          cached.lastCheckedAt,
          clock.now(),
          reason: 'permanent failure MUST touch lastCheckedAt to avoid loop',
        );
      },
    );

    test('long body tampered → PermanentFailure', () async {
      _stubGet(dio, _manifestUrl, _ok(_buildManifestJson(), _manifestUrl));
      _stubGet(dio, _shortUrl, _ok(_shortBody, _shortUrl));
      _stubGet(dio, _longUrl, _ok('{"tampered": true}', _longUrl));

      final updater = _buildUpdater(dio: dio, database: db, clock: clock);
      final result = await updater.checkAndUpdate();

      expect(result, isA<CalibrationFetchPermanentFailure>());
      final cached = await db.getCachedCalibration();
      expect(cached.lastCheckedAt, clock.now());
    });
  });

  // ==========================================================================
  // Malformed manifest
  // ==========================================================================

  group('malformed manifest', () {
    test('missing version field → PermanentFailure, touches', () async {
      final bad = jsonEncode({
        'short': {'url': _shortUrl, 'sha256': _shortHash},
        'long': {'url': _longUrl, 'sha256': _longHash},
        'minimum_app_version': '1.0.0',
      });
      _stubGet(dio, _manifestUrl, _ok(bad, _manifestUrl));

      final updater = _buildUpdater(dio: dio, database: db, clock: clock);
      final result = await updater.checkAndUpdate();

      expect(result, isA<CalibrationFetchPermanentFailure>());
      expect(
        (result as CalibrationFetchPermanentFailure).reason,
        contains('manifest_parse'),
      );
      final cached = await db.getCachedCalibration();
      expect(cached.lastCheckedAt, clock.now());
    });

    test('invalid JSON body → PermanentFailure', () async {
      _stubGet(dio, _manifestUrl, _ok('not a json {{{', _manifestUrl));

      final updater = _buildUpdater(dio: dio, database: db, clock: clock);
      final result = await updater.checkAndUpdate();

      expect(result, isA<CalibrationFetchPermanentFailure>());
      final cached = await db.getCachedCalibration();
      expect(cached.lastCheckedAt, clock.now());
    });

    test('short.sha256 wrong length → PermanentFailure', () async {
      final bad = _buildManifestJson(shortHash: 'tooshort');
      _stubGet(dio, _manifestUrl, _ok(bad, _manifestUrl));

      final updater = _buildUpdater(dio: dio, database: db, clock: clock);
      final result = await updater.checkAndUpdate();

      expect(result, isA<CalibrationFetchPermanentFailure>());
    });

    test('empty manifest body → PermanentFailure', () async {
      _stubGet(dio, _manifestUrl, _ok('', _manifestUrl));

      final updater = _buildUpdater(dio: dio, database: db, clock: clock);
      final result = await updater.checkAndUpdate();

      expect(result, isA<CalibrationFetchPermanentFailure>());
    });
  });

  // ==========================================================================
  // minimum_app_version
  // ==========================================================================

  group('minimum_app_version', () {
    test(
      'manifest requires newer app → UpToDate(min_version_skip) + touch',
      () async {
        _stubGet(
          dio,
          _manifestUrl,
          _ok(_buildManifestJson(minimumAppVersion: '2.5.0'), _manifestUrl),
        );

        final updater = _buildUpdater(
          dio: dio,
          database: db,
          clock: clock,
          appVersion: '1.0.0',
        );
        final result = await updater.checkAndUpdate();

        expect(result, isA<CalibrationFetchUpToDate>());
        expect(
          (result as CalibrationFetchUpToDate).reason,
          contains('min_version_skip'),
        );

        verifyNever(
          () => dio.get<String>(_shortUrl, options: any(named: 'options')),
        );

        final cached = await db.getCachedCalibration();
        expect(cached.lastCheckedAt, clock.now());
      },
    );

    test('current app exactly equals minimum → proceeds', () async {
      _stubGet(
        dio,
        _manifestUrl,
        _ok(_buildManifestJson(minimumAppVersion: '1.0.0'), _manifestUrl),
      );
      _stubGet(dio, _shortUrl, _ok(_shortBody, _shortUrl));
      _stubGet(dio, _longUrl, _ok(_longBody, _longUrl));

      final updater = _buildUpdater(
        dio: dio,
        database: db,
        clock: clock,
        appVersion: '1.0.0',
      );
      final result = await updater.checkAndUpdate();

      expect(result, isA<CalibrationFetchSuccess>());
    });

    test(
      'current app newer than minimum (with +build suffix) → proceeds',
      () async {
        _stubGet(
          dio,
          _manifestUrl,
          _ok(_buildManifestJson(minimumAppVersion: '1.0.0'), _manifestUrl),
        );
        _stubGet(dio, _shortUrl, _ok(_shortBody, _shortUrl));
        _stubGet(dio, _longUrl, _ok(_longBody, _longUrl));

        final updater = _buildUpdater(
          dio: dio,
          database: db,
          clock: clock,
          appVersion: '2.3.1+42',
        );
        final result = await updater.checkAndUpdate();

        expect(result, isA<CalibrationFetchSuccess>());
      },
    );
  });

  // ==========================================================================
  // Touch invariants (design Q6)
  // ==========================================================================

  group('touch invariants (design Q6)', () {
    test('transient → lastCheckedAt unchanged from prior value', () async {
      final priorTime = DateTime.utc(2026, 4, 11, 5, 0);
      await db.touchCalibrationLastCheckedAt(priorTime);
      clock.setTo(DateTime.utc(2026, 4, 12, 10, 0));

      _stubGetThrows(
        dio,
        _manifestUrl,
        DioException(
          requestOptions: RequestOptions(path: _manifestUrl),
          type: DioExceptionType.connectionTimeout,
          message: 'Timed out',
        ),
      );

      final updater = _buildUpdater(dio: dio, database: db, clock: clock);
      await updater.checkAndUpdate();

      final cached = await db.getCachedCalibration();
      expect(
        cached.lastCheckedAt,
        priorTime,
        reason: 'transient must leave lastCheckedAt untouched',
      );
    });

    test('permanent → lastCheckedAt advanced to clock.now()', () async {
      final priorTime = DateTime.utc(2026, 4, 11, 5, 0);
      await db.touchCalibrationLastCheckedAt(priorTime);
      clock.setTo(DateTime.utc(2026, 4, 12, 10, 0));

      _stubGet(
        dio,
        _manifestUrl,
        _ok('{"not a manifest": true}', _manifestUrl),
      );

      final updater = _buildUpdater(dio: dio, database: db, clock: clock);
      await updater.checkAndUpdate();

      final cached = await db.getCachedCalibration();
      expect(cached.lastCheckedAt, clock.now());
      expect(cached.lastCheckedAt, isNot(priorTime));
    });
  });

  // ==========================================================================
  // Never-throws invariant
  // ==========================================================================

  group('never-throws invariant', () {
    test('generic Exception in Dio → TransientFailure', () async {
      _stubGetThrows(dio, _manifestUrl, Exception('something weird'));

      final updater = _buildUpdater(dio: dio, database: db, clock: clock);
      final result = await updater.checkAndUpdate();

      expect(result, isA<CalibrationFetchTransientFailure>());
      expect(
        (result as CalibrationFetchTransientFailure).cause,
        contains('unexpected'),
      );
    });

    test('StateError inside → TransientFailure (last-resort catch)', () async {
      _stubGetThrows(dio, _manifestUrl, StateError('impossible'));

      final updater = _buildUpdater(dio: dio, database: db, clock: clock);
      final result = await updater.checkAndUpdate();

      expect(result, isA<CalibrationFetchTransientFailure>());
    });
  });
}
