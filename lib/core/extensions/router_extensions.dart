import 'package:afterclose/domain/models/screening_condition.dart';
import 'package:go_router/go_router.dart';

/// GoRouterState 的型別安全擴充
///
/// 取代 `state.extra as T?` 強制轉型，避免型別不符時的 runtime error。
extension SafeGoRouterState on GoRouterState {
  /// 安全取得 symbols extra（用於股票比較頁面）
  List<String> get symbolsExtra => switch (extra) {
    final List<String> list => list,
    _ => const <String>[],
  };

  /// 安全取得 conditions extra（用於回測頁面）
  List<ScreeningCondition> get conditionsExtra => switch (extra) {
    final List<ScreeningCondition> list => list,
    _ => const <ScreeningCondition>[],
  };
}
