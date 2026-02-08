import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
/// 若平台不支援（如 macOS 無 Keychain 權限），自動降級為記憶體暫存
/// 其他設定使用 SQLite 資料庫
class SettingsRepository {
  SettingsRepository({required AppDatabase database, SharedPreferences? prefs})
    : _db = database,
      _prefs = prefs;

  final AppDatabase _db;
  SharedPreferences? _prefs;

  /// 標記 Secure Storage 是否可用
  bool? _secureStorageAvailable;

  /// SecureStorage 不可用時的記憶體暫存（不寫入磁碟）
  String? _inMemoryToken;

  /// Secure Storage 實例（用於敏感資料如 API Token）
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
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

  // ==========================================
  // FinMind Token 管理（優先 Secure Storage，降級記憶體暫存）
  // ==========================================

  /// 取得 FinMind Token
  Future<String?> getFinMindToken() async {
    if (await _isSecureStorageAvailable()) {
      return _secureStorage.read(key: _SecureKeys.finmindToken);
    }
    // Fallback: 僅從記憶體讀取（不落地磁碟）
    return _inMemoryToken;
  }

  /// 儲存 FinMind Token
  Future<void> setFinMindToken(String token) async {
    if (await _isSecureStorageAvailable()) {
      await _secureStorage.write(key: _SecureKeys.finmindToken, value: token);
    } else {
      // Fallback: 僅存記憶體，重啟 App 後需重新輸入
      _inMemoryToken = token;
      AppLogger.warning('SettingsRepo', 'Token 僅存於記憶體，重啟 App 後需重新輸入');
    }
  }

  /// 清除 FinMind Token
  Future<void> clearFinMindToken() async {
    _inMemoryToken = null;
    // 清除所有儲存位置（含舊版 SharedPreferences 遺留資料）
    try {
      await _secureStorage.delete(key: _SecureKeys.finmindToken);
    } catch (e) {
      AppLogger.debug('SettingsRepo', '清除 SecureStorage Token 失敗: $e');
    }
    final prefs = await _sharedPrefs;
    await prefs.remove(_FallbackKeys.finmindToken);
  }

  /// 檢查是否已設定 Token
  Future<bool> hasFinMindToken() async {
    final token = await getFinMindToken();
    return token != null && token.isNotEmpty;
  }

  /// 將 Token 從舊儲存位置遷移到當前儲存（一次性遷移）
  ///
  /// 遷移來源優先順序：
  /// 1. Database (最舊)
  /// 2. SharedPreferences 舊 key (舊版)
  Future<void> migrateTokenToSecureStorage() async {
    // 檢查是否已有 Token（無論是 SecureStorage 或 fallback）
    final existingToken = await getFinMindToken();
    if (existingToken != null && existingToken.isNotEmpty) {
      // 已遷移，清除舊資料
      await _db.deleteSetting(SettingsKeys.finmindToken);
      final prefs = await _sharedPrefs;
      await prefs.remove('finmind_api_token'); // 舊 key
      return;
    }

    // 嘗試從 Database 遷移
    final dbToken = await _db.getSetting(SettingsKeys.finmindToken);
    if (dbToken != null && dbToken.isNotEmpty) {
      await setFinMindToken(dbToken);
      await _db.deleteSetting(SettingsKeys.finmindToken);
      return;
    }

    // 嘗試從 SharedPreferences 舊 key 遷移
    final prefs = await _sharedPrefs;
    final prefToken = prefs.getString('finmind_api_token');
    if (prefToken != null && prefToken.isNotEmpty) {
      await setFinMindToken(prefToken);
      await prefs.remove('finmind_api_token');
    }
  }

  // ==========================================
  // 最後更新時間追蹤
  // ==========================================

  /// 取得最後成功更新的日期
  Future<DateTime?> getLastUpdateDate() async {
    final value = await _db.getSetting(SettingsKeys.lastUpdateDate);
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  /// 設定最後成功更新的日期
  Future<void> setLastUpdateDate(DateTime date) {
    return _db.setSetting(SettingsKeys.lastUpdateDate, date.toIso8601String());
  }

  // ==========================================
  // 功能開關
  // ==========================================

  /// 取得是否同步法人資料
  Future<bool> shouldFetchInstitutional() async {
    final value = await _db.getSetting(SettingsKeys.fetchInstitutional);
    return value == 'true';
  }

  /// 設定是否同步法人資料
  Future<void> setFetchInstitutional(bool enabled) {
    return _db.setSetting(SettingsKeys.fetchInstitutional, enabled.toString());
  }

  /// 取得是否同步新聞
  Future<bool> shouldFetchNews() async {
    final value = await _db.getSetting(SettingsKeys.fetchNews);
    // 預設為 true
    return value != 'false';
  }

  /// 設定是否同步新聞
  Future<void> setFetchNews(bool enabled) {
    return _db.setSetting(SettingsKeys.fetchNews, enabled.toString());
  }

  // ==========================================
  // 通用設定存取
  // ==========================================

  /// 依 Key 取得設定值
  Future<String?> getSetting(String key) {
    return _db.getSetting(key);
  }

  /// 設定值
  Future<void> setSetting(String key, String value) {
    return _db.setSetting(key, value);
  }

  /// 刪除設定
  Future<void> deleteSetting(String key) {
    return _db.deleteSetting(key);
  }
}
