/// 應用程式例外的基礎類別
///
/// 所有自定義例外都應繼承此類別，以便統一處理錯誤。
sealed class AppException implements Exception {
  const AppException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() =>
      'AppException: $message${cause != null ? ' ($cause)' : ''}';
}

/// 網路相關例外
final class NetworkException extends AppException {
  const NetworkException(super.message, [super.cause]);
}

/// API 回應例外
final class ApiException extends AppException {
  const ApiException(super.message, this.statusCode, [super.cause]);

  final int? statusCode;

  @override
  String toString() =>
      'ApiException: $message (status: $statusCode)${cause != null ? ' ($cause)' : ''}';
}

/// API 請求頻率超過限制
final class RateLimitException extends AppException {
  const RateLimitException([
    super.message = 'API 請求頻率超過限制，請稍後再試。',
    super.cause,
  ]);
}

/// 資料庫例外
final class DatabaseException extends AppException {
  const DatabaseException(super.message, [super.cause]);
}

/// 解析或格式錯誤例外
final class ParseException extends AppException {
  const ParseException(super.message, [super.cause]);
}

/// 設定相關例外（如缺少 API Token）
final class ConfigException extends AppException {
  const ConfigException(super.message, [super.cause]);
}

/// FinMind API Token 未設定
final class TokenNotConfiguredException extends ConfigException {
  const TokenNotConfiguredException([
    super.message = 'FinMind API Token 尚未設定，請至設定頁面新增您的 Token。',
  ]);
}

/// API Token 格式無效
final class InvalidTokenException extends ConfigException {
  const InvalidTokenException([super.message = 'API Token 格式無效']);
}

/// 使用者輸入驗證例外
///
/// 用於 repository 邊界輸入合法性檢查（e.g. quantity <= 0、賣出超過持有）。
/// [messageKey] 是 i18n key（如 `portfolio.sellExceedsHolding`）；
/// [ErrorDisplay] 會用它做 `.tr()`，無翻譯時 easy_localization 回 key 本身。
///
/// 過去這類錯誤是 `throw ArgumentError(...)` / `throw StateError(...)`，會被
/// `ErrorDisplay` 視為未知例外退到 `error.unknown` — 使用者得不到具體訊息。
final class ValidationException extends AppException {
  const ValidationException(this.messageKey, [Object? cause])
    : super(messageKey, cause);

  /// i18n translation key（如 `portfolio.quantityMustBePositive`）
  final String messageKey;
}
