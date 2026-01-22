/// A functional result type for unified error handling
///
/// Provides a type-safe way to represent success or failure without exceptions.
/// Inspired by Rust's Result type and functional programming patterns.
///
/// Usage:
/// ```dart
/// Result<User> getUser(int id) {
///   try {
///     final user = fetchUser(id);
///     return Result.success(user);
///   } catch (e) {
///     return Result.failure('Failed to fetch user: $e');
///   }
/// }
///
/// // Using the result
/// final result = getUser(1);
/// if (result.isSuccess) {
///   print(result.data);
/// } else {
///   print(result.error);
/// }
///
/// // Or with fold
/// result.fold(
///   onSuccess: (user) => print(user),
///   onFailure: (error) => print(error),
/// );
/// ```
sealed class Result<T> {
  const Result._();

  /// Create a success result with data
  const factory Result.success(T data) = Success<T>;

  /// Create a failure result with error message
  const factory Result.failure(String error, [Object? exception]) = Failure<T>;

  /// Whether this result is a success
  bool get isSuccess;

  /// Whether this result is a failure
  bool get isFailure => !isSuccess;

  /// Get the data if success, null otherwise
  T? get data;

  /// Get the error message if failure, null otherwise
  String? get error;

  /// Get the exception if failure, null otherwise
  Object? get exception;

  /// Transform the success value using a function
  Result<R> map<R>(R Function(T data) transform);

  /// Transform the success value using a function that returns a Result
  Result<R> flatMap<R>(Result<R> Function(T data) transform);

  /// Execute different callbacks based on success or failure
  R fold<R>({
    required R Function(T data) onSuccess,
    required R Function(String error, Object? exception) onFailure,
  });

  /// Get data or throw if failure
  T getOrThrow();

  /// Get data or return a default value if failure
  T getOrDefault(T defaultValue);

  /// Get data or compute a default value if failure
  T getOrElse(T Function() compute);
}

/// Success variant of Result
final class Success<T> extends Result<T> {
  const Success(this._data) : super._();

  final T _data;

  @override
  bool get isSuccess => true;

  @override
  T get data => _data;

  @override
  String? get error => null;

  @override
  Object? get exception => null;

  @override
  Result<R> map<R>(R Function(T data) transform) {
    return Result.success(transform(_data));
  }

  @override
  Result<R> flatMap<R>(Result<R> Function(T data) transform) {
    return transform(_data);
  }

  @override
  R fold<R>({
    required R Function(T data) onSuccess,
    required R Function(String error, Object? exception) onFailure,
  }) {
    return onSuccess(_data);
  }

  @override
  T getOrThrow() => _data;

  @override
  T getOrDefault(T defaultValue) => _data;

  @override
  T getOrElse(T Function() compute) => _data;

  @override
  String toString() => 'Success($_data)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<T> &&
          runtimeType == other.runtimeType &&
          _data == other._data;

  @override
  int get hashCode => _data.hashCode;
}

/// Failure variant of Result
final class Failure<T> extends Result<T> {
  const Failure(this._error, [this._exception]) : super._();

  final String _error;
  final Object? _exception;

  @override
  bool get isSuccess => false;

  @override
  T? get data => null;

  @override
  String get error => _error;

  @override
  Object? get exception => _exception;

  @override
  Result<R> map<R>(R Function(T data) transform) {
    return Result.failure(_error, _exception);
  }

  @override
  Result<R> flatMap<R>(Result<R> Function(T data) transform) {
    return Result.failure(_error, _exception);
  }

  @override
  R fold<R>({
    required R Function(T data) onSuccess,
    required R Function(String error, Object? exception) onFailure,
  }) {
    return onFailure(_error, _exception);
  }

  @override
  T getOrThrow() {
    if (_exception != null) throw _exception;
    throw StateError(_error);
  }

  @override
  T getOrDefault(T defaultValue) => defaultValue;

  @override
  T getOrElse(T Function() compute) => compute();

  @override
  String toString() => 'Failure($_error)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure<T> &&
          runtimeType == other.runtimeType &&
          _error == other._error;

  @override
  int get hashCode => _error.hashCode;
}

/// Extension for async Result operations
extension ResultFutureExtension<T> on Future<Result<T>> {
  /// Map the success value asynchronously
  Future<Result<R>> mapAsync<R>(R Function(T data) transform) async {
    final result = await this;
    return result.map(transform);
  }

  /// FlatMap the success value asynchronously
  Future<Result<R>> flatMapAsync<R>(
    Future<Result<R>> Function(T data) transform,
  ) async {
    final result = await this;
    if (result.isSuccess) {
      return transform(result.data as T);
    }
    return Result.failure(result.error!, result.exception);
  }
}

/// Helper to run a function and wrap result
Result<T> runCatching<T>(T Function() action, {String? errorPrefix}) {
  try {
    return Result.success(action());
  } catch (e) {
    final prefix = errorPrefix != null ? '$errorPrefix: ' : '';
    return Result.failure('$prefix$e', e);
  }
}

/// Helper to run an async function and wrap result
Future<Result<T>> runCatchingAsync<T>(
  Future<T> Function() action, {
  String? errorPrefix,
}) async {
  try {
    return Result.success(await action());
  } catch (e) {
    final prefix = errorPrefix != null ? '$errorPrefix: ' : '';
    return Result.failure('$prefix$e', e);
  }
}
