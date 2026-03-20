/// 應用程式設定資料儲存庫介面
///
/// 管理 API Token、最後更新時間、功能開關等應用程式設定。
/// 支援測試時的 Mock 及不同實作。
abstract class ISettingsRepository {
  // ==================================================
  // FinMind Token 管理
  // ==================================================

  /// 取得 FinMind Token
  Future<String?> getFinMindToken();

  /// 儲存 FinMind Token
  Future<void> setFinMindToken(String token);

  /// 清除 FinMind Token
  Future<void> clearFinMindToken();

  /// 檢查是否已設定 Token
  Future<bool> hasFinMindToken();

  // ==================================================
  // 通用設定存取
  // ==================================================

  /// 依 Key 取得設定值
  Future<String?> getSetting(String key);

  /// 設定值
  Future<void> setSetting(String key, String value);

  /// 刪除設定
  Future<void> deleteSetting(String key);
}
