/// 函數式結果型別，用於統一錯誤處理
///
/// 提供型別安全的方式表示成功或失敗，避免使用例外。
/// 靈感來自 Rust 的 Result 型別與函數式程式設計模式。
///
/// 使用範例：
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
/// // 使用結果
/// final result = getUser(1);
/// if (result.isSuccess) {
///   print(result.data);
/// } else {
///   print(result.error);
/// }
///
/// // 或使用 fold
/// result.fold(
///   onSuccess: (user) => print(user),
///   onFailure: (error) => print(error),
/// );
/// ```
sealed class Result<T> {
  const Result._();

  /// 建立成功結果
  const factory Result.success(T data) = Success<T>;

  /// 建立失敗結果
  const factory Result.failure(String error, [Object? exception]) = Failure<T>;

  /// 是否為成功
  bool get isSuccess;

  /// 是否為失敗
  bool get isFailure => !isSuccess;

  /// 成功時取得資料，否則為 null
  T? get data;

  /// 失敗時取得錯誤訊息，否則為 null
  String? get error;

  /// 失敗時取得例外物件，否則為 null
  Object? get exception;

  /// 使用函數轉換成功值
  Result<R> map<R>(R Function(T data) transform);

  /// 使用回傳 Result 的函數轉換成功值
  Result<R> flatMap<R>(Result<R> Function(T data) transform);

  /// 根據成功或失敗執行不同回呼
  R fold<R>({
    required R Function(T data) onSuccess,
    required R Function(String error, Object? exception) onFailure,
  });

  /// 取得資料，失敗時拋出例外
  T getOrThrow();

  /// 取得資料，失敗時回傳預設值
  T getOrDefault(T defaultValue);

  /// 取得資料，失敗時計算預設值
  T getOrElse(T Function() compute);
}

/// Result 的成功變體
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

/// Result 的失敗變體
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

/// 非同步 Result 操作擴充
extension ResultFutureExtension<T> on Future<Result<T>> {
  /// 非同步轉換成功值
  Future<Result<R>> mapAsync<R>(R Function(T data) transform) async {
    final result = await this;
    return result.map(transform);
  }

  /// 非同步 flatMap 成功值
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

/// 執行函數並包裝結果的輔助函數
Result<T> runCatching<T>(T Function() action, {String? errorPrefix}) {
  try {
    return Result.success(action());
  } catch (e) {
    final prefix = errorPrefix != null ? '$errorPrefix: ' : '';
    return Result.failure('$prefix$e', e);
  }
}

/// 執行非同步函數並包裝結果的輔助函數
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
