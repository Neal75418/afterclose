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

/// 分析運算例外
final class AnalysisException extends AppException {
  const AnalysisException(super.message, [super.cause]);
}

/// 分析所需資料不足
final class InsufficientDataException extends AnalysisException {
  const InsufficientDataException(String symbol, int required, int actual)
    : super('$symbol 資料不足：需要 $required 天，僅有 $actual 天');
}
