import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keys for secure storage (sensitive data)
class SecureStorageKeys {
  static const finmindToken = 'finmind_token';
}

/// Repository for app settings (including token management)
class SettingsRepository {
  SettingsRepository({
    required AppDatabase database,
    FlutterSecureStorage? secureStorage,
  }) : _db = database,
       _secureStorage =
           secureStorage ??
           const FlutterSecureStorage(
             aOptions: AndroidOptions(encryptedSharedPreferences: true),
             iOptions: IOSOptions(
               accessibility: KeychainAccessibility.first_unlock,
             ),
           );

  final AppDatabase _db;
  final FlutterSecureStorage _secureStorage;

  // ==========================================
  // FinMind Token Management (Secure Storage)
  // ==========================================

  /// Get the stored FinMind token (from secure storage)
  Future<String?> getFinMindToken() {
    return _secureStorage.read(key: SecureStorageKeys.finmindToken);
  }

  /// Save the FinMind token (to secure storage)
  Future<void> setFinMindToken(String token) {
    return _secureStorage.write(
      key: SecureStorageKeys.finmindToken,
      value: token,
    );
  }

  /// Clear the FinMind token (from secure storage)
  Future<void> clearFinMindToken() {
    return _secureStorage.delete(key: SecureStorageKeys.finmindToken);
  }

  /// Check if token is configured
  Future<bool> hasFinMindToken() async {
    final token = await getFinMindToken();
    return token != null && token.isNotEmpty;
  }

  /// Migrate token from database to secure storage (one-time migration)
  Future<void> migrateTokenToSecureStorage() async {
    // Check if token exists in old database storage
    final oldToken = await _db.getSetting(SettingsKeys.finmindToken);
    if (oldToken != null && oldToken.isNotEmpty) {
      // Check if already migrated
      final existingSecure = await getFinMindToken();
      if (existingSecure == null || existingSecure.isEmpty) {
        // Migrate to secure storage
        await setFinMindToken(oldToken);
      }
      // Clear from database (no longer needed)
      await _db.deleteSetting(SettingsKeys.finmindToken);
    }
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
