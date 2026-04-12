import 'package:afterclose/data/database/app_database.drift.dart';
import 'package:afterclose/data/database/tables/user_tables.drift.dart';

/// OTA calibration 快取的目前狀態
///
/// 從 `app_settings` 表（key-value）讀出的六個 well-known keys 組合而成。
/// 任一欄位可能為 null —— 首次安裝 / OTA 尚未成功過時全部為 null。
///
/// 呼叫端（`CalibratedScoresRegistry.loadWithOverride`、`CalibrationUpdater`）
/// 負責判斷 `hasCompleteContent` / `hasLastCheckedAt` 等語意。
class CachedCalibration {
  const CachedCalibration({
    this.version,
    this.shortJson,
    this.longJson,
    this.shortHash,
    this.longHash,
    this.lastCheckedAt,
  });

  /// 全欄位皆為 null 的空狀態（首次安裝時）
  static const empty = CachedCalibration();

  /// Manifest 標籤，例如 `"2026-04-12"`。僅供 debug / log；比對走 hash
  final String? version;

  /// Short horizon JSON 原文字串（parse 前）
  final String? shortJson;

  /// Long horizon JSON 原文字串（parse 前）
  final String? longJson;

  /// Short JSON 的 SHA-256 hex string（比對用）
  final String? shortHash;

  /// Long JSON 的 SHA-256 hex string（比對用）
  final String? longHash;

  /// 最後一次成功走完 OTA check 的時間（24h gate 判斷用）
  ///
  /// Transient failure 時**不**更新此欄位；Success / UpToDate /
  /// PermanentFailure 都會更新。
  final DateTime? lastCheckedAt;

  /// 是否有完整 short + long JSON 可供 `loadWithOverride` 覆蓋使用
  bool get hasCompleteContent =>
      shortJson != null && longJson != null && version != null;
}

/// OTA calibration 快取的資料存取介面
///
/// 用 `app_settings` 表（key-value）儲存六個 well-known keys，避免引入新
/// schema 欄位（AppSettings 本來就是 generic key-value store）。Atomic
/// update 透過 Drift `transaction` 保證 —— `writeCalibration` 內部六個
/// `insertOnConflictUpdate` 若中途 throw 會全部 rollback。
///
/// ## Key 命名慣例
///
/// 以 `calibration.` 前綴區隔其他 app_settings 用途（例如 `finmind.token`）。
/// 這個前綴不是魔術字串 —— 所有呼叫都走這個 mixin，上層程式碼不該
/// 直接 hardcode key 名稱。
mixin CalibrationCacheDaoMixin on $AppDatabase {
  // ==================================================
  // Well-known keys (internal)
  // ==================================================

  static const _kVersion = 'calibration.version';
  static const _kShortJson = 'calibration.short_json';
  static const _kLongJson = 'calibration.long_json';
  static const _kShortHash = 'calibration.short_hash';
  static const _kLongHash = 'calibration.long_hash';
  static const _kLastCheckedAt = 'calibration.last_checked_at';

  static const _allKeys = <String>[
    _kVersion,
    _kShortJson,
    _kLongJson,
    _kShortHash,
    _kLongHash,
    _kLastCheckedAt,
  ];

  // ==================================================
  // Public API
  // ==================================================

  /// 讀取當前 cached calibration 狀態
  ///
  /// 冷啟動時由 `main.dart` 呼叫，結果交給
  /// `CalibratedScoresRegistry.loadWithOverride` 決定走 DB cache 還是
  /// fallback 到 bundled asset。
  ///
  /// `lastCheckedAt` 欄位以 ISO 8601 string 存 SQLite，這裡讀回時用
  /// `DateTime.parse` 還原。若格式非法則靜默當作 null（避免啟動時
  /// 因為髒資料爆炸）。
  Future<CachedCalibration> getCachedCalibration() async {
    final rows = await (select(
      appSettings,
    )..where((t) => t.key.isIn(_allKeys))).get();

    if (rows.isEmpty) return CachedCalibration.empty;

    final map = <String, String>{for (final r in rows) r.key: r.value};

    return CachedCalibration(
      version: map[_kVersion],
      shortJson: map[_kShortJson],
      longJson: map[_kLongJson],
      shortHash: map[_kShortHash],
      longHash: map[_kLongHash],
      lastCheckedAt: _parseLastCheckedAt(map[_kLastCheckedAt]),
    );
  }

  /// Atomic write — 在單一 transaction 內寫入完整一組 calibration
  ///
  /// 適用 fetch success 的 happy path。若 transaction 中途 throw，Drift
  /// 保證六個 key 全部 rollback，不會留下 version 新 / JSON 舊的
  /// 半成品狀態。
  Future<void> writeCalibration({
    required String version,
    required String shortJson,
    required String longJson,
    required String shortHash,
    required String longHash,
    required DateTime checkedAt,
  }) async {
    await transaction(() async {
      await _setKey(_kVersion, version);
      await _setKey(_kShortJson, shortJson);
      await _setKey(_kLongJson, longJson);
      await _setKey(_kShortHash, shortHash);
      await _setKey(_kLongHash, longHash);
      await _setKey(_kLastCheckedAt, checkedAt.toUtc().toIso8601String());
    });
  }

  /// 只更新 `lastCheckedAt` 欄位
  ///
  /// 用於：
  /// - **UpToDate**（24h gate skip / hash match）：正常推進 gate
  /// - **PermanentFailure**（hash mismatch / parse error / minimum_app_version
  ///   超出）：避免 24h loop 不斷重撞同個壞掉的 manifest
  ///
  /// **不**用於 `TransientFailure`（network / timeout / 5xx）—— 那種情況
  /// `lastCheckedAt` 要保持不動，讓下次 cold start 早點重試。
  Future<void> touchCalibrationLastCheckedAt(DateTime now) {
    return _setKey(_kLastCheckedAt, now.toUtc().toIso8601String());
  }

  // ==================================================
  // Internal helpers
  // ==================================================

  Future<void> _setKey(String key, String value) {
    return into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(key: key, value: value),
    );
  }

  static DateTime? _parseLastCheckedAt(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
}
