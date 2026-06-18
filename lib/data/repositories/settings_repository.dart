import 'dart:io' show Platform;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/repositories/settings_repository.dart';

/// Secure Storage Key 常數
class _SecureKeys {
  static const finmindToken = 'finmind_api_token';
}

/// 應用程式設定 Repository（包含 Token 管理）
///
/// Token 來源優先順序（fallback chain）：
/// 1. **[FlutterSecureStorage]** 加密儲存 — iOS/Android/macOS release
///    的正式路徑。有值即採用
/// 2. **`FINMIND_TOKEN` 環境變數**（dev fallback，與 `tool/backfill.dart`
///    CLI 共用同一個 env var）— 當 SecureStorage 不可用或無值時採用
/// 3. **記憶體暫存** — Secure Storage 不可用且 env var 未設時的最終
///    fallback；app 重啟後遺失，但不會寫入未加密的 SharedPreferences
///
/// 其他設定使用 SQLite 資料庫。
///
/// ## 為什麼 env var 是 fallback 而非 primary
///
/// 若 env var 優先於 SecureStorage，使用者在 UI 設新 token 時，app 仍會
/// 讀 env var 而忽略新值，造成「我明明設了但沒生效」的困惑。用 fallback
/// 語意讓正常使用者感受不到 env var 存在，只有在 SecureStorage 壞掉時
/// （macOS debug build 缺 code signing entitlement，errSecMissingEntitlement
/// -34018）env var 才接手，剛好對應開發者最痛的場景：每次重啟 app 都要
/// 重新輸入 token。開發者只要 `export FINMIND_TOKEN=...` 一次，後續每次
/// `flutter run` 都自動載入。env var 是 process-scoped memory，不違反
/// 「不寫入未加密儲存」的安全原則。
class SettingsRepository implements ISettingsRepository {
  SettingsRepository({required AppDatabase database, SharedPreferences? prefs})
    : _db = database,
      _prefs = prefs;

  final AppDatabase _db;
  SharedPreferences? _prefs;

  /// 標記 Secure Storage 是否可用
  bool? _secureStorageAvailable;

  /// 記憶體暫存 Token（Secure Storage 不可用時的 fallback）
  ///
  /// 安全取捨：app 重啟後 token 遺失，但不會寫入未加密的 SharedPreferences。
  /// 僅影響 macOS debug build（無 Keychain 權限）的開發體驗。
  String? _inMemoryToken;

  /// 環境變數 key — 與 `tool/backfill.dart` 等 CLI 工具共用。
  static const _envTokenKey = 'FINMIND_TOKEN';

  /// 從 `FINMIND_TOKEN` 環境變數讀取 token
  ///
  /// 回傳值為 null 或空字串時代表沒有設定。env var 的內容不做 trim 或
  /// 正規化（與 CLI 行為一致）— 呼叫端需自行處理 trailing whitespace。
  String? _readEnvToken() {
    // Web build 沒有 Platform.environment，Dart 會拋例外。防禦性處理。
    try {
      final value = Platform.environment[_envTokenKey];
      if (value == null || value.isEmpty) return null;
      return value;
    } catch (_) {
      return null;
    }
  }

  /// Secure Storage 實例（用於敏感資料如 API Token）
  ///
  /// macOS: 使用 legacy file-based keychain（usesDataProtectionKeychain: false）
  /// 避免 debug build 因缺少 code signing 導致 -34018 錯誤
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );

  /// 取得 SharedPreferences 實例（延遲初始化）
  Future<SharedPreferences> get _sharedPrefs async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  /// 檢查 Secure Storage 是否可用
  Future<bool> _isSecureStorageAvailable() async {
    if (_secureStorageAvailable != null) return _secureStorageAvailable!;

    try {
      // 嘗試寫入測試值
      await _secureStorage.write(key: '_test_availability', value: 'test');
      await _secureStorage.delete(key: '_test_availability');
      _secureStorageAvailable = true;
    } catch (e) {
      AppLogger.warning(
        'SettingsRepo',
        'SecureStorage 無法使用，改用 SharedPreferences',
        e,
      );
      // Sentry breadcrumb：FinMind token 降級存 SharedPreferences（明文）的
      // security degradation 在 release build 看不到 warning log，必須有
      // breadcrumb 才能在 backend 上看見此 user 的 token 沒被加密保護。
      Sentry.addBreadcrumb(
        Breadcrumb(
          message:
              'SecureStorage unavailable, falling back to SharedPreferences',
          category: 'storage',
          level: SentryLevel.warning,
          data: {'error': e.toString()},
        ),
      );
      _secureStorageAvailable = false;
    }
    return _secureStorageAvailable!;
  }

  // ==================================================
  // FinMind Token 管理（優先 Secure Storage，降級記憶體暫存）
  // ==================================================

  /// 取得 FinMind Token
  ///
  /// Fallback chain: SecureStorage → env var → 記憶體暫存。詳見 class-level doc。
  @override
  Future<String?> getFinMindToken() async {
    // Priority 1: SecureStorage（正式路徑）
    if (await _isSecureStorageAvailable()) {
      try {
        final stored = await _secureStorage.read(key: _SecureKeys.finmindToken);
        if (stored != null && stored.isNotEmpty) {
          return stored;
        }
      } catch (e, stack) {
        AppLogger.warning(
          'SettingsRepo',
          'SecureStorage 讀取失敗，嘗試 env var / 記憶體 fallback',
          e,
          stack,
        );
      }
    }

    // Priority 2: 環境變數（dev fallback，Secure Storage 無值或不可用時採用）
    final envToken = _readEnvToken();
    if (envToken != null) {
      return envToken;
    }

    // Priority 3: 記憶體暫存（app 重啟後遺失）
    // 同時嘗試遷移 SharedPreferences 遺留 token
    if (_inMemoryToken == null) {
      final prefs = await _sharedPrefs;
      final legacyToken = prefs.getString('finmind_token_fallback');
      if (legacyToken != null) {
        _inMemoryToken = legacyToken;
        // 清除遺留的未加密 token
        await prefs.remove('finmind_token_fallback');
        AppLogger.info('SettingsRepo', '已遷移遺留 token 至記憶體暫存');
      }
    }
    return _inMemoryToken;
  }

  /// 儲存 FinMind Token
  @override
  Future<void> setFinMindToken(String token) async {
    if (await _isSecureStorageAvailable()) {
      try {
        await _secureStorage.write(key: _SecureKeys.finmindToken, value: token);
        return;
      } catch (e, stack) {
        AppLogger.warning(
          'SettingsRepo',
          'SecureStorage 寫入失敗，使用記憶體暫存',
          e,
          stack,
        );
      }
    }
    // Fallback: 記憶體暫存（安全但不持久，app 重啟後需重新輸入）
    _inMemoryToken = token;
    AppLogger.warning('SettingsRepo', 'Token 已存入記憶體暫存（重啟後遺失）');
  }

  /// 清除 FinMind Token（所有儲存位置）
  @override
  Future<void> clearFinMindToken() async {
    _inMemoryToken = null;
    try {
      await _secureStorage.delete(key: _SecureKeys.finmindToken);
    } catch (e) {
      AppLogger.debug('SettingsRepo', '清除 SecureStorage Token 失敗: $e');
    }
    // 清除可能存在的遺留 SharedPreferences token
    final prefs = await _sharedPrefs;
    await prefs.remove('finmind_token_fallback');
  }

  /// 檢查是否已設定 Token
  @override
  Future<bool> hasFinMindToken() async {
    final token = await getFinMindToken();
    return token != null && token.isNotEmpty;
  }

  // ==================================================
  // 通用設定存取
  // ==================================================

  /// 依 Key 取得設定值
  @override
  Future<String?> getSetting(String key) {
    return _db.getSetting(key);
  }

  /// 設定值
  @override
  Future<void> setSetting(String key, String value) {
    return _db.setSetting(key, value);
  }

  /// 刪除設定
  @override
  Future<void> deleteSetting(String key) {
    return _db.deleteSetting(key);
  }
}
