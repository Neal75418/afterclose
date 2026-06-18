// OTA calibration updater service.
//
// Fetches `calibration_manifest.json` from jsDelivr, verifies the
// SHA-256 hashes of the two horizon JSONs, and writes them to the
// AppSettings cache via `CalibrationCacheDaoMixin`. The update takes
// effect on the NEXT cold start (deferred swap — design doc §2 Q5).
//
// Design ref: docs/plans/2026-04-12-ota-calibration-updates-design.md §3.5
//
// ## Usage
//
// Instantiated once at app startup and called fire-and-forget from
// `main.dart` after `runApp`:
//
//     unawaited(
//       container.read(calibrationUpdaterProvider).checkAndUpdate(),
//     );
//
// The result is logged via `AppLogger`. Errors are always caught inside;
// `checkAndUpdate` never throws.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import 'package:afterclose/core/utils/clock.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/network/calibration_fetch_result.dart';

/// Default jsDelivr manifest URL. Client fetches this first on every
/// OTA tick, then follows the `short.url` / `long.url` pointers from
/// the manifest body to download the JSONs.
///
/// The `@main` suffix tracks the default branch. Once a commit lands in
/// `main`, jsDelivr's CDN pulls the fresh files within 1-3 minutes.
const String defaultCalibrationManifestUrl =
    'https://cdn.jsdelivr.net/gh/Neal75418/afterclose@main/assets/calibration_manifest.json';

/// Default interval between OTA checks. Design Q2 = C (non-blocking +
/// 24h gate). See design doc §2 for rationale.
const Duration defaultCalibrationCheckInterval = Duration(hours: 24);

/// HTTP timeout for a single request (manifest or JSON). Kept short so
/// transient network issues resolve quickly rather than blocking.
const Duration _httpTimeout = Duration(seconds: 20);

/// OTA calibration updater — fetches + verifies + persists calibration
/// JSON from jsDelivr.
///
/// ## Lifecycle
///
/// Constructed once per app session (via `calibrationUpdaterProvider`).
/// `checkAndUpdate()` is the single entry point and is always safe to
/// call; it never throws and will no-op if the 24h gate has not elapsed.
///
/// ## Testability
///
/// Every external dependency is injected:
///
/// - [dio] — mockable HTTP client
/// - [database] — in-memory Drift DB in tests (`AppDatabase.forTesting()`)
/// - [clock] — `FakeClock` or similar for deterministic 24h gate tests
/// - [appVersion] — hardcoded string in tests, `PackageInfo` in prod
/// - [manifestUrl] — overridable for local mock server tests
///
/// ## Concurrency
///
/// Not re-entrant safe — callers should not call `checkAndUpdate()`
/// concurrently. In practice `main.dart` only calls it once per cold
/// start, so this is a non-issue. Not guarded with a lock to keep the
/// class simple.
class CalibrationUpdater {
  CalibrationUpdater({
    required Dio dio,
    required AppDatabase database,
    required AppClock clock,
    required String appVersion,
    this.manifestUrl = defaultCalibrationManifestUrl,
    this.checkInterval = defaultCalibrationCheckInterval,
  }) : _dio = dio,
       _database = database,
       _clock = clock,
       _appVersion = appVersion;

  final Dio _dio;
  final AppDatabase _database;
  final AppClock _clock;
  final String _appVersion;

  /// Where to fetch the OTA manifest from. Override in tests.
  final String manifestUrl;

  /// How often the OTA check should actually talk to the network.
  /// Calls within this interval after the last successful check return
  /// [CalibrationFetchUpToDate] immediately without network traffic.
  final Duration checkInterval;

  /// Main entry point — runs the full fetch + verify + persist flow.
  ///
  /// Safe to call fire-and-forget; never throws. See the sealed
  /// [CalibrationFetchResult] subclasses for possible outcomes.
  Future<CalibrationFetchResult> checkAndUpdate() async {
    try {
      final cached = await _database.getCachedCalibration();
      final now = _clock.now();

      // 24h gate — design doc §3.5 phase a-b
      if (cached.lastCheckedAt != null &&
          now.difference(cached.lastCheckedAt!) < checkInterval) {
        return const CalibrationFetchUpToDate(reason: 'within_24h_gate');
      }

      // Fetch manifest
      final manifest = await _fetchManifest();

      // Minimum app version check — design doc §3.3 `minimum_app_version`.
      // Client skips (UpToDate) if running older than required, so that an
      // incompatible recalibration doesn't get applied to an app that can't
      // understand it. Touch lastCheckedAt to avoid retrying every cold
      // start — user must upgrade the app to break the loop.
      if (!_isAppVersionSufficient(manifest.minimumAppVersion)) {
        await _database.touchCalibrationLastCheckedAt(now);
        return CalibrationFetchUpToDate(
          reason: 'min_version_skip_${manifest.minimumAppVersion}',
        );
      }

      // Hash compare against cached — design Q4 = C (content hash, not
      // version string). If both horizons already match what's in the
      // DB, just touch the gate and return.
      if (cached.shortHash == manifest.shortHash &&
          cached.longHash == manifest.longHash &&
          cached.hasCompleteContent) {
        await _database.touchCalibrationLastCheckedAt(now);
        return CalibrationFetchUpToDate(
          reason: 'hash_match_${manifest.version}',
        );
      }

      // Fetch both JSONs in parallel. Each one is ~10 KB; parallel
      // downloading shaves ~1 RTT off the OTA check.
      final jsonFutures = await Future.wait([
        _fetchJson(manifest.shortUrl),
        _fetchJson(manifest.longUrl),
      ]);
      final shortJson = jsonFutures[0];
      final longJson = jsonFutures[1];

      // Verify integrity — design Q4. Hash mismatch is PERMANENT; a
      // broken CDN or JSON tamper won't self-heal by retry.
      final shortActualHash = _sha256Hex(shortJson);
      final longActualHash = _sha256Hex(longJson);
      if (shortActualHash != manifest.shortHash ||
          longActualHash != manifest.longHash) {
        await _database.touchCalibrationLastCheckedAt(now);
        AppLogger.warning(
          'CalibrationUpdater',
          'Hash mismatch — manifest short=${manifest.shortHash} vs '
              'computed=$shortActualHash; manifest long=${manifest.longHash} '
              'vs computed=$longActualHash',
        );
        return const CalibrationFetchPermanentFailure(reason: 'hash_mismatch');
      }

      // Atomic write — design Q3 = 甲 (Drift transaction across six
      // well-known keys in app_settings). All-or-nothing.
      await _database.writeCalibration(
        version: manifest.version,
        shortJson: shortJson,
        longJson: longJson,
        shortHash: manifest.shortHash,
        longHash: manifest.longHash,
        checkedAt: now,
      );

      return CalibrationFetchSuccess(version: manifest.version);
    } on CalibrationManifestMalformedException catch (e) {
      // Manifest itself had structural issues (missing required fields,
      // wrong shape). Permanent — same manifest will fail again.
      final now = _clock.now();
      try {
        await _database.touchCalibrationLastCheckedAt(now);
      } catch (_) {
        // Best-effort; ignore secondary failure.
      }
      return CalibrationFetchPermanentFailure(
        reason: 'manifest_parse: ${e.message}',
      );
    } on DioException catch (e) {
      // Network errors (connection, timeout, DNS, 4xx/5xx) — all
      // transient. A future check may succeed when conditions change.
      return CalibrationFetchTransientFailure(
        cause: 'network: ${e.type.name} ${e.message ?? ''}'.trim(),
      );
    } on SocketException catch (e) {
      return CalibrationFetchTransientFailure(cause: 'socket: ${e.message}');
    } on TimeoutException catch (e) {
      return CalibrationFetchTransientFailure(
        cause: 'timeout: ${e.message ?? ''}',
      );
    } on FormatException catch (e) {
      // Remote returned something that jsonDecode can't parse and it
      // wasn't caught by our Manifest parser (e.g., JSON file fetched
      // from `manifest.shortUrl` was not valid JSON). Permanent.
      final now = _clock.now();
      try {
        await _database.touchCalibrationLastCheckedAt(now);
      } catch (_) {}
      return CalibrationFetchPermanentFailure(
        reason: 'parse_error: ${e.message}',
      );
    } catch (e, st) {
      // Last-resort catch — DB write failure, unexpected I/O. Treat as
      // transient so next cold start retries, but log for diagnosis.
      AppLogger.error(
        'CalibrationUpdater',
        'Unexpected error in checkAndUpdate',
        e,
        st,
      );
      return CalibrationFetchTransientFailure(cause: 'unexpected: $e');
    }
  }

  // ==================================================
  // Internal helpers
  // ==================================================

  /// Fetch + parse manifest. Throws [CalibrationManifestMalformedException]
  /// on structural issues, [DioException] on network issues.
  Future<_ManifestPayload> _fetchManifest() async {
    final response = await _dio.get<String>(
      manifestUrl,
      options: Options(
        responseType: ResponseType.plain,
        receiveTimeout: _httpTimeout,
        sendTimeout: _httpTimeout,
        // Bypass Dio's success-code gate so we can surface structured
        // info instead of a generic "bad response" string.
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    if (response.statusCode != 200) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        message: 'manifest HTTP ${response.statusCode}',
      );
    }

    final body = response.data;
    if (body == null || body.isEmpty) {
      throw const CalibrationManifestMalformedException('empty body');
    }

    return _ManifestPayload.parse(body);
  }

  /// Fetch a single JSON file as raw string. Dio handles redirects +
  /// gzip transparently.
  Future<String> _fetchJson(String url) async {
    final response = await _dio.get<String>(
      url,
      options: Options(
        responseType: ResponseType.plain,
        receiveTimeout: _httpTimeout,
        sendTimeout: _httpTimeout,
      ),
    );
    final body = response.data;
    if (body == null || body.isEmpty) {
      throw const FormatException('empty JSON body');
    }
    return body;
  }

  /// Compare current [_appVersion] against manifest's minimum.
  ///
  /// Expected format: `"MAJOR.MINOR.PATCH"` (semver-ish, leading digits;
  /// `+build` / `-prerelease` suffix is stripped before parsing).
  /// Comparison is numeric-per-segment. Returns `true` if current >=
  /// required, `false` otherwise (i.e., skip the update).
  ///
  /// **Fail-closed on malformed input**: if EITHER side fails to parse
  /// (e.g. manifest writes `"v9.9.9"` / `"tomorrow"` / `""`), returns
  /// `false` and skips the update. Permissive parsing previously allowed
  /// typos / `v`-prefixed strings to bypass the gate; the safer default
  /// is to refuse rather than ship calibration to a client whose version
  /// constraint we can't evaluate.
  bool _isAppVersionSufficient(String requiredVersion) {
    final currentSegments = _parseVersionSegments(_appVersion);
    final requiredSegments = _parseVersionSegments(requiredVersion);
    if (currentSegments == null || requiredSegments == null) return false;

    final len = currentSegments.length > requiredSegments.length
        ? currentSegments.length
        : requiredSegments.length;
    for (var i = 0; i < len; i++) {
      final c = i < currentSegments.length ? currentSegments[i] : 0;
      final r = i < requiredSegments.length ? requiredSegments[i] : 0;
      if (c > r) return true;
      if (c < r) return false;
    }
    return true; // equal
  }

  static List<int>? _parseVersionSegments(String version) {
    // Strip any `+build` / `-prerelease` suffix and just look at the
    // numeric prefix segments.
    final cleaned = version.split(RegExp(r'[+\-]')).first;
    final parts = cleaned.split('.');
    final segments = <int>[];
    for (final part in parts) {
      final n = int.tryParse(part);
      if (n == null) return null;
      segments.add(n);
    }
    return segments.isEmpty ? null : segments;
  }

  static String _sha256Hex(String jsonStr) =>
      sha256.convert(utf8.encode(jsonStr)).toString();
}

/// Parsed manifest body — strongly typed DTO for internal use
class _ManifestPayload {
  const _ManifestPayload({
    required this.version,
    required this.shortUrl,
    required this.longUrl,
    required this.shortHash,
    required this.longHash,
    required this.minimumAppVersion,
  });

  final String version;
  final String shortUrl;
  final String longUrl;
  final String shortHash;
  final String longHash;
  final String minimumAppVersion;

  /// Parse a manifest JSON string. Throws
  /// [CalibrationManifestMalformedException] if any required field is
  /// missing or wrong-typed.
  static _ManifestPayload parse(String jsonStr) {
    final Object? root;
    try {
      root = jsonDecode(jsonStr);
    } on FormatException catch (e) {
      throw CalibrationManifestMalformedException('invalid JSON: ${e.message}');
    }
    if (root is! Map) {
      throw const CalibrationManifestMalformedException('root not object');
    }

    final version = root['version'];
    if (version is! String || version.isEmpty) {
      throw const CalibrationManifestMalformedException(
        'version missing or empty',
      );
    }

    final minimumAppVersion = root['minimum_app_version'];
    if (minimumAppVersion is! String || minimumAppVersion.isEmpty) {
      throw const CalibrationManifestMalformedException(
        'minimum_app_version missing or empty',
      );
    }

    final short = root['short'];
    final long = root['long'];
    if (short is! Map || long is! Map) {
      throw const CalibrationManifestMalformedException(
        'short or long section missing',
      );
    }

    final shortUrl = short['url'];
    final longUrl = long['url'];
    if (shortUrl is! String ||
        shortUrl.isEmpty ||
        longUrl is! String ||
        longUrl.isEmpty) {
      throw const CalibrationManifestMalformedException(
        'short.url or long.url missing',
      );
    }

    final shortHash = short['sha256'];
    final longHash = long['sha256'];
    if (shortHash is! String ||
        shortHash.length != 64 ||
        longHash is! String ||
        longHash.length != 64) {
      throw const CalibrationManifestMalformedException(
        'short.sha256 or long.sha256 missing or wrong length',
      );
    }

    return _ManifestPayload(
      version: version,
      shortUrl: shortUrl,
      longUrl: longUrl,
      shortHash: shortHash,
      longHash: longHash,
      minimumAppVersion: minimumAppVersion,
    );
  }
}

/// Thrown when the manifest body is structurally invalid. Converted to
/// [CalibrationFetchPermanentFailure] by the outer try/catch.
class CalibrationManifestMalformedException implements Exception {
  const CalibrationManifestMalformedException(this.message);
  final String message;

  @override
  String toString() => 'CalibrationManifestMalformedException: $message';
}
