// Sealed result type for CalibrationUpdater.checkAndUpdate outcomes.
//
// Design ref: docs/plans/2026-04-12-ota-calibration-updates-design.md §3.6
//
// Why a sealed class instead of enum + message?
//
// Each branch carries different metadata (success → version, failures →
// cause strings) and the caller needs type-safe exhaustive matching to
// decide whether to touch `lastCheckedAt`. Enum + companion map would
// lose that static guarantee.

/// Result of a single `CalibrationUpdater.checkAndUpdate` invocation.
///
/// Four mutually exclusive branches:
///
/// - [CalibrationFetchSuccess] — new JSON was fetched, verified, and
///   written to the DB cache. Next cold start will use it.
/// - [CalibrationFetchUpToDate] — 24h gate skipped the check, or the
///   manifest hashes matched the cache. No DB content changed; only
///   `lastCheckedAt` was touched to advance the gate.
/// - [CalibrationFetchTransientFailure] — network error, timeout, 5xx,
///   DB write failure, or other recoverable issue. `lastCheckedAt` is
///   **NOT** touched, so the next cold start will retry immediately.
/// - [CalibrationFetchPermanentFailure] — hash mismatch, JSON parse
///   failure, malformed manifest, `minimum_app_version` exceeded.
///   `lastCheckedAt` **IS** touched to avoid the 24h tick loop hammering
///   a broken manifest forever.
///
/// The transient vs permanent distinction is the core design decision
/// from brainstorming Q6 (design doc §2, table row Q6).
sealed class CalibrationFetchResult {
  const CalibrationFetchResult();

  /// Short human-readable summary for logging (format: `<kind>: <detail>`)
  String describe();
}

/// New calibration JSON was fetched, verified, and persisted
class CalibrationFetchSuccess extends CalibrationFetchResult {
  const CalibrationFetchSuccess({required this.version});

  /// Manifest version tag that was applied (e.g., `"2026-04-12"`)
  final String version;

  @override
  String describe() => 'success: version=$version';
}

/// Nothing changed — either 24h gate skipped or manifest hashes matched
class CalibrationFetchUpToDate extends CalibrationFetchResult {
  const CalibrationFetchUpToDate({required this.reason});

  /// Why no update happened. Possible values:
  /// - `"within_24h_gate"` — [CalibrationUpdater.checkInterval] not elapsed
  /// - `"hash_match_<version>"` — manifest hashes equal cached hashes
  /// - `"min_version_skip_<required>"` — manifest demands newer app version
  final String reason;

  @override
  String describe() => 'upToDate: $reason';
}

/// Network / timeout / 5xx / DB write failure — retry next cold start
class CalibrationFetchTransientFailure extends CalibrationFetchResult {
  const CalibrationFetchTransientFailure({required this.cause});

  /// Short cause description (e.g., `"network: SocketException: ..."`)
  final String cause;

  @override
  String describe() => 'transientFailure: $cause';
}

/// Hash mismatch / JSON parse error / malformed manifest — touch
/// `lastCheckedAt` to prevent the 24h loop from hammering a broken
/// manifest forever; retry only when a new manifest is published
class CalibrationFetchPermanentFailure extends CalibrationFetchResult {
  const CalibrationFetchPermanentFailure({required this.reason});

  /// Short reason description (e.g., `"hash_mismatch"`, `"parse_error: ..."`)
  final String reason;

  @override
  String describe() => 'permanentFailure: $reason';
}
