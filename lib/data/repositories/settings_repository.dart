import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences Key 常數
class _PrefKeys {
  static const finmindToken = 'finmind_api_token';
}

/// 應用程式設定 Repository（包含 Token 管理）
class SettingsRepository {
  SettingsRepository({required AppDatabase database, SharedPreferences? prefs})
    : _db = database,
      _prefs = prefs;

  final AppDatabase _db;
  SharedPreferences? _prefs;

  /// 取得 SharedPreferences 實例（延遲初始化）
  Future<SharedPreferences> get _sharedPrefs async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  // ==========================================
  // FinMind Token 管理
  // ==========================================

  /// 取得 FinMind Token
  Future<String?> getFinMindToken() async {
    final prefs = await _sharedPrefs;
    return prefs.getString(_PrefKeys.finmindToken);
  }

  /// 儲存 FinMind Token
  Future<void> setFinMindToken(String token) async {
    final prefs = await _sharedPrefs;
    await prefs.setString(_PrefKeys.finmindToken, token);
  }

  /// 清除 FinMind Token
  Future<void> clearFinMindToken() async {
    final prefs = await _sharedPrefs;
    await prefs.remove(_PrefKeys.finmindToken);
  }

  /// 檢查是否已設定 Token
  Future<bool> hasFinMindToken() async {
    final token = await getFinMindToken();
    return token != null && token.isNotEmpty;
  }

  /// 將 Token 從 Database 遷移到 SharedPreferences（一次性遷移）
  Future<void> migrateTokenToSecureStorage() async {
    // 檢查 Database 中是否有舊的 Token
    final oldToken = await _db.getSetting(SettingsKeys.finmindToken);
    if (oldToken != null && oldToken.isNotEmpty) {
      // 檢查是否已遷移
      final existingToken = await getFinMindToken();
      if (existingToken == null || existingToken.isEmpty) {
        // 遷移到 SharedPreferences
        await setFinMindToken(oldToken);
      }
      // 從 Database 清除（不再需要）
      await _db.deleteSetting(SettingsKeys.finmindToken);
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
