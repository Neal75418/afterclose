import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
/// Token 優先使用 [FlutterSecureStorage] 加密儲存。
/// 若平台不支援（如 macOS debug build 無 Keychain 權限），
/// 降級為記憶體暫存（app 重啟後需重新輸入，不寫入未加密儲存）。
/// 其他設定使用 SQLite 資料庫
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
          'SecureStorage 讀取失敗，使用記憶體暫存',
          e,
          stack,
        );
      }
    }
    // Fallback: 記憶體暫存（app 重啟後遺失）
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
