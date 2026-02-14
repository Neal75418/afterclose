/// 應用程式設定資料儲存庫介面
///
/// 管理 API Token、最後更新時間、功能開關等應用程式設定。
/// 支援測試時的 Mock 及不同實作。
abstract class ISettingsRepository {
  // ==========================================
  // FinMind Token 管理
  // ==========================================

  /// 取得 FinMind Token
  Future<String?> getFinMindToken();

  /// 儲存 FinMind Token
  Future<void> setFinMindToken(String token);

  /// 清除 FinMind Token
  Future<void> clearFinMindToken();

  /// 檢查是否已設定 Token
  Future<bool> hasFinMindToken();

  /// 將 Token 從舊儲存位置遷移到當前儲存
  Future<void> migrateTokenToSecureStorage();

  // ==========================================
  // 最後更新時間追蹤
  // ==========================================

  /// 取得最後成功更新的日期
  Future<DateTime?> getLastUpdateDate();

  /// 設定最後成功更新的日期
  Future<void> setLastUpdateDate(DateTime date);

  // ==========================================
  // 功能開關
  // ==========================================

  /// 取得是否同步法人資料
  Future<bool> shouldFetchInstitutional();

  /// 設定是否同步法人資料
  Future<void> setFetchInstitutional(bool enabled);

  /// 取得是否同步新聞
  Future<bool> shouldFetchNews();

  /// 設定是否同步新聞
  Future<void> setFetchNews(bool enabled);

  // ==========================================
  // 通用設定存取
  // ==========================================

  /// 依 Key 取得設定值
  Future<String?> getSetting(String key);

  /// 設定值
  Future<void> setSetting(String key, String value);

  /// 刪除設定
  Future<void> deleteSetting(String key);
}
