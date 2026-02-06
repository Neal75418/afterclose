/// copyWith 中用於區分「未傳入參數」與「傳入 null」的哨兵值。
///
/// 使用方式：
/// ```dart
/// MyState copyWith({Object? field = sentinel}) {
///   return MyState(
///     field: field == sentinel ? this.field : field as String?,
///   );
/// }
/// ```
const Object sentinel = Object();
