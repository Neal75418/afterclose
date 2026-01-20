import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';

/// Repository for app settings (including token management)
class SettingsRepository {
  SettingsRepository({required AppDatabase database}) : _db = database;

  final AppDatabase _db;

  // ==========================================
  // FinMind Token Management
  // ==========================================

  /// Get the stored FinMind token
  Future<String?> getFinMindToken() {
    return _db.getSetting(SettingsKeys.finmindToken);
  }

  /// Save the FinMind token
  Future<void> setFinMindToken(String token) {
    return _db.setSetting(SettingsKeys.finmindToken, token);
  }

  /// Clear the FinMind token
  Future<void> clearFinMindToken() {
    return _db.deleteSetting(SettingsKeys.finmindToken);
  }

  /// Check if token is configured
  Future<bool> hasFinMindToken() async {
    final token = await getFinMindToken();
    return token != null && token.isNotEmpty;
  }

  // ==========================================
  // Last Update Tracking
  // ==========================================

  /// Get the last successful update date
  Future<DateTime?> getLastUpdateDate() async {
    final value = await _db.getSetting(SettingsKeys.lastUpdateDate);
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  /// Set the last successful update date
  Future<void> setLastUpdateDate(DateTime date) {
    return _db.setSetting(SettingsKeys.lastUpdateDate, date.toIso8601String());
  }

  // ==========================================
  // Feature Toggles
  // ==========================================

  /// Get whether to fetch institutional data
  Future<bool> shouldFetchInstitutional() async {
    final value = await _db.getSetting(SettingsKeys.fetchInstitutional);
    return value == 'true';
  }

  /// Set whether to fetch institutional data
  Future<void> setFetchInstitutional(bool enabled) {
    return _db.setSetting(SettingsKeys.fetchInstitutional, enabled.toString());
  }

  /// Get whether to fetch news
  Future<bool> shouldFetchNews() async {
    final value = await _db.getSetting(SettingsKeys.fetchNews);
    // Default to true if not set
    return value != 'false';
  }

  /// Set whether to fetch news
  Future<void> setFetchNews(bool enabled) {
    return _db.setSetting(SettingsKeys.fetchNews, enabled.toString());
  }

  // ==========================================
  // Generic Settings Access
  // ==========================================

  /// Get any setting by key
  Future<String?> getSetting(String key) {
    return _db.getSetting(key);
  }

  /// Set any setting
  Future<void> setSetting(String key, String value) {
    return _db.setSetting(key, value);
  }

  /// Delete a setting
  Future<void> deleteSetting(String key) {
    return _db.deleteSetting(key);
  }
}
