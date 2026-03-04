/// 從 [list] 尾端取出最多 [count] 個元素，以反序回傳（最新在前）。
///
/// [skip] 可跳過尾端若干元素再開始取。
/// 長度不足時回傳可取得的部分，不會拋出例外。
///
/// ```dart
/// lastN([1, 2, 3, 4, 5], 3);           // [5, 4, 3]
/// lastN([1, 2, 3, 4, 5], 3, skip: 1);  // [4, 3, 2]
/// ```
List<T> lastN<T>(List<T> list, int count, {int skip = 0}) {
  final end = (list.length - skip).clamp(0, list.length);
  final start = (end - count).clamp(0, end);
  return list.sublist(start, end).reversed.toList();
}
