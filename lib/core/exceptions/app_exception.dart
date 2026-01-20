/// Base exception for all app exceptions
sealed class AppException implements Exception {
  const AppException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() =>
      'AppException: $message${cause != null ? ' ($cause)' : ''}';
}

/// Network related exceptions
final class NetworkException extends AppException {
  const NetworkException(super.message, [super.cause]);
}

/// API response exceptions
final class ApiException extends AppException {
  const ApiException(super.message, this.statusCode, [super.cause]);

  final int? statusCode;

  @override
  String toString() =>
      'ApiException: $message (status: $statusCode)${cause != null ? ' ($cause)' : ''}';
}

/// Rate limit exceeded
final class RateLimitException extends AppException {
  const RateLimitException([
    super.message = 'API rate limit exceeded. Please try again later.',
    super.cause,
  ]);
}

/// Database exceptions
final class DatabaseException extends AppException {
  const DatabaseException(super.message, [super.cause]);
}

/// Parse/format exceptions
final class ParseException extends AppException {
  const ParseException(super.message, [super.cause]);
}

/// Configuration exceptions (e.g., missing token)
final class ConfigException extends AppException {
  const ConfigException(super.message, [super.cause]);
}

/// Token not configured
final class TokenNotConfiguredException extends ConfigException {
  const TokenNotConfiguredException([
    super.message =
        'FinMind API token not configured. Please add your token in Settings.',
  ]);
}

/// Analysis exceptions
final class AnalysisException extends AppException {
  const AnalysisException(super.message, [super.cause]);
}

/// Insufficient data for analysis
final class InsufficientDataException extends AnalysisException {
  const InsufficientDataException(String symbol, int required, int actual)
    : super('Insufficient data for $symbol: need $required days, got $actual');
}
