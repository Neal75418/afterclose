import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/repositories/settings_repository.dart';

/// Secure Storage Key 常數
class _SecureKeys {
  static const finmindToken = 'finmind_api_token';
}

/// SharedPreferences 舊版遺留 key（僅用於 clearFinMindToken 清除遺留資料）
class _FallbackKeys {
  static const finmindToken = 'finmind_token_fallback';
}

/// 應用程式設定 Repository（包含 Token 管理）
///
/// Token 優先使用 [FlutterSecureStorage] 加密儲存
/// 若平台不支援（如 macOS debug build 無 Keychain 權限），
/// 自動降級為 SharedPreferences（可跨重啟持久化，但未加密）
/// 其他設定使用 SQLite 資料庫
class SettingsRepository implements ISettingsRepository {
  SettingsRepository({required AppDatabase database, SharedPreferences? prefs})
    : _db = database,
      _prefs = prefs;

  final AppDatabase _db;
  SharedPreferences? _prefs;

  /// 標記 Secure Storage 是否可用
  bool? _secureStorageAvailable;

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
      _secureStorageAvailable = false;
    }
    return _secureStorageAvailable!;
  }

  // ==================================================
  // FinMind Token 管理（優先 Secure Storage，降級記憶體暫存）
  // ==================================================

  /// 取得 FinMind Token
  @override
  Future<String?> getFinMindToken() async {
    if (await _isSecureStorageAvailable()) {
      try {
        return await _secureStorage.read(key: _SecureKeys.finmindToken);
      } catch (e, stack) {
        AppLogger.warning(
          'SettingsRepo',
          'SecureStorage 讀取 Token 失敗，改用 SharedPreferences',
          e,
          stack,
        );
      }
    }
    // Fallback: 從 SharedPreferences 讀取（可跨重啟持久化）
    final prefs = await _sharedPrefs;
    return prefs.getString(_FallbackKeys.finmindToken);
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
          'SecureStorage 寫入 Token 失敗，改用 SharedPreferences',
          e,
          stack,
        );
      }
    }
    // Fallback: 存入 SharedPreferences（可跨重啟持久化，但未加密）
    final prefs = await _sharedPrefs;
    await prefs.setString(_FallbackKeys.finmindToken, token);
    AppLogger.warning(
      'SettingsRepo',
      'Token 已存入 SharedPreferences (非加密 fallback)',
    );
  }

  /// 清除 FinMind Token
  @override
  Future<void> clearFinMindToken() async {
    // 清除所有儲存位置（SecureStorage + SharedPreferences fallback）
    try {
      await _secureStorage.delete(key: _SecureKeys.finmindToken);
    } catch (e) {
      AppLogger.debug('SettingsRepo', '清除 SecureStorage Token 失敗: $e');
    }
    final prefs = await _sharedPrefs;
    await prefs.remove(_FallbackKeys.finmindToken);
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
